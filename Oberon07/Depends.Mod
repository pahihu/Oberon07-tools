MODULE Depends; (* Phu 28.2.2026 *)
  IMPORT Texts, Oberon, RedirFiles, Unix, Files;

  CONST
    MaxImport = 16;
    TAB = 09X;
    CmdLen = 256;
  TYPE
    Path = ARRAY 256 OF CHAR;
    Ident = ARRAY 32 OF CHAR;
    Module = POINTER TO ModuleDesc;
    ModuleDesc = RECORD
      next: Module;
      name: ARRAY 32 OF CHAR;
    END;
  VAR
    W, V: Texts.Writer;
    cls: ARRAY 7,7 OF CHAR;
    verbose, recurse: BOOLEAN;
    modules: Module;
    error: BOOLEAN;
    build, nocmd, force: BOOLEAN;
    pflags, lflags: ARRAY 8 OF CHAR;

  PROCEDURE FindModule(VAR s: ARRAY OF CHAR): Module;
    VAR p: Module;
  BEGIN p := modules; WHILE (p # NIL) & (p.name # s) DO p := p.next END;
    RETURN p
  END FindModule;

  PROCEDURE AddModule(VAR s: ARRAY OF CHAR);
    VAR m: Module;
  BEGIN NEW(m); COPY(s, m.name); m.next := modules; modules := m
  END AddModule;

  PROCEDURE EndLine;
  BEGIN Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
  END EndLine;

  PROCEDURE Ln;
  BEGIN Texts.WriteLn(V)
  END Ln;

  PROCEDURE String(s: ARRAY OF CHAR);
  BEGIN Texts.WriteString(W, s)
  END String;

  PROCEDURE Eof(VAR S: Texts.Scanner): BOOLEAN;
  BEGIN RETURN (S.class = Texts.Char) & (S.c = 0FFX)
  END Eof;

  PROCEDURE StrLen(VAR s: ARRAY OF CHAR): LONGINT;
    VAR i: LONGINT;
  BEGIN i := 0; WHILE s[i] # 0X DO INC(i) END;
    RETURN i
  END StrLen;

  PROCEDURE StrCat(VAR dst: ARRAY OF CHAR; src: ARRAY OF CHAR);
    VAR i, j: LONGINT;
  BEGIN i := StrLen(dst); j := 0;
    WHILE (i < LEN(dst)-1) & (src[j] # 0X) DO
      dst[i] := src[j]; INC(i); INC(j)
    END;
    dst[i] := 0X
  END StrCat;

  PROCEDURE MakeFilename(VAR fname: ARRAY OF CHAR; modname, ext: ARRAY OF CHAR);
    VAR i: INTEGER;
  BEGIN COPY(modname, fname); StrCat(fname, ext)
  END MakeFilename;

  PROCEDURE Talk(VAR S: Texts.Scanner);
  BEGIN
    IF verbose THEN
      Texts.WriteString(W, cls[S.class]); Texts.Write(W, "=");
      CASE S.class OF
        Texts.Char: Texts.Write(W, S.c);
      | Texts.Int: Texts.WriteInt(W, S.i, 0);
      | Texts.Real: Texts.WriteReal(W, S.x, 0);
      | Texts.Name: Texts.WriteString(W, S.s);
      | Texts.String: Texts.Write(W, '"'); Texts.WriteString(W, S.s); Texts.Write(W, '"');
      ELSE Texts.WriteString(W, "<unknown>");
      END;
      Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
    END
  END Talk;

  PROCEDURE CompileRule;
  BEGIN
    Texts.WriteString(V, "%.$(OBJ) %.$(SYM): %.$(MOD)"); Ln;
    Texts.Write(V, TAB); Texts.WriteString(V, "$(OXP) Compile $<"); Ln;
  END CompileRule;

  PROCEDURE ScanImports(VAR T: Texts.Text; VAR mod: Ident; VAR nimports: INTEGER; VAR imports: ARRAY OF Ident);
    VAR S: Texts.Scanner;
        i: INTEGER;
        done, savimp, savmod: BOOLEAN;
        nest: INTEGER;
        fname: Path;
  BEGIN nest := 0; nimports := 0; mod[0] := 0X;
    savimp := FALSE; savmod := FALSE; done := FALSE;
    Texts.OpenScanner(S, T, 0); Texts.Scan(S);
    WHILE ~(Eof(S) OR done) DO
      Talk(S);
      IF (nest = 0) & (S.class = Texts.Name) THEN
        IF savimp & (S.s # "SYSTEM") THEN
          IF nimports < MaxImport THEN
            COPY(S.s, imports[nimports]); INC(nimports)
          END
        ELSIF savmod THEN COPY(S.s, mod); savmod := FALSE;
        ELSIF S.s = "IMPORT" THEN savimp := TRUE
        ELSIF S.s = "MODULE" THEN savmod := TRUE
        END
      ELSIF S.class = Texts.Char THEN
        IF (S.c = "(") & (S.nextCh = "*") THEN
          Texts.Scan(S); INC(nest);
        ELSIF (S.c = "*") & (S.nextCh = ")") THEN
          Texts.Scan(S); DEC(nest);
        ELSIF (nest = 0) & savimp THEN
          IF (S.c = "=") & (nimports > 0) THEN DEC(nimports)
          ELSIF S.c = ";" THEN done := TRUE
          END
        END
      END;
      Texts.Scan(S)
    END;
    AddModule(mod)
  END ScanImports;

  PROCEDURE DependencyRule(VAR mod: Ident; nimports: INTEGER; VAR imports: ARRAY OF Ident);
    VAR i: INTEGER;
  BEGIN
    (* M.obj M.sym: M.Mod I.sym ... *)
    Texts.WriteString(V, mod); Texts.WriteString(V, ".$(OBJ) ");
    Texts.WriteString(V, mod); Texts.WriteString(V, ".$(SYM): ");
    FOR i := 0 TO nimports-1 DO
      Texts.WriteString(V, imports[i]); Texts.WriteString(V, ".$(SYM) ")
    END;
    Texts.WriteString(V, mod); Texts.WriteString(V, ".$(MOD)");
    Ln
  END DependencyRule;

  PROCEDURE GetFileExt(VAR name: ARRAY OF CHAR; VAR ext: ARRAY OF CHAR);
  VAR i, j: LONGINT;
      cpy: BOOLEAN;
  BEGIN i := StrLen(name); j := 0;
    WHILE (0 <= i) & (name[i] # ".") DO DEC(i) END ;
    IF 0 <= i THEN
      name[i] := 0X; 
      REPEAT
        INC(i); 
        ext[j] := name[i]; INC(j)
      UNTIL name[i] = 0X
    END
  END GetFileExt;

  PROCEDURE Older(a, b: Path): BOOLEAN;
    (** a older than b, files should exists*)
    VAR da, ta, db, tb: LONGINT;
        A, B: Files.File;
        ret: BOOLEAN;
  BEGIN ret := FALSE;
    A := Files.Old(a);
    B := Files.Old(b);
    ASSERT(A # NIL);
    ASSERT(B # NIL);
    Files.GetDate(A, ta, da);
    Files.GetDate(B, tb, db);
    IF da = db THEN
      ret := ta <= tb
    ELSE
      ret := da <= db
    END ;
    Files.Close(A); Files.Close(B);
    RETURN ret
  END Older;

  PROCEDURE FindOld(path: Path): BOOLEAN;
    VAR F: Files.File;
        ret: BOOLEAN;
  BEGIN F := Files.Old(path);
    IF F # NIL THEN ret := TRUE; Files.Close(F) ELSE ret := FALSE END ;
    RETURN ret
  END FindOld;

  PROCEDURE Link(path: ARRAY OF CHAR);
    VAR cmd: ARRAY CmdLen OF CHAR;
        mod, bin: Path;
        ext: ARRAY 8 OF CHAR;
        ret: LONGINT;
  BEGIN COPY(path, mod); GetFileExt(mod, ext);
    cmd := "ORL Link ";
    StrCat(cmd, mod);
    IF lflags[0] # 0X THEN
      StrCat(cmd, "/"); StrCat(cmd, lflags);
    END ;
    Texts.WriteLn(W); Texts.WriteString(W, cmd); Texts.Append(Oberon.Log, W.buf);
    IF nocmd THEN ret := 0 ELSE ret := Unix.system(cmd) END ;
    error := error OR (ret # 0)
  END Link;

  PROCEDURE Compile(where: ARRAY OF CHAR);
    VAR cmd: ARRAY CmdLen OF CHAR;
        mod, modbase, smb, rsc: Path;
        ext: ARRAY 8 OF CHAR;
        ret: LONGINT;
        smbfound, rscfound: BOOLEAN;
  BEGIN COPY(where, modbase); COPY(where, mod);
    GetFileExt(modbase, ext);
    MakeFilename(smb, modbase, ".smb");
    smbfound := FindOld(smb);
    MakeFilename(rsc, modbase, ".rsc");
    rscfound := FindOld(rsc);
    IF ~force & smbfound & rscfound & Older(mod, smb) & Older(mod, rsc) THEN
    ELSE
      cmd := "ORP.exe Compile "; StrCat(cmd, mod);
      IF pflags[0] # 0X THEN
        StrCat(cmd, "/"); StrCat(cmd, pflags)
      END ;
      Texts.WriteLn(W); Texts.WriteString(W, cmd); Texts.Append(Oberon.Log, W.buf);
      IF nocmd THEN ret := 0 ELSE ret := Unix.system(cmd) END ;
      error := error OR (ret # 0)
    END
  END Compile;

  PROCEDURE ScanOne(path: ARRAY OF CHAR);
    VAR T: Texts.Text;
        i, nimports: INTEGER;
        mod: Ident;
        imports: ARRAY MaxImport OF Ident;
        fname, fnamei: Path;
        found: BOOLEAN;
        ret: LONGINT;
  BEGIN Texts.WriteString(W, " scanning "); Texts.WriteString(W, path); Texts.Append(Oberon.Log, W.buf);
    COPY(path, fname); found := RedirFiles.FindOld(fname);
    NEW(T); Texts.Open(T, fname);
    IF T.len > 0 THEN
      EndLine;
      ScanImports(T, mod, nimports, imports);
      IF ~build THEN DependencyRule(mod, nimports, imports) END ;
      IF recurse & ~error THEN
        FOR i := 0 TO nimports-1 DO
          IF FindModule(imports[i]) = NIL THEN
            MakeFilename(fnamei, imports[i], ".Mod"); ScanOne(fnamei)
          END
        END ;
        IF build & ~error THEN Compile(path) END
      END
    ELSE Texts.WriteString(W, " cannot open"); EndLine
    END
  END ScanOne;

  PROCEDURE Option(VAR S: Texts.Scanner);
    VAR i: INTEGER;
  BEGIN verbose := FALSE;
    IF S.nextCh = "/" THEN
      Texts.Scan(S); Texts.Scan(S);
      IF S.class = Texts.Name THEN
        FOR i := 0 TO S.len - 1 DO
          CASE S.s[i] OF
            "v": verbose := TRUE
          | "r": recurse := TRUE
          | "n": nocmd := TRUE
          END
        END
      END
    END
  END Option;

  PROCEDURE Scan*;
    VAR S: Texts.Scanner;
        T: Texts.Text;
        fname: Path;
  BEGIN modules := NIL;
    Texts.OpenWriter(V); Texts.WriteString(V, "###"); Ln;
    Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
    WHILE S.class = Texts.Name DO
      COPY(S.s, fname); recurse := FALSE; Option(S); ScanOne(fname); Texts.Scan(S)
    END;
    Texts.WriteString(V, "###"); Ln; Texts.Append(Oberon.Log, V.buf)
  END Scan;

  PROCEDURE BuildInt(rebuild: BOOLEAN);
    VAR S: Texts.Scanner;
        T: Texts.Text;
        fname: Path;
  BEGIN modules := NIL; build := TRUE; recurse := TRUE; force := rebuild;
    Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
    IF S.class = Texts.Name THEN
      COPY(S.s, fname); Option(S); ScanOne(fname)
    END ;
    IF ~error THEN Link(fname) END ;
    EndLine
  END BuildInt;

  PROCEDURE Build*;
  BEGIN BuildInt(FALSE)
  END Build;

  PROCEDURE Rebuild*;
  BEGIN BuildInt(TRUE)
  END Rebuild;

  PROCEDURE Clean*;
    VAR ret: LONGINT;
  BEGIN
    ret := Unix.system("rm -f *.bin *.smb *.rsc");
    ret := Unix.system("rm -f *.pos *.lst")
  END Clean;

  PROCEDURE Help*;
  BEGIN Texts.WriteString(W, "usage: Depends Scan module[/rv] ... | Build|Rebuild module[/nv] | Clean");
    EndLine; String("options:");
    EndLine; String("  /n    - dry run build");
    EndLine; String("  /r    - scan IMPORTs recursively");
    EndLine; String("  /v    - verbose");
    EndLine
  END Help;

BEGIN Texts.OpenWriter(W); Texts.WriteString(W, "Depends Phu 4.2.26"); EndLine;
  cls[Texts.Inval] := "Inval";
  cls[Texts.Name] := "Name";
  cls[Texts.String] := "String";
  cls[Texts.Real] := "Real";
  cls[5] := "LReal";
  cls[Texts.Char] := "Char";
  error := FALSE; build := FALSE; nocmd := FALSE; force := FALSE;
  pflags := "ahl"; lflags := "i"
END Depends.

(* History
 * =======
 *
 * 260207 verbose option, skip comments (Graphics.Mod.txt), skip aliases
 * 260204 initial revision
 *
 *)

(* vim:set ts=2 sw=2 et: *)
