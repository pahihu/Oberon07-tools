MODULE MobxSTM32F103C8Echo0;

	(* Alexander Shiryaev, 2016.04, 2017.04, 2021.08 *)

	IMPORT SYSTEM, ARMv7M := MicroARMv7M,
		Pins := MicroSTM32F10xPinCfg, TPs := MicroSTM32F1TPorts,
		Sys := MicroSTM32F103x8System;

	VAR
		p0: TPs.Port;

	PROCEDURE Receive (id: CHAR; a: ARRAY OF CHAR; len: INTEGER);
		VAR ok: BOOLEAN;
	BEGIN
		TPs.Send(p0, id, SYSTEM.ADR(a), len, ok)
	END Receive;

	PROCEDURE MainLoop;
	BEGIN
		REPEAT
			TPs.Receive(p0);
			ARMv7M.WFI
		UNTIL FALSE
	END MainLoop;

	PROCEDURE Init;
		VAR par: TPs.InitPar2;
	BEGIN
		par.n := TPs.USART1;
		par.RXPinPort := Pins.A; par.RXPinN := 10;
		par.TXPinPort := Pins.A; par.TXPinN := 9;
		par.UCLK := Sys.PCLK2;
		par.baud := 19200;
		par.parity := TPs.parityNone;
		par.receive := Receive;
		TPs.Init(p0, par)
	END Init;

BEGIN
	Init;
	MainLoop
END MobxSTM32F103C8Echo0.

O7ARMv7MLinker.Link STM32F103C8 MobxSTM32F103C8Echo0
