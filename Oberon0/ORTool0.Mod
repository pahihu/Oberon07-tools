MODULE ORTool0;  (*NW 18.2.2013*)
  IMPORT Files := Files07, Texts, Oberon, Sys := System, Disasm, RISC;

  CONST TAB = 9X;
    MaxCode = 8192;
    MaxModules = 8;
    MaxExports = 64;
    MaxImports = 16;

  TYPE
    LONGINT = Sys.INT32;
    INTEGER = Sys.INT32;

    Module = RECORD
      name: ARRAY 32 OF CHAR;
      key, base, ndata: INTEGER;
      nexports: INTEGER;
      expoffs: INTEGER; (*idx.into exports[]*)
    END;

    Import = RECORD
      name: ARRAY 32 OF CHAR;
      key: INTEGER;
    END;

  VAR W: Texts.Writer;
    Form: INTEGER;  (*result of ReadType*)
    code: ARRAY MaxCode OF LONGINT;
    ncode: INTEGER;
    doExecute: BOOLEAN;
    mods: ARRAY MaxModules OF Module;
    nmods: LONGINT;
    exports: ARRAY MaxExports OF LONGINT; (*addr. of exported procs*)
    nexports: LONGINT;

  PROCEDURE Read(VAR R: Files.Rider; VAR n: INTEGER);
    VAR b: Sys.Byte;
  BEGIN Files.ReadByte(R, b); n := b
  END Read;
  
  (* ---------------------------------------------------*)
  PROCEDURE Ln;
  BEGIN Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
  END Ln;

  PROCEDURE FixGlobals(modbase: INTEGER; L, globalFrame: LONGINT);
    VAR L1: LONGINT;
  BEGIN Texts.WriteString(W, " fixing globals "); Ln;
    L := L + modbase;
    WHILE (L - modbase) # 0 DO
      Texts.WriteInt(W, L, 4); Texts.Write(W, TAB); Texts.WriteHex(W, code[L]); Ln;
      L1 := code[L] MOD 10000H;
      code[L] := (code[L] DIV 10000H) * 10000H + globalFrame;
      L := L - L1;
    END
  END FixGlobals;

  PROCEDURE FindMod(VAR imp: Import): INTEGER;
    VAR i: INTEGER;
  BEGIN i := 0;
    WHILE (i < nmods) & (imp.name # mods[i].name) DO INC(i) END;
    RETURN i
  END FindMod;

  PROCEDURE FixImports(modbase: INTEGER; L: LONGINT; nimps: INTEGER; imps: ARRAY OF Import);
    VAR L1: LONGINT;
        mno, eno: LONGINT;
        adr, disp: LONGINT;
  BEGIN Texts.WriteString(W, " fixing imports "); Ln;
    L := L + modbase;
    WHILE (L - modbase) # 0 DO
      Texts.WriteInt(W, L, 4); Texts.Write(W, TAB); Texts.WriteHex(W, code[L]); Ln;
      L1 := code[L] MOD 1000H; (*F7106001*)
      mno := (code[L] DIV 1000H) MOD 1000H;
      eno := mno MOD 100H; mno := (mno DIV 100H) MOD 10H;
      ASSERT(0 < mno, 10); ASSERT(0 < eno, 20);
      Texts.WriteString(W, " fix import "); Texts.WriteInt(W, mno, 0);
      Texts.Write(W, ":"); Texts.WriteInt(W, eno, 0); Texts.Write(W, " ");
      DEC(mno);
      IF mno < nimps THEN
        Texts.WriteString(W, imps[mno].name);
        mno := FindMod(imps[mno]);
        IF mno = nmods THEN Texts.WriteString(W, " not found ");
        ELSE
          IF eno < mods[mno].nexports THEN
            adr := exports[mods[mno].expoffs + eno];
            disp := ((L+1)*4 - adr + 1000000H) MOD 1000000H;
            code[L] := (code[L] DIV 1000000H) * 1000000H + disp;
          ELSE Texts.WriteString(W, " invalid eno ");
          END
        END
      ELSE Texts.WriteString(W, " invalid mno ");
      END;
      Ln;
      L := L - L1;
    END
  END FixImports;

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
      IF (S.class = Texts.Name) & (S.s[0] = "x") THEN doExecute := TRUE END
    END
  END Option;
  
  PROCEDURE DecObj*;  (*decode object file*)
    VAR class, i, n, key, size, fix, adr, data, len: INTEGER;
      ch: CHAR;
      name: ARRAY 32 OF CHAR;
      entry, fixlist, fixorgD: LONGINT;
      ndata, modbase: INTEGER;
      imps: ARRAY MaxImports OF Import;
      nimps: INTEGER;
      F: Files.File; R: Files.Rider;
      S: Texts.Scanner;
  BEGIN ndata := 0; nimps := 0;
    Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
    WHILE (S.class = Texts.Name) & (nmods < MaxModules) DO
      Texts.WriteString(W, "decode "); Texts.WriteString(W, S.s); F := Files.Old(S.s);
      IF F # NIL THEN Option(S);
        Files.Set(R, F, 0); Files.ReadString(R, name); Texts.WriteLn(W); Texts.WriteString(W, name);
        ncode := ncode + (ndata + 3) DIV 4; (*add global data*)
        COPY(name, mods[nmods].name);
        Files.ReadInt(R, key); Texts.WriteHex(W, key); Read(R, class); Texts.WriteInt(W, class, 4); (*version*)
        mods[nmods].key := key;
        Files.ReadInt(R, size); Texts.WriteInt(W, size, 6); Texts.WriteLn(W);
        Texts.WriteString(W, "imports:"); Texts.WriteLn(W); Files.ReadString(R, name);
        nimps := 0;
        WHILE name[0] # 0X DO
          (*XXX load imported modules here*)
          Texts.Write(W, TAB); Texts.WriteString(W, name);
          Files.ReadInt(R, key); Texts.WriteHex(W, key); Texts.WriteLn(W);
          IF nimps < MaxImports THEN
            COPY(name, imps[nimps].name);
            imps[nimps].key := key; INC(nimps)
          ELSE Texts.WriteString(W, " more than 16 imports "); Texts.WriteLn(W)
          END;
          Files.ReadString(R, name)
        END ;
      (* Sync(R); *)
        Texts.WriteString(W, "type descriptors"); Texts.WriteLn(W);
        Files.ReadInt(R, n); n := n DIV 4; i := 0;
        WHILE i < n DO Files.ReadInt(R, data); Texts.WriteHex(W, data); INC(i) END ;
        Texts.WriteLn(W);
        Texts.WriteString(W, "data"); Files.ReadInt(R, ndata); Texts.WriteInt(W, ndata, 6); Texts.WriteLn(W);
        mods[nmods].ndata := ndata;
        Texts.WriteString(W, "strings"); Texts.WriteLn(W);
        Files.ReadInt(R, n); i := 0;
        WHILE i < n DO Files.Read(R, ch); Texts.Write(W, ch); INC(i) END ;
        Texts.WriteLn(W);
        Texts.WriteString(W, "code"); Texts.WriteLn(W);
        modbase := ncode; mods[nmods].base := modbase;
        Files.ReadInt(R, n); i := 0;
        WHILE i < n DO
          Files.ReadInt(R, data); Texts.WriteInt(W, modbase + i, 4); Texts.Write(W, TAB); Texts.WriteHex(W, data);
          IF ncode < MaxCode THEN code[ncode] := data; INC(ncode)
          ELSE doExecute := FALSE; Texts.WriteString(W, " code space full "); Texts.WriteLn(W)
          END;
          Texts.Write(W, TAB); Disasm.Opcode(W, data); Texts.WriteLn(W); INC(i)
        END ;
      (* Sync(R); *)
        Texts.WriteString(W, "commands:"); Texts.WriteLn(W);
        Files.ReadString(R, name);
        WHILE name[0] # 0X DO
          Texts.Write(W, TAB); Texts.WriteString(W, name);
          Files.ReadInt(R, adr); Texts.WriteInt(W, adr, 5); Texts.WriteLn(W);
          Files.ReadString(R, name)
        END ;
      (* Sync(R); *)
        mods[nmods].expoffs := nexports;
        Texts.WriteString(W, "entries"); Texts.WriteLn(W);
        Files.ReadInt(R, n); i := 0;
        WHILE i < n DO
          Files.ReadInt(R, adr); Texts.WriteInt(W, adr, 6); INC(i);
          IF nexports < MaxExports THEN
            exports[nexports] := modbase + adr; INC(nexports)
          END
        END ;
        mods[nmods].nexports := n;
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
        IF ch = "O" THEN
          FixGlobals(modbase, fixorgD, ncode*4);
          FixImports(modbase, fixlist, nimps, imps);
          INC(nmods)
        ELSE Texts.WriteString(W, "format eror"); Texts.WriteLn(W)
        END
      (* Sync(R); *)
      ELSE Texts.WriteString(W, " not found"); Texts.WriteLn(W)
      END ;
      Texts.Append(Oberon.Log, W.buf); Texts.Scan(S)
    END;
    IF doExecute THEN
        IF ncode + ndata > MaxCode THEN
          Texts.WriteString(W, " code + data > "); Texts.WriteInt(W, MaxCode, 0); Texts.WriteLn(W)
        ELSE
          (*call last entry*)
          RISC.Execute(code, modbase + entry DIV 4, ncode, S, W)
        END
    END
  END DecObj;

  PROCEDURE Help*;
  BEGIN Texts.WriteString(W, "usage: ORTool0 DecObj <filename> [/x]");
    Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
  END Help;

BEGIN Texts.OpenWriter(W); Texts.WriteString(W, "ORTool 18.2.2013");
  Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf);
  nmods := 0; nexports := 0;

  Oberon.Run
END ORTool0.

(* vim:set ts=2 sw=2 et: *)
