MODULE MicroLPC1100System;

	(*
		Alexander Shiryaev, 2014.09, 2016.04

		LPC1100, LPC1100L, LPC1100XL, LPC11C00 series
	*)

	IMPORT SYSTEM, MCU := MicroLPC1100, Kernel := MicroKernel0, Traps := MicroARMv6MTraps;

	CONST
		SRAMStart = MCU.SRAMStart;
		VectorsOrg* = SRAMStart;
		HeapOrg = VectorsOrg + 200H;
		StkSize = 1024;

		Fosc* = 12000000; (* Hz *)
		MSEL = 3; PSEL = 1;
		M = MSEL + 1; (* P = LSL(1, PSEL); *)
		CCLK* = M * Fosc;
		SYSAHBCLKDIV = 1;
		PCLK* = CCLK DIV SYSAHBCLKDIV;

	(*
		SYSPLLCLKSEL:
			0: IRC oscillator
			1: system oscillator
	*)
	(* system_LPC11xx.c, SystemInit *)
	PROCEDURE SetupClock (SYSPLLCLKSEL: INTEGER);
		CONST
			(* PDRUNCFG bits: *)
				SYSOSCPD = 5; WDTOSCPD = 6; SYSPLLPD = 7;
			(* SYSPLLSTAT bits: *)
				LOCK = 0;
			SYSOSCCTRL = 0;
			WDTOSCCTRL = 0;
			SYSPLLCTRL = PSEL * 32 + MSEL;
				(*
					Fclkout = M * Fclkin = Fcco / (2 * P)
						10 < Fclkin < 25 MHz
						156 MHz < Fcco < 320 MHz
				*)
			MAINCLKSEL = 3;
				(*
					0: IRC oscillator
					1: input clock to system PLL
					2: WDT oscillator
					3: system PLL clock out
				*)
		VAR x: SET; i: INTEGER;
	BEGIN
		IF SYSPLLCLKSEL = 1 THEN
			SYSTEM.GET(MCU.PDRUNCFG, x);
			SYSTEM.PUT(MCU.PDRUNCFG, x - {SYSOSCPD}); (* power-up system oscillator *)
			SYSTEM.PUT(MCU.SYSOSCCTRL, SYSOSCCTRL);
			i := 200; REPEAT DEC(i) UNTIL i = 0
		END;
		SYSTEM.PUT(MCU.SYSPLLCLKSEL, SYSPLLCLKSEL); (* select PLL input *)
		SYSTEM.PUT(MCU.SYSPLLCLKUEN, 1); (* update clock source *)
		SYSTEM.PUT(MCU.SYSPLLCLKUEN, 0); (* toggle update register *)
		SYSTEM.PUT(MCU.SYSPLLCLKUEN, 1);
		REPEAT UNTIL SYSTEM.BIT(MCU.SYSPLLCLKUEN, 0); (* wait until updated *)

		IF MAINCLKSEL = 3 THEN (* main clock is PLL out *)
			SYSTEM.PUT(MCU.SYSPLLCTRL, SYSPLLCTRL);
			SYSTEM.GET(MCU.PDRUNCFG, x);
			SYSTEM.PUT(MCU.PDRUNCFG, x - {SYSPLLPD}); (* power-up system PLL *)
			REPEAT UNTIL SYSTEM.BIT(MCU.SYSPLLSTAT, LOCK) (* wait until PLL locked *)
		ELSIF MAINCLKSEL = 2 THEN
			SYSTEM.PUT(MCU.WDTOSCCTRL, WDTOSCCTRL);
			SYSTEM.PUT(MCU.PDRUNCFG, x - {WDTOSCPD}); (* power-up watchdog oscillator *)
			i := 200; REPEAT DEC(i) UNTIL i = 0
		END;

		SYSTEM.PUT(MCU.MAINCLKSEL, MAINCLKSEL); (* select PLL clock output *)
		SYSTEM.PUT(MCU.MAINCLKUEN, 1); (* update MCLK clock source *)
		SYSTEM.PUT(MCU.MAINCLKUEN, 0); (* toggle update register *)
		SYSTEM.PUT(MCU.MAINCLKUEN, 1);
		REPEAT UNTIL SYSTEM.BIT(MCU.MAINCLKUEN, 0); (* wait until updated *)

		SYSTEM.PUT(MCU.SYSAHBCLKDIV, SYSAHBCLKDIV)
	END SetupClock;

	PROCEDURE Init;
		CONST MT = 6; (* compiler-dependent *)
		VAR x: SET;
			StkOrg: INTEGER;
	BEGIN
		SYSTEM.GET(MCU.FLASHCFG, x);
		(* SYSTEM.PUT(MCU.FLASHCFG, x - {0,1}); (* 1 system clock flash access time (for system clock frequencies of up to 20 MHz) *) *)
		(* SYSTEM.PUT(MCU.FLASHCFG, x + {0} - {1}); (* 2 system clock flash access time (for system clock frequencies of up to 40 MHz) *) *)
		SYSTEM.PUT(MCU.FLASHCFG, x + {1} - {0}); (* 3 system clock flash access time (for system clock frequencies of up to 50 MHz) *)

		SetupClock(1);

		SYSTEM.PUT(MCU.SYSMEMREMAP, 1); (* User RAM Mode *)
		Traps.Init(VectorsOrg);

		(* linker-dependent *)
			SYSTEM.GET(SYSTEM.REG(MT), StkOrg);
			Kernel.Init(HeapOrg, StkOrg - StkSize)
	END Init;

BEGIN
	Init
END MicroLPC1100System.

O7ARMv6MP.Compile @/s

O7ARMv7MTool.DecObj MicroLPC1100System.a6m 
