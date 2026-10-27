MODULE Basic;
CONST N = 4;
TYPE A* = ARRAY N OF INTEGER;
VAR count*: INTEGER; hidden: INTEGER; data*: A;
PROCEDURE Twice*(x: INTEGER): INTEGER;
RETURN x*2
END Twice;
PROCEDURE Bump*(VAR x: INTEGER);
BEGIN INC(x)
END Bump;
PROCEDURE Sum*(a: ARRAY OF INTEGER): INTEGER;
VAR i, s: INTEGER;
BEGIN s := 0;
  FOR i := 0 TO LEN(a)-1 DO s := s+a[i] END
RETURN s
END Sum;
PROCEDURE Run*;
VAR i: INTEGER;
BEGIN count := 0; hidden := 17;
  FOR i := 0 TO N-1 DO data[i] := Twice(i) END;
  count := Sum(data); Bump(count);
  IF count = 13 THEN count := count+1 ELSIF count=14 THEN count := 0 ELSE count := -1 END;
  WHILE count < 17 DO INC(count) END;
  REPEAT DEC(count) UNTIL count = 15;
  CASE count OF 0: count := 99 | 14..16: count := 20 ELSE count := 100 END
END Run;
BEGIN count := 1
END Basic.
