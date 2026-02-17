MODULE ORTool0;  (*NW 18.2.2013*)
  IMPORT Files := Files07, Texts, Oberon, Sys := System, Disasm, RISC, RISCEmu, WA := WAddress;

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
      key, ndata: INTEGER;
      base: WA.ADDR;
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
    wcode: WA.ADDR;
    execute, debug: BOOLEAN;
    mods: ARRAY MaxModules OF Module;
    nmods: LONGINT;
    exports: ARRAY MaxExports OF LONGINT; (*addr. of exported procs*)
    nexports: LONGINT;
    verbose: BOOLEAN;

  PROCEDURE Read(VAR R: Files.Rider; VAR n: INTEGER);
    VAR b: Sys.Byte;
  BEGIN Files.ReadByte(R, b); n := b
  END Read;
  
  (* ---------------------------------------------------*)

  PROCEDURE String(s: ARRAY OF CHAR);
  BEGIN Texts.WriteString(W, s)
  END String;

  PROCEDURE Int(x, y: LONGINT);
  BEGIN Texts.WriteInt(W, x, y)
  END Int;

  PROCEDURE Hex(x: LONGINT);
  BEGIN Texts.WriteHex(W, x)
  END Hex;

  PROCEDURE Char(x: CHAR);
  BEGIN Texts.Write(W, x)
  END Char;

  PROCEDURE Tab;
  BEGIN Char(TAB)
  END Tab;

  PROCEDURE Space;
  BEGIN Char(" ")
  END Space;

  PROCEDURE Ln;
  BEGIN Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
  END Ln;

  (* ---------------------------------------------------*)

  PROCEDURE FixGlobals(modbase, L: WA.ADDR; globalFrame: LONGINT);
    VAR L1: LONGINT;
  BEGIN String(" fixing globals "); Ln;
    L.IncBy(modbase);
    WHILE (L.ToWords() - modbase.ToWords()) # 0 DO
      Int(L.ToWords(), 4); Tab; Hex(code[L.ToWords()]); Ln;
      L1 := code[L.ToWords()] MOD 10000H;
      code[L.ToWords()] := (code[L.ToWords()] DIV 10000H) * 10000H + globalFrame;
      L.Dec(L1)
    END
  END FixGlobals;

  PROCEDURE FindMod(VAR imp: Import): INTEGER;
    VAR i: INTEGER;
  BEGIN i := 0;
    WHILE (i < nmods) & (imp.name # mods[i].name) DO INC(i) END;
    RETURN i
  END FindMod;

  PROCEDURE FixImports(modbase, L: WA.ADDR; nimps: INTEGER; imps: ARRAY OF Import);
    VAR L1: LONGINT;
        mno, eno: LONGINT;
        adr, disp: LONGINT;
        Lp1, wdisp: WA.ADDR;
  BEGIN String(" fixing imports "); Ln;
    L.IncBy(modbase);
    WHILE (L.ToWords() - modbase.ToWords()) # 0 DO
      Int(L.ToWords(), 4); Tab; Hex(code[L.ToWords()]); Tab;
      L1 := code[L.ToWords()] MOD 1000H; (*F7106001*)
      mno := (code[L.ToWords()] DIV 1000H) MOD 1000H;
      eno := mno MOD 100H; mno := (mno DIV 100H) MOD 10H;
      ASSERT(0 < mno, 10); ASSERT(0 < eno, 20);
      Int(mno, 0); Char(":"); Int(eno, 0);
      Space;
      DEC(mno);
      IF mno < nimps THEN
        String(imps[mno].name);
        mno := FindMod(imps[mno]);
        IF mno = nmods THEN String(" not found ");
        ELSE
          IF eno < mods[mno].nexports THEN
            adr := exports[mods[mno].expoffs + eno];
            Lp1.FromWords(L.ToWords()+1); wdisp.FromBytes(Lp1.ToBytes() - adr);
            disp := (1000000H - wdisp.ToWords()) MOD 1000000H;
            String(" adr="); Int(adr, 4);
            IF verbose THEN
              String(" L+1="); Int(Lp1.ToWords(), 4);
              String(" disp="); Int(wdisp.ToBytes(), 4);
              String(" disp="); Hex(disp)
            END;
            code[L.ToWords()] := (code[L.ToWords()] DIV 1000000H) * 1000000H + disp;
          ELSE String(" invalid eno ");
          END
        END
      ELSE String(" invalid mno ");
      END;
      Ln;
      L.Dec(L1)
    END
  END FixImports;

(* ---------------------------------------------------*)

  PROCEDURE Sync(VAR R: Files.Rider);
    VAR ch: CHAR;
  BEGIN Files.Read(R, ch); String("Sync "); Char(ch); Ln
  END Sync;
  
  PROCEDURE Write(VAR R: Files.Rider; x: INTEGER);
    VAR b: Sys.Byte;
  BEGIN b := SHORT(x); Files.WriteByte(R, b)  (* -128 <= x < 128 *)
  END Write;

  PROCEDURE Option(VAR S: Texts.Scanner);
  BEGIN execute := FALSE; debug := FALSE;
    IF S.nextCh = "/" THEN
      Texts.Scan(S); Texts.Scan(S); 
      IF S.class = Texts.Name THEN
        CASE S.s[0] OF
        "d": execute := TRUE; debug := TRUE |
        "x": execute := TRUE
        END
      END
    END
  END Option;
  
  PROCEDURE DecObj*;  (*decode object file*)
    VAR class, i, n, key, size, fix, adr, data, len: INTEGER;
      ch: CHAR;
      name: ARRAY 32 OF CHAR;
      entry, fixlist, fixorgD: LONGINT;
      wentry, wfixlist, wfixorgD: WA.ADDR;
      ndata: LONGINT;
      modbase, wdata: WA.ADDR;
      imps: ARRAY MaxImports OF Import;
      nimps: INTEGER;
      F: Files.File; R: Files.Rider;
      S: Texts.Scanner;
  BEGIN ndata := 0; nimps := 0;
    Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
    WHILE (S.class = Texts.Name) & (nmods < MaxModules) DO
      String("decode "); String(S.s); F := Files.Old(S.s);
      IF F # NIL THEN Option(S);
        Files.Set(R, F, 0); Files.ReadString(R, name); Ln; String(name);
        wdata.Aligned(ndata); wcode.IncBy(wdata); (*add global data*)
        COPY(name, mods[nmods].name);
        Files.ReadInt(R, key); Hex(key); Read(R, class); Int(class, 4); (*version*)
        mods[nmods].key := key;
        Files.ReadInt(R, size); Int(size, 6); Ln;
        String("imports:"); Ln; Files.ReadString(R, name);
        nimps := 0;
        WHILE name[0] # 0X DO
          (*XXX load imported modules here*)
          Tab; String(name);
          Files.ReadInt(R, key); Hex(key); Ln;
          IF nimps < MaxImports THEN
            COPY(name, imps[nimps].name);
            imps[nimps].key := key; INC(nimps)
          ELSE String(" more than 16 imports "); Ln
          END;
          Files.ReadString(R, name)
        END ;
      (* Sync(R); *)
        String("type descriptors"); Ln;
        Files.ReadInt(R, n); n := n DIV 4; i := 0;
        WHILE i < n DO Files.ReadInt(R, data); Hex(data); INC(i) END ;
        Ln;
        String("data"); Files.ReadInt(R, ndata); Int(ndata, 6); Ln;
        mods[nmods].ndata := ndata;
        String("strings"); Ln;
        Files.ReadInt(R, n); i := 0;
        WHILE i < n DO Files.Read(R, ch); Char(ch); INC(i) END ;
        Ln;
        String("code"); Ln;
        modbase := wcode; mods[nmods].base := modbase;
        Files.ReadInt(R, n); i := 0;
        WHILE i < n DO
          Files.ReadInt(R, data); Int(modbase.ToWords() + i, 4); Tab; Hex(data);
          IF wcode.ToWords() < MaxCode THEN code[wcode.ToWords()] := data; wcode.Next
          ELSE execute := FALSE; String(" code space full "); Ln
          END;
          Tab; Disasm.Opcode(W, data); Ln; INC(i)
        END ;
      (* Sync(R); *)
        String("commands:"); Ln;
        Files.ReadString(R, name);
        WHILE name[0] # 0X DO
          Tab; String(name);
          Files.ReadInt(R, adr); Int(adr, 5); Ln;
          Files.ReadString(R, name)
        END ;
      (* Sync(R); *)
        mods[nmods].expoffs := nexports;
        String("entries"); Ln;
        Files.ReadInt(R, n); i := 0;
        WHILE i < n DO
          Files.ReadInt(R, adr); Int(adr, 6); INC(i);
          IF nexports < MaxExports THEN
            exports[nexports] := modbase.ToBytes() + adr; INC(nexports)
          END
        END ;
        mods[nmods].nexports := n;
        Ln;
      (* Sync(R); *)
        String("pointer refs"); Ln; Files.ReadInt(R, adr);
        WHILE adr # -1 DO Int(adr, 6); Files.ReadInt(R, adr) END ;
        Ln;
      (* Sync(R); *)
        Files.ReadInt(R, data); String("fixP  = "); Int(data, 8); Ln; fixlist := data;
        Files.ReadInt(R, data); String("fixD  = "); Int(data, 8); Ln; fixorgD := data;
        Files.ReadInt(R, data); String("fixT  = "); Int(data, 8); Ln;
        Files.ReadInt(R, data); String("entry = "); Int(data, 8); Ln; entry := data;
        Files.Read(R, ch);
        IF ch = "O" THEN
          wfixorgD.FromWords(fixorgD); wfixlist.FromWords(fixlist);
          FixGlobals(modbase, wfixorgD, wcode.ToBytes());
          FixImports(modbase, wfixlist, nimps, imps);
          INC(nmods)
        ELSE String("format eror"); Ln
        END
      (* Sync(R); *)
      ELSE String(" not found"); Ln
      END ;
      Texts.Append(Oberon.Log, W.buf); Texts.Scan(S)
    END;
    IF execute THEN
        IF wcode.ToWords() + wdata.ToWords() > MaxCode THEN
          String(" code + data > "); Int(MaxCode, 0); Ln
        ELSE
          (*call last entry*)
          wentry.FromBytes(entry); wentry.IncBy(modbase);
          RISCEmu.verbose := debug;
          RISC.Execute(code, wentry, wcode, S, W)
        END
    END
  END DecObj;

  PROCEDURE Help*;
  BEGIN String("usage: ORTool0 DecObj <filename> [/x]"); Ln
  END Help;

BEGIN Texts.OpenWriter(W); String("ORTool 18.2.2013"); Ln;
  nmods := 0; nexports := 0;

  verbose := FALSE; Oberon.Run
END ORTool0.

(* vim:set ts=2 sw=2 et: *)
