MODULE ORTool0;  (*NW 18.2.2013*)
  IMPORT Files := Files07, Texts, Oberon, Sys := System, Disasm, RISC, RISCEmu, WA := WAddress;

  CONST TAB = 9X;
    MaxModules = 8;
    MaxExports = 64;
    MaxImports = 16;
    MaxMem = 8192;

  TYPE
    LONGINT = Sys.INT32;
    INTEGER = Sys.INT32;

    ImportDesc = RECORD
      name: ARRAY 32 OF CHAR;
      key: INTEGER;
    END;

    Module = POINTER TO ModuleDesc;
    ModuleDesc = RECORD
      next: Module;
      name: ARRAY 32 OF CHAR;
      key, ndata: INTEGER;
      entry, fixlist, fixorgD: LONGINT;
      base: WA.ADDR;
      nexports, expOffset: INTEGER; (*offset into exports[]*)
      nimports: INTEGER;
      imports: ARRAY 16 OF ImportDesc;
    END;

  VAR W: Texts.Writer;
    Form: INTEGER;  (*result of ReadType*)
    GF: WA.ADDR;
    code: ARRAY MaxMem OF LONGINT;
    wcode, wdata: WA.ADDR;
    modules: Module;
    exports: ARRAY MaxExports OF LONGINT; (*addr. of exported procs*)
    nexports: LONGINT;
    printOut: BOOLEAN;
    errno: INTEGER;

  PROCEDURE Read(VAR R: Files.Rider; VAR n: INTEGER);
    VAR b: Sys.Byte;
  BEGIN Files.ReadByte(R, b); n := b
  END Read;
  
  (* ---------------------------------------------------*)

  PROCEDURE Ln;
  BEGIN
    IF printOut THEN Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
    ELSE Texts.ClearWriter(W)
    END
  END Ln;

  PROCEDURE String(s: ARRAY OF CHAR);
  BEGIN Texts.WriteString(W, s)
  END String;

  PROCEDURE Verbose(flag: BOOLEAN): BOOLEAN;
    VAR prev: BOOLEAN;
  BEGIN prev := printOut;
    IF ~prev THEN Texts.ClearWriter(W) END;
    printOut := flag;
    RETURN prev
  END Verbose;

  PROCEDURE Err(s: ARRAY OF CHAR);
    VAR prev: BOOLEAN;
  BEGIN
    prev := Verbose(TRUE);
    INC(errno); String(s); Ln;
    printOut := prev
  END Err;

  PROCEDURE Int(x, y: LONGINT);
  BEGIN Texts.WriteInt(W, x, y)
  END Int;

  PROCEDURE Hex(x: LONGINT);
  BEGIN Texts.WriteHex(W, x)
  END Hex;

  PROCEDURE PrInt(s: ARRAY OF CHAR; x,y: LONGINT);
  BEGIN String(s); Int(x, y); Ln
  END PrInt;

  PROCEDURE PrHex(s: ARRAY OF CHAR; x: LONGINT);
  BEGIN String(s); Hex(x); Ln
  END PrHex;

  PROCEDURE Char(x: CHAR);
  BEGIN Texts.Write(W, x)
  END Char;

  PROCEDURE Tab;
  BEGIN Char(TAB)
  END Tab;

  PROCEDURE Space;
  BEGIN Char(" ")
  END Space;

  (* ---------------------------------------------------*)

  PROCEDURE FixGlobals(modbase, L: WA.ADDR; ndata: LONGINT);
    VAR L1: LONGINT;
        gf: LONGINT;
  BEGIN
    IF L.ToWords() # 0 THEN
      gf := GF.ToBytes();
      PrInt(" fixing globals, globalFrame=", gf, 5);
      (*embed the GF ptr in the code section*)
      L.IncBy(modbase);
      WHILE (L.ToWords() - modbase.ToWords()) # 0 DO
        Tab; Int(L.ToWords(), 4); Tab; Hex(code[L.ToWords()]); Ln;
        L1 := code[L.ToWords()] MOD 10000H;
        code[L.ToWords()] := 4C000000H + gf; (*MOV SB,imm*)
        L.Dec(L1)
      END;
      GF.Inc((ndata+3) DIV 4)
    END
  END FixGlobals;

  PROCEDURE FindMod(VAR imp: ImportDesc): Module;
    VAR m: Module;
  BEGIN m := modules;
    WHILE (m # NIL) & (imp.name # m.name) DO m := m.next END;
    RETURN m
  END FindMod;

  PROCEDURE FixImports(base, L: WA.ADDR; nimps: INTEGER; VAR imps: ARRAY OF ImportDesc);
    CONST debug = FALSE;
    VAR L1: LONGINT;
        mno, eno: LONGINT;
        adr, disp: LONGINT;
        Lp1, wdisp: WA.ADDR;
        mod: Module;
  BEGIN
    IF L.ToWords() # 0 THEN
      String(" fixing imports "); Ln;
      L.IncBy(base);
      WHILE (L.ToWords() - base.ToWords()) # 0 DO
        Tab; Int(L.ToWords(), 4); Tab; Hex(code[L.ToWords()]); Tab;
        L1 := code[L.ToWords()] MOD 1000H; (*F7106001*)
        mno := (code[L.ToWords()] DIV 1000H) MOD 1000H;
        eno := mno MOD 100H; mno := (mno DIV 100H) MOD 10H;
        ASSERT(0 < mno, 10); ASSERT(0 < eno, 20);
        Int(mno, 0); Char(":"); Int(eno, 0);
        Space;
        DEC(mno);
        IF mno < nimps THEN
          String(imps[mno].name);
          mod := FindMod(imps[mno]);
          IF mod = NIL THEN Err(" not found ")
          ELSE
            IF eno < mod.nexports THEN
              adr := exports[mod.expOffset + eno];
              Lp1.FromWords(L.ToWords()+1); wdisp.FromBytes(Lp1.ToBytes() - adr);
              disp := (1000000H - wdisp.ToWords()) MOD 1000000H;
              PrInt(" adr=", adr, 4);
              IF debug THEN
                PrInt(" L+1=", Lp1.ToWords(), 4);
                PrInt(" disp=", wdisp.ToBytes(), 4);
                PrHex(" disp=", disp)
              END;
              code[L.ToWords()] := (code[L.ToWords()] DIV 1000000H) * 1000000H + disp;
            ELSE Err(" invalid eno ");
            END
          END
        ELSE Err(" invalid mno ");
        END;
        L.Dec(L1)
      END
    END
  END FixImports;

(* ---------------------------------------------------*)

  PROCEDURE Sync(VAR R: Files.Rider);
    VAR ch: CHAR;
  BEGIN Files.Read(R, ch); String("Sync "); Char(ch); Ln
  END Sync;

  PROCEDURE NewModule(): Module;
    VAR m: Module;
  BEGIN NEW(m); m.next := NIL;
    m.ndata := 0;
    m.nexports := 0;
    m.nimports := 0;
    RETURN m
  END NewModule;
  
  PROCEDURE LoadObj(F: Files.File; verbose: BOOLEAN): Module;  (*decode object file*)
    VAR class, i, n, key, size, fix, adr, data, len: INTEGER;
      ch: CHAR;
      name: ARRAY 32 OF CHAR;
      base: WA.ADDR;
      R: Files.Rider;
      m: Module;
  BEGIN printOut := verbose; m:= NewModule();
    Files.Set(R, F, 0); Files.ReadString(R, name); Ln; String(name);
    COPY(name, m.name);
    Files.ReadInt(R, key); Hex(key); Read(R, class); Int(class, 4); (*version*)
    m.key := key;
    Files.ReadInt(R, size); Int(size, 6); Ln;
    String("imports:"); Ln; Files.ReadString(R, name);
    n := 0;
    WHILE name[0] # 0X DO
      (*XXX load imported modules here*)
      Files.ReadInt(R, key);
      Tab; PrHex(name, key); Ln;
      IF n < MaxImports THEN
        COPY(name, m.imports[n].name);
        m.imports[n].key := key; INC(n)
      ELSE Err(" more than 16 imports ")
      END;
      Files.ReadString(R, name)
    END ;
    m.nimports := n;
    (* Sync(R); *)
    String("type descriptors"); Ln;
    Files.ReadInt(R, n); n := n DIV 4; i := 0;
    WHILE i < n DO Files.ReadInt(R, data); Hex(data); INC(i) END ;
    Ln;
    Files.ReadInt(R, data); PrInt("data", data, 6);
    m.ndata := data;
    String("strings"); Ln;
    Files.ReadInt(R, n); i := 0;
    WHILE i < n DO Files.Read(R, ch); Char(ch); INC(i) END ;
    Ln;
    String("code"); Ln;
    base := wcode; m.base := base;
    Files.ReadInt(R, n); i := 0;
    WHILE i < n DO
      Files.ReadInt(R, data); Int(base.ToWords() + i, 4); Tab; Hex(data);
      IF wcode.ToWords() < MaxMem THEN code[wcode.ToWords()] := data; wcode.Next
      ELSE Err(" code space full ");
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
    m.expOffset := nexports;
    String("entries"); Ln;
    Files.ReadInt(R, n); i := 0;
    WHILE i < n DO
      Files.ReadInt(R, adr); Int(adr, 6); INC(i);
      IF nexports < MaxExports THEN
        exports[nexports] := base.ToBytes() + adr; INC(nexports)
      END
    END ;
    m.nexports := n;
    Ln;
    (* Sync(R); *)
    String("pointer refs"); Ln; Files.ReadInt(R, adr);
    WHILE adr # -1 DO Int(adr, 6); Files.ReadInt(R, adr) END ;
    Ln;
    (* Sync(R); *)
    Files.ReadInt(R, data); PrInt("fixP  = ", data, 8); m.fixlist := data;
    Files.ReadInt(R, data); PrInt("fixD  = ", data, 8); m.fixorgD := data;
    Files.ReadInt(R, data); PrInt("fixT  = ", data, 8);
    Files.ReadInt(R, data); PrInt("entry = ", data, 8); m.entry := data;
    Files.Read(R, ch);
    IF ch # "O" THEN m := NIL; Err("format error") END;
    (* Sync(R); *)
    RETURN m
  END LoadObj;

  PROCEDURE DecObj*;  (*decode object file*)
    VAR F: Files.File;
      S: Texts.Scanner;
      m: Module;
  BEGIN Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
    WHILE S.class = Texts.Name DO
      String("decode "); String(S.s); F := Files.Old(S.s);
      IF F # NIL THEN m := LoadObj(F, TRUE)
      ELSE Err(" not found")
      END ;
      Texts.Scan(S)
    END;
  END DecObj;

  PROCEDURE Fix(m: Module): Module;
    VAR base: WA.ADDR;
      wfixorgD, wfixlist: WA.ADDR;
      perrno: INTEGER;
  BEGIN
    IF m # NIL THEN
      String(" link "); String(m.name); Ln;
      perrno := errno;
      base := m.base;
      wfixorgD.FromWords(m.fixorgD); wfixlist.FromWords(m.fixlist);
      FixGlobals(base, wfixorgD, m.ndata);
      FixImports(base, wfixlist, m.nimports, m.imports);
      (*failed if prev.errno mismatch*)
      IF errno # perrno THEN m := NIL END
    END;
    RETURN m
  END Fix;

  PROCEDURE Link(m: Module);
    VAR l: Module;
  BEGIN
    IF m = NIL THEN
    ELSE Link(m.next); l := Fix(m)
    END
  END Link;

  PROCEDURE ExecObj(debug: BOOLEAN);  (*execute/debug object file*)
    VAR w, wentry, wfixlist, wfixorgD: WA.ADDR;
      F: Files.File;
      S: Texts.Scanner;
      m: Module;
      prev: BOOLEAN;
  BEGIN Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
    WHILE S.class = Texts.Name DO
      String("load "); String(S.s); F := Files.Old(S.s);
      IF F # NIL THEN
        m := LoadObj(F, FALSE);
        IF m # NIL THEN
          w.Aligned(m.ndata); wdata.IncBy(w);
          m.next := modules; modules := m;
        END
      ELSE Err(" not found")
      END ;
      Ln; Texts.Scan(S)
    END;
    prev := Verbose(TRUE);
    PrInt(" code=", wcode.ToWords(), 4);
    PrInt(" data=", wdata.ToWords(), 4);
    IF wcode.ToWords() + wdata.ToWords() > MaxMem THEN Err(" space full ")
    ELSIF (m # NIL) & (errno = 0) THEN (*call last module entry*)
      GF.FromWords(wcode.ToWords()); Link(modules);
      IF errno = 0 THEN
        wentry.FromBytes(m.entry); wentry.IncBy(m.base);
        RISCEmu.verbose := debug;
        RISC.Execute(code, wentry, wcode, S, W)
      END
    END
  END ExecObj;

  PROCEDURE Execute*;
  BEGIN ExecObj(FALSE)
  END Execute;

  PROCEDURE Debug*;
  BEGIN ExecObj(TRUE)
  END Debug;

  PROCEDURE Help*;
  BEGIN String("usage: ORTool0 DecObj <file.rsc>... | Debug mod.rsc... | Execute mod.rsc..."); Ln
  END Help;

BEGIN Texts.OpenWriter(W); String("ORTool 18.2.2013"); Ln;
  errno := 0;
  modules := NIL; nexports := 0;
  GF.FromWords(2048);
  wcode.FromWords(0); wdata.FromWords(0);

  printOut := TRUE; Oberon.Run
END ORTool0.

(* vim:set ts=2 sw=2 et: *)
