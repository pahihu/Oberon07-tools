MODULE MicroSTM32F101x8System;

	(*
		Alexander Shiryaev, 2016.02, 2017.04

		STM32F101x{8,B}

		RM0008, Reference manual
	*)

	IMPORT SYSTEM, ARMv7M := MicroARMv7M, MCU := MicroSTM32F10xxD, Kernel := MicroKernel0, Traps := MicroARMv7MTraps;

	CONST
		SRAMStart = MCU.SRAMStart;
		VectorsOrg* = SRAMStart;
		HeapOrg = VectorsOrg + 200H;
		(*
			STM32F101x8: SRAMSize = 10 KiB
			STM32F101xB: SRAMSize = 16 KiB
		*)
		StkSize = 1024;

		HSIFreq = 8000000; (* Hz *)
		HSEFreq = 8000000; (* Hz *)
		(* PLLSRC *)
			HSI = 0; HSE = 1;

		HPRE = 0; (* HCLK = SYSCLK *)
		PPRE1 = 0; (* PCLK1 = HCLK; PCLK1 <= 36 MHz *)
		PPRE2 = 0; (* PCLK2 = HCLK; PCLK2 <= 72 MHz *)
		USBPRE = 0; (* PLLCLK / 1.5 *)
		ADCPRE = 1; (* ADCCLK = PCLK2 DIV 4; ADCCLK <= 14 MHz *)
		PLLXTPRE = 1; (* HSE clock divided by 2 *)
		PLLSRC = HSE; (* HSI | HSE *)

		HCLK* = 36000000; (* Hz *)
		PCLK1* = HCLK;
		PCLK2* = HCLK;
		ADCCLK* = PCLK2 DIV 4;

		PLLM = (((PLLXTPRE + 1) * HCLK) DIV HSEFreq) * PLLSRC
			+ ((2 * HCLK) DIV HSIFreq) * (1 - PLLSRC); (* 2 <= PLLM <= 16 *)

		(* RCCCR bits: *)
			HSION = 0; HSIRDY = 1; HSEON = 16; HSERDY = 17; HSEBYP = 18;
			CSSON = 19; PLLON = 24; PLLRDY = 25;

		(* RCCCIR bits: *)
			LSIRDYC = 16; LSERDYC = 17; HSIRDYC = 18; HSERDYC = 19; PLLRDYC = 20;
			CSSC = 23;

		(* FLASHACR bits: *)
			PRFTBE = 4;

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

		(* Enable Preferch Buffer *)
			SYSTEM.GET(MCU.FLASHACR, x);
			SYSTEM.PUT(MCU.FLASHACR, x + {PRFTBE});
		(* Flash 1 wait state (24 MHz < SYSCLK <= 48 MHz) *)
			SYSTEM.GET(MCU.FLASHACR, x);
			SYSTEM.PUT(MCU.FLASHACR, x - {1,2} + {0});

		(* device type # CL *)
			(* Configure PLL *)
				SYSTEM.PUT(MCU.RCCCFGR, HPRE * 10H + PPRE1 * 100H + PPRE2 * 800H
					+ ADCPRE * 4000H + USBPRE * 400000H
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
				(* device type IN {LD,MD,HD,XL} *)
					(* Disable all interrupts and clear pending bits *)
						SYSTEM.PUT(MCU.RCCCIR,
							{LSIRDYC,LSERDYC,HSIRDYC,HSERDYC,PLLRDYC,CSSC});

			SetSysClock;

		Traps.Init(VectorsOrg);

		(* linker-dependent *)
			SYSTEM.GET(SYSTEM.REG(MT), StkOrg);
			Kernel.Init(HeapOrg, StkOrg - StkSize)
	END Init;

BEGIN
	Init
END MicroSTM32F101x8System.
