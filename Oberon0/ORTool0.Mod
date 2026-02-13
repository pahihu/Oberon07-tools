MODULE ORTool0;  (*NW 18.2.2013*)
  IMPORT Files := Files07, Texts, Oberon, Sys := System, Disasm, RISC;

  CONST MaxCode = 8192;

  TYPE
    LONGINT = Sys.INT32;
    INTEGER = Sys.INT32;

  VAR W: Texts.Writer;
    Form: INTEGER;  (*result of ReadType*)
    cmd: ARRAY 32 OF CHAR;
    code: ARRAY MaxCode OF LONGINT;
    entry, fixlist, fixorgD: LONGINT;
    doExecute: BOOLEAN;
    ncode: INTEGER;

  PROCEDURE Read(VAR R: Files.Rider; VAR n: INTEGER);
    VAR b: Sys.Byte;
  BEGIN Files.ReadByte(R, b); n := b
  END Read;
  
(* ---------------------------------------------------*)

  PROCEDURE Sync(VAR R: Files.Rider);
    VAR ch: CHAR;
  BEGIN Files.Read(R, ch); Texts.WriteString(W, "Sync "); Texts.Write(W, ch); Texts.WriteLn(W)
  END Sync;
  
  PROCEDURE Write(VAR R: Files.Rider; x: INTEGER);
    VAR b: Sys.Byte;
  BEGIN b := SHORT(x); Files.WriteByte(R, b)  (* -128 <= x < 128 *)
  END Write;

  PROCEDURE Option(VAR S: Texts.Scanner);
  BEGIN doExecute := FALSE;
    IF S.nextCh = "/" THEN
      Texts.Scan(S); Texts.Scan(S); 
      IF (S.class = Texts.Name) & (S.s[0] = "d") THEN doExecute := TRUE END
    END
  END Option;
  
  PROCEDURE DecObj*;  (*decode object file*)
    VAR class, i, n, key, size, fix, adr, data, len: INTEGER;
      ch: CHAR;
      name: ARRAY 32 OF CHAR;
      F: Files.File; R: Files.Rider;
      S: Texts.Scanner;
  BEGIN Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
    IF S.class = Texts.Name THEN
      Texts.WriteString(W, "decode "); Texts.WriteString(W, S.s); F := Files.Old(S.s);
      IF F # NIL THEN Option(S);
        Files.Set(R, F, 0); Files.ReadString(R, name); Texts.WriteLn(W); Texts.WriteString(W, name);
        Files.ReadInt(R, key); Texts.WriteHex(W, key); Read(R, class); Texts.WriteInt(W, class, 4); (*version*)
        Files.ReadInt(R, size); Texts.WriteInt(W, size, 6); Texts.WriteLn(W);
        Texts.WriteString(W, "imports:"); Texts.WriteLn(W); Files.ReadString(R, name);
        WHILE name[0] # 0X DO
          Texts.Write(W, 9X); Texts.WriteString(W, name);
          Files.ReadInt(R, key); Texts.WriteHex(W, key); Texts.WriteLn(W);
          Files.ReadString(R, name)
        END ;
      (* Sync(R); *)
        Texts.WriteString(W, "type descriptors"); Texts.WriteLn(W);
        Files.ReadInt(R, n); n := n DIV 4; i := 0;
        WHILE i < n DO Files.ReadInt(R, data); Texts.WriteHex(W, data); INC(i) END ;
        Texts.WriteLn(W);
        Texts.WriteString(W, "data"); Files.ReadInt(R, data); Texts.WriteInt(W, data, 6); Texts.WriteLn(W);
        Texts.WriteString(W, "strings"); Texts.WriteLn(W);
        Files.ReadInt(R, n); i := 0;
        WHILE i < n DO Files.Read(R, ch); Texts.Write(W, ch); INC(i) END ;
        Texts.WriteLn(W);
        Texts.WriteString(W, "code"); Texts.WriteLn(W);
        Files.ReadInt(R, ncode); i := 0;
        WHILE i < ncode DO
          Files.ReadInt(R, data); Texts.WriteInt(W, i, 4); Texts.Write(W, 9X); Texts.WriteHex(W, data);
          IF i < MaxCode THEN code[i] := data END;
          Texts.Write(W, 9X); Disasm.Opcode(W, data); Texts.WriteLn(W); INC(i)
        END ;
        IF ncode > MaxCode THEN Texts.WriteString(W, " code length > 8192 "); Texts.WriteLn(W) END;
      (* Sync(R); *)
        Texts.WriteString(W, "commands:"); Texts.WriteLn(W);
        Files.ReadString(R, name);
        WHILE name[0] # 0X DO
          Texts.Write(W, 9X); Texts.WriteString(W, name);
          Files.ReadInt(R, adr); Texts.WriteInt(W, adr, 5); Texts.WriteLn(W);
          Files.ReadString(R, name)
        END ;
      (* Sync(R); *)
        Texts.WriteString(W, "entries"); Texts.WriteLn(W);
        Files.ReadInt(R, n); i := 0;
        WHILE i < n DO
          Files.ReadInt(R, adr); Texts.WriteInt(W, adr, 6); INC(i)
        END ;
        Texts.WriteLn(W);
      (* Sync(R); *)
        Texts.WriteString(W, "pointer refs"); Texts.WriteLn(W); Files.ReadInt(R, adr);
        WHILE adr # -1 DO Texts.WriteInt(W, adr, 6); Files.ReadInt(R, adr) END ;
        Texts.WriteLn(W);
      (* Sync(R); *)
        Files.ReadInt(R, data); Texts.WriteString(W, "fixP  = "); Texts.WriteInt(W, data, 8); Texts.WriteLn(W); fixlist := data;
        Files.ReadInt(R, data); Texts.WriteString(W, "fixD  = "); Texts.WriteInt(W, data, 8); Texts.WriteLn(W); fixorgD := data;
        Files.ReadInt(R, data); Texts.WriteString(W, "fixT  = "); Texts.WriteInt(W, data, 8); Texts.WriteLn(W);
        Files.ReadInt(R, data); Texts.WriteString(W, "entry = "); Texts.WriteInt(W, data, 8); Texts.WriteLn(W); entry := data;
        Files.Read(R, ch);
        IF ch # "O" THEN Texts.WriteString(W, "format eror"); Texts.WriteLn(W) END
      (* Sync(R); *)
      ELSE Texts.WriteString(W, " not found"); Texts.WriteLn(W)
      END ;
      Texts.Append(Oberon.Log, W.buf)
    END;
    IF doExecute THEN RISC.Execute(code, entry DIV 4, S, W) END
  END DecObj;

  PROCEDURE Help*;
  BEGIN Texts.WriteString(W, "usage: ORTool0 DecObj <filename> [/x]");
    Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
  END Help;

BEGIN Texts.OpenWriter(W); Texts.WriteString(W, "ORTool 18.2.2013");
  Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf);

  Oberon.Run
END ORTool0.

(* vim:set ts=2 sw=2 et: *)
