MODULE Oberon;
  IMPORT Files, Texts, Out, Args, Modules, Kernel;
  
  CONST OberonLog = 'Oberon.Log';
  
  VAR Log*: Texts.Text;
      Par*: RECORD
        text*: Texts.Text;
        pos-: LONGINT;
      END;

  PROCEDURE EnsureLog;
    VAR F: Files.File;
        R: Files.Rider;
  BEGIN F := Files.Old (OberonLog);
    IF F = NIL THEN F := Files.New (OberonLog); Files.Register (F) END;
    Files.Close (F)
  END EnsureLog;

  PROCEDURE Banner;
    VAR t, d: LONGINT;
        W: Texts.Writer;
  BEGIN Kernel.GetClock(t, d);
    Texts.OpenWriter (W); Texts.WriteDate (W, t, d);
    Texts.WriteLn (W); Texts.Append (Log, W.buf)
  END Banner;

  PROCEDURE InitPar;
    VAR i: INTEGER;
        arg: ARRAY 256 OF CHAR;
        W: Texts.Writer;
  BEGIN Texts.OpenWriter (W); Texts.Write (W, " ");
    FOR i := 2 TO Args.argc DO
      Args.GetArg (i, arg);
      Texts.WriteString (W, arg);
      Texts.Write (W, " ")
    END;
    Par.pos := 0; NEW(Par.text); Texts.OpenRider (Par.text, W.rider)
  END InitPar;

  PROCEDURE Usage(mod: Modules.Module);
    VAR cmd: Modules.Command;
        W: Texts.Writer;
  BEGIN
    cmd := Modules.ThisCommand(mod, "Help");
    IF cmd # NIL THEN cmd
    ELSE Texts.OpenWriter(W);
      Texts.WriteString(W, "usage: "); Texts.WriteString(W, Modules.main);
      Texts.WriteString(W, " command arg...");
      Texts.WriteLn(W); Texts.Append(Log, W.buf)
    END;
  END Usage;

  PROCEDURE Run*;
    VAR mod: Modules.Module;
        cmd: Modules.Command;
        W: Texts.Writer;
        done: BOOLEAN;
  BEGIN
    mod := Modules.ThisMod(Modules.main);
    ASSERT(mod # NIL, 100);
    done := FALSE;
    IF Args.argc # 0 THEN
      cmd := Modules.ThisCommand(mod, Modules.cmd);
      IF cmd # NIL THEN done := TRUE; cmd END
    END;
    IF ~done THEN Usage(mod) END
  END Run;

  PROCEDURE Close*;
  BEGIN Texts.Close (Log)
  END Close;

BEGIN EnsureLog; NEW(Log); Texts.Open (Log, OberonLog);
  Files.Purge (Log.base); (*Files.Set(Log.rider, Log.base, Files.Length (Log.base));*)
  Banner; InitPar
END Oberon.

(* vim:set ts=2 sw=2 et: *)
