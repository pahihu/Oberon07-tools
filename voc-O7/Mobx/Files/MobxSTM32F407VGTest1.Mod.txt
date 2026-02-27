MODULE MobxSTM32F407VGTest1;

	(* Alexander Shiryaev, Ivan Denisov, 2015.07, 2021.08 *)

	(* Blinking LED, connected to PD12 *)

	(* NOTE: default clock frequency is 16 MHz *)

	IMPORT SYSTEM, MCU := MicroSTM32F4;

	CONST
		sleepTime = 1600000; (* ~ 1 sec @ Thumb-16 *)

	PROCEDURE InitLED;
		CONST GPIODEN = 3;
		VAR x: SET;
	BEGIN
		(* enable GPIOD clock *)
			SYSTEM.GET(MCU.RCCAHB1ENR, x);
			SYSTEM.PUT(MCU.RCCAHB1ENR, x + {GPIODEN});

		(* PD12: output *)
			SYSTEM.GET(MCU.GPIODMODER, x);
			SYSTEM.PUT(MCU.GPIODMODER, x + {12*2} - {12*2+1})
	END InitLED;

	PROCEDURE Sleep (x: INTEGER);
	BEGIN REPEAT DEC(x) UNTIL x = 0
	END Sleep;

BEGIN
	InitLED;
	REPEAT
		Sleep(sleepTime);
		SYSTEM.PUT(MCU.GPIODBSRR, {12}); (* !PD12 *)
		Sleep(sleepTime);
		SYSTEM.PUT(MCU.GPIODBSRR, {12 + 16}) (* !~PD12 *)
	UNTIL FALSE
END MobxSTM32F407VGTest1.

O7ARMv6MP.Compile @/s

O7ARMv6MLinker.Link STM32F407VG MobxSTM32F407VGTest1 


O7ARMv7MP.Compile @/s

O7ARMv7MLinker.Link STM32F407VG MobxSTM32F407VGTest1 


O7ARMv7MTool.DecHex MobxSTM32F407VGTest1.hex 

O7ARMv7MTool.DecBin MobxSTM32F407VGTest1.bin 
