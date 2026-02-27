MODULE MobxLPC1778Echo0;

	(* Alexander Shiryaev, 2016.03 *)

	IMPORT SYSTEM, ARMv7M := MicroARMv7M, TPs := MicroLPC1788TPorts;

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
	BEGIN
		TPs.Init(p0, TPs.UART0, 0, 19200, TPs.parityNone, Receive)
	END Init;

BEGIN
	Init;
	MainLoop
END MobxLPC1778Echo0.

O7ARMv7MLinker.Link LPC1778 MobxLPC1778Echo0 
