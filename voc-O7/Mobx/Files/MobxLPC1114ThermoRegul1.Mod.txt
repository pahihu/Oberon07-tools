MODULE MobxLPC1114ThermoRegul1;

	(* Alexander Shiryaev, 2014.10 *)

	(* PI-thermoregulator, based on
		thermo sensor of SHT1x and Herz 1 7710 00 actuator *)

	(* LPC1114FBD48/302 *)

	IMPORT SYSTEM, MCU := MicroLPC1100, ARMv6M := MicroARMv6M, Traps := MicroARMv6MTraps, TP0 := MicroLPC1114TPort0, Sys := MicroLPC1100System, SHT1x := MobxLPC1114SHT1x;

	CONST
		controlN = 8;
		controlClose = 0; controlOpen = controlN;
		controlDef = controlClose;

		idInit = 0CBX;
		idTrap = 0D0X;
		idSHT1x = 4X;
		idState0 = 5X;
		idTempZad = 6X;

		timerFreq = 8; (* Hz *) (* 2^n *)

		(* thermo task parameters *)
			thermoK1 = 32 DIV (controlN DIV 2);
				(* max control @ error = 0.32 °C *)
			thermoDt = 4; (* sec *)
			thermoK2 = 1024 DIV thermoDt; (* T = 1024 sec *)
			thermoIntLimit = 256 * thermoK2; (* 2.56 °C *)
			thermoIntELimit = 64; (* 0.64 °C *)

	VAR
		(* measure task *)
			msrState: INTEGER;
			humi0, temp0: INTEGER;
		(* thermo task *)
			tempZad: INTEGER; (* target temperature *)
			thermoInt: INTEGER; (* integral *)
				thermoIntLocked, thermoIntLimited, thermoIntELimited: BOOLEAN;
			thermoIntDisable: BOOLEAN; (* disable integral change *)
		(* control task *)
			controlUp, controlDown, controlCnt: INTEGER;
			controlZad: INTEGER; (* 0 <= controlZad <= controlN *)
			servoZad: BOOLEAN; (* close/open *)
		(* timer *)
			timerFlag: BOOLEAN;
			cnt0: INTEGER;

	PROCEDURE ThermoTask (tempCur: INTEGER);			
		VAR e, u: INTEGER;
	BEGIN
		e := tempZad - tempCur;
		u := (e + thermoInt DIV thermoK2) DIV thermoK1; (* PI-regulator *)
		controlZad := u + controlN DIV 2;

		IF e > thermoIntELimit THEN
			e := thermoIntELimit;
			thermoIntELimited := TRUE
		ELSIF e < -thermoIntELimit THEN
			e := -thermoIntELimit;
			thermoIntELimited := TRUE
		ELSE
			thermoIntELimited := FALSE
		END;

		IF controlZad < 0 THEN
			controlZad := 0;
			thermoIntLocked := TRUE
		ELSIF controlZad > controlN THEN
			controlZad := controlN;
			thermoIntLocked := TRUE
		ELSE
			thermoIntLocked := FALSE;
			IF ~thermoIntDisable THEN
				thermoInt := thermoInt + e;
				IF thermoInt >= thermoIntLimit THEN
					thermoInt := thermoIntLimit;
					thermoIntLimited := TRUE
				ELSIF thermoInt <= -thermoIntLimit THEN
					thermoInt := -thermoIntLimit;
					thermoIntLimited := TRUE
				ELSE
					thermoIntLimited := FALSE
				END
			END
		END
	END ThermoTask;

	(* Herz 1 7710 00 calibration *)

		PROCEDURE ControlZadToUpDown;
		BEGIN
			IF controlZad <= 0 THEN
				controlUp := 0; controlDown := 1 (* 0% *)
			ELSIF controlZad = 1 THEN
				controlUp := 1; controlDown := 79 (* 1.25% *)
			ELSIF controlZad = 2 THEN
				controlUp := 1; controlDown := 39 (* 2.5% *)
			ELSIF controlZad = 3 THEN
				controlUp := 3; controlDown := 77 (* 3.75% *)
			ELSIF controlZad = 4 THEN
				controlUp := 1; controlDown := 19 (* 5% *)
			ELSIF controlZad = 5 THEN
				controlUp := 1; controlDown := 15 (* 6.25% *)
			ELSIF controlZad = 6 THEN
				controlUp := 3; controlDown := 37 (* 7.5% *)
			ELSIF controlZad = 7 THEN
				controlUp := 7; controlDown := 73 (* 8.75% *)
			ELSE
				controlUp := 1; controlDown := 9 (* 10% *)
			END
		END ControlZadToUpDown;

	PROCEDURE ControlTask;
	BEGIN
		INC(controlCnt);
		IF servoZad THEN
			IF controlCnt >= controlUp THEN
				IF controlDown <= 0 THEN
					ControlZadToUpDown
				END;
				IF controlDown > 0 THEN
					servoZad := FALSE;
					controlCnt := 0
				ELSE
					controlCnt := controlUp
				END
			END
		ELSE
			IF controlCnt >= controlDown THEN
				ControlZadToUpDown;
				IF controlUp > 0 THEN
					servoZad := TRUE;
					controlCnt := 0
				ELSE
					controlCnt := controlDown
				END
			END
		END
	END ControlTask;

	PROCEDURE ServoTask;
	BEGIN
		IF servoZad THEN
			SYSTEM.PUT(
				MCU.GPIO3MASKEDACCESS + SYSTEM.VAL(INTEGER, {0}) * 4, {0})
		ELSE
			SYSTEM.PUT(
				MCU.GPIO3MASKEDACCESS + SYSTEM.VAL(INTEGER, {0}) * 4, {})
		END
	END ServoTask;

	PROCEDURE SendState0;
		VAR ok: BOOLEAN;
			s: SET;
			a: ARRAY 6 OF CHAR;
			int: INTEGER;
	BEGIN
		IF servoZad THEN s := {0} ELSE s := {} END;
		IF thermoIntLocked THEN INCL(s, 1) END;
		IF thermoIntLimited THEN INCL(s, 2) END;
		IF thermoIntELimited THEN INCL(s, 3) END;
		a[0] := CHR(SYSTEM.VAL(INTEGER, s));
		a[1] := CHR(controlZad);
		a[2] := CHR(tempZad);
		a[3] := CHR(tempZad DIV 100H);
		int := thermoInt DIV thermoK2;
		a[4] := CHR(int);
		a[5] := CHR(int DIV 100H);
		TP0.Send(idState0, SYSTEM.ADR(a), 6, ok)
	END SendState0;

	PROCEDURE Receive0 (id: CHAR; a: ARRAY OF CHAR; len: INTEGER);
	BEGIN
		IF id = idTempZad THEN
			IF len = 2 THEN
				tempZad := ORD(a[0]) + 100H * ORD(a[1])
			END
		END
	END Receive0;

	PROCEDURE SendSHT1x (temp0, humi0: INTEGER);
		VAR a: ARRAY 5 OF CHAR; ok: BOOLEAN;
	BEGIN
		a[0] := 0X;
		a[1] := CHR(temp0);
		a[2] := CHR(temp0 DIV 100H);
		a[3] := CHR(humi0);
		a[4] := CHR(humi0 DIV 100H);
		TP0.Send(idSHT1x, SYSTEM.ADR(a), 5, ok)
	END SendSHT1x;

	PROCEDURE SendMsrErr (id: CHAR; err: INTEGER);
		VAR x: INTEGER; ok: BOOLEAN;
	BEGIN
		x := ORD(id) + err * 100H;
		TP0.Send(idSHT1x, SYSTEM.ADR(x), 2, ok)
	END SendMsrErr;

	PROCEDURE MeasureTask;
		VAR res: INTEGER;

		PROCEDURE TempErr (res: INTEGER);
		BEGIN
			SendMsrErr(1X, res);
			IF SHT1x.SoftReset() THEN END;
			controlZad := controlDef;
			msrState := 0
		END TempErr;

		PROCEDURE HumiErr (res: INTEGER);
		BEGIN
			SendMsrErr(2X, res);
			IF SHT1x.SoftReset() THEN END;
			msrState := 0
		END HumiErr;

	BEGIN
		IF msrState = 0 THEN
			SHT1x.StartMeasure(SHT1x.TEMP, res);
			IF res = 0 THEN msrState := 1
			ELSE TempErr(res)
			END
		ELSIF msrState = 1 THEN
			SHT1x.CheckResult(SHT1x.TEMP, temp0, res);
			IF res = 0 THEN
				ThermoTask(temp0);
				SHT1x.StartMeasure(SHT1x.HUMI, res);
				IF res = 0 THEN msrState := 2
				ELSE HumiErr(res)
				END
			ELSE TempErr(res)
			END
		ELSIF msrState = 2 THEN
			SHT1x.CheckResult(SHT1x.HUMI, humi0, res);
			IF res = 0 THEN
				SendSHT1x(temp0, humi0);
				msrState := 3
			ELSE HumiErr(res)
			END
		ELSIF msrState = 7 THEN msrState := 0
		ELSE INC(msrState)
		END
	END MeasureTask;

	(* timerFreq *)
	PROCEDURE OnTimer;
	BEGIN
		INC(cnt0);
		IF ODD(cnt0) THEN
			ControlTask;
			ServoTask;
			SendState0
		ELSIF cnt0 MOD 4 = 0 THEN
			MeasureTask
		END
	END OnTimer;

	PROCEDURE* SysTickIntHandler;
	BEGIN
		timerFlag := TRUE
	END SysTickIntHandler;

	PROCEDURE MainLoop;
	BEGIN
		REPEAT
			TP0.Receive(Receive0);
			IF timerFlag THEN timerFlag := FALSE;
				OnTimer
			END;
			ARMv6M.WFI
		UNTIL FALSE
	END MainLoop;

	PROCEDURE Init;
		VAR ok: BOOLEAN;

		PROCEDURE InitThermo;
			CONST
				tempZad0 = 2400 (* 24.0 °C *) + 3965;
		BEGIN
			tempZad := tempZad0;
			thermoInt := 0;
				thermoIntLocked := FALSE; thermoIntLimited := FALSE;
				thermoIntELimited := FALSE;
				thermoIntDisable := FALSE
		END InitThermo;

		PROCEDURE InitControl;

			PROCEDURE InitServo;
				CONST GPIO = 6;
				VAR x: SET;
			BEGIN
				(* enable clock for GPIO *)
					SYSTEM.GET(MCU.SYSAHBCLKCTRL, x);
					SYSTEM.PUT(MCU.SYSAHBCLKCTRL, x + {GPIO});

				SYSTEM.GET(MCU.GPIO3DIR, x);
				SYSTEM.PUT(MCU.GPIO3DIR, x + {0}) (* P3.0: output *)
			END InitServo;

		BEGIN
			controlCnt := 0; controlUp := 0; controlDown := 0;
			controlZad := controlDef;
			servoZad := controlZad # controlClose;
			InitServo;
			ServoTask
		END InitControl;

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

		PROCEDURE InitMeasure;
		BEGIN
			msrState := 3;
			SHT1x.Init
		END InitMeasure;

	BEGIN
		InitThermo;
		InitControl;
		InitMeasure;
		InitTimer;
		TP0.Init(19200, TP0.parityNone);
		TP0.Send(idInit, SYSTEM.ADR(Traps.nResets), 4, ok);
		TP0.Send(idInit, SYSTEM.ADR(Traps.nResets), 4, ok);
		IF Traps.trapFlag THEN
			TP0.Send(idTrap, SYSTEM.ADR(Traps.trap), 9, ok);
			IF ok THEN Traps.ClearTrapFlag END
		END
	END Init;

BEGIN
	Init;
	MainLoop
END MobxLPC1114ThermoRegul1.

O7ARMv6MP.Compile MicroARMv6M MicroARMv6MTraps MicroLPC1100 MicroLPC1100System MicroLPC1114TPort0 MobxLPC1114SHT1x 

O7ARMv6MP.Compile @/s

O7ARMv7MTool.DecObj MobxLPC1114ThermoRegul1.a6m 

O7ARMv6MLinker.Link LPC1114FBD48302 MobxLPC1114ThermoRegul1 

O7ARMv7MTool.DecHex MobxLPC1114ThermoRegul1.hex 

O7ARMv7MTool.DecBin MobxLPC1114ThermoRegul1.bin 
