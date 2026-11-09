MODULE UART;
  IMPORT CType, Unix;

  VAR
    eof: BOOLEAN;

  PROCEDURE Receive*(): INTEGER;
    VAR ch: CHAR;
  BEGIN IF Unix.feof(Unix.stdin) # 0 THEN eof := TRUE; ch := 0X
    ELSE ch := CHR(Unix.fgetc(Unix.stdin))
    END;
    RETURN ORD(ch)
  END Receive;

  PROCEDURE Send*(x: INTEGER);
    VAR rc: CType.int;
  BEGIN rc := Unix.fputc(x, Unix.stdout)
  END Send;

  PROCEDURE Flush*;
    VAR rc: CType.int;
  BEGIN rc := Unix.fflush(Unix.stdout)
  END Flush;
  
BEGIN eof := FALSE
END UART.
(* vim:set ts=2 sw=2 et:*)
