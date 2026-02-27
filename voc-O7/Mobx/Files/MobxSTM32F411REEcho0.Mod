MODULE MobxSTM32F411REEcho0;

	(* Alexander Shiryaev, 2014.09, 2016.06, 2021.08 *)

	IMPORT SYSTEM, ARMv7M := MicroARMv7M,
		Pins := MicroSTM32F4Pins, TPs := MicroSTM32F4TPorts,
		Sys := MicroSTM32F4System;

	VAR p: TPs.Port;

	PROCEDURE Receive (id: CHAR; a: ARRAY OF CHAR; len: INTEGER);
		VAR ok: BOOLEAN;
	BEGIN
		TPs.Send(p, id, SYSTEM.ADR(a), len, ok)
	END Receive;

	PROCEDURE MainLoop;
	BEGIN
		REPEAT
			TPs.Receive(p);
			ARMv7M.WFI
		UNTIL FALSE
	END MainLoop;

	PROCEDURE Init;
		VAR par: TPs.InitPar1;
	BEGIN
		par.n := TPs.USART2;
		par.RXPinPort := Pins.A; par.RXPinN := 3; par.RXPinAF := Pins.AF7;
		par.TXPinPort := Pins.A; par.TXPinN := 2; par.TXPinAF := Pins.AF7;
		par.UCLK := Sys.PCLK1;
		par.baud := 19200;
		par.parity := TPs.parityNone;
		par.receive := Receive;
		TPs.Init(p, par)
	END Init;

BEGIN
	Init;
	MainLoop
END MobxSTM32F411REEcho0.

O7ARMv7MP.Compile @/s

O7ARMv7MLinker.Link STM32F411RE MobxSTM32F411REEcho0 

O7ARMv7MTool.DecHex MobxSTM32F411REEcho0.hex 

O7ARMv7MTool.DecBin MobxSTM32F411REEcho0.bin 
