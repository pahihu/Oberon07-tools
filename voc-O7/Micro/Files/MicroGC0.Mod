MODULE MicroGC0;

	(* Alexander Shiryaev, 2014.09 *)

	(* NOTE: GC should be not in Kernel, because GC requires Modules *)

	IMPORT SYSTEM, Kernel := MicroKernel0;

	CONST MT = 6; (* compiler-dependent *)

	(* linker-dependent *)
	PROCEDURE Collect*;
		VAR n, adr, ptr: INTEGER;
	BEGIN
		adr := SYSTEM.REG(MT) - 4;
		SYSTEM.GET(adr, n);
		adr := adr - n * 4;
		WHILE n > 0 DO
			SYSTEM.GET(adr, ptr);
			INC(adr, 4);
			Kernel.Mark(ptr);
			DEC(n)
		END;
		Kernel.Scan
	END Collect;

END MicroGC0.

O7ARMv6MP.Compile @/s

O7ARMv7MTool.DecObj MicroGC0.a6m 


O7ARMv7MP.Compile @/s

O7ARMv7MTool.DecObj MicroGC0.a7m 
