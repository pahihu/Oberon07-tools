MODULE System;
  IMPORT SYSTEM, Files, In;

  TYPE
    INT8* = SHORTINT;
    INT16* = INTEGER;
    INT32* = LONGINT;
    Integer* = INTEGER; (*compiler natives*)
    LongInt* = LONGINT;
    Address* = INT32;
    Byte* = INT16; (*[0,255]*)

  PROCEDURE Ash*(x,y: LONGINT): INT32;
  BEGIN RETURN ASH(x,y)
  END Ash;

  PROCEDURE InInt*(VAR x: INT32);
  BEGIN In.LongInt(x)
  END InInt;

  PROCEDURE AddrToInt*(x: Address): INT32;
  BEGIN RETURN x
  END AddrToInt;

  PROCEDURE Short*(x: LONGINT): INT32;
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
    
  PROCEDURE ReadInt*(VAR R: Files.Rider; VAR x: INT32);
  BEGIN Files.ReadLInt(R, x)
  END ReadInt;

  PROCEDURE ReadNum*(VAR R: Files.Rider; VAR x: INT32);
    VAR y: LONGINT;
  BEGIN Files.ReadNum(R, y); x := Short(y)
  END ReadNum;

  PROCEDURE WriteInt*(VAR R: Files.Rider; x: INT32);
  BEGIN Files.WriteLInt(R, x)
  END WriteInt;

  PROCEDURE BinOr*(x, y: LONGINT): INT32;
  BEGIN RETURN x + y
  END BinOr;

END System.
