MODULE MicroSTM32F1Ports;

	(*
		Alexander Shiryaev, 2016.09, 2017.04, 2020.11

		RM0008, Reference manual,
			STM32F10{1,2,3,5,7}xx

		RM0041, Reference manual,
			STM32F100xx
	*)

	IMPORT SYSTEM, ARMv7M := MicroARMv7M, Traps := MicroARMv7MTraps,
		Pins := MicroSTM32F10xPinCfg;

	CONST
		maxPorts* = 5;
			USART1* = 0;
			USART2* = 1;
			USART3* = 2;
			UART4* = 3;
			UART5* = 4;

		parityNone* = 0; parityEven* = 8 + 2; parityOdd* = 8 + 3;

		outBufLen* = 256; (* 2^n *)

		inBufLen* = 128; (* 2^n *)

		(* U[S]ARTxSR bits: *)
			PE = 0; FE = 1; NF = 2; ORE = 3; IDLE = 4; RXNE = 5; TC = 6; TXE = 7;

		(* APB1 *)
			USART2Base = 40004400H;
			USART3Base = 40004800H;
			UART4Base = 40004C00H;
			UART5Base = 40005000H;
		(* APB2 *)
			USART1Base = 40013800H;
		(* AHB1 *)
			RCC = 40021000H;
				RCCAPB1ENR = RCC + 1CH;
				RCCAPB2ENR = RCC + 18H;

		(* NVIC *)
			(* interrupt sources *)
				USART1Int = 37;
				USART2Int = 38;
				USART3Int = 39;
				UART4Int = 52;
				UART5Int = 53;

	TYPE
		Port* = RECORD
			SR, DR, CR1: INTEGER;

			ISER, ICER: INTEGER;
				intS: SET;

			enableTCI, disableTCI: SET;

			(* out *)
				outFree: INTEGER;
				(* W *)
					outW: INTEGER; (* writer *)
				(* R *)
					outR: INTEGER; (* reader *)
				outBusy: BOOLEAN;

			(* in *)
				inFree: INTEGER;
				(* W *)
					inW: INTEGER; (* writer *)
				(* R *)
					inR: INTEGER; (* reader *)

			inBuf: ARRAY inBufLen OF CHAR;
			outBuf: ARRAY outBufLen OF CHAR
		END;

		InitPar2* = RECORD
			n*: INTEGER;
			RXPinPort*, RXPinN*: INTEGER;
			TXPinPort*, TXPinN*: INTEGER;
			UCLK*: INTEGER;
			baud*: INTEGER;
			parity*: INTEGER
		END;

		Proc0 = PROCEDURE (adr: INTEGER);

	VAR
		interrupt: Proc0;
		pAdr: ARRAY maxPorts OF INTEGER;

	PROCEDURE SendNext (VAR p: Port);
		VAR x: CHAR;
	BEGIN
		IF p.outFree < outBufLen THEN
			p.outBusy := TRUE;
			(* Get(x) *)
				x := p.outBuf[p.outR]; p.outR := (p.outR + 1) MOD outBufLen;
				INC(p.outFree);
			SYSTEM.PUT(p.DR, ORD(x))
		ELSE
			SYSTEM.PUT(p.CR1, p.disableTCI);
			p.outBusy := FALSE
		END
	END SendNext;

	(* This procedure may be called from RX interrupts handler only *)
	PROCEDURE ByteReceived (VAR p: Port; x: CHAR);
	BEGIN
		IF p.inFree > 0 THEN
			(* Put(x) *)
				DEC(p.inFree);
				p.inBuf[p.inW] := x; p.inW := (p.inW + 1) MOD inBufLen
		END
	END ByteReceived;

	PROCEDURE Interrupt (VAR p: Port);
		VAR s: SET;
			n, x: INTEGER;
	BEGIN
		n := 400H;
		SYSTEM.GET(p.SR, s);
		WHILE (s * {PE,RXNE} # {}) & (n > 0) DO
			IF RXNE IN s THEN
				SYSTEM.GET(p.DR, x);
				ByteReceived(p, CHR(x))
			END;
			DEC(n);
			SYSTEM.GET(p.SR, s)
		END;
		n := 100H;
		WHILE p.outBusy & (TC IN s) & (n > 0) DO
			SendNext(p);
			DEC(n);
			SYSTEM.GET(p.SR, s)
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

	PROCEDURE Init* (VAR p: Port; par: InitPar2);
		CONST
			(* U[S]ARTxCR1 bits: *)
				RE = 2; TE = 3;
				IDLEIE = 4; RXNEIE = 5; TCIE = 6; TXEIE = 7; PEIE = 8;
				M = 12; UE = 13;
			(* U[S]ARTxCR3 bits: *)
				EIE = 0; DMAR = 6; DMAT = 7;
		VAR x, intS: SET;
			Int, ISER, ICER, b: INTEGER;
			base, CR1, CR2, CR3, BRR, SR, DR, GTPR: INTEGER;
			URCCENR, UEN: INTEGER;
			interrupt0: Proc0;
	BEGIN
		ASSERT(par.UCLK > 0);
		ASSERT(par.baud > 0);
		ASSERT((par.parity = parityNone) OR (par.parity = parityEven) OR (par.parity = parityOdd));

		IF par.n = USART1 THEN
			Int := USART1Int;
				URCCENR := RCCAPB2ENR;
				UEN := 14;
			base := USART1Base
		ELSIF par.n = USART2 THEN
			Int := USART2Int;
				URCCENR := RCCAPB1ENR;
				UEN := 17;
			base := USART2Base
		ELSIF par.n = USART3 THEN
			Int := USART3Int;
				URCCENR := RCCAPB1ENR;
				UEN := 18;
			base := USART3Base
		ELSIF par.n = UART4 THEN
			Int := UART4Int;
				URCCENR := RCCAPB1ENR;
				UEN := 19;
			base := UART4Base
		ELSIF par.n = UART5 THEN
			Int := UART5Int;
				URCCENR := RCCAPB1ENR;
				UEN := 20;
			base := UART5Base
		ELSE ASSERT(FALSE)
		END;

		SR := base;
		DR := base + 4;
		BRR := base + 8;
		CR1 := base + 0CH;
		CR2 := base + 10H;
		CR3 := base + 14H;
		GTPR := base + 18H;

		intS := {Int MOD 32};
		ISER := ARMv7M.NVICISER0 + (Int DIV 32) * 4;
		ICER := ARMv7M.NVICICER0 + (Int DIV 32) * 4;

		(* disable interrupts *)
			SYSTEM.PUT(ICER, intS); ARMv7M.ISB;

		p.ISER := ISER; p.ICER := ICER; p.intS := intS;
		p.SR := SR; p.DR := DR; p.CR1 := CR1;

		(* out *)
			p.outW := 0;
			p.outR := 0;
			p.outFree := outBufLen;
			p.outBusy := FALSE;

		(* in *)
			p.inW := 0;
			p.inFree := inBufLen;
			p.inR := 0;

		(* enable clock for U[S]ART *)
			SYSTEM.GET(URCCENR, x);
			SYSTEM.PUT(URCCENR, x + {UEN});

		(* configure U[S]ART pins *)
			Pins.Configure(par.RXPinPort, par.RXPinN, Pins.inputPullUp);
			Pins.Configure(par.TXPinPort, par.TXPinN, Pins.afOutputPushPull2MHz);

		(* defaults *)
			SYSTEM.PUT(CR1, {});
			SYSTEM.PUT(CR2, {});
			SYSTEM.PUT(CR3, {});
			SYSTEM.PUT(GTPR, {});

		SYSTEM.GET(CR1, x);
		SYSTEM.PUT(CR1, x + {UE}); (* enable U[S]ART *)

		(* select parity *)
			SYSTEM.GET(CR1, x);
			SYSTEM.PUT(CR1, x + SYSTEM.VAL(SET, par.parity * 200H));

		(* baud rate register *)
			b := par.UCLK DIV par.baud;
			ASSERT(b DIV 10000H = 0);
			SYSTEM.PUT(BRR, b);

		(* enable receiver and transmitter *)
			SYSTEM.GET(CR1, x);
			SYSTEM.PUT(CR1, x + {RE,TE});

		(* interrupts handler *)
			b := Traps.vectorsOrg + (ARMv7M.ExternalInterrupt0 + Int) * 4;
			IF par.n = USART1 THEN SYSTEM.PUT(b, InterruptsHandler0)
			ELSIF par.n = USART2 THEN SYSTEM.PUT(b, InterruptsHandler1)
			ELSIF par.n = USART3 THEN SYSTEM.PUT(b, InterruptsHandler2)
			ELSIF par.n = UART4 THEN SYSTEM.PUT(b, InterruptsHandler3)
			ELSIF par.n = UART5 THEN SYSTEM.PUT(b, InterruptsHandler4)
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

	PROCEDURE WriteAvailable* (p: Port; n: INTEGER): BOOLEAN;
	BEGIN
	RETURN p.outFree >= n (* outFree access is safe here *)
	END WriteAvailable;

	PROCEDURE Write* (VAR p: Port;
			adr: INTEGER; n: INTEGER; VAR done: INTEGER);
		VAR x: CHAR;
	BEGIN
		ASSERT(n >= 0);

		done := p.outFree; (* outFree access is safe here, because it may be incremented only in interrupts handler *)

		IF n < done THEN done := n END;

		IF done > 0 THEN
			n := done;
			REPEAT
				(* Get(x) *)
					SYSTEM.GET(adr, x); INC(adr);
				(* Put(x) *)
					p.outBuf[p.outW] := x; p.outW := (p.outW + 1) MOD outBufLen;
				DEC(n)
			UNTIL n = 0;

			(* CRITICAL *)
				SYSTEM.PUT(p.ICER, p.intS); ARMv7M.ISB;
					p.outFree := p.outFree - done;
					IF ~p.outBusy THEN
						SendNext(p);
						SYSTEM.PUT(p.CR1, p.enableTCI)
					END;
				SYSTEM.PUT(p.ISER, p.intS)
		END
	END Write;

	PROCEDURE Read* (VAR p: Port; adr: INTEGER; n: INTEGER; VAR done: INTEGER);
		VAR x: CHAR;
	BEGIN
		(* CRITICAL *)
			done := inBufLen - p.inFree; (* Available *)

		IF n < done THEN done := n END;

		IF done > 0 THEN
			n := done;
			REPEAT
				(* Get(x) *)
					x := p.inBuf[p.inR]; p.inR := (p.inR + 1) MOD inBufLen;
				(* Put(x) *)
					SYSTEM.PUT(adr, x); INC(adr);
				DEC(n)
			UNTIL n = 0;

			(* CRITICAL *)
				SYSTEM.PUT(p.ICER, p.intS); ARMv7M.ISB;
					p.inFree := p.inFree + done;
				SYSTEM.PUT(p.ISER, p.intS)
		END
	END Read;

BEGIN
	interrupt := SYSTEM.VAL(Proc0, Interrupt)
END MicroSTM32F1Ports.

O7ARMv7MTool.DecObj MicroSTM32F1Ports.a7m
