MODULE MicroARMv7MSTM32F4WWDG;

	(*
		Alexander Shiryaev, 2018.05, 2019.10

		RM0090, Reference manual,
			STM32F4{0,1}{5,7}xx, STM32F4{2,3}{7,9}xx
	*)

	IMPORT SYSTEM, ARMv7M := MicroARMv7M, Traps := MicroARMv7MTraps;

	CONST
		(* WDGTB values: *)
			WDGTB1* = 0; WDGTB2* = 1; WDGTB4* = 2; WDGTB8* = 3;
			WDGTBMax* = WDGTB8;
		(* W values: *)
			WMax* = 127;
		(* T values: *)
			TMax* = 63;

		SP = 13;
		SR0 = 0; SR1 = 1; SR2 = 2; SR3 = 3; SR12 = 4; SLR = 5; SPC = 6;

		(* memory map *)
			(* APB1 *)
				WWDG = 40002C00H;
					WWDGCR = WWDG;
					WWDGCFR = WWDG + 4;
					WWDGSR = WWDG + 8;
			(* AHB1 *)
				RCC = 40023800H;
					RCCAPB1ENR = RCC + 40H;

		(* interrupt sources *)
			WWDGInt = 0;

		Int = WWDGInt;
		int = Int MOD 32;
		ISER = ARMv7M.NVICISER0 + (Int DIV 32) * 4;
		ICER = ARMv7M.NVICICER0 + (Int DIV 32) * 4;
		IPR = ARMv7M.NVICIPR0 + Int;

		(* WWDGCR bits: *)
			WDGA = 7;

	VAR cr: SET;

	PROCEDURE* InterruptsHandler;
		CONST nLVars = 1;
		VAR pc: INTEGER;
	BEGIN
		(* compiler-dependent *)
			SYSTEM.GET(SYSTEM.REG(SP) + (SPC + nLVars + 8) * 4, pc);
		Traps.trapHandler(14X (* 20 *), pc, 0)
	END InterruptsHandler;

	PROCEDURE Update*;
	BEGIN
		SYSTEM.PUT(WWDGCR, cr)
	END Update;

	(* timeout = 4096 * 2^WDGTB / PCLK1 * (T + 1) *)
	PROCEDURE Init* (WDGTB, W, T: INTEGER);
		CONST
			(* RCCAPB1ENR bits: *)
				WWDGEN = 11;
			(* WWDGCFR bits: *)
				EWI = 9;
			(* WWDGSR bits: *)
				EWIF = 0;
		VAR x: SET;
			i: INTEGER;
	BEGIN
		ASSERT(WDGTB DIV 4 = 0);
		ASSERT(W DIV 80H = 0);
		ASSERT(T DIV 40H = 0);

		SYSTEM.PUT(ICER, {int}); ARMv7M.ISB;

		SYSTEM.GET(RCCAPB1ENR, x);
		SYSTEM.PUT(RCCAPB1ENR, x + {WWDGEN}); ARMv7M.DSB;

		SYSTEM.PUT(WWDGCFR,
			SYSTEM.VAL(SET, W + WDGTB * 80H) + {EWI}); (* W, WDGTB, EWI *)

		SYSTEM.PUT(Traps.vectorsOrg + (ARMv7M.ExternalInterrupt0 + Int) * 4, InterruptsHandler);

		(* decrease priority of all interrupts *)
			i := 0;
			WHILE i < 60 DO
				SYSTEM.PUT(ARMv7M.NVICIPR0 + i, 80808080H); (* set priorities to 8 *)
				INC(i)
			END;
		(* increase priority of WWDG interrupts *)
			SYSTEM.PUT(IPR, 0X); (* set priority to 0 *)

		SYSTEM.GET(WWDGSR, x);
		SYSTEM.PUT(WWDGSR, x - {EWIF});

		cr := SYSTEM.VAL(SET, T + 40H) + {WDGA};

		SYSTEM.PUT(WWDGCR, cr); (* enable *)

		SYSTEM.PUT(ISER, {int})
	END Init;

END MicroARMv7MSTM32F4WWDG.
