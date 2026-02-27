MODULE MobxSTM32F446RETest1;

	(* Alexander Shiryaev, 2016.06 *)

	(* Blinking LED, connected to PA5 *)

	(* NOTE: default clock frequency is 16 MHz *)

	IMPORT SYSTEM,
		Pins := MicroSTM32F4Pins;

	CONST
		sleepTime = 1600000; (* ~1 sec @ Thumb-16 *)

	PROCEDURE InitLED;
	BEGIN
		Pins.Configure(Pins.A, 5,
			Pins.output, Pins.pushPull, Pins.low, Pins.noPull, 0)
	END InitLED;

	PROCEDURE Sleep (x: INTEGER);
	BEGIN REPEAT DEC(x) UNTIL x = 0
	END Sleep;

BEGIN
	InitLED;
	REPEAT
		Sleep(sleepTime);
		SYSTEM.PUT(Pins.GPIOABSRR, {5}); (* !PA5 *)
		Sleep(sleepTime);
		SYSTEM.PUT(Pins.GPIOABSRR, {16+5}) (* !~PA5 *)
	UNTIL FALSE
END MobxSTM32F446RETest1.

O7ARMv7MLinker.Link STM32F446RE MobxSTM32F446RETest1 

O7ARMv7MTool.DecHex MobxSTM32F446RETest1.hex 
