MODULE ORL;  (*Oberon boot linker/loader for RISC / AP 1.5.23 / Phu 28.1.26 *)
  IMPORT SYSTEM, Files, Texts, Oberon, Args, Sys := System;
  CONST versionkey = 1X; versionkey0 = 0X; MT = 12; DescSize = 80; MnLength = 32; BootSec = 2; BootSize = 64; FPrint = 12345678H;
    noerr* = 0; nofile* = 1; badversion* = 2; badkey* = 3; badfile* = 4; nospace* = 5;
    DestAdr = 8; MemAdr = 12; AllocAdr = 16; RootAdr = 20; StackAdr = 24; FPrintAdr = 28; MTAdr = 32; ModAdr = 256;
    C4 = 10H; C6 = 40H; C8 = 100H; C10 = 400H; C12 = 1000H; C14 = 4000H; C16 = 10000H;
    C18 = 40000H; C20 = 100000H; C22 = 400000H; C24 = 1000000H; BCT = 0E7000000H; BLT = 0F7000000H;
    
    MemSize = 20000H; (*128K area for linking*)

  TYPE  (*copied from Modules for use as cross linker/loader*)
    PtrOffset* = Sys.Integer;
    Procedure* = Sys.Integer;
    Command* = Procedure;
    
    Module* = POINTER TO ModDesc;
    ModuleName* = ARRAY MnLength OF CHAR;
    ModDesc* = RECORD
      name*: ModuleName;
      next*: PtrOffset; (*memory offset*)
      key*, num*, size*, refcnt*: Sys.Integer;
      data*, code*, imp*, cmd*, ent*, ptr*, unused*: Sys.Integer  (*addresses*)
    END ;

  VAR root: Module;
    MTOrg, AllocPtr, Start, limit, res*: Sys.Integer;
    importing*, imported*: ModuleName;
    W: Texts.Writer;

  VAR
    Mem: POINTER TO ARRAY MemSize OF CHAR;
    cmd: ARRAY 32 OF CHAR;
    
  (*==================================================================*)

  VAR
    MemBase: Sys.Address;
    
  PROCEDURE ChkBase;
  BEGIN ASSERT(MemBase # 0, 10)
  END ChkBase;

  PROCEDURE RelPtr*(x: SYSTEM.PTR): PtrOffset;
    VAR ret: PtrOffset;
  BEGIN ChkBase; ret := 0;
    IF x # NIL THEN ret := Sys.AddrToInt(SYSTEM.VAL(Sys.Address,x) - MemBase) END;
    RETURN ret
  END RelPtr;

  (** Convert memory offset to absolute address *)
  PROCEDURE AbsPtr*(x: PtrOffset): Module;
    VAR ret: Module;
  BEGIN ChkBase; ret := NIL;
    IF x # 0 THEN ret := SYSTEM.VAL(Module, x + MemBase) END;
    RETURN ret
  END AbsPtr;

  (** Get 4bytes at memory offset *)
  PROCEDURE Get4*(a: PtrOffset; VAR v: Sys.Integer);
  BEGIN ChkBase; SYSTEM.GET(a + MemBase, v)
  END Get4;

  (** Put 4bytes at memory offset *)
  PROCEDURE Put4*(a: PtrOffset; x: Sys.Integer);
  BEGIN ChkBase; SYSTEM.PUT(a + MemBase, x)
  END Put4;

  (** Put 1byte at memory offset *)
  PROCEDURE Put1*(a: PtrOffset; x: CHAR);
  BEGIN ChkBase; SYSTEM.PUT(a + MemBase, x)
  END Put1;
  
  (*==================================================================*)

  PROCEDURE EndLine;
  BEGIN Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
  END EndLine;

  PROCEDURE MakeFileName(VAR FName: ARRAY OF CHAR; name, ext: ARRAY OF CHAR);
    VAR i, j: INTEGER;
  BEGIN i := 0; j := 0;  (*assume name suffix less than 4 characters*)
    WHILE (i < MnLength-5) & (name[i] > 0X) DO FName[i] := name[i]; INC(i) END ;
    REPEAT FName[i]:= ext[j]; INC(i); INC(j) UNTIL ext[j] = 0X;
    FName[i] := 0X
  END MakeFileName;

  PROCEDURE ThisFile(name: ARRAY OF CHAR): Files.File;
    VAR F: Files.File;
      filename: ModuleName;
  BEGIN MakeFileName(filename, name, ".rsc"); F := Files.Old(filename); RETURN F
  END ThisFile;

  PROCEDURE error(n: INTEGER; name: ARRAY OF CHAR);
  BEGIN res := n; COPY(name, importing)
  END error;

  PROCEDURE check(s: ARRAY OF CHAR; VAR slen: Sys.Integer);  (*slen includes trailing 0X*)
    VAR i: Sys.Integer; ch: CHAR;
  BEGIN ch := s[0]; res := 1; i := 0; slen := 0;
    IF (ch >= "A") & (ch <= "Z") OR (ch >= "a") & (ch <= "z") THEN
      REPEAT INC(i); ch := s[i]
      UNTIL ~((ch >= "0") & (ch <= "9") OR (ch >= "A") & (ch <= "Z")
        OR (ch >= "a") & (ch <= "z") OR (ch = ".")) OR (i >= MnLength);
      IF ch = 0X THEN res := 0; slen := i+1 END
    END
  END check;

  PROCEDURE LinkOne(name: ARRAY OF CHAR; VAR newmod: Module);
    (*search module in list; if not found, link module.
      res = noerr: already present or linked;
      res = nofile: file not available;
      res = badversion: bad file version;
      res = badkey: key conflict;
      res = badfile: corrupted file;
      res = nospace: insufficient space*)
    VAR mod, impmod: Module;
      i, n, key, impkey, mno, nofimps, size: Sys.Integer;
      p, u, v, w: Sys.Integer;  (*addresses*)
      ch: CHAR;
      body: Command;
      fixorgP, fixorgD, fixorgT: Sys.Integer;
      disp, adr, inst, pno, vno, dest, offset: Sys.Integer;
      name1, impname: ModuleName;
      F: Files.File; R: Files.Rider;
      import: ARRAY 16 OF Module;
      ptr: Sys.Integer;
  BEGIN mod := root; error(noerr, name); nofimps := 0;
    WHILE (mod # NIL) & (name # mod.name) DO mod := AbsPtr(mod.next) END ;
    IF mod = NIL THEN (*link*)
      check(name, n);
      IF res = noerr THEN F := ThisFile(name) ELSE F := NIL END ;
      IF F # NIL THEN
        Files.Set(R, F, 0); Files.ReadString(R, name1); Sys.ReadInt(R, key); Files.Read(R, ch);
        Sys.ReadInt(R, size); importing := name1;
        IF (ch = versionkey) (*regular module*) OR (ch = versionkey0) (*standalone program*) THEN
          Files.ReadString(R, impname);   (*imports*)
          WHILE (impname[0] # 0X) & (res = noerr) DO
            Sys.ReadInt(R, impkey);
            LinkOne(impname, impmod); import[nofimps] := impmod; importing := name1;
            IF res = noerr THEN
              IF impmod.key = impkey THEN INC(impmod.refcnt); INC(nofimps)
              ELSE error(badkey, name1); imported := impname
              END
            END ;
            Files.ReadString(R, impname)
          END
        ELSE error(badversion, name1)
        END
      ELSE error(nofile, name)
      END ;
      IF res = noerr THEN
        INC(size, DescSize);
        IF AllocPtr + size < limit THEN (*allocate*)
          p := AllocPtr; mod := AbsPtr(p);
          AllocPtr := (p + size + 3) DIV 4 * 4; mod.size := AllocPtr - p;
          IF root = NIL THEN mod.num := 1 ELSE mod.num := root.num + 1 END ;
          mod.next := RelPtr(root); root := mod
        ELSE error(nospace, name1)
        END
      END ;
      IF res = noerr THEN (*read file*)
        INC(p, DescSize); (*allocate descriptor*)
        COPY(name, mod.name); mod.key := key; mod.refcnt := 0; mod.unused := 0; i := n;
        WHILE i < MnLength DO mod.name[i] := 0X; INC(i) END ;
        mod.data := p;  (*data*)
        Put4(mod.num * 4 + MTOrg, p);  (*module table entry*)
        Sys.ReadInt(R, n);
        WHILE n > 0 DO Sys.ReadInt(R, w); Put4(p, w); INC(p, 4); DEC(n, 4) END ;  (*type descriptors*)
        Sys.ReadInt(R, n);
        WHILE n > 0 DO Put4(p, 0); INC(p, 4); DEC(n, 4) END ;  (*variable space*)
        Sys.ReadInt(R, n);
        WHILE n > 0 DO Files.Read(R, ch); Put1(p, ch); INC(p); DEC(n) END ;   (*strings*)
        mod.code := p;  (*program*)
        Sys.ReadInt(R, n);
        WHILE n > 0 DO Sys.ReadInt(R, w); Put4(p, w); INC(p, 4); DEC(n) END ;  (*program code*)
        mod.imp := p;  (*copy imports*)
        i := 0;
        WHILE i < nofimps DO
          Put4(p, RelPtr(import[i])); INC(p, 4); INC(i)
        END ;
        mod.cmd := p;  (*commands*) Files.Read(R, ch);
        WHILE ch # 0X DO
          REPEAT Put1(p, ch); INC(p); Files.Read(R, ch) UNTIL ch = 0X;
          REPEAT Put1(p, 0X); INC(p) UNTIL p MOD 4 = 0;
          Sys.ReadInt(R, n); Put4(p, n); INC(p, 4); Files.Read(R, ch)
        END ;
        REPEAT Put1(p, 0X); INC(p) UNTIL p MOD 4 = 0;
        mod.ent := p;  (*entries*)
        Sys.ReadInt(R, n);
        WHILE n > 0 DO Sys.ReadInt(R, w); Put4(p, w); INC(p, 4); DEC(n) END ;
        mod.ptr := p;  (*pointer references*)
        Sys.ReadInt(R, w);
        WHILE w >= 0 DO Put4(p, mod.data + w - Start); INC(p, 4); Sys.ReadInt(R, w) END ;
        Put4(p, 0); INC(p, 4);
        Sys.ReadInt(R, fixorgP); Sys.ReadInt(R, fixorgD); Sys.ReadInt(R, fixorgT);
        Sys.ReadInt(R, w); body := SYSTEM.VAL(Command, mod.code + w - Start);
        Files.Read(R, ch);
        IF ch # "O" THEN mod := NIL; error(badfile, name) END
      END ;
      IF res = noerr THEN (*fixup of BL*)
        adr := mod.code + fixorgP*4;
        WHILE adr # mod.code DO
          Get4(adr, inst);
          mno := inst DIV C20 MOD C4;
          pno := inst DIV C12 MOD C8;
          disp := inst MOD C12;
          Get4(mod.imp + (mno-1)*4, ptr); impmod := AbsPtr(ptr);
          Get4(impmod.ent + pno*4, dest); dest := dest + impmod.code;
          offset := (dest - adr - 4) DIV 4;
          Put4(adr, Sys.BinOr(BLT, offset MOD C24));
          adr := adr - disp*4
        END ;
        (*fixup of LDR/STR/ADD*)
        adr := mod.code + fixorgD*4;
        WHILE adr # mod.code DO
          Get4(adr, inst);
          mno := inst DIV C20 MOD C4;
          disp := inst MOD C12;
          IF mno = 0 THEN (*global*)
            Put4(adr, (inst DIV C24 * C4 + MT) * C20 + mod.num * 4)
          ELSE (*import*)
            Get4(mod.imp + (mno-1)*4, ptr); impmod := AbsPtr(ptr); v := impmod.num;
            Put4(adr, (inst DIV C24 * C4 + MT) * C20 + v*4);
            Get4(adr+4, inst); vno := inst MOD C8;
            Get4(impmod.ent + vno*4, offset);
            IF ODD(inst DIV C8) THEN offset := offset + impmod.code - impmod.data END ;
            Put4(adr+4, inst DIV C16 * C16 + offset)
          END ;
          adr := adr - disp*4
        END ;
        (*fixup of type descriptors*)
        adr := mod.data + fixorgT*4;
        WHILE adr # mod.data DO
          Get4(adr, inst);
          mno := inst DIV C24 MOD C4;
          vno := inst DIV C12 MOD C12;
          disp := inst MOD C12;
          IF mno = 0 THEN (*global*) inst := mod.data - Start + vno
          ELSE (*import*)
            Get4(mod.imp + (mno-1)*4, ptr); impmod := AbsPtr(ptr);
            Get4(impmod.ent + vno*4, offset);
            inst := impmod.data - Start + offset
          END ;
          Put4(adr, inst); adr := adr - disp*4
        END ;
        Put4(Start, body) (*module initialization body*)
      ELSIF res >= badkey THEN COPY(name, importing);
        WHILE nofimps > 0 DO DEC(nofimps); DEC(import[nofimps].refcnt) END
      END
    END ;
    newmod := mod
  END LinkOne;

  PROCEDURE Link*;  (*link multiple object files together and create a single boot file M.bin from them*)
    VAR i, x: Sys.Integer;
      F: Files.File; R: Files.Rider;
      S: ARRAY 32 OF CHAR;
      M, p: Module;
      name: ModuleName;
      pos: INTEGER;
  BEGIN res := -1; pos := 2;
    IF Args.argc > 1 THEN
      root := NIL; Start := 0; MTOrg := Start + MTAdr; AllocPtr :=  Start + ModAdr; i := Start;
      WHILE i < AllocPtr DO Put4(i, 0); INC(i, 4) END ;
      REPEAT Args.GetArg(pos, S); LinkOne(S, M); INC(pos) UNTIL (pos > Args.argc) OR (res # noerr);
      IF res = noerr THEN p := root; Texts.WriteString(W, "  linking");
        WHILE p # NIL DO (*fixup*) Texts.Write(W, " "); Texts.WriteString(W, p.name);
          M := p; p := AbsPtr(p.next);
          IF p # NIL THEN M.next := RelPtr(p) - Start END ;
          M.data := M.data - Start;
          Put4(M.num * 4 + MTOrg, M.data);  (*module table entry*)
          M.code := M.code - Start;
          i := M.imp;
          WHILE i < M.cmd DO Get4(i, x); Put4(i, x - Start); INC(i, 4) END ;
          M.imp := M.imp - Start;
          M.cmd := M.cmd - Start;
          M.ent := M.ent - Start;
          M.ptr := M.ptr - Start
        END ;
        Get4(Start, x);  (*address of initialization body of the top module relative to Start*)
        Put4(Start, Sys.BinOr(BCT, (x DIV 4) - 1));  (*branch instruction to the initialization body of the top module*)
        Put4(Start + DestAdr, 0);  (*destination address of the prelinked, executable binary*)
        Put4(Start + MemAdr, 0);  (*limit of available memory, typically overwritten by the boot loader*)
        Put4(Start + AllocAdr, AllocPtr - Start);  (*address of the end of the module space loaded*)
        Put4(Start + RootAdr, RelPtr(root) - Start);  (*current root of the links of loaded modules*)
        Put4(Start + StackAdr, 0);  (*current limit of the module area, typically overwritten by the boot loader*)
        Put4(Start + FPrintAdr, FPrint);  (*fingerprint*)
        MakeFileName(name, S, ".bin"); F := Files.New(name); Files.Set(R, F, 0); i := Start;
        WHILE i < AllocPtr DO Get4(i, x); Sys.WriteInt(R, x); INC(i, 4) END ;
        Texts.WriteInt(W, AllocPtr - Start, 7); Files.Register(F)
      ELSE
        Texts.WriteString(W, "Link error:  "); Texts.WriteString(W, importing);
        IF res = nofile THEN Texts.WriteString(W, " module not found")
        ELSIF res = badversion THEN Texts.WriteString(W, " bad version")
        ELSIF res = badkey THEN Texts.WriteString(W, " imports ");
          Texts.WriteString(W, imported); Texts.WriteString(W, " with bad key")
        ELSIF res = badfile THEN Texts.WriteString(W, " corrupted obj file")
        ELSIF res = nospace THEN Texts.WriteString(W, " insufficient space")
        END
      END
    ELSE Texts.WriteString(W, "Usage: ORL.Link [module...] topmodule")
    END ;
    EndLine; root := NIL
  END Link;

  PROCEDURE Load*;  (*load prelinked boot file M.bin onto the boot area of the local disk*)      
    CONST SectorLength = 1024;
          FSoffset = 80000H; (*256MB in 512-byte blocks*)
    TYPE
      Sector = ARRAY SectorLength OF SYSTEM.BYTE;

    VAR i, secno: Sys.Integer; b: CHAR (*SYSTEM.BYTE*);
      F, SD: Files.File; R, SDR: Files.Rider;
      S: ARRAY 32 OF CHAR;
      buf: Sector;
      
    PROCEDURE PutSector(dst: Sys.Integer; VAR src: Sector);
    BEGIN dst := dst DIV 29;
      dst := dst * 2 + FSoffset;
      Files.Set(SDR, SD, dst * SectorLength);
      Files.WriteBytes(SDR, src, SectorLength)
    END PutSector;
    
  BEGIN res := -1;
    IF Args.argc > 2 THEN Args.GetArg(2, S);
      Texts.WriteString(W, "  loading "); Texts.WriteString(W, S); F := Files.Old(S);
      IF F # NIL THEN Texts.WriteString(W, " onto boot area"); Texts.WriteInt(W, Files.Length(F), 7);
        Args.GetArg(3, S);
        Texts.WriteString(W, "  image "); Texts.WriteString(W, S); SD := Files.Old(S);
        IF SD # NIL THEN Files.Set(SDR, SD, 0);        
          secno := BootSec; i := 0; Files.Set(R, F, 0); Files.Read(R, b); res := noerr;
          WHILE ~R.eof DO buf[i] := b; INC(i);
            IF i = SectorLength THEN PutSector(secno*29, buf); INC(secno); i := 0 END ;
            Files.Read(R, b)
          END ;
          IF i > 0 THEN
            WHILE i < SectorLength DO buf[i] := 0; INC(i) END ;
            PutSector(secno*29, buf); INC(secno)
          END ;
          FOR i := 0 TO SectorLength-1 DO buf[i] := 0 END ;
          WHILE secno < BootSize DO PutSector(secno*29, buf); INC(secno) END;
        ELSE Texts.WriteString(W, " not found")
        END
      ELSE Texts.WriteString(W, " not found")
      END
    ELSE Texts.WriteString(W, "Usage: ORL.Load M.bin SD.img")
    END;
    EndLine
  END Load;

BEGIN Texts.OpenWriter(W); Texts.WriteString(W, "OR Boot linker/loader  AP 1.5.23"); EndLine;

  NEW(Mem); MemBase := SYSTEM.VAL(Sys.Address, Mem); limit := MemSize;

  IF Args.argc = 0 THEN
    Texts.WriteString(W, "usage: ORL Link [module ...] topmodule | Load M.bin SD.img");
    Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
  ELSE
    Args.GetArg(1, cmd);
    IF cmd = "Link" THEN Link
    ELSIF cmd = "Load" THEN Load
    END
  END
END ORL.
