MODULE IO;
  IMPORT CType, Unix;

  CONST CR = 0DX; LF = 0AX;

  VAR eof: BOOLEAN;

  PROCEDURE Open*;
  BEGIN 
  END Open;

  PROCEDURE IsEof*(): BOOLEAN;
  BEGIN RETURN eof
  END IsEof;
  
  PROCEDURE Key*(): CHAR;
    VAR ch: CHAR;
  BEGIN IF Unix.feof(Unix.stdin) # 0 THEN eof := TRUE; ch := 0X
    ELSE ch := CHR(Unix.fgetc(Unix.stdin))
    END;
    RETURN ch
  END Key;

  PROCEDURE Emit*(x: CHAR);
    VAR rc: CType.int;
  BEGIN rc := Unix.fputc(ORD(x), Unix.stdout)
  END Emit;

  PROCEDURE Cr*;
  BEGIN Emit(CR); Emit(LF)
  END Cr;

  PROCEDURE Type*(s: ARRAY OF CHAR);
    VAR i: INTEGER;
        ch: CHAR;
  BEGIN ch := s[0]; i := 1;
    WHILE ch # 0X DO Emit(ch); ch := s[i]; INC(i) END
  END Type;

  PROCEDURE Print*(x, y, base: LONGINT);
    VAR s: ARRAY 64+1 OF CHAR;
        i, j, d: LONGINT;
        ch: CHAR;
        sign: BOOLEAN;
  BEGIN i := 0; sign := FALSE; IF x < 0 THEN sign := TRUE; x := -x END;
    REPEAT
      d := x MOD base; x := x DIV base;
      IF d > 9 THEN d := ORD("A")+d-10 ELSE d := ORD("0") + d END;
      s[i] := CHR(d); INC(i);
    UNTIL x = 0;
    IF sign THEN s[i] := "-"; INC(i) END;
    DEC(i); FOR j := 0 TO i DIV 2 DO
      ch := s[j]; s[j] := s[i-j]; s[i-j] := ch
    END; INC(i);
    WHILE i < y DO Emit(" "); INC(i) END;
    s[i] := 0X;
    Type(s); Emit(" ")
  END Print;

  PROCEDURE Flush*;
    VAR rc: CType.int;
  BEGIN rc := Unix.fflush(Unix.stdout)
  END Flush;
  
BEGIN eof := FALSE
END IO.
