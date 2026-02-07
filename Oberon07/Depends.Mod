MODULE Depends; (* Phu 7.2.2026 *)
  IMPORT Texts, Oberon;

  CONST
    MaxImport = 16;
    TAB = 09X;
  TYPE
    String = ARRAY 32 OF CHAR;
  VAR W, V: Texts.Writer;
      cls: ARRAY 7,7 OF CHAR;
      imports: ARRAY MaxImport OF String;
      mod: String;
      verbose: BOOLEAN;


  PROCEDURE EndLine;
  BEGIN Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
  END EndLine;

  PROCEDURE Ln;
  BEGIN Texts.WriteLn(V)
  END Ln;

  PROCEDURE Eof(VAR S: Texts.Scanner): BOOLEAN;
  BEGIN RETURN (S.class = Texts.Char) & (S.c = 0FFX)
  END Eof;

  PROCEDURE WriteBool(x: BOOLEAN);
  BEGIN IF x THEN Texts.Write(W, "Y") ELSE Texts.Write(W, "N") END
  END WriteBool;

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

  PROCEDURE ScanImports(VAR T: Texts.Text);
    VAR S: Texts.Scanner;
        i, n: INTEGER;
        done, savimp, savmod: BOOLEAN;
        nest: INTEGER;
  BEGIN nest := 0; n := 0; mod[0] := 0X;
    savimp := FALSE; savmod := FALSE; done := FALSE;
    Texts.OpenScanner(S, T, 0); Texts.Scan(S);
    WHILE ~(Eof(S) OR done) DO
      Talk(S);
      IF (nest = 0) & (S.class = Texts.Name) THEN
        IF savimp & (S.s # "SYSTEM") THEN
          IF n < MaxImport THEN
            COPY(S.s, imports[n]); INC(n)
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
        ELSIF (nest = 0) & savimp & (S.c = ";") THEN done := TRUE END
      END;
      Texts.Scan(S)
    END;
    (* M.rsc M.smb: M.Mod.txt I.smb ... *)
    Texts.WriteString(V, mod); Texts.WriteString(V, ".rsc ");
    Texts.WriteString(V, mod); Texts.WriteString(V, ".smb: ");
    Texts.WriteString(V, mod); Texts.WriteString(V, ".Mod.txt");
    FOR i := 0 TO n-1 DO
      Texts.Write(V, " ");
      Texts.WriteString(V, imports[i]); Texts.WriteString(V, ".smb")
    END; Ln
  END ScanImports;

  PROCEDURE Option(VAR S: Texts.Scanner);
  BEGIN verbose := FALSE;
    IF S.nextCh = "/" THEN
      Texts.Scan(S); Texts.Scan(S);
      IF (S.class = Texts.Name) & (S.s[0] = "v") THEN verbose := TRUE END
    END
  END Option;

  PROCEDURE Scan*;
    VAR S: Texts.Scanner;
        T: Texts.Text;
  BEGIN Texts.OpenWriter(V); Texts.WriteString(V, "---"); Ln;
    Texts.WriteString(V, "%.rsc %.smb: %.Mod.txt"); Ln;
    Texts.Write(V, TAB); Texts.WriteString(V, "ORP Compile $<"); Ln;
    Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
    WHILE S.class = Texts.Name DO
      Texts.WriteString(W, " scanning "); Texts.WriteString(W, S.s);
      NEW(T); Texts.Open(T, S.s); Option(S);
      IF T.len > 0 THEN ScanImports(T);
      ELSE Texts.WriteString(W, " cannot open");
      END;
      EndLine; Texts.Scan(S)
    END;
    Texts.WriteString(V, "---"); Ln; Texts.Append(Oberon.Log, V.buf)
  END Scan;

  PROCEDURE Help*;
  BEGIN Texts.WriteString(W, "usage: Depends Scan module[/v] ..."); EndLine
  END Help;

BEGIN Texts.OpenWriter(W); Texts.WriteString(W, "Depends Phu 4.2.26"); EndLine;
  cls[Texts.Inval] := "Inval";
  cls[Texts.Name] := "Name";
  cls[Texts.String] := "String";
  cls[Texts.Real] := "Real";
  cls[5] := "LReal";
  cls[Texts.Char] := "Char";
  Oberon.Run
END Depends.

(* History
 * =======
 *
 * 260207 verbose option, skip comments (Graphics.Mod.txt)
 * 260204 initial revision
 *
 *)

(* vim:set ts=2 sw=2 et: *)
