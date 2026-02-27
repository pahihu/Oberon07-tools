MODULE MicroSTM32F1IWDG;

	(*
		Alexander Shiryaev, 2018.05

		RM0008, Reference manual,
			STM32F10{1,2,3,5,7}xx

		RM0041, Reference manual,
			STM32F100xx
	*)

	IMPORT SYSTEM;

	CONST
		(* PR values: *)
			PR4* = 0; PR8* = 1; PR16* = 2; PR32* = 3; PR64* = 4; PR128* = 5; PR256* = 6;
			PRMax* = 7;
		(* RL values: *)
			RLMax* = 0FFFH;

		(* memory map *)
			(* APB1 *)
				IWDG = 40003000H;
					IWDGKR = IWDG;
					IWDGPR = IWDG + 4;
					IWDGRLR = IWDG + 8;
					IWDGSR = IWDG + 0CH;
			(* AHB *)
				RCC = 40021000H;
					RCCCSR = RCC + 24H;

	PROCEDURE Update*;
	BEGIN
		SYSTEM.PUT(IWDGKR, 0AAAAH)
	END Update;

	PROCEDURE Init* (PR, RL: INTEGER);
		CONST
			(* RCCCSR bits: *)
				LSION = 0; LSIRDY = 1;
			(* IWDGSR bits: *)
				PVU = 0; RVU = 1;
		VAR x: SET;
	BEGIN
		ASSERT(PR DIV 8 = 0);
		ASSERT(RL DIV 1000H = 0);

		(* enable LSI *)
			SYSTEM.GET(RCCCSR, x);
			SYSTEM.PUT(RCCCSR, x + {LSION});
			REPEAT UNTIL SYSTEM.BIT(RCCCSR, LSIRDY);

		(* setup IWDG *)

			(* enable write access *)
				SYSTEM.PUT(IWDGKR, 5555H);

			(* setup PR *)
				REPEAT UNTIL ~SYSTEM.BIT(IWDGSR, PVU);
				SYSTEM.PUT(IWDGPR, PR);

			(* setup RLR *)
				REPEAT UNTIL ~SYSTEM.BIT(IWDGSR, RVU);
				SYSTEM.PUT(IWDGRLR, RL);

		(* reload IWDG *)
			SYSTEM.PUT(IWDGKR, 0AAAAH);

		(* start IWDG *)
			SYSTEM.PUT(IWDGKR, 0CCCCH)
	END Init;

END MicroSTM32F1IWDG.
