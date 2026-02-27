MODULE MicroSTM32F0TPorts;

	(*
		Alexander Shiryaev, 2016.04, 2017.04, 2020.11

		RM0360, Reference manual,
			STM32F030x{4,6,8,C}, STM32F070x{6,B}

		RM0091, Reference manual,
			STM32F0x{1,2,8}
	*)

	IMPORT SYSTEM, ARMv6M := MicroARMv6M, Traps := MicroARMv6MTraps,
		Pins := MicroSTM32F0Pins;

	CONST
		maxPorts* = 8;
			USART1* = 0;
			USART2* = 1;
			USART3* = 2;
			USART4* = 3;
			USART5* = 4;
			USART6* = 5;
			(* STM32F0x{1,2,8} *)
				USART7* = 6;
				USART8* = 7;

		parityNone* = 0; parityEven* = 8 + 2; parityOdd* = 8 + 3;

		DLE* = 10X; ETX* = 03X;

		maxInfoBytesIn* = 40;
		maxInfoBytesOut* = 40;

		outBufLen = 128; (* 2^n; >= maxInfoBytesOut + 2 *)

		inBufLen = 128; (* 2^n; >= maxInfoBytesIn + 2 *)

		(* USARTxISR bits: *)
			PE = 0; FE = 1; NF = 2; ORE = 3; IDLE = 4; RXNE = 5; TC = 6; TXE = 7;

		(* USARTxICR bits: *)
			PECF = 0; FECF = 1; NCF = 2; ORECF = 3; TCCF = 6;

		(* APB *)
			USART2Base = 40004400H;
			USART3Base = 40004800H;
			USART4Base = 40004C00H;
			USART5Base = 40005000H;
			USART1Base = 40013800H;
			USART6Base = 40011400H;
			(* STM32F0x{1,2,8} *)
				USART7Base = 40011800H;
				USART8Base = 40011C00H;
		(* AHB1 *)
			RCC = 40021000H;
				RCCAPB1ENR = RCC + 1CH;
				RCCAPB2ENR = RCC + 18H;

		(* NVIC *)
			(* interrupt sources *)
				USART1Int = 27;
				USART2Int = 28;
				USART345678Int = 29;

		ISER = ARMv6M.NVICISER;
		ICER = ARMv6M.NVICICER;

	TYPE
		MessageReceived* = PROCEDURE (id: CHAR; a: ARRAY OF CHAR; len: INTEGER);

		Port* = RECORD
			ISR, ICR, RDR, TDR, CR1: INTEGER;

			intS: SET;

			enableTCI, disableTCI: SET;

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

		InitPar1* = RECORD
			n*: INTEGER;
			RXPinPort*, RXPinN*, RXPinAF*: INTEGER;
			TXPinPort*, TXPinN*, TXPinAF*: INTEGER;
			UCLK*: INTEGER;
			baud*: INTEGER;
			parity*: INTEGER;
			receive*: MessageReceived
		END;

		Proc0 = PROCEDURE (adr: INTEGER);

	VAR
		interrupt: Proc0;
		pAdr: ARRAY maxPorts OF INTEGER;

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
				SYSTEM.PUT(p.TDR, ORD(DLE)) (* DLE before ID *)
			ELSE
				SYSTEM.PUT(p.CR1, p.disableTCI);
				p.outBusy := FALSE
			END
		ELSIF p.outState = 1 THEN (* DLE before ID sent *)
			p.outState := 2;
			x := OutBufGet(p);
			ASSERT(x # DLE); (* check outBuf consistency *)
			ASSERT(x # ETX); (* check outBuf consistency *)
			SYSTEM.PUT(p.TDR, ORD(x)) (* ID *)
		ELSIF p.outState = 2 THEN (* ID sent *)
			p.outN := ORD(OutBufGet(p)); (* number of infobytes *)
			ASSERT(p.outN <= maxInfoBytesOut); (* check outBuf consistency *)
			IF p.outN = 0 THEN
				p.outState := 6;
				SYSTEM.PUT(p.TDR, ORD(DLE)) (* DLE before ETX *)
			ELSE (* outN > 0 *)
				x := OutBufGet(p);
				DEC(p.outN);
				IF x = DLE THEN
					p.outState := 4
				ELSE
					p.outState := 3
				END;
				SYSTEM.PUT(p.TDR, ORD(x))
			END
		ELSIF p.outState = 3 THEN (* infobyte sent *)
			IF p.outN = 0 THEN
				p.outState := 6;
				SYSTEM.PUT(p.TDR, ORD(DLE)) (* DLE before ETX *)
			ELSE (* outN > 0 *)
				x := OutBufGet(p);
				DEC(p.outN);
				IF x = DLE THEN
					p.outState := 4
				END;
				SYSTEM.PUT(p.TDR, ORD(x))
			END
		ELSIF p.outState = 4 THEN (* first DLE of double DLE inside message sent *)
			IF p.outN = 0 THEN
				p.outState := 5
			ELSE
				p.outState := 3
			END;
			SYSTEM.PUT(p.TDR, ORD(DLE))
		ELSIF p.outState = 5 THEN (* send DLE before ETX *)
			p.outState := 6;
			SYSTEM.PUT(p.TDR, ORD(DLE)) (* DLE before ETX *)
		ELSIF p.outState = 6 THEN (* DLE before ETX sent *)
			p.outState := 0;
			SYSTEM.PUT(p.TDR, ORD(ETX))
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
		VAR s: SET;
			n, x: INTEGER;
	BEGIN
		n := 400H;
		SYSTEM.GET(p.ISR, s);
		WHILE (s * {PE,RXNE} # {}) & (n > 0) DO
			IF s * {PE,FE,NF,ORE} # {} THEN
				SYSTEM.PUT(p.ICR, {PECF,FECF,NCF,ORECF})
			END;
			IF RXNE IN s THEN
				SYSTEM.GET(p.RDR, x);
				ByteReceived(p, CHR(x))
			END;
			DEC(n);
			SYSTEM.GET(p.ISR, s)
		END;
		n := 100H;
		WHILE p.outBusy & (TC IN s) & (n > 0) DO
			SendNext(p);
			DEC(n);
			SYSTEM.GET(p.ISR, s)
		END
	END Interrupt;

	PROCEDURE* InterruptsHandler0;
	BEGIN interrupt(pAdr[0])
	END InterruptsHandler0;

	PROCEDURE* InterruptsHandler1;
	BEGIN interrupt(pAdr[1])
	END InterruptsHandler1;

	PROCEDURE* InterruptsHandler2;
	BEGIN
		IF pAdr[2] # 0 THEN interrupt(pAdr[2]) END;
		IF pAdr[3] # 0 THEN interrupt(pAdr[3]) END;
		IF pAdr[4] # 0 THEN interrupt(pAdr[4]) END;
		IF pAdr[5] # 0 THEN interrupt(pAdr[5]) END;
		IF pAdr[6] # 0 THEN interrupt(pAdr[6]) END;
		IF pAdr[7] # 0 THEN interrupt(pAdr[7]) END
	END InterruptsHandler2;

	PROCEDURE Init* (VAR p: Port; par: InitPar1);
		CONST
			(* USARTxCR1 bits: *)
				UE = 0; RE = 2; TE = 3;
				IDLEIE = 4; RXNEIE = 5; TCIE = 6; TXEIE = 7; PEIE = 8;
				M0 = 12;
			(* USARTxCR3 bits: *)
				EIE = 0; DMAR = 6; DMAT = 7;
		VAR x, intS: SET;
			Int, b: INTEGER;
			base, CR1, CR2, CR3, BRR, ISR, ICR, RDR, TDR, GTPR: INTEGER;
			URCCENR, UEN: INTEGER;
			interrupt0: Proc0;
	BEGIN
		ASSERT(par.UCLK > 0);
		ASSERT(par.baud > 0);
		ASSERT((par.parity = parityNone) OR (par.parity = parityEven) OR (par.parity = parityOdd));

		IF par.n = USART1 THEN
			Int := USART1Int;
				URCCENR := RCCAPB2ENR; UEN := 14;
			base := USART1Base
		ELSIF par.n = USART2 THEN
			Int := USART2Int;
				URCCENR := RCCAPB1ENR; UEN := 17;
			base := USART2Base
		ELSIF par.n = USART3 THEN
			Int := USART345678Int;
				URCCENR := RCCAPB1ENR; UEN := 18;
			base := USART3Base
		ELSIF par.n = USART4 THEN
			Int := USART345678Int;
				URCCENR := RCCAPB1ENR; UEN := 19;
			base := USART4Base
		ELSIF par.n = USART5 THEN
			Int := USART345678Int;
				URCCENR := RCCAPB1ENR; UEN := 20;
			base := USART5Base
		ELSIF par.n = USART6 THEN
			Int := USART345678Int;
				URCCENR := RCCAPB2ENR; UEN := 5;
			base := USART6Base
		ELSIF par.n = USART7 THEN
			Int := USART345678Int;
				URCCENR := RCCAPB2ENR; UEN := 6;
			base := USART7Base
		ELSIF par.n = USART8 THEN
			Int := USART345678Int;
				URCCENR := RCCAPB2ENR; UEN := 7;
			base := USART8Base
		ELSE ASSERT(FALSE)
		END;

		CR1 := base;
		CR2 := base + 4;
		CR3 := base + 8;
		BRR := base + 0CH;
		GTPR := base + 10H;
		ISR := base + 1CH;
		ICR := base + 20H;
		RDR := base + 24H;
		TDR := base + 28H;

		intS := {Int (* MOD 32 *)};

		(* disable interrupts *)
			SYSTEM.PUT(ICER, intS); ARMv6M.ISB;

		p.intS := intS;
		p.ISR := ISR; p.ICR := ICR; p.RDR := RDR; p.TDR := TDR;
		p.CR1 := CR1;

		p.h := par.receive;

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

		(* enable clock for USART *)
			SYSTEM.GET(URCCENR, x);
			SYSTEM.PUT(URCCENR, x + {UEN});

		(* configure USART pins *)
			Pins.ConfigureAlt(par.RXPinPort, par.RXPinN,
				Pins.pullUp, Pins.pushPullLow, par.RXPinAF);
			Pins.ConfigureAlt(par.TXPinPort, par.TXPinN,
				Pins.pullUp, Pins.pushPullLow, par.TXPinAF);

		(* defaults *)
			SYSTEM.PUT(CR1, {});
			SYSTEM.PUT(CR2, {});
			SYSTEM.PUT(CR3, {});
			SYSTEM.PUT(GTPR, {});

		(* select parity *)
			SYSTEM.GET(CR1, x);
			SYSTEM.PUT(CR1, x + SYSTEM.VAL(SET, par.parity * 200H));

		(* baud rate register *)
			b := par.UCLK DIV par.baud;
			ASSERT(b DIV 10000H = 0);
			ASSERT(b >= 16);
			SYSTEM.PUT(BRR, b);

		SYSTEM.GET(CR1, x);
		SYSTEM.PUT(CR1, x + {UE}); (* enable USART *)

		(* enable receiver and transmitter *)
			SYSTEM.GET(CR1, x);
			SYSTEM.PUT(CR1, x + {RE,TE});

		SYSTEM.PUT(ICR, {PECF,FECF,NCF,ORECF});

		(* interrupts handler *)
			b := Traps.vectorsOrg + (ARMv6M.ExternalInterrupt0 + Int) * 4;
			IF par.n = USART1 THEN SYSTEM.PUT(b, InterruptsHandler0)
			ELSIF par.n = USART2 THEN SYSTEM.PUT(b, InterruptsHandler1)
			ELSIF par.n IN {USART3,USART4,USART5,USART6,USART7,USART8} THEN
				SYSTEM.PUT(b, InterruptsHandler2)
			ELSE ASSERT(FALSE)
			END;
			pAdr[par.n] := SYSTEM.ADR(p);

			interrupt0 := SYSTEM.VAL(Proc0, Interrupt);
			IF interrupt0 # interrupt THEN interrupt := interrupt0 END;

		(* enable interrupts *)
			SYSTEM.GET(CR1, x);
			p.disableTCI := x + {RXNEIE,PEIE};
			p.enableTCI := p.disableTCI + {TCIE};
			SYSTEM.PUT(CR1, p.disableTCI);
			SYSTEM.PUT(ISER, intS)
	END Init;

	PROCEDURE SendAvailable* (p: Port; n: INTEGER): BOOLEAN;
	BEGIN
	RETURN p.outFree >= n + 2 (* outFree access is safe here *)
	END SendAvailable;

	PROCEDURE Send* (VAR p: Port;
			id: CHAR; adr: INTEGER; n: INTEGER);
		VAR x: CHAR; i: INTEGER;

		PROCEDURE OutBufPut (VAR p: Port; x: CHAR);
			VAR adr: INTEGER;
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
				SYSTEM.PUT(ICER, p.intS); ARMv6M.ISB;
					p.outFree := p.outFree - 2 - n;
					IF ~p.outBusy THEN
						SendNext(p);
						SYSTEM.PUT(p.CR1, p.enableTCI)
					END;
				SYSTEM.PUT(ISER, p.intS)
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
				SYSTEM.PUT(ICER, p.intS); ARMv6M.ISB;
					p.inFree := p.inFree + toFree;
					p.inFree1 := p.inFree1 + toFree;
				SYSTEM.PUT(ISER, p.intS)
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

			Free(p, 2 + nBytes);

			p.h(id, a, nBytes)
		END
	END Receive;

	PROCEDURE Init0;
	BEGIN
		SYSTEM.PUT(ICER, {USART345678Int}); ARMv6M.ISB;
		pAdr[2] := 0; pAdr[3] := 0; pAdr[4] := 0; pAdr[5] := 0;
			pAdr[6] := 0; pAdr[7] := 0;
		interrupt := SYSTEM.VAL(Proc0, Interrupt)
	END Init0;

BEGIN
	Init0
END MicroSTM32F0TPorts.

O7ARMv7MTool.DecObj MicroSTM32F0TPorts.a6m
