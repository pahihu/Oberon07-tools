MODULE MicroLPC1788System;

	(*
		Alexander Shiryaev, 2016.03

		UM10470,
			LPC178x/7x User manual

		LPC17{73,74,76,77,78,85,86,87,88}
	*)

	IMPORT SYSTEM, ARMv7M := MicroARMv7M, MCU := MicroLPC1788,
		Kernel := MicroKernel0, Traps := MicroARMv7MTraps;

	CONST
		SRAMStart = MCU.SRAMStart;
		VectorsOrg* = SRAMStart;
		HeapOrg = VectorsOrg + 200H;
		StkSize = 4096;

		IRCFreq = 12000000; (* Hz *)
		MainOscFreq = 12000000; (* Hz *)
			PLLINCLK = 12000000; (* Hz *)
				(* 10 MHz <= PLLINCLK <= 25 MHz *)

		M = 10; MSEL = M - 1; (* 1 <= M <= 32 *)
		P = 1; PSEL = 0; (* P IN {1,2,4,8} *)

		PLLOUTCLK = M * PLLINCLK; (* 9.75 MHz <= PLLOUTCLK <= 160 MHz *)

		fCCO = PLLOUTCLK * 2 * P; (* 156 MHz <= fCCO <= 320 MHz *)

		PLLCLK = PLLOUTCLK;

		CCLKDIV = 1;
		PCLKDIV = 2;

		CCLK* = PLLCLK DIV CCLKDIV;
		PCLK* = PLLCLK DIV PCLKDIV;

	(*
		CLKSRC: sysclk and PLL0 clock source
			0: internal RC oscillator
			1: main oscillator
	*)
	PROCEDURE ClockSetup (CLKSRC: INTEGER);
		CONST
			(* SCS bits: *)
				OSCEN = 5; OSCSTAT = 6;
			(* PLL{0,1}CON bits: *)
				PLLE = 0;
			(* PLL{0,1}STAT bits: *)
				PLOCK = 10;
		VAR x: SET;
	BEGIN
		IF CLKSRC = 1 THEN
			(* enable main oscillator *)
				SYSTEM.GET(MCU.SCS, x);
				SYSTEM.PUT(MCU.SCS, x + {OSCEN});
				REPEAT UNTIL SYSTEM.BIT(MCU.SCS, OSCSTAT)
		END;

		(* select sysclk and PLL0 clock source *)
			SYSTEM.PUT(MCU.CLKSRCSEL, CLKSRC);

		(* setup PLL0 *)
			SYSTEM.PUT(MCU.PLL0CFG, MSEL + PSEL * 32);
			SYSTEM.PUT(MCU.PLL0CON, {PLLE});
			SYSTEM.PUT(MCU.PLL0FEED, 0AAH);
			SYSTEM.PUT(MCU.PLL0FEED, 55H);
			REPEAT UNTIL SYSTEM.BIT(MCU.PLL0STAT, PLOCK);

		SYSTEM.PUT(MCU.CCLKSEL, CCLKDIV + 100H);
			(* use output of main PLL as input to CPU clock divider *)
		SYSTEM.PUT(MCU.PCLKSEL, PCLKDIV)
	END ClockSetup;

	PROCEDURE Init;
		CONST MT = 6; (* compiler-dependent *)
		VAR x: SET;
			StkOrg: INTEGER;
	BEGIN
		SYSTEM.PUT(MCU.FLASHCFG, 503AH); (* "Safe" setting *)

		(* system_LPC177x_8x.c, v1.0, SystemInit: *)

			ClockSetup(1);

			SYSTEM.GET(MCU.PBOOST, x);
			SYSTEM.PUT(MCU.PBOOST, x + {0,1});
				(* boost is on, operation up to 120 MHz is supported *)

		Traps.Init(VectorsOrg);

		(* linker-dependent *)
			SYSTEM.GET(SYSTEM.REG(MT), StkOrg);
			Kernel.Init(HeapOrg, StkOrg - StkSize)
	END Init;

BEGIN
	Init
END MicroLPC1788System.
