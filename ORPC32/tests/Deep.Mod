MODULE Deep;
IMPORT SYSTEM;
CONST min = 80000000H; hi = LSL(1, 31); f = FLT(3);
TYPE T* = RECORD c*: CHAR; hidden: ARRAY 3 OF INTEGER; d*: REAL END;
  P* = POINTER TO T;
VAR answer*: INTEGER; a*: ARRAY 2 OF T;
PROCEDURE Fact*(n: INTEGER): INTEGER;
VAR result: INTEGER;
BEGIN IF n = 0 THEN result := 1 ELSE result := n*Fact(n-1) END
RETURN result
END Fact;
PROCEDURE Local1(): INTEGER;
TYPE T = RECORD n: INTEGER END;
VAR r: T;
BEGIN r.n := 3
RETURN r.n
END Local1;
PROCEDURE Local2(): INTEGER;
TYPE T = RECORD x: REAL END;
VAR r: T;
BEGIN r.x := 4.0
RETURN FLOOR(r.x)
END Local2;
PROCEDURE CopyOpen(src: ARRAY OF INTEGER): INTEGER;
VAR dst: ARRAY 2 OF INTEGER;
BEGIN dst := src
RETURN dst[0]+dst[1]
END CopyOpen;
PROCEDURE ReverseBits(n: INTEGER): INTEGER;
VAR table: ARRAY 17 OF CHAR; i, ret: INTEGER;
BEGIN table := $0008040C020A060E0109050D030B070F$;
  ret := 0;
  FOR i := 0 TO 7 DO
    ret := ret*10H + ORD(table[n MOD 10H]); n := n DIV 10H
  END
RETURN ret
END ReverseBits;
PROCEDURE Run*;
VAR n, i: INTEGER; data: ARRAY 2 OF INTEGER; s: ARRAY 4 OF CHAR;
    bytes: ARRAY 4 OF CHAR; exact: ARRAY 3 OF CHAR;
BEGIN n := -7; ASSERT(n DIV 3 = -3); ASSERT(n MOD 3 = 2);
  ASSERT(min = hi); ASSERT(SYSTEM.VAL(INTEGER, f) = 40400000H);
  ASSERT(SYSTEM.VAL(REAL, 40400000H) = 3.0);
  s := $61
    626300$; ASSERT(s = "abc");
  bytes := "xyz";
  bytes := $00080C$;
  ASSERT((bytes[0] = 0X) & (bytes[1] = 08X) & (bytes[2] = 0CX));
  bytes[3] := 7FX;
  bytes := $410042$;
  ASSERT((bytes[0] = "A") & (bytes[1] = 0X) & (bytes[2] = "B") & (bytes[3] = 7FX));
  exact := $FF0080$;
  ASSERT((ORD(exact[0]) = 255) & (exact[1] = 0X) & (ORD(exact[2]) = 128));
  ASSERT(ReverseBits(12345678H) = 1E6A2C48H);
  data[0] := 5; data[1] := 6;
  answer := CopyOpen(data)+Fact(5)+Local1()+Local2();
  i := 3;
  WHILE i = 3 DO i := 2 ELSIF i = 2 DO i := 1 END;
  FOR i := 4 TO 0 BY -2 DO INC(answer, i) END;
  CASE answer OF 144: INC(answer) | 145: DEC(answer) END;
  answer := answer + SYSTEM.SIZE(T)
END Run;
END Deep.
