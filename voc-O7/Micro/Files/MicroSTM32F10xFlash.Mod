MODULE MicroSTM32F10xFlash;

	(*
		Alexander Shiryaev, 2016.03

		PM0075

		STM32F10{1,2,3,5,7}xx
			(XL-density devices: bank 1 only)

		stm32f10x_flash.c
	*)

	IMPORT SYSTEM;

	CONST
		FLASH = 40022000H;
		FLASHACR = FLASH;
		FLASHKEYR = FLASH + 4;
		FLASHOPTKEYR = FLASH + 8;
		FLASHSR = FLASH + 0CH;
			BSY = 0; PGERR = 2; WRPRTERR = 4; EOP = 5;
		FLASHCR = FLASH + 10H;
			PG = 0; PER = 1; MER = 2; OPTPG = 4; OPTER = 5; STRT = 6; LOCK = 7;
			OPTWRE = 9; ERRIR = 10; EOPIE = 12;
		FLASHAR = FLASH + 14H;
		FLASHOBR = FLASH + 1CH;
		FLASHWRPR = FLASH + 20H;

		Page0* = 08000000H;

		(* res *)
			complete* = 0; busy* = 1; writeError* = 2; writeProtected* = 3;

	TYPE
		Proc2 = PROCEDURE (a, b: INTEGER);

	VAR
		STRH: Proc2;

	PROCEDURE UnLock*;
		CONST KEY1 = 45670123H; KEY2 = 0CDEF89ABH;
	BEGIN
		IF SYSTEM.BIT(FLASHCR, LOCK) THEN
			SYSTEM.PUT(FLASHKEYR, KEY1);
			SYSTEM.PUT(FLASHKEYR, KEY2)
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
		ELSIF PGERR IN s THEN res := writeError
		ELSIF WRPRTERR IN s THEN res := writeProtected
		ELSE res := complete
		END
	RETURN res
	END GetStatus;

	PROCEDURE WaitForLastOperation (): INTEGER;
		VAR res: INTEGER;
	BEGIN REPEAT res := GetStatus() UNTIL res # busy
	RETURN res
	END WaitForLastOperation;

	PROCEDURE ErasePage* (pageAdr: INTEGER; VAR res: INTEGER);
		VAR x: SET;
	BEGIN
		res := WaitForLastOperation();
		IF res = complete THEN
			SYSTEM.GET(FLASHCR, x);
			SYSTEM.PUT(FLASHCR, x + {PER});

			SYSTEM.PUT(FLASHAR, pageAdr);

			SYSTEM.GET(FLASHCR, x);
			SYSTEM.PUT(FLASHCR, x + {STRT});

			res := WaitForLastOperation();

			SYSTEM.GET(FLASHCR, x);
			SYSTEM.PUT(FLASHCR, x - {PER})
		END
	END ErasePage;

	PROCEDURE Write* (adr: INTEGER; data: INTEGER; VAR res: INTEGER);
		VAR x: SET;
	BEGIN
		res := WaitForLastOperation();
		IF res = complete THEN
			SYSTEM.GET(FLASHCR, x);
			SYSTEM.PUT(FLASHCR, x + {PG});

			STRH(data, adr);
			res := WaitForLastOperation();
			IF res = complete THEN
				STRH(data DIV 10000H, adr + 2);
				res := WaitForLastOperation()
			END;

			SYSTEM.GET(FLASHCR, x);
			SYSTEM.PUT(FLASHCR, x - {PG})
		END
	END Write;

BEGIN
	STRH := SYSTEM.VAL(Proc2, (* STRH r0, [r1]; BX LR *)
		SYSTEM.ADR($08 80 70 47$) + 1 (* Thumb *))
END MicroSTM32F10xFlash.

O7ARMv7MTool.DecObj MicroSTM32F10xFlash.a7m 
