MODULE MicroCRC8;

	(*
		A. V. Shiryaev, 2013.01, 2014.11
	*)

	IMPORT SYSTEM;

	CONST
		init* = 0FFX;

	PROCEDURE Update* (crc8: CHAR; x: CHAR): CHAR;
		VAR i: INTEGER; cs: SET;
	BEGIN
		cs := SYSTEM.VAL(SET, ORD(crc8)) / SYSTEM.VAL(SET, ORD(x));
		i := 8;
		REPEAT
			cs := SYSTEM.VAL(SET, LSL(SYSTEM.VAL(INTEGER, cs), 1));
			IF 8 IN cs THEN
				cs := cs / {0,4,5}
			END;
			DEC(i)
		UNTIL i = 0
	RETURN CHR(SYSTEM.VAL(INTEGER, cs))
	END Update;

END MicroCRC8.

O7ARMv7MTool.DecObj MicroCRC8.a6m 

O7ARMv7MTool.DecObj MicroCRC8.a7m 
