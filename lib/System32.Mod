MODULE System;
  IMPORT SYSTEM, Files, In;

  TYPE
    Integer* = LONGINT;
    Address* = LONGINT;
    INT8* = SHORTINT;
    INT16* = INTEGER;
    INT32* = LONGINT;
    Byte* = INT16; (*[0,255]*)

  PROCEDURE Ash(x,y: LONGINT): Integer;
  BEGIN RETURN ASH(x,y)
  END Ash;

  PROCEDURE InInt(VAR x: Integer);
  BEGIN In.LongInt(x)
  END InInt;

  PROCEDURE AddrToInt*(x: Address): Integer;
  BEGIN RETURN x
  END AddrToInt;

  PROCEDURE Short*(x: LONGINT): Integer;
  BEGIN RETURN x;
  END Short;

  PROCEDURE ReadByte*(VAR R: Files.Rider; VAR x: Byte);
    VAR ch: CHAR;
  BEGIN Files.Read(R, ch); x := ORD(ch);
    IF x > 127 THEN x := x - 256 END
  END ReadByte;

  PROCEDURE WriteByte*(VAR R: Files.Rider; x: Byte);
    VAR ch: CHAR;
  BEGIN IF x < 0 THEN x := x + 256 END;
    ch := CHR(x); Files.Write(R, ch)
  END WriteByte;
    
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
