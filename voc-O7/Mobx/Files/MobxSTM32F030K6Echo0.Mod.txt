MODULE MobxSTM32F030K6Echo0;

	(*
		Alexander Shiryaev, 2016.04, 2021.08
	*)

	IMPORT SYSTEM, ARMv6M := MicroARMv6M,
		Pins := MicroSTM32F0Pins, TPorts := MicroSTM32F0TPorts,
		Sys := MicroSTM32F030System;

	VAR p0: TPorts.Port;

	PROCEDURE Receive (id: CHAR; a: ARRAY OF CHAR; len: INTEGER);
	BEGIN
		TPorts.Send(p0, id, SYSTEM.ADR(a), len)
	END Receive;

	PROCEDURE MainLoop;
	BEGIN
		REPEAT
			TPorts.Receive(p0);
			ARMv6M.WFI
		UNTIL FALSE
	END MainLoop;

	PROCEDURE Init;
		VAR par: TPorts.InitPar1;
	BEGIN
		par.n := TPorts.USART1;
		par.RXPinPort := Pins.A; par.RXPinN := 10; par.RXPinAF := Pins.AF1;
		par.TXPinPort := Pins.A; par.TXPinN := 9; par.TXPinAF := Pins.AF1;
		par.UCLK := Sys.PCLK;
		par.baud := 19200;
		par.parity := TPorts.parityNone;
		par.receive := Receive;
		TPorts.Init(p0, par)
	END Init;

BEGIN
	Init;
	MainLoop
END MobxSTM32F030K6Echo0.

O7ARMv6MP.Compile @/s

O7ARMv6MLinker.Link STM32F030K6 MobxSTM32F030K6Echo0
