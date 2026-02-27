MODULE MicroSTM32F100x8System;

	(*
		Alexander Shiryaev, 2016.02, 2017.04

		STM32F100x{8,B}

		RM0041, Reference manual
	*)

	IMPORT SYSTEM, ARMv7M := MicroARMv7M, MCU := MicroSTM32F100, Kernel := MicroKernel0, Traps := MicroARMv7MTraps;

	CONST
		SRAMStart = MCU.SRAMStart;
		VectorsOrg* = SRAMStart;
		HeapOrg = VectorsOrg + 200H;
		(* STM32F100x{8,B} *)
			SRAMSize = 2000H; (* 8 KiB *)
		StkSize = 1024;

		HSIFreq = 8000000; (* Hz *)
		HSEFreq = 8000000; (* Hz *)
		(* PLLSRC *)
			HSI = 0; HSE = 1;

		HPRE = 0; (* HCLK = SYSCLK *)
		PPRE1 = 0; (* PCLK1 = HCLK; PCLK1 <= 24 MHz *)
		PPRE2 = 0; (* PCLK2 = HCLK; PCLK2 <= 24 MHz *)
		ADCPRE = 0; (* ADCCLK = PCLK2 DIV 2; ADCCLK <= 12 MHz *)
		PLLXTPRE = 1; (* HSE clock divided by 2 *)
		PLLSRC = HSE; (* HSI | HSE *)

		HCLK* = 24000000; (* Hz *)
		PCLK1* = HCLK;
		PCLK2* = HCLK;
		ADCCLK* = PCLK2 DIV 2;

		PLLM = (((PLLXTPRE + 1) * HCLK) DIV HSEFreq) * PLLSRC
			+ ((2 * HCLK) DIV HSIFreq) * (1 - PLLSRC); (* 2 <= PLLM <= 16 *)

		(* RCCCR bits: *)
			HSION = 0; HSIRDY = 1; HSEON = 16; HSERDY = 17; HSEBYP = 18;
			CSSON = 19; PLLON = 24; PLLRDY = 25;

		(* RCCCIR bits: *)
			LSIRDYC = 16; LSERDYC = 17; HSIRDYC = 18; HSERDYC = 19; PLLRDYC = 20;
			CSSC = 23;

	PROCEDURE SetSysClock;
		VAR x: SET;
	BEGIN
		IF PLLSRC = HSE THEN
			(* Enable HSE *)
				SYSTEM.GET(MCU.RCCCR, x);
				SYSTEM.PUT(MCU.RCCCR, x + {HSEON});
			REPEAT UNTIL SYSTEM.BIT(MCU.RCCCR, HSERDY)
		ELSE
			REPEAT UNTIL SYSTEM.BIT(MCU.RCCCR, HSIRDY)
		END;

		(* value line devices *)
			(* Configure PLL *)
				SYSTEM.PUT(MCU.RCCCFGR, HPRE * 10H + PPRE1 * 100H + PPRE2 * 800H
					+ ADCPRE * 4000H
					+ PLLSRC * 10000H + PLLXTPRE * 20000H
					+ (PLLM - 2) * 40000H);

		(* Enable PLL *)
			SYSTEM.GET(MCU.RCCCR, x);
			SYSTEM.PUT(MCU.RCCCR, x + {PLLON});
		REPEAT UNTIL SYSTEM.BIT(MCU.RCCCR, PLLRDY);

		(* Select PLL as system clock source *)
			SYSTEM.GET(MCU.RCCCFGR, x);
			SYSTEM.PUT(MCU.RCCCFGR, x - {0,1});
			SYSTEM.GET(MCU.RCCCFGR, x);
			SYSTEM.PUT(MCU.RCCCFGR, x - {0} + {1});
		REPEAT SYSTEM.GET(MCU.RCCCFGR, x) UNTIL x * {2,3} = {3}
	END SetSysClock;

	PROCEDURE Init;
		CONST MT = 6; (* compiler-dependent *)
		VAR x: SET;
			StkOrg: INTEGER;
	BEGIN
		(* system_stm32f10x.c, SystemInit: *)

			(* RCC *)
				(* Reset clock configuration to the default reset state *)
					SYSTEM.GET(MCU.RCCCR, x);
					SYSTEM.PUT(MCU.RCCCR, x + {HSION});
				(* Reset SW, HPRE, PPRE1, PPRE2, ADCPRE and MCO bits *)
					(* device type # CL *)
						SYSTEM.GET(MCU.RCCCFGR, x);
						SYSTEM.PUT(MCU.RCCCFGR, x - {0..15,24..27});
				(* Reset HSEON, CSSON and PLLON bits *)
					SYSTEM.GET(MCU.RCCCR, x);
					SYSTEM.PUT(MCU.RCCCR, x - {HSEON,CSSON,PLLON});
				(* Reset HSEBYP bit *)
					SYSTEM.GET(MCU.RCCCR, x);
					SYSTEM.PUT(MCU.RCCCR, x - {HSEBYP});
				(* Reset PLLSRC, PLLXTPRE, PLLMUL, USBPRE bits *)
					SYSTEM.GET(MCU.RCCCFGR, x);
					SYSTEM.PUT(MCU.RCCCFGR, x - {16..22});
				(* value line devices *)
					(* Disable all interrupts and clear pending bits *)
						SYSTEM.PUT(MCU.RCCCIR,
							{LSIRDYC,LSERDYC,HSIRDYC,HSERDYC,PLLRDYC,CSSC});
					(* Reset CFGR2 register *)
						SYSTEM.PUT(MCU.RCCCFGR2, 0);

			SetSysClock;

		Traps.Init(VectorsOrg);

		(* linker-dependent *)
			SYSTEM.GET(SYSTEM.REG(MT), StkOrg);
			Kernel.Init(HeapOrg, StkOrg - StkSize)
	END Init;

BEGIN
	Init
END MicroSTM32F100x8System.
