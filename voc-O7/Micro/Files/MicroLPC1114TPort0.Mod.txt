MODULE MicroLPC1114TPort0;

	(* Alexander Shiryaev, 2014.11, 2016.04, 2017.04 *)

	IMPORT SYSTEM, MCU := MicroLPC1100, ARMv6M := MicroARMv6M, Sys := MicroLPC1100System;

	CONST
		parityNone* = 0; parityOdd* = 8; parityEven* = 16 + 8;

		DLE* = 10X; ETX* = 03X;

		maxInfoBytesIn* = 40;
		maxInfoBytesOut* = 40;

		outBufLen = 128; (* 2^n; >= maxInfoBytesOut + 2 *)

		inBufLen = 128; (* 2^n; >= maxInfoBytesIn + 2 *)

		UARTCLKDIV = 4;
			UCLK = Sys.CCLK DIV UARTCLKDIV;

		(* U0IER bits: *)
			RBRIE = 0; THREIE = 1; RXLIE = 2;
			ABEOINTEN = 8; ABTOINTEN = 9;

		(* U0IIR bits: *)
			INTSTATUS = 0; ABEOINT = 8; ABTOINT = 9;

		(* U0FCR bits: *)
			FIFOEN = 0; RXFIFORES = 1; TXFIFORES = 2;

		(* U0LCR bits: *)
			DLAB = 7;

		(* U0LSR bits: *)
			RDR = 0; OE = 1; PE = 2; FE = 3; BI = 4; THRE = 5; TEMT = 6;
			RXFE = 7;

		(* U0TER bits: *)
			TXEN = 7;

	TYPE
		MessageReceived* = PROCEDURE (id: CHAR; a: ARRAY OF CHAR; len: INTEGER);

	VAR
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

		inBuf: ARRAY inBufLen OF CHAR;
		outBuf: ARRAY outBufLen OF CHAR;

	PROCEDURE SendNext;
		VAR x: CHAR;

		PROCEDURE Get (): CHAR;
			VAR x: CHAR;
		BEGIN
			x := outBuf[outR];
			outR := (outR + 1) MOD outBufLen;

			INC(outFree)
		RETURN x
		END Get;

	BEGIN
		IF outState = 0 THEN (* outside message *)
			IF outFree < outBufLen THEN
				outBusy := TRUE;
				outState := 1;
				SYSTEM.PUT(MCU.U0THR, ORD(DLE)) (* DLE before ID *)
			ELSE
				outBusy := FALSE
			END
		ELSIF outState = 1 THEN (* DLE before ID sent *)
			outState := 2;
			x := Get();
			ASSERT(x # DLE); (* check outBuf consistency *)
			ASSERT(x # ETX); (* check outBuf consistency *)
			SYSTEM.PUT(MCU.U0THR, ORD(x)) (* ID *)
		ELSIF outState = 2 THEN (* ID sent *)
			outN := ORD(Get()); (* number of infobytes *)
			ASSERT(outN <= maxInfoBytesOut); (* check outBuf consistency *)
			IF outN = 0 THEN
				outState := 6;
				SYSTEM.PUT(MCU.U0THR, ORD(DLE)) (* DLE before ETX *)
			ELSE (* outN > 0 *)
				x := Get();
				DEC(outN);
				IF x = DLE THEN
					outState := 4
				ELSE
					outState := 3
				END;
				SYSTEM.PUT(MCU.U0THR, ORD(x))
			END
		ELSIF outState = 3 THEN (* infobyte sent *)
			IF outN = 0 THEN
				outState := 6;
				SYSTEM.PUT(MCU.U0THR, ORD(DLE)) (* DLE before ETX *)
			ELSE (* outN > 0 *)
				x := Get();
				DEC(outN);
				IF x = DLE THEN
					outState := 4
				END;
				SYSTEM.PUT(MCU.U0THR, ORD(x))
			END
		ELSIF outState = 4 THEN (* first DLE of double DLE inside message sent *)
			IF outN = 0 THEN
				outState := 5
			ELSE
				outState := 3
			END;
			SYSTEM.PUT(MCU.U0THR, ORD(DLE))
		ELSIF outState = 5 THEN (* send DLE before ETX *)
			outState := 6;
			SYSTEM.PUT(MCU.U0THR, ORD(DLE)) (* DLE before ETX *)
		ELSIF outState = 6 THEN (* DLE before ETX sent *)
			outState := 0;
			SYSTEM.PUT(MCU.U0THR, ORD(ETX))
		ELSE ASSERT(FALSE)
		END
	END SendNext;

	(* This procedure may be called from RX interrupts handler only *)
	PROCEDURE ByteReceived (x: CHAR);
	BEGIN
		IF inState = 0 THEN (* outside *)
			IF x = DLE THEN
				inState := 1
			END
		ELSIF inState = 1 THEN (* initial DLE already received *)
			IF (x = DLE) OR (x = ETX) THEN
				inState := 0
			ELSE (* ID *)
				IF inFree >= 2 THEN (* free space for empty message available *)
					inBuf[inW] := x;

					inW1 := (inW + 2) MOD inBufLen;

					inFree1 := inFree - 2;
					inIgnore := FALSE;
					inState := 2
				ELSE (* if this message will be received, it will be lost *)
					inIgnore := TRUE;
					inState := 2
				END;
				inInfoBytes := 0
			END
		ELSIF inState = 2 THEN (* inside; ID already received *)
			IF x = DLE THEN
				inState := 3
			ELSE
				IF inInfoBytes < maxInfoBytesIn THEN
					IF ~inIgnore THEN
						IF inFree1 > 0 THEN
							inBuf[inW1] := x;

							inW1 := (inW1 + 1) MOD inBufLen;

							DEC(inFree1)
						ELSE (* if this message will be received, it will be lost *)
							inIgnore := TRUE
						END
					END;
					INC(inInfoBytes)
				ELSE
					inState := 0
				END
			END
		ELSIF inState = 3 THEN (* inside; first DLE already received *)
			IF x = DLE THEN (* double DLE *)
				IF inInfoBytes < maxInfoBytesIn THEN
					IF ~inIgnore THEN
						IF inFree1 > 0 THEN
							inBuf[inW1] := DLE;

							inW1 := (inW1 + 1) MOD inBufLen;

							DEC(inFree1)
						ELSE (* if this message will be received, it will be lost *)
							inIgnore := TRUE
						END
					END;
					INC(inInfoBytes);
					inState := 2
				ELSE
					inState := 0
				END
			ELSIF x = ETX THEN
				IF ~inIgnore THEN

					inBuf[(inW + 1) MOD inBufLen] := CHR(inInfoBytes);

					inW := inW1;
					inFree := inFree1
				END;
				inState := 0
			ELSE
				inState := 0
			END
		ELSE ASSERT(FALSE)
		END
	END ByteReceived;

	PROCEDURE* InterruptsHandler;
		VAR x: SET; t, n, m: INTEGER;
	BEGIN
		m := 400H;
		SYSTEM.GET(MCU.U0IIR, t);
		WHILE ~ODD(t) & (m > 0) DO
			n := 400H;
			SYSTEM.GET(MCU.U0LSR, x);
			WHILE (x * {RDR,OE,PE,FE,BI,RXFE} # {}) & (n > 0) DO
				IF RDR IN x THEN
					SYSTEM.GET(MCU.U0RBR, t);
					ByteReceived(CHR(t))
				END;
				DEC(n);
				SYSTEM.GET(MCU.U0LSR, x)
			END;
			IF THRE IN x THEN SendNext END;

			DEC(m);
			SYSTEM.GET(MCU.U0IIR, t)
		END
	END InterruptsHandler;

	PROCEDURE Init* (baud, parity: INTEGER);
		CONST
			(* SYSAHBCLKCTRL bits: *)
				UART = 12; IOCON = 16;
		VAR x: SET; divisor: INTEGER;

		PROCEDURE Match (desiredBaud, matchBaud, DL, FDR: INTEGER);
		BEGIN
			IF desiredBaud = matchBaud THEN
				SYSTEM.PUT(MCU.U0DLM, DL DIV 100H);
				SYSTEM.PUT(MCU.U0DLL, DL MOD 100H);
				SYSTEM.PUT(MCU.U0FDR, FDR)
			END
		END Match;

	BEGIN
		(* disable interrupts *)
			SYSTEM.PUT(ARMv6M.NVICICER, {MCU.UARTInt}); ARMv6M.ISB;
			SYSTEM.PUT(MCU.U0IER, {});

		(* disable UART_PCLK *)
			SYSTEM.PUT(MCU.UARTCLKDIV, 0);

		(* disable clock for UART *)
			SYSTEM.GET(MCU.SYSAHBCLKCTRL, x);
			SYSTEM.PUT(MCU.SYSAHBCLKCTRL, x - {UART});

		(* out *)
			outW := 0;
			outR := 0;
			outFree := outBufLen;
			outState := 0;
			outBusy := FALSE;

		(* in *)
			inW := 0;
			inFree := inBufLen;
			inState := 0;
			inR := 0;

		(* enable clock for I/O configuration block *)
			SYSTEM.GET(MCU.SYSAHBCLKCTRL, x);
			SYSTEM.PUT(MCU.SYSAHBCLKCTRL, x + {IOCON});

		(* configure PINs *)
			SYSTEM.GET(MCU.IOCONPIO16, x);
			SYSTEM.PUT(MCU.IOCONPIO16, x * {6..9,11..31} + {0,4}); (* P1.6: RXD function, enable pull-up resistor, no hysteresis, no open-drain output *)

			SYSTEM.GET(MCU.IOCONPIO17, x);
			SYSTEM.PUT(MCU.IOCONPIO17, x * {6..9,11..31} + {0}); (* P1.7: TXD function, no pull-up/pull-down resistors enabled, no hysteresis, no open-drain output *)

		(* enable clock for UART (after PINs configuration) *)
			SYSTEM.GET(MCU.SYSAHBCLKCTRL, x);
			SYSTEM.PUT(MCU.SYSAHBCLKCTRL, x + {UART});

		(* setup UART_PCLK (after PINs configuration) *)
			SYSTEM.PUT(MCU.UARTCLKDIV, UARTCLKDIV); (* UCLK := CCLK DIV UARTCLKDIV *)

		SYSTEM.PUT(MCU.U0LCR, {DLAB}); (* !DLAB *)

		(* This table generated automatically *)
			IF UCLK = 12000000 THEN
				Match(baud, 1200, 625, 16);
				Match(baud, 2400, 250, 65);
				Match(baud, 4800, 125, 65);
				Match(baud, 9600, 71, 161);
				Match(baud, 19200, 23, 167);
				Match(baud, 38400, 16, 146);
				Match(baud, 57600, 13, 16);
				Match(baud, 115200, 4, 133)
			ELSIF UCLK = 24000000 THEN
				Match(baud, 1200, 1250, 16);
				Match(baud, 2400, 625, 16);
				Match(baud, 4800, 250, 65);
				Match(baud, 9600, 125, 65);
				Match(baud, 19200, 71, 161);
				Match(baud, 38400, 23, 167);
				Match(baud, 57600, 23, 242);
				Match(baud, 115200, 13, 16)
			ELSIF UCLK = 48000000 THEN
				Match(baud, 1200, 2500, 16);
				Match(baud, 2400, 1250, 16);
				Match(baud, 4800, 625, 16);
				Match(baud, 9600, 250, 65);
				Match(baud, 19200, 125, 65);
				Match(baud, 38400, 71, 161);
				Match(baud, 57600, 27, 237);
				Match(baud, 115200, 23, 242)
			END;

		SYSTEM.PUT(MCU.U0LCR, 3 + parity); (* 8-bit character length, 1 stop bit, parity *)

		SYSTEM.PUT(MCU.U0FCR, {FIFOEN,RXFIFORES,TXFIFORES}); (* enable FIFOs and clear them, RX trigger level := 0 *)

		SYSTEM.PUT(MCU.U0TER, {TXEN}); (* enable transmit *)

		SYSTEM.PUT(Sys.VectorsOrg + (ARMv6M.ExternalInterrupt0 + MCU.UARTInt) * 4, InterruptsHandler);

		(* enable interrupts *)
			SYSTEM.PUT(MCU.U0IER, {RBRIE,THREIE,RXLIE});
			SYSTEM.PUT(ARMv6M.NVICISER, {MCU.UARTInt})
	END Init;

	PROCEDURE Send* (id: CHAR; adr: INTEGER; n: INTEGER; VAR ok: BOOLEAN);
		VAR i: INTEGER; x: CHAR;

		PROCEDURE Get (VAR adr: INTEGER): CHAR;
			VAR x: CHAR;
		BEGIN
			SYSTEM.GET(adr, x);
			INC(adr)
		RETURN x
		END Get;

		PROCEDURE Put (x: CHAR);
		BEGIN
			outBuf[outW] := x;
			outW := (outW + 1) MOD outBufLen
		END Put;

	BEGIN
		ASSERT(id # DLE);
		ASSERT(id # ETX);
		ASSERT(n >= 0);
		ASSERT(n <= maxInfoBytesOut);

		IF outFree >= n + 2 THEN (* outFree access is safe here *)
			Put(id);
			Put(CHR(n));
			i := 0;
			WHILE i < n DO
				Put(Get(adr));
				INC(i)
			END;

			(* CRITICAL *)
				SYSTEM.PUT(ARMv6M.NVICICER, {MCU.UARTInt}); ARMv6M.ISB;
					outFree := outFree - n - 2;
					IF ~outBusy THEN
						SendNext
					END;
				SYSTEM.PUT(ARMv6M.NVICISER, {MCU.UARTInt});

			ok := TRUE
		ELSE
			ok := FALSE
		END
	END Send;

	PROCEDURE Receive* (p: MessageReceived);
		VAR
			id: CHAR; nBytes: INTEGER;
			i: INTEGER;
			a: ARRAY maxInfoBytesIn OF CHAR;

		PROCEDURE Get (): CHAR;
			VAR x: CHAR;
		BEGIN
			x := inBuf[inR];
			inR := (inR + 1) MOD inBufLen
		RETURN x
		END Get;

		(* CRITICAL *)
			PROCEDURE Free (toFree: INTEGER);
			BEGIN
				SYSTEM.PUT(ARMv6M.NVICICER, {MCU.UARTInt}); ARMv6M.ISB;
					inFree := inFree + toFree;
					inFree1 := inFree1 + toFree;
				SYSTEM.PUT(ARMv6M.NVICISER, {MCU.UARTInt})
			END Free;

	BEGIN
		WHILE inFree < inBufLen (* Available *) DO
			id := Get();
			(* check inBuf consistency *)
				ASSERT(id # DLE);
				ASSERT(id # ETX);

			nBytes := ORD(Get());
			(* check inBuf consistency *)
				ASSERT(nBytes <= maxInfoBytesIn);

			i := 0;
			WHILE i < nBytes DO
				a[i] := Get();
				INC(i)
			END;

			Free(nBytes + 2);

			p(id, a, nBytes)
		END
	END Receive;

END MicroLPC1114TPort0.

O7ARMv6MP.Compile MicroLPC1100 MicroARMv6M MicroLPC1100System 

O7ARMv6MP.Compile @/s

O7ARMv7MTool.DecObj MicroLPC1114TPort0.a6m 
