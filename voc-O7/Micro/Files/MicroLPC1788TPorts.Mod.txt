MODULE MicroLPC1788TPorts;

	(*
		Alexander Shiryaev, 2016.04, 2017.04

		UM10470,
			LPC178x/7x User manual

		LPC17{73,74,76,77,78,85,86,87,88}
	*)

	IMPORT SYSTEM, ARMv7M := MicroARMv7M,
		MCU := MicroLPC1788, PinCfg := MicroLPC1788PinCfg,
		Sys := MicroLPC1788System;

	CONST
		maxPorts* = 5;
			UART0* = 0;
			UART1* = 1;
			UART2* = 2;
			UART3* = 3;
			UART4* = 4;

		parityNone* = 0; parityOdd* = 8; parityEven* = 16 + 8;

		DLE* = 10X; ETX* = 03X;

		maxInfoBytesIn* = 40;
		maxInfoBytesOut* = 40;

		outBufLen = 512; (* 2^n; >= maxInfoBytesOut + 2 *)

		inBufLen = 128; (* 2^n; >= maxInfoBytesIn + 2 *)

		(* UARTx LSR bits: *)
			RDR = 0; OE = 1; PE = 2; FE = 3; BI = 4; THRE = 5; TEMT = 6; RXFE = 7;

	TYPE
		MessageReceived* = PROCEDURE (id: CHAR; a: ARRAY OF CHAR; len: INTEGER);

		Port* = RECORD
			IIR, LSR, THR, RBR: INTEGER;

			ISER, ICER: INTEGER;
				intS: SET;

			(* out *)
				outFree: INTEGER;
				(* W *)
					outW: INTEGER; (* writer *)
				(* R *)
					outR: INTEGER; (* reader *)
					outState: INTEGER;
					outN: INTEGER;
				outBusy: BOOLEAN;

			(* in *)
				inFree: INTEGER;
				(* W *)
					inW: INTEGER; (* writer *)
					inW1, inFree1, inInfoBytes: INTEGER;
					inState: INTEGER;
					inIgnore: BOOLEAN;
				(* R *)
					inR: INTEGER; (* reader *)

			h: MessageReceived;

			inBuf: ARRAY inBufLen OF CHAR;
			outBuf: ARRAY outBufLen OF CHAR
		END;

		Proc0 = PROCEDURE (adr: INTEGER);

	VAR
		interrupt: Proc0;
		pAdr: ARRAY maxPorts OF INTEGER;

		UDLL, UDLM, UFDR: INTEGER; (* for Init only *)

	PROCEDURE SendNext (VAR p: Port);
		VAR x: CHAR;

		PROCEDURE OutBufGet (VAR p: Port): CHAR;
			VAR x: CHAR;
		BEGIN
			x := p.outBuf[p.outR];
			p.outR := (p.outR + 1) MOD outBufLen;

			INC(p.outFree)
		RETURN x
		END OutBufGet;

	BEGIN
		IF p.outState = 0 THEN (* outside message *)
			IF p.outFree < outBufLen THEN
				p.outBusy := TRUE;
				p.outState := 1;
				SYSTEM.PUT(p.THR, ORD(DLE)) (* DLE before ID *)
			ELSE
				p.outBusy := FALSE
			END
		ELSIF p.outState = 1 THEN (* DLE before ID sent *)
			p.outState := 2;
			x := OutBufGet(p);
			ASSERT(x # DLE); (* check outBuf consistency *)
			ASSERT(x # ETX); (* check outBuf consistency *)
			SYSTEM.PUT(p.THR, ORD(x)) (* ID *)
		ELSIF p.outState = 2 THEN (* ID sent *)
			p.outN := ORD(OutBufGet(p)); (* number of infobytes *)
			ASSERT(p.outN <= maxInfoBytesOut); (* check outBuf consistency *)
			IF p.outN = 0 THEN
				p.outState := 6;
				SYSTEM.PUT(p.THR, ORD(DLE)) (* DLE before ETX *)
			ELSE (* outN > 0 *)
				x := OutBufGet(p);
				DEC(p.outN);
				IF x = DLE THEN
					p.outState := 4
				ELSE
					p.outState := 3
				END;
				SYSTEM.PUT(p.THR, ORD(x))
			END
		ELSIF p.outState = 3 THEN (* infobyte sent *)
			IF p.outN = 0 THEN
				p.outState := 6;
				SYSTEM.PUT(p.THR, ORD(DLE)) (* DLE before ETX *)
			ELSE (* outN > 0 *)
				x := OutBufGet(p);
				DEC(p.outN);
				IF x = DLE THEN
					p.outState := 4
				END;
				SYSTEM.PUT(p.THR, ORD(x))
			END
		ELSIF p.outState = 4 THEN (* first DLE of double DLE inside message sent *)
			IF p.outN = 0 THEN
				p.outState := 5
			ELSE
				p.outState := 3
			END;
			SYSTEM.PUT(p.THR, ORD(DLE))
		ELSIF p.outState = 5 THEN (* send DLE before ETX *)
			p.outState := 6;
			SYSTEM.PUT(p.THR, ORD(DLE)) (* DLE before ETX *)
		ELSIF p.outState = 6 THEN (* DLE before ETX sent *)
			p.outState := 0;
			SYSTEM.PUT(p.THR, ORD(ETX))
		ELSE ASSERT(FALSE)
		END
	END SendNext;

	(* This procedure may be called from RX interrupts handler only *)
	PROCEDURE ByteReceived (VAR p: Port; x: CHAR);
	BEGIN
		IF p.inState = 0 THEN (* outside *)
			IF x = DLE THEN
				p.inState := 1
			END
		ELSIF p.inState = 1 THEN (* initial DLE already received *)
			IF (x = DLE) OR (x = ETX) THEN
				p.inState := 0
			ELSE (* ID *)
				IF p.inFree >= 2 THEN (* free space for empty message available *)
					p.inBuf[p.inW] := x;

					p.inW1 := (p.inW + 2) MOD inBufLen;

					p.inFree1 := p.inFree - 2;
					p.inIgnore := FALSE;
					p.inState := 2
				ELSE (* if this message will be received, it will be lost *)
					p.inIgnore := TRUE;
					p.inState := 2
				END;
				p.inInfoBytes := 0
			END
		ELSIF p.inState = 2 THEN (* inside; ID already received *)
			IF x = DLE THEN
				p.inState := 3
			ELSE
				IF p.inInfoBytes < maxInfoBytesIn THEN
					IF ~p.inIgnore THEN
						IF p.inFree1 > 0 THEN
							p.inBuf[p.inW1] := x;

							p.inW1 := (p.inW1 + 1) MOD inBufLen;

							DEC(p.inFree1)
						ELSE (* if this message will be received, it will be lost *)
							p.inIgnore := TRUE
						END
					END;
					INC(p.inInfoBytes)
				ELSE
					p.inState := 0
				END
			END
		ELSIF p.inState = 3 THEN (* inside; first DLE already received *)
			IF x = DLE THEN (* double DLE *)
				IF p.inInfoBytes < maxInfoBytesIn THEN
					IF ~p.inIgnore THEN
						IF p.inFree1 > 0 THEN
							p.inBuf[p.inW1] := DLE;

							p.inW1 := (p.inW1 + 1) MOD inBufLen;

							DEC(p.inFree1)
						ELSE (* if this message will be received, it will be lost *)
							p.inIgnore := TRUE
						END
					END;
					INC(p.inInfoBytes);
					p.inState := 2
				ELSE
					p.inState := 0
				END
			ELSIF x = ETX THEN
				IF ~p.inIgnore THEN

					p.inBuf[(p.inW + 1) MOD inBufLen] := CHR(p.inInfoBytes);

					p.inW := p.inW1;
					p.inFree := p.inFree1
				END;
				p.inState := 0
			ELSE
				p.inState := 0
			END
		ELSE ASSERT(FALSE)
		END
	END ByteReceived;

	PROCEDURE Interrupt (VAR p: Port);
		VAR x: SET; t, n, m: INTEGER;
	BEGIN
		m := 400H;
		SYSTEM.GET(p.IIR, t);
		WHILE ~ODD(t) & (m > 0) DO
			n := 400H;
			SYSTEM.GET(p.LSR, x);
			WHILE (x * {RDR,OE,PE,FE,BI,RXFE} # {}) & (n > 0) DO
				IF RDR IN x THEN
					SYSTEM.GET(p.RBR, t);
					ByteReceived(p, CHR(t))
				END;
				DEC(n);
				SYSTEM.GET(p.LSR, x)
			END;
			IF THRE IN x THEN SendNext(p) END;

			DEC(m);
			SYSTEM.GET(p.IIR, t)
		END
	END Interrupt;

	PROCEDURE* InterruptsHandler0;
	BEGIN interrupt(pAdr[0])
	END InterruptsHandler0;

	PROCEDURE* InterruptsHandler1;
	BEGIN interrupt(pAdr[1])
	END InterruptsHandler1;

	PROCEDURE* InterruptsHandler2;
	BEGIN interrupt(pAdr[2])
	END InterruptsHandler2;

	PROCEDURE* InterruptsHandler3;
	BEGIN interrupt(pAdr[3])
	END InterruptsHandler3;

	PROCEDURE* InterruptsHandler4;
	BEGIN interrupt(pAdr[4])
	END InterruptsHandler4;

	PROCEDURE Init* (VAR p: Port; n, pinsVariant,
			baud, parity: INTEGER; h: MessageReceived);
		CONST
			(* UARTx IER bits: *)
				RBRIE = 0; THREIE = 1; RXIE = 2; ABEOINTEN = 8; ABTOINTEN = 9;
			(* UARTx FCR bits: *)
				FIFOEN = 0; RXFIFORES = 1; TXFIFORES = 2;
			(* UARTx LCR bits: *)
				DLAB = 7;
(*
			(* UARTx TER bits: *)
				TXEN = 7;
*)
		VAR x, intS: SET;
			Int, ISER, ICER, UCLK, divisor: INTEGER;
			PCUART: INTEGER;
			THR, RBR, IIR, LSR, IER, LCR, FCR, v: INTEGER;
			RXPinPort, RXPinN, RXPinFunc, TXPinPort, TXPinN, TXPinFunc: INTEGER;
			type, mode: INTEGER;
			interrupt0: Proc0;

		PROCEDURE Match (desiredBaud, matchBaud, DL, FDR: INTEGER);
		BEGIN
			IF desiredBaud = matchBaud THEN
				SYSTEM.PUT(UDLM, DL DIV 100H); SYSTEM.PUT(UDLL, DL MOD 100H);
				SYSTEM.PUT(UFDR, FDR)
			END
		END Match;

	BEGIN
		ASSERT(baud > 0);
		ASSERT((parity = parityNone) OR (parity = parityEven) OR (parity = parityOdd));

		IF n = UART0 THEN
			Int := MCU.UART0Int;
			PCUART := 3;
			ASSERT(pinsVariant = 0);
				RXPinPort := PinCfg.P0; RXPinN := 3; RXPinFunc := 1;
				TXPinPort := PinCfg.P0; TXPinN := 2; TXPinFunc := 1;
			IER := MCU.UART0IER;
			LCR := MCU.UART0LCR;
			FCR := MCU.UART0FCR;
			UDLL := MCU.UART0DLL; UDLM := MCU.UART0DLM;
				UFDR := MCU.UART0FDR;
			THR := MCU.UART0THR; RBR := MCU.UART0RBR;
			IIR := MCU.UART0IIR; LSR := MCU.UART0LSR
		ELSIF n = UART1 THEN
			Int := MCU.UART1Int;
			PCUART := 4;
			ASSERT(pinsVariant = 0);
				RXPinPort := PinCfg.P2; RXPinN := 1; RXPinFunc := 2;
				TXPinPort := PinCfg.P2; TXPinN := 0; TXPinFunc := 2;
			IER := MCU.UART1IER;
			LCR := MCU.UART1LCR;
			FCR := MCU.UART1FCR;
			UDLL := MCU.UART1DLL; UDLM := MCU.UART1DLM;
				UFDR := MCU.UART1FDR;
			THR := MCU.UART1THR; RBR := MCU.UART1RBR;
			IIR := MCU.UART1IIR; LSR := MCU.UART1LSR
		ELSIF n = UART2 THEN
			Int := MCU.UART2Int;
			PCUART := 24;
			ASSERT(pinsVariant = 0);
				RXPinPort := PinCfg.P0; RXPinN := 11; RXPinFunc := 1;
				TXPinPort := PinCfg.P0; TXPinN := 10; TXPinFunc := 1;
			IER := MCU.UART2IER;
			LCR := MCU.UART2LCR;
			FCR := MCU.UART2FCR;
			UDLL := MCU.UART2DLL; UDLM := MCU.UART2DLM;
				UFDR := MCU.UART2FDR;
			THR := MCU.UART2THR; RBR := MCU.UART2RBR;
			IIR := MCU.UART2IIR; LSR := MCU.UART2LSR
		ELSIF n = UART3 THEN
			Int := MCU.UART3Int;
			PCUART := 25;
			ASSERT(pinsVariant = 0);
				RXPinPort := PinCfg.P4; RXPinN := 29; RXPinFunc := 2;
				TXPinPort := PinCfg.P4; TXPinN := 28; TXPinFunc := 2;
			IER := MCU.UART3IER;
			LCR := MCU.UART3LCR;
			FCR := MCU.UART3FCR;
			UDLL := MCU.UART3DLL; UDLM := MCU.UART3DLM;
				UFDR := MCU.UART3FDR;
			THR := MCU.UART3THR; RBR := MCU.UART3RBR;
			IIR := MCU.UART3IIR; LSR := MCU.UART3LSR
		ELSIF n = UART4 THEN
			Int := MCU.UART4Int;
			PCUART := 8;
			ASSERT(pinsVariant = 0);
				RXPinPort := PinCfg.P5; RXPinN := 3; RXPinFunc := 4;
				TXPinPort := PinCfg.P5; TXPinN := 4; TXPinFunc := 4;
			IER := MCU.UART4IER;
			LCR := MCU.UART4LCR;
			FCR := MCU.UART4FCR;
			UDLL := MCU.UART4DLL; UDLM := MCU.UART4DLM;
				UFDR := MCU.UART4FDR;
			THR := MCU.UART4THR; RBR := MCU.UART4RBR;
			IIR := MCU.UART4IIR; LSR := MCU.UART4LSR
		ELSE ASSERT(FALSE)
		END;

		intS := {Int MOD 32};
		ISER := ARMv7M.NVICISER0 + (Int DIV 32) * 4;
		ICER := ARMv7M.NVICICER0 + (Int DIV 32) * 4;

		(* disable interrupts *)
			SYSTEM.PUT(ICER, intS); ARMv7M.ISB;
			SYSTEM.PUT(IER, {});

		p.ISER := ISER; p.ICER := ICER; p.intS := intS;
		p.IIR := IIR; p.LSR := LSR; p.THR := THR; p.RBR := RBR;

		p.h := h;

		(* out *)
			p.outW := 0;
			p.outR := 0;
			p.outFree := outBufLen;
			p.outState := 0;
			p.outBusy := FALSE;

		(* in *)
			p.inW := 0;
			p.inFree := inBufLen;
			p.inState := 0;
			p.inR := 0;

		SYSTEM.GET(MCU.PCONP, x);
		SYSTEM.PUT(MCU.PCONP, x - {PCUART}); (* disable UART power *)

		SYSTEM.GET(MCU.PCONP, x);
		SYSTEM.PUT(MCU.PCONP, x + {PCUART}); (* enable UART power *)

		(* configure UART pins *)
			(* RX *)
				type := PinCfg.Type(RXPinPort, RXPinN);
				IF type = PinCfg.I THEN mode := 0 ELSE mode := PinCfg.pullUp END;
				PinCfg.Configure(RXPinPort, RXPinN, RXPinFunc,
					mode, PinCfg.DefaultOpts(RXPinPort, RXPinN));
			(* TX *)
				type := PinCfg.Type(TXPinPort, TXPinN);
				IF type = PinCfg.I THEN mode := 0 ELSE mode := PinCfg.pullUp END;
				PinCfg.Configure(TXPinPort, TXPinN, TXPinFunc,
					mode, PinCfg.DefaultOpts(TXPinPort, TXPinN));

		(* Set DLAB *)
			SYSTEM.PUT(LCR, {0,1,DLAB}); (* 8-bit, 1 stop bit, parity none,
				disable break transmission, enable access to Divisor Latches *)

		(* Actual baud rate = VPB clock / (16 * divisor) *)
			divisor := (Sys.PCLK + baud * 8) DIV (baud * 16);
			SYSTEM.PUT(UDLM, divisor DIV 100H); SYSTEM.PUT(UDLL, divisor MOD 100H);
			SYSTEM.PUT(UFDR, 16); (* divAddVal := 0; mulVal := 1 *)

		(* Try to reduce error. This table generated automatically *)
			IF Sys.PCLK = 15000000 THEN
				Match(baud, 1200, 625, 65);
				Match(baud, 2400, 217, 84);
				Match(baud, 4800, 179, 177);
				Match(baud, 9600, 71, 131);
				Match(baud, 19200, 38, 114);
				Match(baud, 38400, 19, 114);
				Match(baud, 57600, 12, 229);
				Match(baud, 115200, 6, 229)
			ELSIF Sys.PCLK = 30000000 THEN
				Match(baud, 1200, 875, 235);
				Match(baud, 2400, 625, 65);
				Match(baud, 4800, 217, 84);
				Match(baud, 9600, 179, 177);
				Match(baud, 19200, 71, 131);
				Match(baud, 38400, 38, 114);
				Match(baud, 57600, 24, 229);
				Match(baud, 115200, 12, 229)
			ELSIF Sys.PCLK = 60000000 THEN
				Match(baud, 2400, 875, 235);
				Match(baud, 4800, 625, 65);
				Match(baud, 9600, 217, 84);
				Match(baud, 19200, 179, 177);
				Match(baud, 38400, 71, 131);
				Match(baud, 57600, 47, 213);
				Match(baud, 115200, 24, 229)
			ELSIF Sys.PCLK = 120000000 THEN
				Match(baud, 4800, 875, 235);
				Match(baud, 9600, 625, 65);
				Match(baud, 19200, 217, 84);
				Match(baud, 38400, 179, 177);
				Match(baud, 57600, 93, 82);
				Match(baud, 115200, 47, 213)
			(*
			ELSIF Sys.PCLK = 17971200 THEN
				Match(baud, 19200, 36, 133);
				Match(baud, 38400, 18, 133);
				Match(baud, 57600, 12, 133);
				Match(baud, 115200, 6, 133)
			ELSIF Sys.PCLK = 18000000 THEN
				Match(baud, 1200, 500, 135);
				Match(baud, 2400, 250, 135);
				Match(baud, 4800, 125, 135);
				Match(baud, 9600, 74, 199);
				Match(baud, 19200, 37, 199);
				Match(baud, 38400, 23, 179);
				Match(baud, 57600, 11, 151);
				Match(baud, 115200, 8, 146)
			ELSIF Sys.PCLK = 36000000 THEN
				Match(baud, 2400, 500, 135);
				Match(baud, 4800, 250, 135);
				Match(baud, 9600, 125, 135);
				Match(baud, 19200, 74, 199);
				Match(baud, 38400, 37, 199);
				Match(baud, 57600, 23, 167);
				Match(baud, 115200, 11, 151)
			ELSIF Sys.PCLK = 72000000 THEN
				Match(baud, 4800, 500, 135);
				Match(baud, 9600, 250, 135);
				Match(baud, 19200, 125, 135);
				Match(baud, 38400, 74, 199);
				Match(baud, 57600, 71, 161);
				Match(baud, 115200, 23, 167)
			*)
			END;

		(* Clear DLAB; 8-bit data; 1 stop bit; select parity *)
			SYSTEM.PUT(LCR, 3 + parity); (* 8-bit, 1 stop bit, select parity,
				disable break transmission, disable access to Divisor Latches *)

		(* enable FIFOs, clear them, RX trigger level := 0 *)
			SYSTEM.PUT(FCR, {FIFOEN,RXFIFORES,TXFIFORES});

(*
		SYSTEM.PUT(TER, {TXEN});
*)

		(* interrupts handler *)
			v := Sys.VectorsOrg + (ARMv7M.ExternalInterrupt0 + Int) * 4;
			IF n = 0 THEN SYSTEM.PUT(v, InterruptsHandler0)
			ELSIF n = 1 THEN SYSTEM.PUT(v, InterruptsHandler1)
			ELSIF n = 2 THEN SYSTEM.PUT(v, InterruptsHandler2)
			ELSIF n = 3 THEN SYSTEM.PUT(v, InterruptsHandler3)
			ELSIF n = 4 THEN SYSTEM.PUT(v, InterruptsHandler4)
			ELSE ASSERT(FALSE)
			END;
			pAdr[n] := SYSTEM.ADR(p);

			interrupt0 := SYSTEM.VAL(Proc0, Interrupt);
			IF interrupt0 # interrupt THEN interrupt := interrupt0 END;

		(* enable interrupts *)
			SYSTEM.PUT(IER, {RBRIE,THREIE,RXIE});
			SYSTEM.PUT(ISER, intS)
	END Init;

	PROCEDURE Send* (VAR p: Port;
			id: CHAR; adr: INTEGER; n: INTEGER; VAR ok: BOOLEAN);
		VAR i: INTEGER; x: CHAR;

		PROCEDURE OutBufPut (VAR p: Port; x: CHAR);
		BEGIN
			p.outBuf[p.outW] := x;
			p.outW := (p.outW + 1) MOD outBufLen
		END OutBufPut;

	BEGIN
		ASSERT(id # DLE);
		ASSERT(id # ETX);
		ASSERT(n >= 0);
		ASSERT(n <= maxInfoBytesOut);

		IF p.outFree >= n + 2 THEN (* outFree access is safe here *)
			OutBufPut(p, id);
			OutBufPut(p, CHR(n));
			i := 0;
			WHILE i < n DO
				SYSTEM.GET(adr, x); INC(adr);
				OutBufPut(p, x);
				INC(i)
			END;

			(* CRITICAL *)
				SYSTEM.PUT(p.ICER, p.intS); ARMv7M.ISB;
					p.outFree := p.outFree - n - 2;
					IF ~p.outBusy THEN
						SendNext(p)
					END;
				SYSTEM.PUT(p.ISER, p.intS);

			ok := TRUE
		ELSE
			ok := FALSE
		END
	END Send;

	PROCEDURE Receive* (VAR p: Port);
		VAR
			id: CHAR; nBytes: INTEGER;
			i: INTEGER;
			a: ARRAY maxInfoBytesIn OF CHAR;

		PROCEDURE InBufGet (VAR p: Port): CHAR;
			VAR x: CHAR;
		BEGIN
			x := p.inBuf[p.inR];
			p.inR := (p.inR + 1) MOD inBufLen
		RETURN x
		END InBufGet;

		(* CRITICAL *)
			PROCEDURE Free (VAR p: Port; toFree: INTEGER);
			BEGIN
				SYSTEM.PUT(p.ICER, p.intS); ARMv7M.ISB;
					p.inFree := p.inFree + toFree;
					p.inFree1 := p.inFree1 + toFree;
				SYSTEM.PUT(p.ISER, p.intS)
			END Free;

	BEGIN
		WHILE p.inFree < inBufLen (* Available *) DO
			id := InBufGet(p);
			(* check inBuf consistency *)
				ASSERT(id # DLE);
				ASSERT(id # ETX);

			nBytes := ORD(InBufGet(p));
			(* check inBuf consistency *)
				ASSERT(nBytes <= maxInfoBytesIn);

			i := 0;
			WHILE i < nBytes DO
				a[i] := InBufGet(p);
				INC(i)
			END;

			Free(p, nBytes + 2);

			p.h(id, a, nBytes)
		END
	END Receive;

BEGIN
	interrupt := SYSTEM.VAL(Proc0, Interrupt)
END MicroLPC1788TPorts.

O7ARMv7MTool.DecObj MicroLPC1788TPorts.a7m
