MODULE MobxLPC1115Test1;

	(*
		Alexander Shiryaev, 2014.09
		Pablo Cayuela, 2016.04
	*)

	(* Blinking LED(s), connected to P0.N *)

	(* NOTE: default clock frequency is 12 MHz *)

	IMPORT SYSTEM, MCU := MicroLPC1100;

	CONST
		sleepTime = 1125000; (* ~ 1 sec @ Thumb-16 *)
		N = {7};

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

		SYSTEM.GET(MCU.GPIO0DIR, x);
		SYSTEM.PUT(MCU.GPIO0DIR, x + N) (* P0.N: output(s) *)
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
			MCU.GPIO0MASKEDACCESS + SYSTEM.VAL(INTEGER, N) * 4, {});

		Sleep(sleepTime);

		SYSTEM.PUT(
			MCU.GPIO0MASKEDACCESS + SYSTEM.VAL(INTEGER, N) * 4, N)
	UNTIL FALSE
END MobxLPC1115Test1.

O7ARMv6MP.Compile @/s

O7ARMv7MTool.DecObj MobxLPC1115Test1.a6m 

O7ARMv6MLinker.Link LPC1115 MobxLPC1115Test1 

O7ARMv7MTool.DecHex MobxLPC1115Test1.hex 

O7ARMv7MTool.DecBin MobxLPC1115Test1.bin 
