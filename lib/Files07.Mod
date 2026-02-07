MODULE Files07;
  IMPORT SYSTEM, Files, Out, Sys := System;
  
  TYPE
    File* = Files.File;
    Rider* = Files.Rider;
    
  VAR o2c64*, doCompress*: BOOLEAN;

  PROCEDURE Base* (VAR R: Rider): File;
  BEGIN RETURN Files.Base(R)
  END Base;

  PROCEDURE Close* (VAR f: File);
  BEGIN Files.Close(f)
  END Close;

  PROCEDURE Length* (f: File): LONGINT;
  BEGIN RETURN Files.Length(f)
  END Length;

  PROCEDURE New* (name: ARRAY OF CHAR): File;
  BEGIN RETURN Files.New(name)
  END New;

  PROCEDURE Old* (name: ARRAY OF CHAR): File;
  BEGIN RETURN Files.Old(name)
  END Old;
  
  PROCEDURE Pos* (VAR R: Rider): LONGINT;
  BEGIN RETURN Files.Pos(R)
  END Pos;

  PROCEDURE Register* (f: File);
  BEGIN Files.Register(f)
  END Register;

  PROCEDURE Set* (VAR r: Rider; f: File; pos: LONGINT);
  BEGIN Files.Set(r, f, pos)
  END Set;

  PROCEDURE Read* (VAR R: Rider; VAR x: CHAR);
  BEGIN Files.Read(R, x)
  END Read;

  PROCEDURE ReadByte* (VAR R: Rider; VAR x: Sys.Integer);
    VAR ch: CHAR;
  BEGIN Files.Read(R, ch); x := ORD(ch);
    IF x > 127 THEN x := x - 256 END
  END ReadByte;

  PROCEDURE ReadBytes* (VAR R: Rider; VAR x: ARRAY OF SYSTEM.BYTE; n: LONGINT);
  BEGIN Files.ReadBytes(R, x, n)
  END ReadBytes;

  PROCEDURE ReadInt* (VAR R: Rider; VAR x: Sys.Integer);
    VAR i: INTEGER;
  BEGIN Sys.ReadInt(R, x);
  END ReadInt;

  PROCEDURE ReadLInt* (VAR R: Rider; VAR x: LONGINT);
  BEGIN Files.ReadLInt(R, x)
  END ReadLInt;

  PROCEDURE ReadNum* (VAR R: Rider; VAR x: Sys.Integer);
  BEGIN IF doCompress THEN Sys.ReadNum(R, x) ELSE ReadInt(R, x) END
  END ReadNum;

  PROCEDURE ReadString* (VAR R: Rider; VAR x: ARRAY OF CHAR);
  BEGIN Files.ReadString(R, x)
  END ReadString;

  PROCEDURE WriteByte* (VAR R: Rider; x: Sys.Integer);
    VAR ch: CHAR;
  BEGIN IF x < 0 THEN x := x + 256 END;
    ch := CHR(x); Files.Write(R, ch)
  END WriteByte;
  
  PROCEDURE WriteBytes* (VAR R: Rider; VAR x: ARRAY OF SYSTEM.BYTE; n: LONGINT);
  BEGIN Files.WriteBytes(R, x, n)
  END WriteBytes;

  PROCEDURE Write* (VAR R: Rider; x: CHAR);
  BEGIN Files.Write(R, x)
  END Write;

  PROCEDURE WriteInt* (VAR R: Rider; x: Sys.Integer);
  BEGIN Sys.WriteInt(R, x)
  END WriteInt;

  PROCEDURE WriteLInt* (VAR R: Rider; x: LONGINT);
  BEGIN Files.WriteLInt(R, x)
  END WriteLInt;

  PROCEDURE WriteNum* (VAR R: Rider; x: Sys.Integer);
  BEGIN IF doCompress THEN Files.WriteNum(R, x) ELSE WriteInt(R, x) END
  END WriteNum;

  PROCEDURE WriteString* (VAR R: Rider; x: ARRAY OF CHAR);
  BEGIN Files.WriteString(R, x)
  END WriteString;

BEGIN o2c64 := 8 = SIZE(LONGINT); doCompress := TRUE;
END Files07.

(* vim:set ts=2 sw=2 et: *)
