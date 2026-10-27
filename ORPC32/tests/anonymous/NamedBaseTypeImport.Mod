MODULE NamedBaseTypeImport;
  IMPORT NamedBaseType, SYSTEM;

  TYPE
    P0 = POINTER TO R0 ;
    R0 = RECORD END ;
  VAR
    FD: NamedBaseType.FontDesc;
    s: ARRAY 32 OF CHAR;

  PROCEDURE CLEARX(ptr: LONGINT; size: INTEGER);
    VAR limit: LONGINT;
        b: BYTE;
  BEGIN limit := ptr + size; b := 0;
    REPEAT
      SYSTEM.PUT(ptr, b); INC(ptr)
    UNTIL ptr = limit;
  END CLEARX;

  PROCEDURE ClearByte(VAR x: BYTE);
  BEGIN CLEAR(x)
  END ClearByte;

  PROCEDURE ClearBoolean(VAR x: BOOLEAN);
  BEGIN CLEAR(x)
  END ClearBoolean;

  PROCEDURE ClearChar(VAR x: CHAR);
  BEGIN CLEAR(x)
  END ClearChar;

  PROCEDURE ClearPointer(VAR x: P0);
  BEGIN CLEAR(x)
  END ClearPointer;

  PROCEDURE ClearPointerVar(x: P0);
  BEGIN CLEAR(x)
  END ClearPointerVar;

  PROCEDURE ClearS;
  BEGIN CLEAR(s)
  END ClearS;

BEGIN CLEAR(FD.name);
  FD.name := "CourierNew";
  s := FD.name;
  NamedBaseType.AssignDsc(1, 2, NamedBaseType.dsc)
END NamedBaseTypeImport.
(* vim:set ts=2 sw=2 et syn=off:*)
