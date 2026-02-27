MODULE MicroSTM32L1System;

	(*
		Alexander Shiryaev, 2021.09

		RM0038, Reference manual,
			STM32L100xx, STM32L151xx, STM32L152xx, STM32L162xx
	*)

	IMPORT SYSTEM, ARMv7M := MicroARMv7M, MCU := MicroSTM32L1, Kernel := MicroKernel0, Traps := MicroARMv7MTraps;

	CONST
		SRAMStart = MCU.SRAMStart;
		VectorsOrg* = SRAMStart;
		HeapOrg = VectorsOrg + 200H;
		StkSize = 1024;

		fHSI = 16000000; (* Hz *)
		fHSE = 8000000; (* Hz *)

		(* PLLSRC *)
			HSI = 0; HSE = 1;

		PLLSRC = HSE; (* HSI | HSE *)
			fPLLIn = PLLSRC * fHSE + (1 - PLLSRC) * fHSI; (* >= 2 MHz *)
			PLLM = PLLSRC * 12 + (1 - PLLSRC) * 6; (* 3 | 4 | 6 | 8 | 12 | 16 | 24 | 32 | 48 *)
			PLLMUL = PLLSRC * 4 + (1 - PLLSRC) * 2; (* 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 *)

		fPLLVCO = fPLLIn * PLLM; (* Range 1: <= 96 MHz *)

		PLLD = 3; (* 2 | 3 | 4 *)

		fPLLOut = fPLLVCO DIV PLLD;

		HPRE = 0; (* HCLK = SYSCLK *)
		PPRE1 = 0; (* PCLK1 = HCLK; PCLK1 <= 32 MHz *)
		PPRE2 = 0; (* PCLK2 = HCLK; PCLK2 <= 32 MHz *)

		MCOSEL = 0; (* MCO output disabled, no clock on MCO *)
		MCOPRE = 0; (* MCO is divided by 1 *)

		HCLK* = fPLLOut;
		PCLK1* = HCLK;
		TIMCLK1* = PCLK1;
		PCLK2* = HCLK;
		TIMCLK2* = PCLK2;
		(* ADCCLK* = fHSI; *)
		SDIOCLK* = fPLLVCO DIV 2;

		(* RCCCR bits: *)
			HSION = 0; HSIRDY = 1;
			MSION = 8; MSIRDY = 9;
			HSEON = 16; HSERDY = 17; HSEBYP = 18;
			PLLON = 24; PLLRDY = 25;
			CSSON = 28;

		(* RCCCIR bits: *)
			LSIRDYC = 16; LSERDYC = 17;
			HSIRDYC = 18; HSERDYC = 19;
			PLLRDYC = 20;
			MSIRDYC = 21;
			LSECSSC = 22;
			CSSC = 23;

		(* RCCAPB1ENR bits: *)
			PWREN = 28;

		(* PWRCR bits: *)
			VOS0 = 11; VOS1 = 12;

		(* PWRCSR bits: *)
			VOSF = 4;

		(* FLASHACR bits: *)
			LATENCY = 0; PRFTEN = 1; ACC64 = 2;

	PROCEDURE SetSysClock;
		VAR x: SET;
	BEGIN
		SYSTEM.GET(MCU.RCCCR, x);
		IF PLLSRC = HSE THEN
			(* Enable HSE *)
				SYSTEM.PUT(MCU.RCCCR, x + {HSEON});
			REPEAT UNTIL SYSTEM.BIT(MCU.RCCCR, HSERDY)
		ELSE
			(* Enable HSI *)
				SYSTEM.PUT(MCU.RCCCR, x + {HSION});
			REPEAT UNTIL SYSTEM.BIT(MCU.RCCCR, HSIRDY)
		END;

		(* Enable 64-bit access *)
			SYSTEM.GET(MCU.FLASHACR, x);
			SYSTEM.PUT(MCU.FLASHACR, x + {ACC64});
		(* Enable Preferch Buffer *)
			SYSTEM.GET(MCU.FLASHACR, x);
			SYSTEM.PUT(MCU.FLASHACR, x + {PRFTEN});
		(* Flash 1 wait state *)
			SYSTEM.GET(MCU.FLASHACR, x);
			SYSTEM.PUT(MCU.FLASHACR, x + {LATENCY});

		(* Enable PWR power *)
			SYSTEM.GET(MCU.RCCAPB1ENR, x);
			SYSTEM.PUT(MCU.RCCAPB1ENR, x + {PWREN});

		(* Select the Voltage Range 1 *)
			SYSTEM.GET(MCU.PWRCR, x);
			SYSTEM.PUT(MCU.PWRCR, x - {VOS0,VOS1} + {VOS0});
		REPEAT UNTIL ~SYSTEM.BIT(MCU.PWRCSR, VOSF);

		(* Configure PLL *)
			SYSTEM.PUT(MCU.RCCCFGR, HPRE * 10H + PPRE1 * 100H + PPRE2 * 800H
				+ PLLSRC * 10000H
				+ PLLMUL * 40000H + (PLLD - 1) * 400000H
				+ MCOSEL * 1000000H + MCOPRE * 10000000H);

		(* Enable PLL *)
			SYSTEM.GET(MCU.RCCCR, x);
			SYSTEM.PUT(MCU.RCCCR, x + {PLLON});
		REPEAT UNTIL SYSTEM.BIT(MCU.RCCCR, PLLRDY);

		(* Select PLL as system clock source *)
			SYSTEM.GET(MCU.RCCCFGR, x);
			SYSTEM.PUT(MCU.RCCCFGR, x - {0,1});
			SYSTEM.GET(MCU.RCCCFGR, x);
			SYSTEM.PUT(MCU.RCCCFGR, x + {0,1});
		REPEAT SYSTEM.GET(MCU.RCCCFGR, x) UNTIL x * {2,3} = {2,3}
	END SetSysClock;

	PROCEDURE Init;
		CONST MT = 6; (* compiler-dependent *)
		VAR x: SET;
			StkOrg: INTEGER;
	BEGIN
		(* system_stm32l1xx.c, SystemInit: *)

			(* RCC *)
				(* Reset clock configuration to the default reset state *)
					SYSTEM.GET(MCU.RCCCR, x);
					SYSTEM.PUT(MCU.RCCCR, x + {MSION});
				(* Reset SW, HPRE, PPRE1, PPRE2, MCOSEL and MCOPRE bits *)
					SYSTEM.GET(MCU.RCCCFGR, x);
					SYSTEM.PUT(MCU.RCCCFGR, x - {0,1,4..13,24..26,28..30});
				(* Reset HSION, HSEON, CSSON and PLLON bits *)
					SYSTEM.GET(MCU.RCCCR, x);
					SYSTEM.PUT(MCU.RCCCR, x - {HSION,HSEON,CSSON,PLLON});
				(* Reset HSEBYP bit *)
					SYSTEM.GET(MCU.RCCCR, x);
					SYSTEM.PUT(MCU.RCCCR, x - {HSEBYP});
				(* Reset PLLSRC, PLLMUL and PLLDIV bits *)
					SYSTEM.GET(MCU.RCCCFGR, x);
					SYSTEM.PUT(MCU.RCCCFGR, x - {16,18..23});
				(* Disable all interrupts and clear pending bits *)
					SYSTEM.PUT(MCU.RCCCIR, 0);

			SetSysClock;

		Traps.Init(VectorsOrg);

		(* linker-dependent *)
			SYSTEM.GET(SYSTEM.REG(MT), StkOrg);
			Kernel.Init(HeapOrg, StkOrg - StkSize)
	END Init;

BEGIN
	Init
END MicroSTM32L1System.
