MODULE MicroSTM32F030System;

	(*
		Alexander Shiryaev, 2016.04

		RM0360, Reference manual,
			STM32F030x{4,6,8,C}, STM32F070x{6,B}
	*)

	IMPORT SYSTEM, MCU := MicroSTM32F030, Kernel := MicroKernel0, Traps := MicroARMv6MTraps;

	CONST
		SRAMStart = MCU.SRAMStart;
		VectorsOrg* = SRAMStart;
		HeapOrg = VectorsOrg + 200H;
		StkSize = 1024;

		HSIFreq = 8000000; (* Hz *)
		HSEFreq = 8000000; (* Hz *)
		(* PLLSRC *)
			HSI = 0; HSE = 1;

		HPRE = 0; (* HCLK = SYSCLK *)
		PPRE = 0; (* PCLK = HCLK *)
		PLLXTPRE = 1; (* HSE clock divided by 2 *)
		PLLSRC = HSI; (* HSI | HSE *)

		HCLK* = 48000000; (* Hz *)
		PCLK* = HCLK;

		PLLM = (((PLLXTPRE + 1) * HCLK) DIV HSEFreq) * PLLSRC
			+ ((2 * HCLK) DIV HSIFreq) * (1 - PLLSRC); (* 2 <= PLLM <= 16 *)

		(* RCCCR bits: *)
			HSION = 0; HSIRDY = 1; HSEON = 16; HSERDY = 17; HSEBYP = 18;
			CSSON = 19; PLLON = 24; PLLRDY = 25;

		(* FLASHACR bits: *)
			PRFTBE = 4;

	PROCEDURE SetSysClock;
		VAR x: SET;
	BEGIN
		IF PLLSRC = HSE THEN
			(* enable HSE *)
				SYSTEM.GET(MCU.RCCCR, x);
				SYSTEM.PUT(MCU.RCCCR, x + {HSEON});
			REPEAT UNTIL SYSTEM.BIT(MCU.RCCCR, HSERDY)
		ELSE
			REPEAT UNTIL SYSTEM.BIT(MCU.RCCCR, HSIRDY)
		END;

		(* enable prefetch buffer *)
			SYSTEM.GET(MCU.FLASHACR, x);
			SYSTEM.PUT(MCU.FLASHACR, x + {PRFTBE});
		(* flash 1 wait state (24 MHz < SYSCLK <= 48 MHz) *)
			SYSTEM.GET(MCU.FLASHACR, x);
			SYSTEM.PUT(MCU.FLASHACR, x - {1,2} + {0});

		(* configure PLL *)
			SYSTEM.PUT(MCU.RCCCFGR, HPRE * 10H + PPRE * 100H
				+ PLLSRC * 10000H + PLLXTPRE * 20000H
				+ (PLLM - 2) * 40000H);

		(* enable PLL *)
			SYSTEM.GET(MCU.RCCCR, x);
			SYSTEM.PUT(MCU.RCCCR, x + {PLLON});
		REPEAT UNTIL SYSTEM.BIT(MCU.RCCCR, PLLRDY);

		(* select PLL as system clock source *)
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
		(* system_stm32f0xx.c, SystemInit: *)

			(* set HSION *)
				SYSTEM.GET(MCU.RCCCR, x);
				SYSTEM.PUT(MCU.RCCCR, x + {HSION});

			(* reset SW, HPRE, PPRE *)
				SYSTEM.GET(MCU.RCCCFGR, x);
				SYSTEM.PUT(MCU.RCCCFGR, x - {0,1,4..10});

			(* reset HSEON, CSSON and PLLON *)
				SYSTEM.GET(MCU.RCCCR, x);
				SYSTEM.PUT(MCU.RCCCR, x - {HSEON,CSSON,PLLON});

			(* reset HSEBYP *)
				SYSTEM.GET(MCU.RCCCR, x);
				SYSTEM.PUT(MCU.RCCCR, x - {HSEBYP});

			(* reset PLLSRC, PLLXTPRE and PLLMUL *)
				SYSTEM.GET(MCU.RCCCFGR, x);
				SYSTEM.PUT(MCU.RCCCFGR, x - {16..21});

			(* reset PREDIV *)
				SYSTEM.GET(MCU.RCCCFGR2, x);
				SYSTEM.PUT(MCU.RCCCFGR2, x - {0..3});

			SetSysClock;

		SYSTEM.GET(MCU.SYSCFGCFGR1, x);
		SYSTEM.PUT(MCU.SYSCFGCFGR1, x + {0,1});

		Traps.Init(VectorsOrg);

		(* linker-dependent *)
			SYSTEM.GET(SYSTEM.REG(MT), StkOrg);
			Kernel.Init(HeapOrg, StkOrg - StkSize)
	END Init;

BEGIN
	Init
END MicroSTM32F030System.
