MODULE OCGTarget;
IMPORT SYSTEM, Sys := System, RealStr, Conv := ConvTypes;
CONST WordSize* = SIZE(Sys.Address); Bits* = 8*WordSize;
TYPE Int* = Sys.Address; Real* = LONGREAL;
PROCEDURE AddOverflow*(a, b: Int): BOOLEAN;
BEGIN RETURN (b > 0) & (a > MAX(Int)-b) OR (b < 0) & (a < MIN(Int)-b)
END AddOverflow;
PROCEDURE SubOverflow*(a, b: Int): BOOLEAN;
BEGIN RETURN (b > 0) & (a < MIN(Int)+b) OR (b < 0) & (a > MAX(Int)+b)
END SubOverflow;
PROCEDURE Add*(a, b: Int): Int;
BEGIN
  IF (b > 0) & (a > MAX(Int)-b) THEN RETURN (a-MAX(Int))+(b-1)+MIN(Int)
  ELSIF (b < 0) & (a < MIN(Int)-b) THEN RETURN (a-MIN(Int))+(b+1)+MAX(Int)
  ELSE RETURN a+b END
END Add;
PROCEDURE Neg*(x: Int): Int;
BEGIN IF x = MIN(Int) THEN RETURN x ELSE RETURN -x END END Neg;
PROCEDURE Sub*(a, b: Int): Int;
BEGIN RETURN Add(a, Neg(b)) END Sub;
PROCEDURE Mul*(a, b: Int): Int;
VAR result: Int;
BEGIN result := 0;
  WHILE b # 0 DO
    IF ODD(b) THEN result := Add(result, a) END;
    a := SYSTEM.LSH(a, 1); b := SYSTEM.LSH(b, -1)
  END;
RETURN result
END Mul;
PROCEDURE MulOverflow*(a, b: Int): BOOLEAN;
VAR negative: BOOLEAN;
BEGIN
  IF (a = 0) OR (b = 0) OR (a = 1) OR (b = 1) THEN RETURN FALSE END;
  IF (a = MIN(Int)) OR (b = MIN(Int)) THEN RETURN TRUE END;
  negative := (a < 0) # (b < 0); a := ABS(a); b := ABS(b);
  IF a <= MAX(Int) DIV b THEN RETURN FALSE END;
  RETURN ~(negative & (MIN(Int) MOD a = 0) & (MIN(Int) DIV a = -b))
END MulOverflow;
PROCEDURE Round*(x: Real): Real;
VAR single: REAL;
BEGIN IF WordSize = 4 THEN single := SHORT(x); x := single END;
RETURN x
END Round;
PROCEDURE ParseReal*(text: ARRAY OF CHAR; VAR value: Real): BOOLEAN;
VAR result: Conv.ConvResults;
BEGIN RealStr.Take(text, value, result);
  IF result # Conv.allRight THEN RETURN FALSE END;
  IF (WordSize = 4) & (ABS(value) > 3.4028234663852886D38) THEN RETURN FALSE END;
  value := Round(value); RETURN TRUE
END ParseReal;
PROCEDURE RealBits*(x: Real): Int;
VAR single: REAL; bits: Int;
BEGIN IF WordSize = 4 THEN
  single := SHORT(x); SYSTEM.MOVE(SYSTEM.ADR(single), SYSTEM.ADR(bits), WordSize)
ELSE SYSTEM.MOVE(SYSTEM.ADR(x), SYSTEM.ADR(bits), WordSize) END;
RETURN bits
END RealBits;
PROCEDURE BitsReal*(bits: Int): Real;
VAR single: REAL; x: Real;
BEGIN IF WordSize = 4 THEN
  SYSTEM.MOVE(SYSTEM.ADR(bits), SYSTEM.ADR(single), WordSize); x := single
ELSE SYSTEM.MOVE(SYSTEM.ADR(bits), SYSTEM.ADR(x), WordSize) END;
RETURN x
END BitsReal;
END OCGTarget.
