MODULE MicroSTM32F4Flash;

	(*
		Alexander Shiryaev, 2015.01, 2016.06, 2017.10, 2023.06

		RM0090, Reference manual,
			STM32F405xx/07xx, STM32F415xx/17xx,
			[ STM32F42xxx, STM32F43xxx ]

		RM0390, Reference manual,
			STM32F446xx

		stm32f4xx_flash.c
	*)

	IMPORT SYSTEM;

	CONST
		(* FLASHSR bits: *)
			EOP = 0;
			OPERR = 1; WRPERR = 4; PGAERR = 5; PGPERR = 6; PGSERR = 7;
			BSY = 16;
		(* FLASHCR bits: *)
			PG = 0; SER = 1; MER = 2; STRT = 16; LOCK = 31;
		(* OPTCR bits:*)
			OPTLOCK = 0; OPTSTRT = 1;

		FlashStart* = 8000000H;
			Sector0* = FlashStart;
			Sector1* = FlashStart + 4000H;
			Sector2* = FlashStart + 8000H;
			Sector3* = FlashStart + 0C000H;
			Sector4* = FlashStart + 10000H;
			Sector5* = FlashStart + 20000H;
			Sector6* = FlashStart + 40000H;
			Sector7* = FlashStart + 60000H;
			Sector8* = FlashStart + 80000H;
			Sector9* = FlashStart + 0A0000H;
			Sector10* = FlashStart + 0C0000H;
			Sector11* = FlashStart + 0E0000H;

		(* device electronic signature *)
			(* Flash size, in KiB *)
				FlashSizeKiBAdr* = 1FFF7A22H; (* 2 B *)

		(* AHB1 *)
			FlashInterface* = 40023C00H; (* Flash interface register *)
				FLASHACR* = FlashInterface;
				FLASHKEYR* = FlashInterface + 4;
				FLASHOPTKEYR* = FlashInterface + 8;
				FLASHSR* = FlashInterface + 0CH;
				FLASHCR* = FlashInterface + 10H;
				FLASHOPTCR* = FlashInterface + 14H;

		(* res *)
			complete* = 0; busy* = 1; writeError* = 2;
				writeProtected* = 3; operationError* = 4;

	PROCEDURE UnLock*;
		CONST
			FLASHKEY1 = 45670123H;
			FLASHKEY2 = 0CDEF89ABH;
	BEGIN
		IF SYSTEM.BIT(FLASHCR, LOCK) THEN
			SYSTEM.PUT(FLASHKEYR, FLASHKEY1);
			SYSTEM.PUT(FLASHKEYR, FLASHKEY2)
		END
	END UnLock;

	PROCEDURE Lock*;
		VAR x: SET;
	BEGIN
		SYSTEM.GET(FLASHCR, x);
		SYSTEM.PUT(FLASHCR, x + {LOCK})
	END Lock;

	PROCEDURE GetStatus (): INTEGER;
		VAR res: INTEGER;
			s: SET;
	BEGIN
		SYSTEM.GET(FLASHSR, s);
		IF BSY IN s THEN res := busy
		ELSIF WRPERR IN s THEN res := writeProtected
		ELSIF s * {PGAERR,PGPERR,PGSERR} # {} THEN res := writeError
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
		ASSERT(sector <= 11);
		res := WaitForLastOperation();
		IF res = complete THEN
			SYSTEM.GET(FLASHCR, x);
			SYSTEM.PUT(FLASHCR, x + {9} - {8}); (* PSIZE := x32 *)

			SYSTEM.GET(FLASHCR, x);
			SYSTEM.PUT(FLASHCR, x + {SER}
				- SNB + SYSTEM.VAL(SET, sector * 8));

			SYSTEM.GET(FLASHCR, x);
			SYSTEM.PUT(FLASHCR, x + {STRT});

			res := WaitForLastOperation();

			SYSTEM.GET(FLASHCR, x);
			SYSTEM.PUT(FLASHCR, x - {SER});

			SYSTEM.GET(FLASHCR, x);
			SYSTEM.PUT(FLASHCR, x - SNB)
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
			SYSTEM.GET(FLASHCR, x);
			SYSTEM.PUT(FLASHCR, x + {9} - {8}); (* PSIZE := x32 *)

			SYSTEM.GET(FLASHCR, x);
			SYSTEM.PUT(FLASHCR, x + {PG}); (* !PG *)

			SYSTEM.PUT(adr, data);

			res := WaitForLastOperation();

			SYSTEM.GET(FLASHCR, x);
			SYSTEM.PUT(FLASHCR, x - {PG}) (* !~PG *)
		END
	END Write;

	PROCEDURE OBUnLock*;
		CONST
			FLASHOPTKEY1 = 08192A3BH;
			FLASHOPTKEY2 = 4C5D6E7FH;
	BEGIN
		IF SYSTEM.BIT(FLASHOPTCR, OPTLOCK) THEN
			SYSTEM.PUT(FLASHOPTKEYR, FLASHOPTKEY1);
			SYSTEM.PUT(FLASHOPTKEYR, FLASHOPTKEY2)
		END
	END OBUnLock;

	PROCEDURE OBLock*;
		VAR x: SET;
	BEGIN
		SYSTEM.GET(FLASHOPTCR, x);
		SYSTEM.PUT(FLASHOPTCR, x + {OPTLOCK})
	END OBLock;

	PROCEDURE OBWrite* (x: SET; VAR res: INTEGER);
	BEGIN
		ASSERT(x * {OPTSTRT,OPTLOCK} = {});

		res := WaitForLastOperation();
		IF res = complete THEN
			SYSTEM.PUT(FLASHOPTCR, x);

			SYSTEM.GET(FLASHOPTCR, x);
			SYSTEM.PUT(FLASHOPTCR, x + {OPTSTRT});

			res := WaitForLastOperation()
		END
	END OBWrite;

	PROCEDURE SizeKiB* (): INTEGER;
		VAR x: INTEGER;
	BEGIN
		SYSTEM.GET(FlashSizeKiBAdr, x);
	RETURN x MOD 10000H
	END SizeKiB;

END MicroSTM32F4Flash.

O7ARMv6MP.Compile @/s

O7ARMv7MTool.DecObj MicroSTM32F4Flash.a6m


O7ARMv7MP.Compile @/s

O7ARMv7MTool.DecObj MicroSTM32F4Flash.a7m
