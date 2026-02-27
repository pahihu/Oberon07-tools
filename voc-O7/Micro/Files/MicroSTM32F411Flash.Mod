MODULE MicroSTM32F411Flash;

	(*
		Alexander Shiryaev, 2015.01, 2021.08

		RM0383, Reference manual, STM32F411xC/E

		stm32f4xx_flash.c
	*)

	IMPORT SYSTEM, MCU := MicroSTM32F4;

	CONST
		(* FLASHSR bits: *)
			EOP = 0;
			OPERR = 1; WRPERR = 4; PGAERR = 5; PGPERR = 6; PGSERR = 7;
				RDERR = 8;
			BSY = 16;
		(* FLASHCR bits: *)
			PG = 0; SER = 1; MER = 2; STRT = 16; LOCK = 31;

		Sector0* = MCU.Sector0;
		Sector1* = MCU.Sector1;
		Sector2* = MCU.Sector2;
		Sector3* = MCU.Sector3;
		Sector4* = MCU.Sector4;
		Sector5* = MCU.Sector5;
		Sector6* = MCU.Sector6;
		Sector7* = MCU.Sector7;

		(* res *)
			complete* = 0; busy* = 1; writeError* = 2;
				writeProtected* = 3; operationError* = 4;

	PROCEDURE UnLock*;
		CONST
			FLASHKEY1 = 45670123H;
			FLASHKEY2 = 0CDEF89ABH;
	BEGIN
		IF SYSTEM.BIT(MCU.FLASHCR, LOCK) THEN
			SYSTEM.PUT(MCU.FLASHKEYR, FLASHKEY1);
			SYSTEM.PUT(MCU.FLASHKEYR, FLASHKEY2)
		END
	END UnLock;

	PROCEDURE Lock*;
		VAR x: SET;
	BEGIN
		SYSTEM.GET(MCU.FLASHCR, x);
		SYSTEM.PUT(MCU.FLASHCR, x + {LOCK})
	END Lock;

	PROCEDURE GetStatus (): INTEGER;
		VAR res: INTEGER;
			s: SET;
	BEGIN
		SYSTEM.GET(MCU.FLASHSR, s);
		IF BSY IN s THEN res := busy
		ELSIF WRPERR IN s THEN res := writeProtected
		ELSIF s * {PGAERR,PGPERR,PGSERR,RDERR} # {} THEN
			res := writeError
		ELSIF OPERR IN s THEN res := operationError
		ELSE res := complete
		END
	RETURN res
	END GetStatus;

	PROCEDURE WaitForLastOperation (): INTEGER;
		VAR res: INTEGER;
	BEGIN REPEAT res := GetStatus() UNTIL res # busy
	RETURN res
	END WaitForLastOperation;

	(*
		device voltage must be in range 2.7--3.6 V
	*)
	PROCEDURE EraseSector* (sector: INTEGER; VAR res: INTEGER);
		CONST SNB = {3..6};
		VAR x: SET;
	BEGIN
		ASSERT(sector >= 0);
		ASSERT(sector <= 7);
		res := WaitForLastOperation();
		IF res = complete THEN
			SYSTEM.GET(MCU.FLASHCR, x);
			SYSTEM.PUT(MCU.FLASHCR, x + {9} - {8}); (* PSIZE := x32 *)

			SYSTEM.GET(MCU.FLASHCR, x);
			SYSTEM.PUT(MCU.FLASHCR, x + {SER}
				- SNB + SYSTEM.VAL(SET, sector * 8));

			SYSTEM.GET(MCU.FLASHCR, x);
			SYSTEM.PUT(MCU.FLASHCR, x + {STRT});

			res := WaitForLastOperation();

			SYSTEM.GET(MCU.FLASHCR, x);
			SYSTEM.PUT(MCU.FLASHCR, x - {SER});

			SYSTEM.GET(MCU.FLASHCR, x);
			SYSTEM.PUT(MCU.FLASHCR, x - SNB)
		END
	END EraseSector;

	(*
		programs a word (32-bit) at a specified address

		device voltage must be in range 2.7--3.6 V

		if an erase and a program operations are requested simustaneously,
			the erase operation is performed before the program one

		adr: specifies the address to be programmed. This parameter can be any
			address in Program memory zone or in OTP zone
		data: specifies the data to be programmed
	*)
	PROCEDURE Write* (adr: INTEGER; data: INTEGER; VAR res: INTEGER);
		VAR x: SET;
	BEGIN
		res := WaitForLastOperation();
		IF res = complete THEN (* proceed to program the new data *)
			SYSTEM.GET(MCU.FLASHCR, x);
			SYSTEM.PUT(MCU.FLASHCR, x + {9} - {8}); (* PSIZE := x32 *)

			SYSTEM.GET(MCU.FLASHCR, x);
			SYSTEM.PUT(MCU.FLASHCR, x + {PG}); (* !PG *)

			SYSTEM.PUT(adr, data);

			res := WaitForLastOperation();

			SYSTEM.GET(MCU.FLASHCR, x);
			SYSTEM.PUT(MCU.FLASHCR, x - {PG}) (* !~PG *)
		END
	END Write;

END MicroSTM32F411Flash.

O7ARMv7MP.Compile @/s

O7ARMv7MTool.DecObj MicroSTM32F411Flash.a7m
