MODULE MobxLPC1343Blink;

	(* Ivan Denisov, Alexander Shiryaev, 2014.10 *)

	(* Blinking LED(s), connected to P0.leds *)

	IMPORT SYSTEM, MCU := MicroLPC1343, Sys := MicroLPC1343System;

	CONST
		leds = {7};

		(* timer *)
			TCR = MCU.TMR32B0TCR; (* timer control register *)
				(* TCR bits: *)
					CEN = 0; CRES = 1;
			PR = MCU.TMR32B0PR; (* prescale register *)
			TC = MCU.TMR32B0TC; (* timer counter *)

	PROCEDURE MSecDelay (delay: INTEGER);
		VAR tc, prescale: INTEGER;
	BEGIN
		SYSTEM.PUT(TCR, {CRES});
		prescale := (Sys.PCLK + 1000 DIV 2) DIV 1000;
		SYSTEM.PUT(PR, prescale * delay - 1);
		SYSTEM.PUT(TCR, {CEN});
		REPEAT SYSTEM.GET(TC, tc) UNTIL tc # 0;
		SYSTEM.PUT(TCR, {})
	END MSecDelay;

	PROCEDURE MainLoop;
		VAR x: SET;
	BEGIN
		REPEAT
			SYSTEM.GET(MCU.GPIO0DATA, x);
			SYSTEM.PUT(MCU.GPIO0DATA, x + leds);

			MSecDelay(500);

			SYSTEM.GET(MCU.GPIO0DATA, x);
			SYSTEM.PUT(MCU.GPIO0DATA, x - leds);

			MSecDelay(500)
		UNTIL FALSE
	END MainLoop;

	PROCEDURE Init;
		CONST
			(* SYSAHBCLKCTRL bits: *)
				GPIO = 6; CT32B0 = 9;

		PROCEDURE InitLED;
			VAR x: SET;
		BEGIN
			(* enable clock for GPIO *)
				SYSTEM.GET(MCU.SYSAHBCLKCTRL, x);
				SYSTEM.PUT(MCU.SYSAHBCLKCTRL, x + {GPIO});

			SYSTEM.GET(MCU.GPIO0DIR, x);
			SYSTEM.PUT(MCU.GPIO0DIR, x + leds) (* P0.leds: output(s) *)
		END InitLED;

		PROCEDURE InitTimer;
			VAR x: SET;
		BEGIN
			(* enable clock for Timer 0 *)
				SYSTEM.GET(MCU.SYSAHBCLKCTRL, x);
				SYSTEM.PUT(MCU.SYSAHBCLKCTRL, x + {CT32B0})
		END InitTimer;

	BEGIN
		InitTimer;
		InitLED
	END Init;

BEGIN
	Init;
	MainLoop
END MobxLPC1343Blink.

O7ARMv7MP.Compile MicroLPC1343 MicroLPC1343System 

O7ARMv7MP.Compile @/s

O7ARMv7MLinker.Link LPC1343 MobxLPC1343Blink 

O7ARMv7MTool.DecHex MobxLPC1343Blink.hex 

O7ARMv7MTool.DecBin MobxLPC1343Blink.bin 
