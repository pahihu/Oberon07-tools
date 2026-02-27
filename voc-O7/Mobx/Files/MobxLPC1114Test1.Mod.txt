MODULE MobxLPC1114Test1;

	(* Alexander Shiryaev, 2014.09 *)

	(* Blinking LED(s), connected to P3.N *)

	(* NOTE: default clock frequency is 12 MHz *)

	IMPORT SYSTEM, MCU := MicroLPC1100;

	CONST
		sleepTime = 1125000; (* ~ 1 sec @ Thumb-16 *)
		N = {0,1,2};

	PROCEDURE InitMCU;
		VAR x: SET;
	BEGIN
		SYSTEM.GET(MCU.FLASHCFG, x);
		SYSTEM.PUT(MCU.FLASHCFG, x - {0,1}) (* 1 system clock flash access time (for system clock frequencies of up to 20 MHz) *)
	END InitMCU;

	PROCEDURE InitLED;
		CONST GPIO = 6;
		VAR x: SET;
	BEGIN
		(* enable clock for GPIO *)
			SYSTEM.GET(MCU.SYSAHBCLKCTRL, x);
			SYSTEM.PUT(MCU.SYSAHBCLKCTRL, x + {GPIO});

		SYSTEM.GET(MCU.GPIO3DIR, x);
		SYSTEM.PUT(MCU.GPIO3DIR, x + N) (* P3.N: output(s) *)
	END InitLED;

	PROCEDURE Sleep (x: INTEGER);
	BEGIN REPEAT DEC(x) UNTIL x = 0
	END Sleep;

BEGIN
	InitMCU;
	InitLED;
	REPEAT
		Sleep(sleepTime);

		SYSTEM.PUT(
			MCU.GPIO3MASKEDACCESS + SYSTEM.VAL(INTEGER, N) * 4, {});

		Sleep(sleepTime);

		SYSTEM.PUT(
			MCU.GPIO3MASKEDACCESS + SYSTEM.VAL(INTEGER, N) * 4, N)
	UNTIL FALSE
END MobxLPC1114Test1.

O7ARMv6MP.Compile @/s

O7ARMv7MTool.DecObj MobxLPC1114Test1.a6m 

O7ARMv6MLinker.Link LPC1114FBD48302 MobxLPC1114Test1 

O7ARMv7MTool.DecHex MobxLPC1114Test1.hex 

O7ARMv7MTool.DecBin MobxLPC1114Test1.bin 
