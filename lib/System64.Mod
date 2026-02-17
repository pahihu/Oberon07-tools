MODULE System;
  IMPORT SYSTEM, Files, In;

  TYPE
    INT16* = SHORTINT;
    INT32* = INTEGER;
    INT64* = LONGINT;
    Integer* = INT32;
    Address* = INT64;
    Byte* = INT16; (*[0,255]*)

  PROCEDURE Ash*(x,y: LONGINT): Integer;
  BEGIN RETURN SHORT(ASH(x,y))
  END Ash;

  PROCEDURE InInt*(VAR x: Integer);
  BEGIN In.Int(x);
  END InInt;

  PROCEDURE AddrToInt*(x: Address): Integer;
  BEGIN RETURN SHORT(x)
  END AddrToInt;

  PROCEDURE Short*(x: LONGINT): Integer;
  BEGIN RETURN SHORT(x);
  END Short;

  PROCEDURE ReadByte*(VAR R: Files.Rider; VAR x: Byte);
    VAR ch: CHAR;
  BEGIN Files.Read(R, ch); x := SHORT(ORD(ch));
    IF x > 127 THEN x := x - 256 END
  END ReadByte;

  PROCEDURE WriteByte*(VAR R: Files.Rider; x: Byte);
    VAR ch: CHAR;
  BEGIN IF x < 0 THEN x := x + 256 END;
    ch := CHR(x); Files.Write(R, ch)
  END WriteByte;
    
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
