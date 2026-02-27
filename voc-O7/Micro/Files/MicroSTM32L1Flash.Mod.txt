MODULE MicroSTM32L1Flash;

	(*
		Alexander Shiryaev, 2021.10

		RM0038, Reference manual,
			STM32L100xx, STM32L151xx, STM32L152xx, STM32L162xx
	*)

	IMPORT SYSTEM;

	CONST
		pageLen* = 256; (* B *)

		(* memory map *)
			FlashStart* = 08000000H;
			EEPROM* = 08080000H;
			(* AHB *)
				FLASH* = 40023C00H;
				FLASHACR* = FLASH;
				FLASHPECR* = FLASH + 4;
					PELOCK = 0; PRGLOCK = 1; OPTLOCK = 2;
					PROG = 3; DATA = 4;
					FTDW = 8; ERASE = 9; FPRG = 10;
					OBLLAUNCH = 18;
				FLASHPDKEYR* = FLASH + 8;
				FLASHPEKEYR* = FLASH + 0CH;
				FLASHPRGKEYR* = FLASH + 10H;
				FLASHOPTKEYR* = FLASH + 14H;
				FLASHSR* = FLASH + 18H;
					BSY* = 0; EOP* = 1; ENDHV = 2; READY = 3;
					WRPERR = 8; PGAERR = 9; SIZERR = 10;
					OPTVERR = 11; OPTVERRUSR = 12; RDERR = 13;
				FLASHOBR* = FLASH + 1CH;

		(* res *)
			complete* = 0; busy* = 1; writeError* = 2; writeProtected* = 3;

		(* unlock keys *)
			PEKEY1 = 89ABCDEFH;
			PEKEY2 = 02030405H;
			PRGKEY1 = 8C9DAEBFH;
			PRGKEY2 = 13141516H;
			OPTKEY1 = 0FBEAD9C8H;
			OPTKEY2 = 24252627H;

	(* Unlock Data EEPROM *)
	PROCEDURE DUnLock*;
	BEGIN
		IF SYSTEM.BIT(FLASHPECR, PELOCK) THEN
			SYSTEM.PUT(FLASHPEKEYR, PEKEY1);
			SYSTEM.PUT(FLASHPEKEYR, PEKEY2)
		END
	END DUnLock;

	(* Lock Data EEPROM *)
	PROCEDURE DLock*;
		VAR x: SET;
	BEGIN
		SYSTEM.GET(FLASHPECR, x);
		SYSTEM.PUT(FLASHPECR, x + {PELOCK})
	END DLock;

	(* Unlock program memory *)
	PROCEDURE PUnLock*;
	BEGIN
		IF SYSTEM.BIT(FLASHPECR, PRGLOCK) THEN
			DUnLock;

			SYSTEM.PUT(FLASHPRGKEYR, PRGKEY1);
			SYSTEM.PUT(FLASHPRGKEYR, PRGKEY2)
		END
	END PUnLock;

	(* Lock program memory *)
	PROCEDURE PLock*;
		VAR x: SET;
	BEGIN
		SYSTEM.GET(FLASHPECR, x);
		SYSTEM.PUT(FLASHPECR, x + {PRGLOCK})
	END PLock;

	PROCEDURE GetStatus (): INTEGER;
		VAR res: INTEGER;
			s: SET;
	BEGIN
		SYSTEM.GET(FLASHSR, s);
		IF BSY IN s THEN res := busy
		ELSIF WRPERR IN s THEN res := writeProtected
		ELSIF s * {PGAERR,SIZERR,OPTVERR,OPTVERRUSR} # {} THEN
			res := writeError
		ELSE res := complete
		END
	RETURN res
	END GetStatus;

	PROCEDURE WaitForLastOperation (): INTEGER;
		VAR res: INTEGER;
	BEGIN REPEAT res := GetStatus() UNTIL res # busy
	RETURN res
	END WaitForLastOperation;

	(* Erase program memory page *)
	PROCEDURE PErase* (pageAdr: INTEGER; VAR res: INTEGER);
		VAR x: SET;
	BEGIN
		res := WaitForLastOperation();
		IF res = complete THEN
			SYSTEM.GET(FLASHPECR, x);
			SYSTEM.PUT(FLASHPECR, x + {ERASE});

			SYSTEM.GET(FLASHPECR, x);
			SYSTEM.PUT(FLASHPECR, x + {PROG});

			SYSTEM.PUT(pageAdr, 0);

			res := WaitForLastOperation();

			SYSTEM.GET(FLASHPECR, x);
			SYSTEM.PUT(FLASHPECR, x - {PROG});

			SYSTEM.GET(FLASHPECR, x);
			SYSTEM.PUT(FLASHPECR, x - {ERASE})
		END
	END PErase;

	PROCEDURE PWrite* (adr: INTEGER; data: INTEGER; VAR res: INTEGER);
	BEGIN
		res := WaitForLastOperation();
		IF res = complete THEN
			SYSTEM.PUT(adr, data);
			res := WaitForLastOperation()
		END
	END PWrite;

	(* Unlock option byte *)
	PROCEDURE OBUnLock*;
	BEGIN
		IF SYSTEM.BIT(FLASHPECR, OPTLOCK) THEN
			DUnLock;

			SYSTEM.PUT(FLASHOPTKEYR, OPTKEY1);
			SYSTEM.PUT(FLASHOPTKEYR, OPTKEY2)
		END
	END OBUnLock;

	(* Lock option byte *)
	PROCEDURE OBLock*;
		VAR x: SET;
	BEGIN
		SYSTEM.GET(FLASHPECR, x);
		SYSTEM.PUT(FLASHPECR, x + {OPTLOCK})
	END OBLock;

END MicroSTM32L1Flash.
