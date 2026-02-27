MODULE MicroSTM32F4System;

	(*
		Alexander Shiryaev, 2021.08

		RM0368, Reference manual,
			STM32F401x{B,C,D,E}

		RM0383, Reference manual,
			STM32F411xC/E

		RM0090, Reference manual,
			STM32F405xx/07xx, STM32F415xx/17xx,
			STM32F42xxx, STM32F43xxx

		RM0390, Reference manual,
			STM32F446xx
	*)

	IMPORT SYSTEM,
		ARMv7M := MicroARMv7M,
		MCU := MicroSTM32F4,
		Kernel := MicroKernel0,
		Traps := MicroARMv7MTraps;

	CONST
		SRAMStart = MCU.SRAMStart;
		VectorsOrg* = SRAMStart;
		HeapOrg = VectorsOrg + 200H;
		StkSize = 8192;

		fHSI = 16000000; (* Hz *)

		(* PLLSRC *)
			HSI = 0; HSE = 1;

		(* RCCCR bits: *)
			HSION = 0; HSIRDY = 1; HSEON = 16; HSERDY = 17; HSEBYP = 18;
			CSSON = 19; PLLON = 24; PLLRDY = 25;

		(* RCCAPB1ENR bits: *)
			WWDGEN = 11; PWREN = 28;

		(* FLASHACR bits: *)
			PRFTEN = 8; ICEN = 9; DCEN = 10; ICRST = 11; DCRST = 12;

	VAR
		HCLK*,
		PCLK1*, TIMCLK1*,
		PCLK2*, TIMCLK2*,
		QCLK*,
		RCLK*: INTEGER; (* Hz *)
			(* QCLK <= 48 MHz, best is 48 MHz *)

	(*
		Configures the System clock source,
			PLL Multiplier and Divider factors,
			AHB/APBx prescalers and Flash settings
		PLLSRC: HSI | HSE
		NOTE:
			should be called only once the RCC clock configuration
			is reset to the default reset state (done in Init)
	*)
	PROCEDURE SetSysClock (PLLSRC: INTEGER);
		CONST
			(* PWRCR bits: *)
				VOS0 = 14; VOS1 = 15; ODEN = 16; ODSWEN = 17;
			(* PWRCSR bits: *)
				ODRDY = 16; ODSWRDY = 17;
		VAR x: SET;
			id: INTEGER;
			fHSE: INTEGER; (* Hz *)
			PLLM: INTEGER;
			VOS: SET;
			HPREN, PPRE1N, PPRE2N: INTEGER;
			fVCOIn: INTEGER; (* Hz *) (* 1 MHz <= fVCOIn <= 2 MHz, up is best *)
			fVCOOut, fPLLOut: INTEGER;
			PLLN: INTEGER;
			PLLP: INTEGER; (* 2 | 4 | 6 | 8 *)
			PLLQ: INTEGER; (* 2 <= PLLQ <= 15 *)
			PLLR: INTEGER; (* 2 <= PLLR <= 7 *)
			flashLatency: INTEGER; (* WS *)
	BEGIN
		fHSE := 8000000;
		fVCOIn := 2000000;
		PLLR := 2;
		SYSTEM.GET(MCU.DBGMCUIDCODE, id); id := id MOD 1000H;
		IF id = 413H THEN (* STM32F4{0,1}{5,7} *)
			VOS := {VOS0}; (* fHCLKmax = 168 MHz *)
			(* fPCLK2 <= 90 MHz *)
			(* fPCLK1 <= 45 MHz *)
			HPREN := 0; PPRE2N := 1; PPRE1N := 2;
			(* 50 <= PLLN <= 432 *)
				(* PLLN := 168; *)
				PLLN := 160; (* to reach I2C clock of 400 kHz *)
			(* 100 MHz <= fVCOOut <= 432 MHz *)
			PLLP := 2;
			(* QCLK := 48000000; *)
			QCLK := 40000000;
			flashLatency := 5 (* 2.7--3.6 (V), 150 < HCLK <= 168 (MHz) *)
		ELSIF id = 419H THEN (* STM32F4{2,3}x *)
			fHSE := 24000000;
			VOS := {VOS0,VOS1}; (* fHCLKmax = 180 MHz *)
			HPREN := 0; PPRE2N := 1; PPRE1N := 2;
			(* 50 <= PLLN <= 432 *)
				(* PLLN := 180; *)
				PLLN := 160; (* to reach I2C clock of 400 kHz *)
			(* 100 MHz <= fVCOOut <= 432 MHz *)
			PLLP := 2;
			(* QCLK := 48000000; *)
			QCLK := 40000000;
			flashLatency := 5 (* 2.7--3.6 (V), 150 < HCLK <= 180 (MHz) *)
		ELSIF id = 421H THEN (* STM32F446 *)
			VOS := {VOS0,VOS1}; (* fHCLKmax = 180 MHz *)
			(* fPCLK2 <= 90 MHz *)
			(* fPCLK1 <= 45 MHz *)
			HPREN := 0; PPRE2N := 1; PPRE1N := 2;
			(* 50 <= PLLN <= 432 *)
				(* PLLN := 180; *)
				PLLN := 160; (* to reach I2C clock of 400 kHz *)
			(* 100 MHz <= fVCOOut <= 432 MHz *)
			PLLP := 2;
			(* QCLK := 48000000; *)
			QCLK := 40000000;
			flashLatency := 5 (* 2.7--3.6 (V), 150 < HCLK <= 180 (MHz) *)
		ELSIF (id = 423H) OR (id = 433H) THEN (* STM32F401x{B,C,D,E} *)
			fHSE := 25000000;
			VOS := {VOS1}; (* fHCLKmax = 84 MHz *)
			(* fPCLK2 <= 84 MHz *)
			(* fPCLK1 <= 42 MHz *)
			HPREN := 0; PPRE2N := 0; PPRE1N := 1;
			fVCOIn := 1000000;
			(* 192 <= PLLN <= 432 *)
				(* PLLN := 336; *)
				PLLN := 320; (* to reach I2C clock of 400 kHz *)
			(* 192 MHz <= fVCOOut <= 432 MHz *)
			PLLP := 4;
			(* QCLK := 48000000; *)
			QCLK := 40000000;
			flashLatency := 2 (* 2.7--3.6 (V), 60 < HCLK <= 84 (MHz) *)
		ELSIF id = 431H THEN (* STM32F411x{C,E} *)
			VOS := {VOS0,VOS1}; (* fHCLKmax = 100 MHz *)
			(* fPCLK2 <= 100 MHz *)
			(* fPCLK1 <= 50 MHz *)
			HPREN := 0; PPRE2N := 0; PPRE1N := 1;
			(* 50 <= PLLN <= 432 *)
				PLLN := 100; (* to reach I2C clock of 400 kHz *)
			(* 100 MHz <= fVCOOut <= 432 MHz *)
			PLLP := 2;
			(* QCLK := 48000000; *)
			QCLK := 40000000;
			flashLatency := 3 (* 2.7--3.6 (V), 90 < HCLK <= 100 (MHz) *)
		ELSE
			REPEAT UNTIL FALSE (* HALT *)
		END;
		fVCOOut := fVCOIn * PLLN;
		fPLLOut := fVCOOut DIV PLLP;
		PLLQ := (fVCOOut - 1) DIV QCLK + 1;
		QCLK := fVCOOut DIV PLLQ;
		RCLK := fVCOOut DIV PLLR;
		HCLK := ASR(fPLLOut, HPREN);
		PCLK1 := ASR(HCLK, PPRE1N);
		PCLK2 := ASR(HCLK, PPRE2N);
		IF PPRE1N = 0 THEN
			TIMCLK1 := PCLK1
		ELSE
			TIMCLK1 := PCLK1 * 2
		END;
		IF PPRE2N = 0 THEN
			TIMCLK2 := PCLK2
		ELSE
			TIMCLK2 := PCLK2 * 2
		END;

		IF PLLSRC = HSE THEN
			(* Enable HSE *)
				SYSTEM.GET(MCU.RCCCR, x);
				SYSTEM.PUT(MCU.RCCCR, x + {HSEON});
			REPEAT UNTIL SYSTEM.BIT(MCU.RCCCR, HSERDY)
		ELSE
			REPEAT UNTIL SYSTEM.BIT(MCU.RCCCR, HSIRDY)
		END;

		(* Select regulator voltage output Scale 1 mode *)
			SYSTEM.GET(MCU.RCCAPB1ENR, x);
			SYSTEM.PUT(MCU.RCCAPB1ENR, x + {PWREN});
			SYSTEM.GET(MCU.PWRCR, x);
			SYSTEM.PUT(MCU.PWRCR, x - {VOS0,VOS1} + VOS);

		(* NOTE: The AHB clock frequency must be at least 25 MHz when the Ethernet is used *)
			SYSTEM.GET(MCU.RCCCFGR, x);
			SYSTEM.PUT(MCU.RCCCFGR, x - {4..7}
				+ SYSTEM.VAL(SET, (HPREN + 7) * 10H));

			SYSTEM.GET(MCU.RCCCFGR, x);
			SYSTEM.PUT(MCU.RCCCFGR, x - {13,14,15}
				+ SYSTEM.VAL(SET, (PPRE2N + 3) * 2000H));

			SYSTEM.GET(MCU.RCCCFGR, x);
			SYSTEM.PUT(MCU.RCCCFGR, x - {10,11,12}
				+ SYSTEM.VAL(SET, (PPRE1N + 3) * 400H));

		(* Configure the main PLL *)
			IF PLLSRC = HSE THEN PLLM := fHSE DIV fVCOIn
			ELSE PLLM := fHSI DIV fVCOIn
			END; (* 2 <= PLLM <= 63 *)
			SYSTEM.PUT(MCU.RCCPLLCFGR, PLLM + PLLN * 40H
				+ (PLLP DIV 2 - 1) * 10000H
				+ PLLSRC * 400000H
				+ PLLQ * 1000000H
				+ PLLR * 10000000H);

		(* Enable the main PLL *)
			SYSTEM.GET(MCU.RCCCR, x);
			SYSTEM.PUT(MCU.RCCCR, x + {PLLON});
		REPEAT UNTIL SYSTEM.BIT(MCU.RCCCR, PLLRDY);

		IF HCLK > 168000000 THEN
			(* Enable the Over-drive to extend the clock frequency to 180 MHz *)
				SYSTEM.GET(MCU.PWRCR, x);
				SYSTEM.PUT(MCU.PWRCR, x + {ODEN});
				REPEAT UNTIL SYSTEM.BIT(MCU.PWRCSR, ODRDY);

				SYSTEM.GET(MCU.PWRCR, x);
				SYSTEM.PUT(MCU.PWRCR, x + {ODSWEN});
				REPEAT UNTIL SYSTEM.BIT(MCU.PWRCSR, ODSWRDY)
		END;

		(*
			Configure Flash prefetch, Instruction cache, Data cache
			and wait state
		*)
			SYSTEM.PUT(MCU.FLASHACR, {PRFTEN,ICEN,DCEN}
				+ SYSTEM.VAL(SET, flashLatency));

		(* Select the main PLL as system clock source *)
			SYSTEM.GET(MCU.RCCCFGR, x);
			SYSTEM.PUT(MCU.RCCCFGR, x - {0,1});
			SYSTEM.GET(MCU.RCCCFGR, x);
			SYSTEM.PUT(MCU.RCCCFGR, x - {0} + {1});
		REPEAT SYSTEM.GET(MCU.RCCCFGR, x) UNTIL x * {2,3} = {3}
	END SetSysClock;

	PROCEDURE Init;
		CONST MT = 6; (* compiler-dependent *)
			(* ARMv7M.FPCCR bits: *)
				LSPEN = 30;
		VAR x: SET;
			StkOrg: INTEGER;
	BEGIN
		(* system_stm32f4xx.c, SystemInit: *)

			(* FPU: set CP10 and CP11 Full Access *)
				SYSTEM.GET(ARMv7M.CPACR, x);
				SYSTEM.PUT(ARMv7M.CPACR, x + {2*10,2*10+1,2*11,2*11+1});

