MODULE MicroLPC1769System;

	(*
		Alexander Shiryaev, 2016.04

		UM10360,
			LPC176x/5x User manual

		LPC17{51,52,54,56,58,63,64,65,66,67,68} (CCLK = 100 MHz)
		LPC17{5,6}9 (CCLK = 120 MHz)
	*)

	IMPORT SYSTEM, ARMv7M := MicroARMv7M, MCU := MicroLPC1769,
		Kernel := MicroKernel0, Traps := MicroARMv7MTraps;

	CONST
		SRAMStart = MCU.SRAMStart;
		VectorsOrg* = SRAMStart;
		HeapOrg = VectorsOrg + 200H;
		StkSize = 4096;

		IRCFreq = 4000000; (* Hz *)
		MainOscFreq = 12000000; (* Hz *)	

		(*
			32 kHz <= PLLINCLK <= 50 MHz
			6 <= M0 <= 512
			1 <= N0 <= 32
			fCCO = (2 * M0 * PLL0INCLK) DIV N0
			275 MHz <= fCCO <= 550 MHz
			PLL0OUTCLK = fCCO
			PLLCLK = PLL0OUTCLK
			1 <= CCLKDIV <= 256
			CCLK = PLLCLK DIV CCLKDIV
			PCLK0 = CCLK DIV PCLK0DIV
			PCLK1 = CCLK DIV PCLK1DIV
		*)

		M100M0 = 25; M100N0 = 2;
		M100M0IRC = 75; M100N0IRC = 2;
		M100CCLKDIV = 3;
		M100CCLK = (2 * M100M0 * MainOscFreq) DIV (M100N0 * M100CCLKDIV);

		M120M0 = 20; M120N0 = 1;
		M120M0IRC = 60; M120N0IRC = 1;
		M120CCLKDIV = 4;
		M120CCLK = (2 * M120M0 * MainOscFreq) DIV (M120N0 * M120CCLKDIV);

		PCLK0SEL = 0; PCLK0DIV = 4;
		PCLK1SEL = 0; PCLK1DIV = 4;

	VAR
		CCLK*, PCLK0*, PCLK1*: INTEGER;

	(*
		CLKSRC: PLL0 clock source
			0: internal RC oscillator
			1: main oscillator
	*)
	PROCEDURE ClockSetup (CLKSRC: INTEGER; is120MHz: BOOLEAN);
		CONST
			(* SCS bits: *)
				OSCEN = 5; OSCSTAT = 6;
			(* PLL0CON bits: *)
				PLLE0 = 0; PLLC0 = 1;
			(* PLL0STAT bits: *)
				PLLE0STAT = 24; PLLC0STAT = 25; PLOCK0 = 26;
		VAR x: SET;
	BEGIN
		IF CLKSRC = 1 THEN
			(* enable main oscillator *)
				SYSTEM.GET(MCU.SCS, x);
				SYSTEM.PUT(MCU.SCS, x + {OSCEN});
				REPEAT UNTIL SYSTEM.BIT(MCU.SCS, OSCSTAT)
		END;

		IF is120MHz THEN
			SYSTEM.PUT(MCU.CCLKCFG, M120CCLKDIV - 1)
		ELSE
			SYSTEM.PUT(MCU.CCLKCFG, M100CCLKDIV - 1)
		END;
		(* periphral clock must be selected before PLL0 enabling and connecting
				according errata.lpc1768-16.March.2010 *)
			SYSTEM.PUT(MCU.PCLKSEL0, PCLK0SEL);
			SYSTEM.PUT(MCU.PCLKSEL1, PCLK1SEL);

		(* select sysclk and PLL0 clock source *)
			SYSTEM.PUT(MCU.CLKSRCSEL, CLKSRC);

		(* setup PLL0 *)
			IF CLKSRC = 0 THEN
				IF is120MHz THEN
					SYSTEM.PUT(MCU.PLL0CFG,
						(M120M0IRC - 1) + (M120N0IRC - 1) * 10000H)
				ELSE
					SYSTEM.PUT(MCU.PLL0CFG,
						(M100M0IRC - 1) + (M100N0IRC - 1) * 10000H)
				END
			ELSE (* CLKSRC = 1 *)
				IF is120MHz THEN
					SYSTEM.PUT(MCU.PLL0CFG, (M120M0 - 1) + (M120N0 - 1) * 10000H)
				ELSE
					SYSTEM.PUT(MCU.PLL0CFG, (M100M0 - 1) + (M100N0 - 1) * 10000H)
				END
			END;
			SYSTEM.PUT(MCU.PLL0FEED, 0AAH);
			SYSTEM.PUT(MCU.PLL0FEED, 55H);
			SYSTEM.PUT(MCU.PLL0CON, {PLLE0}); (* PLL0 enable *)
			SYSTEM.PUT(MCU.PLL0FEED, 0AAH);
			SYSTEM.PUT(MCU.PLL0FEED, 55H);
			REPEAT UNTIL SYSTEM.BIT(MCU.PLL0STAT, PLOCK0);

			SYSTEM.PUT(MCU.PLL0CON, {PLLE0,PLLC0}); (* PLL0 enable and connect *)
			SYSTEM.PUT(MCU.PLL0FEED, 0AAH);
			SYSTEM.PUT(MCU.PLL0FEED, 55H);
			REPEAT SYSTEM.GET(MCU.PLL0STAT, x)
			UNTIL x * {PLLE0STAT,PLLC0STAT} = {PLLE0STAT,PLLC0STAT};

		IF is120MHz THEN CCLK := M120CCLK ELSE CCLK := M100CCLK END;
		PCLK0 := CCLK DIV PCLK0DIV;
		PCLK1 := CCLK DIV PCLK1DIV
	END ClockSetup;

	PROCEDURE Is120MHz (): BOOLEAN;
		CONST
			(* IAP *)
				IAPLOCATION = 1FFF1FF0H + 1 (* Thumb *);
				ReadPartID = 54;
				CMDSUCCESS = 0;
				LPC1759 = 25113737H;
				LPC1769 = 26113F37H;
		TYPE ProcIAP = PROCEDURE (a, b: INTEGER);
		VAR
			IAP: ProcIAP;
			a: ARRAY 2 OF INTEGER;
	BEGIN
		a[0] := ReadPartID;
		SYSTEM.PUT(SYSTEM.ADR(IAP), IAPLOCATION);
		IAP(SYSTEM.ADR(a), SYSTEM.ADR(a));
	RETURN (a[0] = CMDSUCCESS) & ((a[1] = LPC1759) OR (a[1] = LPC1769))
	END Is120MHz;

	PROCEDURE Init;
		CONST MT = 6; (* compiler-dependent *)
		VAR x: SET;
			StkOrg: INTEGER;
			is120MHz: BOOLEAN;
	BEGIN
		is120MHz := Is120MHz();

		IF is120MHz THEN
			SYSTEM.PUT(MCU.FLASHCFG, 503AH) (* "Safe" setting *)
		ELSE
			(* Flash accesses use 5 CPU clocks. Use for up to 100 MHz CPU clock *)
				SYSTEM.PUT(MCU.FLASHCFG, 403AH)
		END;

		(* system_LPC17xx.c, v1.13, SystemInit: *)

			ClockSetup(1, is120MHz);

		Traps.Init(VectorsOrg);

		(* linker-dependent *)
			SYSTEM.GET(SYSTEM.REG(MT), StkOrg);
			Kernel.Init(HeapOrg, StkOrg - StkSize)
	END Init;

BEGIN
	Init
END MicroLPC1769System.
