MODULE MobxSTM32F405RGTest1;

	(* Alexander Shiryaev, 2014.12, 2021.08 *)

	(* Blinking LED, connected to PC12 *)

	(* NOTE: default clock frequency is 16 MHz *)

	IMPORT SYSTEM, MCU := MicroSTM32F4;

	CONST
		sleepTime = 1600000; (* ~ 1 sec @ Thumb-16 *)

	PROCEDURE InitLED;
		CONST GPIOCEN = 2;
		VAR x: SET;
	BEGIN
		(* enable GPIOC clock *)
			SYSTEM.GET(MCU.RCCAHB1ENR, x);
			SYSTEM.PUT(MCU.RCCAHB1ENR, x + {GPIOCEN});

		(* PC12: output *)
			SYSTEM.GET(MCU.GPIOCMODER, x);
			SYSTEM.PUT(MCU.GPIOCMODER, x + {12*2} - {12*2+1})
	END InitLED;

	PROCEDURE Sleep (x: INTEGER);
	BEGIN REPEAT DEC(x) UNTIL x = 0
	END Sleep;

BEGIN
	InitLED;
	REPEAT
		Sleep(sleepTime);
		SYSTEM.PUT(MCU.GPIOCBSRR, {12}); (* !PC12 *)
		Sleep(sleepTime);
		SYSTEM.PUT(MCU.GPIOCBSRR, {12 + 16}) (* !~PC12 *)
	UNTIL FALSE
END MobxSTM32F405RGTest1.

O7ARMv6MP.Compile @/s

O7ARMv6MLinker.Link STM32F405RG MobxSTM32F405RGTest1 


O7ARMv7MP.Compile @/s

O7ARMv7MLinker.Link STM32F405RG MobxSTM32F405RGTest1 


O7ARMv7MTool.DecHex MobxSTM32F405RGTest1.hex 

O7ARMv7MTool.DecBin MobxSTM32F405RGTest1.bin 