(*
		(*
			http://www.st.com/web/en/resource/technical/document/errata_sheet/DM00037591.pdf, section 1.2

			http://www.st.com/content/ccc/resource/technical/document/errata_sheet/c3/6b/f8/32/fc/01/48/6e/DM00155929.pdf/files/DM00155929.pdf/jcr:content/translations/en.DM00155929.pdf, section 1.2
		*)

			(* Disable lazy context save of floating point state *)
				SYSTEM.GET(ARMv7M.FPCCR, x);
				SYSTEM.PUT(ARMv7M.FPCCR, x - {LSPEN});
*)

			(* RCC *)
				(* Reset clock configuration to the default reset state *)
					SYSTEM.GET(MCU.RCCCR, x);
					SYSTEM.PUT(MCU.RCCCR, x + {HSION});
				(* Reset CFGR register *)
					SYSTEM.PUT(MCU.RCCCFGR, {});
				(* Reset HSEON, CSSON and PLLON bits *)
					SYSTEM.GET(MCU.RCCCR, x);
					SYSTEM.PUT(MCU.RCCCR, x - {HSEON,CSSON,PLLON});
				(* Reset PLLCFGR register *)
					SYSTEM.PUT(MCU.RCCPLLCFGR, 24003010H);
				(* Reset HSEBYP bit *)
					SYSTEM.GET(MCU.RCCCR, x);
					SYSTEM.PUT(MCU.RCCCR, x - {HSEBYP});
				(* Disable all interrupts *)
					SYSTEM.PUT(MCU.RCCCIR, {});

			SetSysClock(HSE);

		Traps.Init(VectorsOrg);

		(* linker-dependent *)
			SYSTEM.GET(SYSTEM.REG(MT), StkOrg);
			Kernel.Init(HeapOrg, StkOrg - StkSize)
	END Init;

BEGIN
	Init
END MicroSTM32F4System.

O7ARMv7MP.Compile @/s

O7ARMv7MTool.DecObj MicroSTM32F4System.a7m 
