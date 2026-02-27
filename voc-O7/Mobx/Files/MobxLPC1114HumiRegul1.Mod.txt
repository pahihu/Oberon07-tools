MODULE MobxLPC1114HumiRegul1;

	(* Alexander Shiryaev, 2014.09 *)

	(* Simple relay humidity regulator, based on Sensirion SHT1x sensor *)

	(* LPC1114FBD48/302 *)

	IMPORT SYSTEM, TP0 := MicroLPC1114TPort0, ARMv6M := MicroARMv6M, SHT1x := MobxLPC1114SHT1x, Traps := MicroARMv6MTraps, MCU := MicroLPC1100, Sys := MicroLPC1100System;

	CONST
		timerFreq = 2; (* Hz *) (* 2^n *)

	VAR
		timerFlag: BOOLEAN;
		cnt0: INTEGER;

	PROCEDURE HumiTask (humi0: INTEGER);
	BEGIN
		IF humi0 > 2500 THEN
			SYSTEM.PUT(
				MCU.GPIO3MASKEDACCESS + SYSTEM.VAL(INTEGER, {0}) * 4, {0})
		ELSIF humi0 < 2400 THEN
			SYSTEM.PUT(
				MCU.GPIO3MASKEDACCESS + SYSTEM.VAL(INTEGER, {0}) * 4, {})
		END
	END HumiTask;

	PROCEDURE Receive0 (id: CHAR; a: ARRAY OF CHAR; len: INTEGER);
		VAR ok: BOOLEAN;
			b: ARRAY 3 OF CHAR;
			x, res: INTEGER;
	BEGIN
		IF id = 0X THEN
			IF len = 0 THEN
				SHT1x.Init;
				TP0.Send(id, 0, 0, ok)
			END
		ELSIF id = 1X THEN
			IF len = 0 THEN
				ok := SHT1x.SoftReset();
				TP0.Send(id, SYSTEM.ADR(ok), 1, ok)
			END
		ELSIF id = 2X THEN
			IF len = 1 THEN
				IF a[0] = 0X THEN
					SHT1x.Measure(SHT1x.TEMP, x, res)
				ELSIF a[0] = 1X THEN
					SHT1x.Measure(SHT1x.HUMI, x, res);
					IF res = 0 THEN
						HumiTask(x)
					END
				ELSE res := 4
				END;
				IF res = 0 THEN
					b[0] := a[0];
					b[1] := CHR(x);
					b[2] := CHR(x DIV 100H);
					TP0.Send(id, SYSTEM.ADR(b), 3, ok)
				ELSE
					TP0.Send(id, SYSTEM.ADR(res), 1, ok)
				END
			END
		ELSE
			TP0.Send(id, SYSTEM.ADR(a), len, ok)
		END
	END Receive0;

	PROCEDURE OnTimer4sec;
		VAR temp0, humi0, res: INTEGER; ok: BOOLEAN;
			a: ARRAY 5 OF CHAR;
	BEGIN
		SHT1x.Measure(SHT1x.TEMP, temp0, res);
		IF res = 0 THEN
			SHT1x.Measure(SHT1x.HUMI, humi0, res);
			IF res = 0 THEN
				HumiTask(humi0);
				a[0] := 0X;
				a[1] := CHR(temp0);
				a[2] := CHR(temp0 DIV 100H);
				a[3] := CHR(humi0);
				a[4] := CHR(humi0 DIV 100H);
				TP0.Send(4X, SYSTEM.ADR(a), 5, ok)
			ELSE
				a[0] := 2X;
				a[1] := CHR(res);
				TP0.Send(4X, SYSTEM.ADR(a), 2, ok)
			END
		ELSE
			a[0] := 1X;
			a[1] := CHR(res);
			TP0.Send(4X, SYSTEM.ADR(a), 2, ok)
		END
	END OnTimer4sec;

	PROCEDURE InitLED;
		CONST GPIO = 6;
		VAR x: SET;
	BEGIN
		(* enable clock for GPIO *)
			SYSTEM.GET(MCU.SYSAHBCLKCTRL, x);
			SYSTEM.PUT(MCU.SYSAHBCLKCTRL, x + {GPIO});

		SYSTEM.GET(MCU.GPIO3DIR, x);
		SYSTEM.PUT(MCU.GPIO3DIR, x + {0}); (* P3.0: output *)

		SYSTEM.PUT(
			MCU.GPIO3MASKEDACCESS + SYSTEM.VAL(INTEGER, {0}) * 4, {})
	END InitLED;

	PROCEDURE* SysTickIntHandler;
	BEGIN
		timerFlag := TRUE
	END SysTickIntHandler;

	PROCEDURE InitTimer;
		CONST delay1sec = Sys.CCLK DIV 2;
			(* SYSTCSR bits: *)
				ENABLE = 0; TICKINT = 1; CLKSOURCE = 2;
	BEGIN
		SYSTEM.PUT(ARMv6M.SYSTCSR, {}); (* disable SysTick *)
		timerFlag := FALSE; cnt0 := 0;
		(* NOTE: timer is 24-bit! *)
		SYSTEM.PUT(ARMv6M.SYSTRVR, delay1sec DIV timerFreq - 1);
		SYSTEM.PUT(ARMv6M.SYSTCVR, 0); (* any write to current clears it *)
		SYSTEM.PUT(Sys.VectorsOrg + ARMv6M.SysTick * 4, SysTickIntHandler);
		SYSTEM.PUT(ARMv6M.SYSTCSR, {ENABLE,TICKINT}) (* enable timer with clock source of system clock / 2 with interrupts *)
	END InitTimer;

	PROCEDURE Init;
		VAR ok: BOOLEAN;
	BEGIN
		InitLED;
		SHT1x.Init;
		InitTimer;
		TP0.Init(19200, TP0.parityNone);
		TP0.Send(0CBX, SYSTEM.ADR(Traps.nResets), 4, ok);
		TP0.Send(0CBX, SYSTEM.ADR(Traps.nResets), 4, ok);
		IF Traps.trapFlag THEN
			TP0.Send(0D0X, SYSTEM.ADR(Traps.trap), 9, ok);
			IF ok THEN Traps.ClearTrapFlag END
		END
	END Init;

BEGIN
	Init;
	REPEAT
		TP0.Receive(Receive0);
		IF timerFlag THEN timerFlag := FALSE;
			INC(cnt0);
			IF cnt0 MOD (timerFreq * 4) = 0 THEN
				OnTimer4sec
			END
		END;
		ARMv6M.WFI
	UNTIL FALSE
END MobxLPC1114HumiRegul1.

O7ARMv6MP.Compile MicroARMv6M MicroLPC1100 MicroKernel0 MicroARMv6MTraps MicroLPC1100System MicroCRC8 MobxLPC1114SHT1x MicroLPC1114TPort0 

O7ARMv6MP.Compile @/s

O7ARMv7MTool.DecObj MobxLPC1114HumiRegul1.a6m 

O7ARMv6MLinker.Link LPC1114FBD48302 MobxLPC1114HumiRegul1 

O7ARMv7MTool.DecHex MobxLPC1114HumiRegul1.hex 

O7ARMv7MTool.DecBin MobxLPC1114HumiRegul1.bin 
