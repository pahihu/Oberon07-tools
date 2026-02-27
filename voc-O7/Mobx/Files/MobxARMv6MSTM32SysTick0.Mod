MODULE MobxARMv6MSTM32SysTick0;

	(*
		Alexander Shiryaev, 2015.03, 2016.04

		SysTick timer for producing periodic events
	*)

	IMPORT SYSTEM, ARMv6M := MicroARMv6M, Traps := MicroARMv6MTraps;

	VAR flag: BOOLEAN;

	PROCEDURE* SysTickIntHandler;
	BEGIN flag := TRUE
	END SysTickIntHandler;

	PROCEDURE Init* (HCLK, freq: INTEGER);
		CONST
			(* SYSTCSR bits: *)
				ENABLE = 0; TICKINT = 1; CLKSOURCE = 2;
		VAR x: INTEGER;
	BEGIN
		SYSTEM.PUT(ARMv6M.SYSTCSR, {}); (* disable SysTick *)
		flag := FALSE;
		(* NOTE: timer is 24-bit! *)
		(* http://infocenter.arm.com/help/index.jsp?topic=/com.arm.doc.dui0552a/Babieigh.html *)
			x := HCLK DIV 8 DIV freq - 1;
			ASSERT(x > 0);
			ASSERT(x < 1000000H);
			SYSTEM.PUT(ARMv6M.SYSTRVR, x);
		SYSTEM.PUT(ARMv6M.SYSTCVR, 0); (* any write to current clears it *)
		SYSTEM.PUT(Traps.vectorsOrg + ARMv6M.SysTick * 4, SysTickIntHandler);
		SYSTEM.PUT(ARMv6M.SYSTCSR, {ENABLE,TICKINT}) (* enable timer with clock source of HCLK/8 with interrupts *)
	END Init;

	PROCEDURE OnTimer* (): BOOLEAN;
		VAR res: BOOLEAN;
	BEGIN
		res := flag; IF res THEN flag := FALSE END
	RETURN res
	END OnTimer;

END MobxARMv6MSTM32SysTick0.
