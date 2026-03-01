MODULE SerIO;
  IMPORT CType, Unix;

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

  PROCEDURE Flush*;
    VAR rc: CType.int;
  BEGIN rc := Unix.fflush(Unix.stdout)
  END Flush;
  
BEGIN eof := FALSE
END SerIO.
