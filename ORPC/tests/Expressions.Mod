MODULE Expressions;
IMPORT SYSTEM;
CONST greeting = "hello"; k = 2+3*4;
TYPE F = PROCEDURE (): INTEGER;
VAR ticks*, result*: INTEGER; flags*: SET; real*: REAL;
PROCEDURE Tick(): BOOLEAN;
BEGIN INC(ticks)
RETURN TRUE
END Tick;
PROCEDURE Change(): INTEGER;
BEGIN result := 100
RETURN 3
END Change;
PROCEDURE Pair(x, y: INTEGER): INTEGER;
RETURN x*10+y
END Pair;
PROCEDURE Outer(): INTEGER;
  PROCEDURE Inner(x: INTEGER): INTEGER;
  RETURN x+1
  END Inner;
RETURN Inner(8)
END Outer;
PROCEDURE Run*;
VAR b: BOOLEAN; text: ARRAY 16 OF CHAR; n: INTEGER;
BEGIN ticks := 0; b := FALSE & Tick(); b := TRUE OR Tick();
  IF b & (ticks = 0) THEN result := 2 END;
  result := result + Change();
  ASSERT(result = 5);
  result := Pair(result, Change()); ASSERT(result = 53);
  flags := {0, 2..4, 31}; INCL(flags, 6); EXCL(flags, 3);
  IF (31 IN flags) & ~(3 IN flags) THEN INC(result) END;
  result := result + (-7 DIV 3)*10 + (-7 MOD 3);
  text := greeting; IF text = "hello" THEN INC(result) END;
  real := FLT(9); PACK(real, 2); UNPK(real, n);
  result := result + FLOOR(real) + n + Outer();
  ASSERT(LSL(1, 31) = 80000000H);
  ASSERT(ASR(LSL(1, SYSTEM.SIZE(INTEGER)*8-1), SYSTEM.SIZE(INTEGER)*8-1) = -1);
  ASSERT(ROR(1, 1) = LSL(1, SYSTEM.SIZE(INTEGER)*8-1))
END Run;
END Expressions.
