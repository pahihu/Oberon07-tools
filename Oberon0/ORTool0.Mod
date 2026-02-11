MODULE ORTool0;  (*NW 18.2.2013*)
  IMPORT Files := Files07, Texts, Oberon, Args, Sys := System;
  TYPE
    LONGINT = Sys.INT32;
    INTEGER = Sys.INT32;

  VAR W: Texts.Writer;
    Form: INTEGER;  (*result of ReadType*)
    mnemo0, mnemo1: ARRAY 16, 4 OF CHAR;  (*mnemonics*)
    cmd: ARRAY 32 OF CHAR;

  PROCEDURE Read(VAR R: Files.Rider; VAR n: INTEGER);
    VAR b: Sys.Byte;
  BEGIN Files.ReadByte(R, b); n := b
  END Read;
  
(* ---------------------------------------------------*)

  PROCEDURE WriteReg(r: LONGINT);
  BEGIN Texts.Write(W, " ");
    IF r < 12 THEN 
      IF r < 10 THEN Texts.Write(W, " ") END;
      Texts.WriteString(W, "R"); Texts.WriteInt(W, r MOD 10H, 1);
    ELSIF r = 12 THEN Texts.WriteString(W, " MT")
    ELSIF r = 13 THEN Texts.WriteString(W, " SB")
    ELSIF r = 14 THEN Texts.WriteString(W, " SP")
    ELSE Texts.WriteString(W, "LNK")
    END
  END WriteReg;

  PROCEDURE opcode(w: LONGINT);
    VAR k, op, u, a, b, c: LONGINT;
  BEGIN
      k := w DIV 40000000H MOD 4;
      a := w DIV 1000000H MOD 10H;
      b := w DIV 100000H MOD 10H;
      op := w DIV 10000H MOD 10H;
      u := w DIV 20000000H MOD 2;
      IF k = 0 THEN
        Texts.WriteString(W, mnemo0[op]);
        IF u = 1 THEN Texts.Write(W, "'") END ;
        WriteReg(a); WriteReg(b); WriteReg(w MOD 10H)
      ELSIF k = 1 THEN
        Texts.WriteString(W, mnemo0[op]);
        IF u = 1 THEN Texts.Write(W, "'") END ;
        WriteReg(a); WriteReg(b); w := w MOD 10000H;
        IF w >= 8000H THEN w := w - 10000H END ;
        Texts.WriteInt(W, w, 8)
      ELSIF k = 2 THEN  (*LDR/STR*)
        IF u = 1 THEN Texts.WriteString(W, "STR") ELSE Texts.WriteString(W, "LDR") END ;
        WriteReg(a); WriteReg(b); w := w MOD 100000H;
        IF w >= 80000H THEN w := w - 100000H END ;
        Texts.WriteInt(W, w, 8)
      ELSIF k = 3 THEN  (*Branch instr*)
        Texts.Write(W, "B");
        IF ODD(w DIV 10000000H) THEN Texts.WriteString(W, "L  ") ELSE Texts.WriteString(W, "   ") END ;
        Texts.WriteString(W, mnemo1[a]);
        IF u = 0 THEN WriteReg(w MOD 10H) ELSE
          w := w MOD 100000H;
          IF w >= 80000H THEN w := w - 100000H END ;
          Texts.WriteInt(W, w, 8)
        END
      END
  END opcode;

  PROCEDURE Sync(VAR R: Files.Rider);
    VAR ch: CHAR;
  BEGIN Files.Read(R, ch); Texts.WriteString(W, "Sync "); Texts.Write(W, ch); Texts.WriteLn(W)
  END Sync;
  
  PROCEDURE Write(VAR R: Files.Rider; x: INTEGER);
    VAR b: Sys.Byte;
  BEGIN b := SHORT(x); Files.WriteByte(R, b)  (* -128 <= x < 128 *)
  END Write;

  PROCEDURE DecObj*;  (*decode object file*)
    VAR class, i, n, key, size, fix, adr, data, len: INTEGER;
      ch: CHAR;
      name: ARRAY 32 OF CHAR;
      F: Files.File; R: Files.Rider;
      s: ARRAY 32 OF CHAR;
  BEGIN
    IF Args.argc > 1 THEN Args.GetArg(2, s);
    Texts.WriteString(W, "decode "); Texts.WriteString(W, s); F := Files.Old(s);
    IF F # NIL THEN
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
      Files.ReadInt(R, n); i := 0;
      WHILE i < n DO
        Files.ReadInt(R, data); Texts.WriteInt(W, i, 4); Texts.Write(W, 9X); Texts.WriteHex(W, data);
        Texts.Write(W, 9X); opcode(data); Texts.WriteLn(W); INC(i)
      END ;
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
      Files.ReadInt(R, data); Texts.WriteString(W, "fixP  = "); Texts.WriteInt(W, data, 8); Texts.WriteLn(W);
      Files.ReadInt(R, data); Texts.WriteString(W, "fixD  = "); Texts.WriteInt(W, data, 8); Texts.WriteLn(W);
      Files.ReadInt(R, data); Texts.WriteString(W, "fixT  = "); Texts.WriteInt(W, data, 8); Texts.WriteLn(W);
      Files.ReadInt(R, data); Texts.WriteString(W, "entry = "); Texts.WriteInt(W, data, 8); Texts.WriteLn(W);
      Files.Read(R, ch);
      IF ch # "O" THEN Texts.WriteString(W, "format eror"); Texts.WriteLn(W) END
    (* Sync(R); *)
    ELSE Texts.WriteString(W, " not found"); Texts.WriteLn(W)
    END ;
    Texts.Append(Oberon.Log, W.buf)
    END
  END DecObj;

BEGIN Texts.OpenWriter(W); Texts.WriteString(W, "ORTool 18.2.2013");
  Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf);
  mnemo0[0] := "MOV";
  mnemo0[1] := "LSL";
  mnemo0[2] := "ASR";
  mnemo0[3] := "ROR";
  mnemo0[4] := "AND";
  mnemo0[5] := "ANN";
  mnemo0[6] := "IOR";
  mnemo0[7] := "XOR";
  mnemo0[8] := "ADD";
  mnemo0[9] := "SUB";
  mnemo0[10] := "MUL";
  mnemo0[11] := "DIV";
  mnemo0[12] := "FAD";
  mnemo0[13] := "FSB";
  mnemo0[14] := "FML";
  mnemo0[15] := "FDV";
  mnemo1[0] := " MI";
  mnemo1[8] := " PL";
  mnemo1[1] := " EQ";
  mnemo1[9] := " NE";
  mnemo1[2] := " LS";
  mnemo1[10] := " HI";
  mnemo1[5] := " LT";
  mnemo1[13] := " GE";
  mnemo1[6] := " LE";
  mnemo1[14] := " GT";
  mnemo1[15] := " NO";
  
  mnemo1[3] := "   ";
  mnemo1[4] := "   ";
  mnemo1[7] := "   ";
  mnemo1[11] := "   ";
  mnemo1[12] := "   ";

  IF Args.argc = 0 THEN
    Texts.WriteString(W, "usage: ORTool0 DecObj <filename>");
    Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
  ELSE
    Args.GetArg(1, cmd);
    IF cmd = "DecObj" THEN DecObj END
  END
END ORTool0.

(* vim:set ts=2 sw=2 et: *)
