MODULE POSystem; (*JG 3.10.90 / NW 12.10.93 / NW 20.6.2016*)
  IMPORT Kernel := POKernel, FileDir := POFileDir, Files := POFiles,
    Texts, Oberon, Sys := System, HostFiles := Files;

  VAR W: Texts.Writer;
    pat: ARRAY 32 OF CHAR;

  PROCEDURE GetArg(VAR S: Texts.Scanner);
    VAR T: Texts.Text; beg, end, time: Sys.Integer;
  BEGIN Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
    (*IF (S.class = Texts.Char) & (S.c = "^") THEN
      Oberon.GetSelection(T, beg, end, time);
      IF time >= 0 THEN Texts.OpenScanner(S, T, beg); Texts.Scan(S) END
    END*)
  END GetArg;

  PROCEDURE EndLine;
  BEGIN Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
  END EndLine;

  (* ------------- Toolbox of file system ---------------*)

  PROCEDURE List(name: FileDir.FileName; adr: Sys.Integer; VAR cont: BOOLEAN);
    VAR i0, i, j0, j: Sys.Integer; hp: FileDir.FileHeader;
  BEGIN
    i := 0;
    WHILE (pat[i] > "*") & (pat[i] = name[i]) DO INC(i) END ;
    IF (pat[i] = 0X) & (name[i] = 0X) THEN i0 := i; j0 := i
    ELSIF pat[i] = "*" THEN
      i0 := i; j0 := i+1;
      WHILE name[i0] # 0X DO
        i := i0; j := j0;
        WHILE (name[i] # 0X) & (name[i] = pat[j]) DO INC(i); INC(j) END ;
        IF pat[j] = 0X THEN
          IF name[i] = 0X THEN (*match*) j0 := j ELSE INC(i0) END
        ELSIF pat[j] = "*" THEN i0 := i; j0 := j+1
        ELSE INC(i0)
        END
      END
    END ;
    IF (name[i0] = 0X) & (pat[j0] = 0X) THEN (*found*)
      Texts.WriteString(W, name);
      IF pat[j0+1] = "!" THEN (*option*)
        Kernel.GetSector(adr, hp);
        Texts.Write(W, 9X); Texts.WriteClock(W, hp.date);
        Texts.WriteInt(W, hp.aleng*FileDir.SectorSize + hp.bleng - FileDir.HeaderSize, 8); (*length*)
        (*Texts.WriteHex(W, adr)*)
      END ;
      Texts.WriteLn(W)
    END
  END List;

  PROCEDURE Directory*;
    VAR X, Y, i: Sys.Integer; ch: CHAR;
      R: Texts.Reader;
      T, t: Texts.Text;
      beg, end, time: Sys.Integer;
      pre: ARRAY 32 OF CHAR;
  BEGIN Texts.OpenReader(R, Oberon.Par.text, Oberon.Par.pos); Texts.Read(R, ch);
    WHILE ch = " " DO Texts.Read(R, ch) END;
    (*IF (ch = "^") OR (ch = 0DX) THEN
      Oberon.GetSelection(T, beg, end, time);
      IF time >= 0 THEN
        Texts.OpenReader(R, T, beg); Texts.Read(R, ch);
        WHILE ch <= " " DO Texts.Read(R, ch) END
      END
    END ;*)
    i := 0;
    WHILE ch > "!" DO pat[i] := ch; INC(i); Texts.Read(R, ch) END;
    pat[i] := 0X;
    IF ch = "!" THEN pat[i+1] := "!" END ;  (*directory option*)
    i := 0;
    WHILE pat[i] > "*" DO pre[i] := pat[i]; INC(i) END;
    pre[i] := 0X;
    FileDir.Enumerate(pre, List); Texts.Append(Oberon.Log, W.buf)
  END Directory;

  PROCEDURE CopyFiles*;
    VAR f, g: Files.File; Rf, Rg: Files.Rider; ch: CHAR;
      name: ARRAY 32 OF CHAR;
      S: Texts.Scanner;
  BEGIN GetArg(S);
    Texts.WriteString(W, "System.CopyFiles"); EndLine;
    WHILE S.class = Texts.Name DO
      COPY(S.s, name); Texts.Scan(S);
      IF (S.class = Texts.Char) & (S.c = "=") THEN Texts.Scan(S);
        IF (S.class = Texts.Char) & (S.c = ">") THEN Texts.Scan(S);
          IF S.class = Texts.Name THEN
            Texts.WriteString(W, name); Texts.WriteString(W, " => "); Texts.WriteString(W, S.s);
            Texts.WriteString(W, " copying"); Texts.Append(Oberon.Log, W.buf);
            f := Files.Old(name);
            IF f # NIL THEN g := Files.New(S.s);
              Files.Set(Rf, f, 0); Files.Set(Rg, g, 0); Files.Read(Rf, ch);
              WHILE ~Rf.eof DO Files.Write(Rg, ch); Files.Read(Rf, ch) END;
              Files.Register(g)
            ELSE Texts.WriteString(W, " failed")
            END ;
            EndLine
          END
        END
      END ;
      Texts.Scan(S)
    END
  END CopyFiles;

  PROCEDURE RenameFiles*;
    VAR res: Sys.Integer;
      name: ARRAY 32 OF CHAR;
      S: Texts.Scanner;
  BEGIN GetArg(S);
    Texts.WriteString(W, "System.RenameFiles"); EndLine;
    WHILE S.class = Texts.Name DO
      COPY(S.s, name); Texts.Scan(S);
      IF (S.class = Texts.Char) & (S.c = "=") THEN Texts.Scan(S);
        IF (S.class = Texts.Char) & (S.c = ">") THEN Texts.Scan(S);
          IF S.class = Texts.Name THEN
            Texts.WriteString(W, name); Texts.WriteString(W, " => "); Texts.WriteString(W, S.s);
            Texts.WriteString(W, " renaming"); Files.Rename(name, S.s, res);
            IF res > 1 THEN Texts.WriteString(W, " failed") END;
            EndLine
          END
        END
      END ;
      Texts.Scan(S)
    END
  END RenameFiles;

  PROCEDURE DeleteFiles*;
    VAR res: Sys.Integer; S: Texts.Scanner;
  BEGIN GetArg(S);
    Texts.WriteString(W, "System.DeleteFiles"); EndLine;
    WHILE S.class = Texts.Name DO
      Texts.WriteString(W, S.s); Texts.WriteString(W, " deleting");
      Files.Delete(S.s, res);
      IF res # 0 THEN Texts.WriteString(W, " failed") END;
      EndLine; Texts.Scan(S)
    END
  END DeleteFiles;

  (* ------------- Toolbox of host file system ---------------*)
  
  PROCEDURE CopyFrom*;
    VAR f: Files.File; Rf: Files.Rider; ch: CHAR;
      g: HostFiles.File; Rg: HostFiles.Rider;
      name: ARRAY 32 OF CHAR;
      S: Texts.Scanner;
  BEGIN GetArg(S);
    Texts.WriteString(W, "System.CopyFrom"); EndLine;
    WHILE S.class = Texts.Name DO
      COPY(S.s, name); Texts.Scan(S);
      IF (S.class = Texts.Char) & (S.c = "=") THEN Texts.Scan(S);
        IF (S.class = Texts.Char) & (S.c = ">") THEN Texts.Scan(S);
          IF S.class = Texts.Name THEN
            Texts.WriteString(W, name); Texts.WriteString(W, " => "); Texts.WriteString(W, S.s);
            Texts.WriteString(W, " copying"); Texts.Append(Oberon.Log, W.buf);
            f := Files.Old(name);
            IF f # NIL THEN g := HostFiles.New(S.s);
              Files.Set(Rf, f, 0); HostFiles.Set(Rg, g, 0); Files.Read(Rf, ch);
              WHILE ~Rf.eof DO HostFiles.Write(Rg, ch); Files.Read(Rf, ch) END;
              HostFiles.Register(g)
            ELSE Texts.WriteString(W, " failed")
            END ;
            EndLine
          END
        END
      END ;
      Texts.Scan(S)
    END
  END CopyFrom;
  
  PROCEDURE CopyTo*;
    VAR f: HostFiles.File; Rf: HostFiles.Rider; ch: CHAR;
      g: Files.File; Rg: Files.Rider;
      name: ARRAY 32 OF CHAR;
      S: Texts.Scanner;
  BEGIN GetArg(S);
    Texts.WriteString(W, "System.CopyTo"); EndLine;
    WHILE S.class = Texts.Name DO
      COPY(S.s, name); Texts.Scan(S);
      IF (S.class = Texts.Char) & (S.c = "=") THEN Texts.Scan(S);
        IF (S.class = Texts.Char) & (S.c = ">") THEN Texts.Scan(S);
          IF S.class = Texts.Name THEN
            Texts.WriteString(W, name); Texts.WriteString(W, " => "); Texts.WriteString(W, S.s);
            Texts.WriteString(W, " copying"); Texts.Append(Oberon.Log, W.buf);
            f := HostFiles.Old(name);
            IF f # NIL THEN g := Files.New(S.s);
              HostFiles.Set(Rf, f, 0); Files.Set(Rg, g, 0); HostFiles.Read(Rf, ch);
              WHILE ~Rf.eof DO Files.Write(Rg, ch); HostFiles.Read(Rf, ch) END;
              Files.Register(g)
            ELSE Texts.WriteString(W, " failed")
            END ;
            EndLine
          END
        END
      END ;
      Texts.Scan(S)
    END
  END CopyTo;

  (* ---------------------------------------------------------*)

  PROCEDURE Help*;
  BEGIN Texts.WriteString(W, "usage: POSystem Directory pat! | CopyFiles from => to... | CopyFrom from => host... | CopyTo host => to... | RenameFiles old => new... | DeleteFiles files...");
    Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
  END Help;
  
BEGIN Texts.OpenWriter(W);
  Kernel.OpenImage("RISC.img");
  IF Kernel.res # Kernel.done THEN
    Texts.WriteString(W, " cannot open RISC5.img");
    Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
  ELSE
    Files.Init;
    Oberon.Run
  END
END POSystem.
