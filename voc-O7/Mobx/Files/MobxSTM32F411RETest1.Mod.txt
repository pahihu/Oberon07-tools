MODULE MobxSTM32F411RETest1;

	(* Alexander Shiryaev, 2014.09, 2021.08 *)

	(* Blinking LED, connected to PA5 *)

	(* NOTE: default clock frequency is 16 MHz *)

	IMPORT SYSTEM, MCU := MicroSTM32F4;

	CONST
		sleepTime = 1600000; (* ~ 1 sec @ Thumb-16 *)

	PROCEDURE InitLED;
		CONST GPIOAEN = 0;
		VAR x: SET;
	BEGIN
		(* enable GPIOA clock *)
			SYSTEM.GET(MCU.RCCAHB1ENR, x);
			SYSTEM.PUT(MCU.RCCAHB1ENR, x + {GPIOAEN});

		SYSTEM.GET(MCU.GPIOAMODER, x);
		SYSTEM.PUT(MCU.GPIOAMODER, x + {10} - {11}); (* PA5: output *)

		SYSTEM.GET(MCU.GPIOAOTYPER, x);
		SYSTEM.PUT(MCU.GPIOAOTYPER, x - {5}); (* PA5: push-pull *)

		SYSTEM.GET(MCU.GPIOAPUPDR, x);
		SYSTEM.PUT(MCU.GPIOAPUPDR, x - {10,11}) (* PA5: no pull resistors *)
	END InitLED;

	PROCEDURE Sleep (x: INTEGER);
	BEGIN REPEAT DEC(x) UNTIL x = 0
	END Sleep;

BEGIN
	InitLED;
	REPEAT
		Sleep(sleepTime);
		SYSTEM.PUT(MCU.GPIOABSRR, {5}); (* !PA5 *)
		Sleep(sleepTime);
		SYSTEM.PUT(MCU.GPIOABSRR, {5 + 16}) (* !~PA5 *)
	UNTIL FALSE
END MobxSTM32F411RETest1.

O7CM4P.Compile @/s

O7CM4Linker.Link STM32F411RE MobxSTM32F411RETest1 

O7CM4Tool.DecHex MobxSTM32F411RETest1.hex 


O7ARMv6MP.Compile @/s

O7ARMv6MLinker.Link STM32F411RE MobxSTM32F411RETest1 


O7ARMv7MP.Compile @/s

O7ARMv7MLinker.Link STM32F411RE MobxSTM32F411RETest1 


O7ARMv7MTool.DecHex MobxSTM32F411RETest1.hex 

O7ARMv7MTool.DecBin MobxSTM32F411RETest1.bin 
