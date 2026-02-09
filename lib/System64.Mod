MODULE System;
  IMPORT SYSTEM, Files;

  TYPE
    Integer* = INTEGER;
    Address* = LONGINT;
    INT16* = SHORTINT;
    INT32* = INTEGER;
    INT64* = LONGINT;
    Byte* = INT16; (*[0,255]*)

  PROCEDURE AddrToInt*(x: Address): Integer;
  BEGIN RETURN SHORT(x)
  END AddrToInt;

  PROCEDURE Short*(x: LONGINT): Integer;
  BEGIN RETURN SHORT(x);
  END Short;
    
  PROCEDURE ReadInt*(VAR R: Files.Rider; VAR x: Integer);
  BEGIN Files.ReadInt(R, x)
  END ReadInt;

  PROCEDURE ReadNum*(VAR R: Files.Rider; VAR x: Integer);
    VAR y: LONGINT;
  BEGIN Files.ReadNum(R, y); x := Short(y)
  END ReadNum;

  PROCEDURE WriteInt*(VAR R: Files.Rider; x: Integer);
  BEGIN Files.WriteInt(R, x)
  END WriteInt;

  PROCEDURE BinOr*(x, y: LONGINT): Integer;
  BEGIN RETURN Short(x + y)
  END BinOr;

END System.

(* vim:set ts=2 sw=2 et: *)
