MODULE MobxLPC1114SHT1x;

	(*
		Alexander Shiryaev, 2014.11

		LPC1114FBD48/302

		Sensirion Humidity SHT1x sensor

		MCU				SHT1x
		P2.4 (19)		SCK (3)
		P2.5 (20)		DATA (2)

		implementation taken from
			SHT1x and SHT7x sample code application note
	*)

	IMPORT SYSTEM, MCU := MicroLPC1100, CRC8 := MicroCRC8;

	CONST
		noACK = FALSE;
		ACK = TRUE;

		STATUSREGW = 6;
		STATUSREGR = 7;
		MEASURETEMP = 3;
		MEASUREHUMI = 5;
		RESET = 1EH;

		TEMP* = MEASURETEMP;
		HUMI* = MEASUREHUMI;

	PROCEDURE SCK1;
	BEGIN
		SYSTEM.PUT(
			MCU.GPIO2MASKEDACCESS + SYSTEM.VAL(INTEGER, {4}) * 4, {4})
	END SCK1;

	PROCEDURE SCK0;
	BEGIN
		SYSTEM.PUT(
			MCU.GPIO2MASKEDACCESS + SYSTEM.VAL(INTEGER, {4}) * 4, {})
	END SCK0;

	PROCEDURE DATA1;
	BEGIN
		SYSTEM.PUT(
			MCU.GPIO2MASKEDACCESS + SYSTEM.VAL(INTEGER, {5}) * 4, {5})
	END DATA1;

	PROCEDURE DATA0;
	BEGIN
		SYSTEM.PUT(
			MCU.GPIO2MASKEDACCESS + SYSTEM.VAL(INTEGER, {5}) * 4, {})
	END DATA0;

	PROCEDURE RDATA (): BOOLEAN;
	BEGIN
		RETURN SYSTEM.BIT(MCU.GPIO2DATA, 5)
	END RDATA;

	PROCEDURE DW;
		VAR x: SET;
	BEGIN
		SYSTEM.GET(MCU.GPIO2DIR, x);
		SYSTEM.PUT(MCU.GPIO2DIR, x + {5}) (* P2.5: output *)
	END DW;

	PROCEDURE DR;
		VAR x: SET;
	BEGIN
		SYSTEM.GET(MCU.GPIO2DIR, x);
		SYSTEM.PUT(MCU.GPIO2DIR, x - {5}) (* P2.5: input *)
	END DR;

	PROCEDURE Init*;
		CONST
			(* SYSAHBCLKCTRL bits: *)
				GPIO = 6; IOCON = 16;
		VAR x: SET;
	BEGIN
		(* enable clock for GPIO and I/O configuration block *)
			SYSTEM.GET(MCU.SYSAHBCLKCTRL, x);
			SYSTEM.PUT(MCU.SYSAHBCLKCTRL, x + {GPIO,IOCON});

		(* configure PINs *)
			SYSTEM.GET(MCU.IOCONPIO24, x);
			SYSTEM.PUT(MCU.IOCONPIO24, x * {6..9,11..31}); (* P2.4: no pull-up/pull-down resistor, no hysteresis, no open-drain output *)

			SYSTEM.GET(MCU.IOCONPIO25, x);
			SYSTEM.PUT(MCU.IOCONPIO25, x * {6..9,11..31} + {4}); (* P2.5: enable pull-up resistor, no hysteresis, no open-drain output *)

		SYSTEM.GET(MCU.GPIO2DIR, x);
		SYSTEM.PUT(MCU.GPIO2DIR, x + {4} - {5}) (* P2.4: output, P2.5: input *)
	END Init;

	PROCEDURE S;
		VAR i: INTEGER;
	BEGIN
		i := 400H; (* FIXME *)
		REPEAT DEC(i) UNTIL i = 0
	END S;

	PROCEDURE WB (x: INTEGER): BOOLEAN;
		VAR i: INTEGER; error: BOOLEAN;
	BEGIN DW;
		i := 8;
		REPEAT
			DEC(i);
			IF i IN SYSTEM.VAL(SET, x) THEN
				DATA1
			ELSE
				DATA0
			END;
			S;
			SCK1;
			S; S; S;
			SCK0;
			S
		UNTIL i = 0;
		DATA1; DR;
		S;
		SCK1;
		error := RDATA();
		SCK0;
		RETURN error
	END WB;

	PROCEDURE RB (ack: BOOLEAN): INTEGER;
		VAR i: INTEGER; x: SET;
	BEGIN
		x := {};
		DATA1;
		i := 80H;
		WHILE i > 0 DO
			SCK1;
			IF RDATA() THEN
				x := x + SYSTEM.VAL(SET, i)
			END;
			SCK0;
			i := i DIV 2
		END; DW;
		IF ack THEN
			DATA0
		ELSE
			DATA1
		END;
		S;
		SCK1;
		S; S; S;
		SCK0;
		S;
		DATA1; DR;
		RETURN SYSTEM.VAL(INTEGER, x)
	END RB;

	PROCEDURE TS;
	BEGIN
		DATA1; SCK0;
		S;
		SCK1;
		S; DW;
		DATA0;
		S;
		SCK0;
		S; S; S;
		SCK1;
		S;
		DATA1; DR;
		S;
		SCK0
	END TS;

	PROCEDURE CR;
		VAR i: INTEGER;
	BEGIN
		DATA1; SCK0;
		i := 0;
		WHILE i < 9 DO
			SCK1;
			SCK0;
			INC(i)
		END;
		TS
	END CR;

	PROCEDURE SoftReset* (): BOOLEAN;
	BEGIN
		CR;
		RETURN WB(RESET)
	END SoftReset;

	PROCEDURE ReadStatusReg (VAR x, cs: INTEGER; VAR error: BOOLEAN);
	BEGIN
		TS;
		error := WB(STATUSREGR);
		x := RB(ACK);
		cs := RB(noACK)
	END ReadStatusReg;

	PROCEDURE WriteStatusReg (x: INTEGER): BOOLEAN;
		VAR error: BOOLEAN;
	BEGIN
		TS;
		error := WB(STATUSREGW);
		IF WB(x) THEN error := TRUE END;
		RETURN error
	END WriteStatusReg;

	PROCEDURE BitReverse8 (x: INTEGER): INTEGER;
		VAR i: INTEGER; s: SET;
	BEGIN
		s := {};
		i := 8;
		REPEAT DEC(i);
			IF i IN SYSTEM.VAL(SET, ORD(x)) THEN
				INCL(s, 7 - i)
			END
		UNTIL i = 0;
		RETURN SYSTEM.VAL(INTEGER, s)
	END BitReverse8;

	PROCEDURE StartMeasure* (mode: INTEGER; VAR res: INTEGER);
	BEGIN
		ASSERT(mode IN {TEMP,HUMI});
		TS;
		IF ~WB(mode) THEN res := 0
		ELSE res := 1
		END
	END StartMeasure;

	PROCEDURE CheckResult* (mode: INTEGER; VAR x, res: INTEGER);
		VAR i, cs: INTEGER; crc8: CHAR;
	BEGIN
		ASSERT(mode IN {TEMP,HUMI});
		IF ~RDATA() THEN
			crc8 := CRC8.Update(
				0X (* bit-reversed status register *), CHR(mode));
			i := RB(ACK); (* MSB *)
			crc8 := CRC8.Update(crc8, CHR(i));
			x := 100H * i;
			i := RB(ACK); (* LSB *)
			crc8 := CRC8.Update(crc8, CHR(i));
			x := x + i;
			cs := RB(noACK);
			IF cs = BitReverse8(ORD(crc8)) THEN res := 0
			ELSE res := 3 (* checksum error *)
			END
		ELSE
			res := 2 (* not complete *)
		END
	END CheckResult;

	PROCEDURE Measure* (mode: INTEGER; VAR x, res: INTEGER);
		VAR i: INTEGER;
	BEGIN
		StartMeasure(mode, res);
		IF res = 0 THEN
			i := 100000H (* > 300 msec *);
			REPEAT DEC(i) UNTIL (i = 0) OR ~RDATA();
			CheckResult(mode, x, res)
		END
	END Measure;

END MobxLPC1114SHT1x.

O7ARMv6MP.Compile @/s

O7ARMv7MTool.DecObj MobxLPC1114SHT1x.a6m 
