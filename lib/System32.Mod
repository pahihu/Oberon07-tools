MODULE System;
  IMPORT SYSTEM, Files;

  TYPE
    Integer* = LONGINT;
    Address* = LONGINT;
    INT8* = SHORTINT;
    INT16* = INTEGER;
    INT32* = LONGINT;
    Byte* = INT16; (*[0,255]*)

  PROCEDURE AddrToInt*(x: Address): Integer;
  BEGIN RETURN x
  END AddrToInt;

  PROCEDURE Short*(x: LONGINT): Integer;
  BEGIN RETURN x;
  END Short;

  PROCEDURE ReadInt*(VAR R: Files.Rider; VAR x: Integer);
  BEGIN Files.ReadLInt(R, x)
  END ReadInt;

  PROCEDURE ReadNum*(VAR R: Files.Rider; VAR x: Integer);
    VAR y: LONGINT;
  BEGIN Files.ReadNum(R, y); x := Short(y)
  END ReadNum;

  PROCEDURE WriteInt*(VAR R: Files.Rider; x: Integer);
  BEGIN Files.WriteLInt(R, x)
  END WriteInt;

  PROCEDURE BinOr*(x, y: LONGINT): Integer;
  BEGIN RETURN x + y
  END BinOr;

END System.
