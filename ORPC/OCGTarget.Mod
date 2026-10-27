MODULE OCGTarget;
IMPORT SYSTEM, Sys := System, RealStr, Conv := ConvTypes;
CONST HostWordSize* = SIZE(Sys.Address);
TYPE Int* = Sys.Address; Real* = LONGREAL;
VAR WordSize*, Bits*, Cortex*: Sys.INT32;
PROCEDURE Configure*(core: Sys.INT32);
BEGIN Cortex := core;
  IF core = 0 THEN WordSize := HostWordSize ELSE WordSize := 4 END;
  Bits := 8*WordSize
END Configure;
PROCEDURE Min*(): Int;
BEGIN IF WordSize = 4 THEN RETURN MIN(Sys.INT32) ELSE RETURN MIN(Int) END END Min;
PROCEDURE Max*(): Int;
BEGIN IF WordSize = 4 THEN RETURN MAX(Sys.INT32) ELSE RETURN MAX(Int) END END Max;
PROCEDURE Normalize*(x: Int): Int;
BEGIN IF WordSize = 4 THEN RETURN Sys.Short(x) ELSE RETURN x END END Normalize;
PROCEDURE Shift*(operation: Sys.INT32; x, n: Int): Int;
VAR word: Sys.INT32; count: Sys.INT32;
BEGIN count := Sys.Short(n MOD Bits);
  IF WordSize = 4 THEN word := Sys.Short(x);
    CASE operation OF
      0: word := SYSTEM.LSH(word, count) |
      1: word := Sys.Short(ASH(word, -count)) |
      2: word := SYSTEM.ROT(word, -count) |
      14: word := SYSTEM.LSH(word, -count)
    END; RETURN word
  ELSE
    CASE operation OF
      0: x := SYSTEM.LSH(x, count) |
      1: x := ASH(x, -count) |
      2: x := SYSTEM.ROT(x, -count) |
      14: x := SYSTEM.LSH(x, -count)
    END; RETURN x
  END
END Shift;
PROCEDURE AddOverflow*(a, b: Int): BOOLEAN;
BEGIN RETURN (b > 0) & (a > Max()-b) OR (b < 0) & (a < Min()-b)
END AddOverflow;
PROCEDURE SubOverflow*(a, b: Int): BOOLEAN;
BEGIN RETURN (b > 0) & (a < Min()+b) OR (b < 0) & (a > Max()+b)
END SubOverflow;
PROCEDURE Add*(a, b: Int): Int;
BEGIN
  IF (b > 0) & (a > Max()-b) THEN RETURN (a-Max())+(b-1)+Min()
  ELSIF (b < 0) & (a < Min()-b) THEN RETURN (a-Min())+(b+1)+Max()
  ELSE RETURN a+b END
END Add;
PROCEDURE Neg*(x: Int): Int;
BEGIN IF x = Min() THEN RETURN x ELSE RETURN -x END END Neg;
PROCEDURE Sub*(a, b: Int): Int;
BEGIN RETURN Add(a, Neg(b)) END Sub;
PROCEDURE Mul*(a, b: Int): Int;
VAR result: Int;
BEGIN result := 0;
  WHILE b # 0 DO
    IF ODD(b) THEN result := Add(result, a) END;
    a := Shift(0, a, 1); b := Shift(14, b, 1)
  END;
RETURN result
END Mul;
PROCEDURE MulOverflow*(a, b: Int): BOOLEAN;
VAR negative: BOOLEAN;
BEGIN
  IF (a = 0) OR (b = 0) OR (a = 1) OR (b = 1) THEN RETURN FALSE END;
  IF (a = Min()) OR (b = Min()) THEN RETURN TRUE END;
  negative := (a < 0) # (b < 0); a := ABS(a); b := ABS(b);
  IF a <= Max() DIV b THEN RETURN FALSE END;
  RETURN ~(negative & (Min() MOD a = 0) & (Min() DIV a = -b))
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
VAR single: REAL; word: Sys.INT32; bits: Int;
BEGIN IF WordSize = 4 THEN
  single := SHORT(x); SYSTEM.MOVE(SYSTEM.ADR(single), SYSTEM.ADR(word), 4); bits := word
ELSE SYSTEM.MOVE(SYSTEM.ADR(x), SYSTEM.ADR(bits), WordSize) END;
RETURN bits
END RealBits;
PROCEDURE BitsReal*(bits: Int): Real;
VAR single: REAL; word: Sys.INT32; x: Real;
BEGIN IF WordSize = 4 THEN
  word := Sys.Short(bits); SYSTEM.MOVE(SYSTEM.ADR(word), SYSTEM.ADR(single), 4); x := single
ELSE SYSTEM.MOVE(SYSTEM.ADR(bits), SYSTEM.ADR(x), WordSize) END;
RETURN x
END BitsReal;
BEGIN Configure(0)
END OCGTarget.
