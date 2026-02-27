MODULE MicroARMv6MTraps;

	(* Alexander Shiryaev, 2014.09, 2017.03, 2019.10, 2023.06 *)

	(* ARMv6-M *)

	(*
		TODO: init all other traps, extend TrapHandler

		NOTE:
			trap codes:
				1: index check
				2: type cast
				3: array size
				4: nil check
				5: nil check (procedure call)
				6: bad divisor (must be > 0)
				7: assert

				10: hard fault
				11: memory manage
				12: bus fault
				13: usage fault
	*)

	IMPORT SYSTEM, ARMv6M := MicroARMv6M, Kernel := MicroKernel0;

	CONST
		SP = 13;
		SR0 = 0; SR1 = 1; SR2 = 2; SR3 = 3; SR12 = 4; SLR = 5; SPC = 6;

		rstCheckKey = 19847C2AH;

	TYPE
		TrapHandler* = PROCEDURE (code: CHAR; pc, pos: INTEGER);

		Trap* = RECORD
			pc*, pos*: INTEGER;
			code*: CHAR
		END;

	VAR
		nResets*: INTEGER;
		trapFlag*: BOOLEAN;
		trap*: Trap;
		trapHandler*: TrapHandler;
		vectorsOrg*: INTEGER;
		rstCheck: INTEGER;

	PROCEDURE DefaultTrapHandler* (code: CHAR; pc, pos: INTEGER);
	BEGIN
		IF ~trapFlag THEN
			trap.code := code;
			trap.pc := pc;
			trap.pos := pos;
			trapFlag := TRUE
		END;

		rstCheck := rstCheckKey;

		(* system reset *)
			ARMv6M.DSB;
			SYSTEM.PUT(ARMv6M.AIRCR, 05FA0004H); (* SYSRESETREQ *)
			ARMv6M.DSB;
			REPEAT UNTIL FALSE
	END DefaultTrapHandler;

	PROCEDURE SVCTrap (VAR a: INTEGER; b: INTEGER);
		CONST nLVars = 4;
		VAR pc: INTEGER; code: CHAR;
	BEGIN
		(* compiler-dependent *)
			SYSTEM.GET(SYSTEM.REG(SP) + (SPC + nLVars + 1) * 4, pc);
		pc := pc - 2;
		SYSTEM.GET(pc, code);

		IF code = 0X THEN (* NEW *)
			Kernel.New(a, b)
		ELSE
			trapHandler(code, pc, b (* pos *))
		END
	END SVCTrap;

	PROCEDURE* HardFaultTrap;
		CONST nLVars = 1;
		VAR pc: INTEGER;
	BEGIN
		(* compiler-dependent *)
			SYSTEM.GET(SYSTEM.REG(SP) + (SPC + nLVars + 4) * 4, pc);
			IF pc = 0 THEN
				SYSTEM.GET(SYSTEM.REG(SP) + (SLR + nLVars + 4) * 4, pc) (* lr *)
			END;
		trapHandler(0AX, pc, 0)
	END HardFaultTrap;

	PROCEDURE SetTrapHandler* (newTrapHandler: TrapHandler);
	BEGIN
		trapHandler := newTrapHandler
	END SetTrapHandler;

	PROCEDURE ClearTrapFlag*;
	BEGIN
		trapFlag := FALSE
	END ClearTrapFlag;

	PROCEDURE Init* (vectorsorg: INTEGER);
	BEGIN
		vectorsOrg := vectorsorg;
		trapHandler := DefaultTrapHandler;

		IF rstCheck # rstCheckKey THEN
			nResets := 0;
			trapFlag := FALSE
		ELSE
			INC(nResets)
		END;
		rstCheck := 0; (* # rstCheckKey *)

		SYSTEM.PUT(ARMv6M.VTOR, vectorsorg);

		SYSTEM.PUT(vectorsOrg + ARMv6M.HardFault * 4, HardFaultTrap);
		SYSTEM.PUT(vectorsOrg + ARMv6M.SVCall * 4, SVCTrap)
	END Init;

END MicroARMv6MTraps.

O7ARMv6MP.Compile @/s

O7ARMv7MTool.DecObj MicroARMv6MTraps.a6m 
