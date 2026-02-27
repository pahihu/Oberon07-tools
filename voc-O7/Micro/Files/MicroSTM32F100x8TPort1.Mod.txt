MODULE MicroSTM32F100x8TPort1;

	(* Alexander Shiryaev, 2016.04, 2017.04 *)

	IMPORT SYSTEM, MCU := MicroSTM32F100, ARMv7M := MicroARMv7M, Sys := MicroSTM32F100x8System, PinCfg := MicroSTM32F10xPinCfg;

	CONST
		parityNone* = 0; parityEven* = 8 + 2; parityOdd* = 8 + 3;

		DLE* = 10X; ETX* = 03X;

		maxInfoBytesIn* = 40;
		maxInfoBytesOut* = 40;

		outBufLen = 128; (* 2^n; >= maxInfoBytesOut + 2 *)

		inBufLen = 128; (* 2^n; >= maxInfoBytesIn + 2 *)

		(* USARTxSR bits: *)
			PE = 0; FE = 1; NF = 2; ORE = 3; IDLE = 4; RXNE = 5; TC = 6;
				TXE = 7;

		DR = MCU.USART1DR;
		CR1 = MCU.USART1CR1;
		CR2 = MCU.USART1CR2;
		CR3 = MCU.USART1CR3;
		GTPR = MCU.USART1GTPR;
		BRR = MCU.USART1BRR;
		SR = MCU.USART1SR;

		Int = MCU.USART1Int;
		int = Int MOD 32;

		USARTRCCENR = MCU.RCCAPB2ENR;
			USARTEN = 14;

		UCLK = Sys.PCLK2;

		RXPinPort = PinCfg.A; RXPinN = 10;
		TXPinPort = PinCfg.A; TXPinN = 9;

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

		ISER, ICER: INTEGER;
		disableTCI, enableTCI: SET;

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
				SYSTEM.PUT(DR, ORD(DLE)) (* DLE before ID *)
			ELSE
				SYSTEM.PUT(CR1, disableTCI);
				outBusy := FALSE
			END
		ELSIF outState = 1 THEN (* DLE before ID sent *)
			outState := 2;
			x := Get();
			ASSERT(x # DLE); (* check outBuf consistency *)
			ASSERT(x # ETX); (* check outBuf consistency *)
			SYSTEM.PUT(DR, ORD(x)) (* ID *)
		ELSIF outState = 2 THEN (* ID sent *)
			outN := ORD(Get()); (* number of infobytes *)
			ASSERT(outN <= maxInfoBytesOut); (* check outBuf consistency *)
			IF outN = 0 THEN
				outState := 6;
				SYSTEM.PUT(DR, ORD(DLE)) (* DLE before ETX *)
			ELSE (* outN > 0 *)
				x := Get();
				DEC(outN);
				IF x = DLE THEN
					outState := 4
				ELSE
					outState := 3
				END;
				SYSTEM.PUT(DR, ORD(x))
			END
		ELSIF outState = 3 THEN (* infobyte sent *)
			IF outN = 0 THEN
				outState := 6;
				SYSTEM.PUT(DR, ORD(DLE)) (* DLE before ETX *)
			ELSE (* outN > 0 *)
				x := Get();
				DEC(outN);
				IF x = DLE THEN
					outState := 4
				END;
				SYSTEM.PUT(DR, ORD(x))
			END
		ELSIF outState = 4 THEN (* first DLE of double DLE inside message sent *)
			IF outN = 0 THEN
				outState := 5
			ELSE
				outState := 3
			END;
			SYSTEM.PUT(DR, ORD(DLE))
		ELSIF outState = 5 THEN (* send DLE before ETX *)
			outState := 6;
			SYSTEM.PUT(DR, ORD(DLE)) (* DLE before ETX *)
		ELSIF outState = 6 THEN (* DLE before ETX sent *)
			outState := 0;
			SYSTEM.PUT(DR, ORD(ETX))
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
		VAR s: SET;
			n, x: INTEGER;
	BEGIN
		n := 400H;
		SYSTEM.GET(SR, s);
		WHILE (s * {PE,RXNE} # {}) & (n > 0) DO
			IF RXNE IN s THEN
				SYSTEM.GET(DR, x);
				ByteReceived(CHR(x))
			END;
			DEC(n);
			SYSTEM.GET(SR, s)
		END;
		n := 100H;
		WHILE outBusy & (TC IN s) & (n > 0) DO
			SendNext;
			DEC(n);
			SYSTEM.GET(SR, s)
		END
	END InterruptsHandler;

	PROCEDURE Init* (baud, parity: INTEGER);
		CONST
			(* USARTxCR1 bits: *)
				RE = 2; TE = 3;
				IDLEIE = 4; RXNEIE = 5; TCIE = 6; TXEIE = 7; PEIE = 8;
				M = 12; UE = 13;
			(* USARTxCR3 bits: *)
				EIE = 0; DMAR = 6; DMAT = 7;
		VAR x: SET; b: INTEGER;
	BEGIN
		ASSERT(baud > 0);
		ASSERT((parity = parityNone) OR (parity = parityEven) OR (parity = parityOdd));

		ISER := ARMv7M.NVICISER0 + (Int DIV 32) * 4;
		ICER := ARMv7M.NVICICER0 + (Int DIV 32) * 4;

		(* disable interrupts *)
			SYSTEM.PUT(ICER, {int}); ARMv7M.ISB;

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

		(* enable clock for USART *)
			SYSTEM.GET(USARTRCCENR, x);
			SYSTEM.PUT(USARTRCCENR, x + {USARTEN});

		(* configure USART pins *)
			PinCfg.Configure(RXPinPort, RXPinN, PinCfg.inputPullUp);
			PinCfg.Configure(TXPinPort, TXPinN, PinCfg.afOutputPushPull2MHz);

		(* defaults *)
			SYSTEM.PUT(CR1, {});
			SYSTEM.PUT(CR2, {});
			SYSTEM.PUT(CR3, {});
			SYSTEM.PUT(GTPR, {});

		SYSTEM.GET(CR1, x);
		SYSTEM.PUT(CR1, x + {UE}); (* enable USART *)

		(* select parity *)
			SYSTEM.GET(CR1, x);
			SYSTEM.PUT(CR1, x + SYSTEM.VAL(SET, parity * 200H));

		(* baud rate register *)
			b := UCLK DIV baud;
			ASSERT(b DIV 10000H = 0);
			SYSTEM.PUT(BRR, b);

		(* enable receiver and transmitter *)
			SYSTEM.GET(CR1, x);
			SYSTEM.PUT(CR1, x + {RE,TE});

		SYSTEM.PUT(Sys.VectorsOrg + (ARMv7M.ExternalInterrupt0 + Int) * 4, InterruptsHandler);

		(* enable interrupts *)
			SYSTEM.GET(CR1, x);
			disableTCI := x + {RXNEIE,PEIE};
			enableTCI := disableTCI + {TCIE};
			SYSTEM.PUT(CR1, disableTCI);
			SYSTEM.PUT(ISER, {int})
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
				SYSTEM.PUT(ICER, {int}); ARMv7M.ISB;
					outFree := outFree - n - 2;
					IF ~outBusy THEN
						SendNext;
						SYSTEM.PUT(CR1, enableTCI)
					END;
				SYSTEM.PUT(ISER, {int});

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
				SYSTEM.PUT(ICER, {int}); ARMv7M.ISB;
					inFree := inFree + toFree;
					inFree1 := inFree1 + toFree;
				SYSTEM.PUT(ISER, {int})
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

END MicroSTM32F100x8TPort1.

O7ARMv7MP.Compile @/s

O7ARMv7MTool.DecObj MicroSTM32F100x8TPort1.a7m 
