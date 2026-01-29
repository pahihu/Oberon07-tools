MODULE Oberon;
  IMPORT Files, Texts, Out;
  
  CONST OberonLog = 'Oberon.Log';
  
  VAR Log*: Texts.Text;
      t, d: LONGINT;
      
  PROCEDURE EnsureLog;
    VAR F: Files.File;
        R: Files.Rider;
  BEGIN F := Files.Old (OberonLog);
    IF F = NIL THEN F := Files.New (OberonLog); Files.Register (F) END;
    Files.Set (R, F, Files.Length (F)); Files.Write (R, " ");
    Files.GetDate (F, t, d);
    Files.Close (F);
  END EnsureLog;

  PROCEDURE Banner (date, time: LONGINT);
    VAR y, mo, d, h, m, s: LONGINT;
        W: Texts.Writer;
  BEGIN 
    h := time DIV 4096; m := time DIV 64 MOD 64; s := time MOD 64;
    y := date DIV 512; mo := date DIV 32 MOD 16; d := date MOD 32;
    Texts.OpenWriter (W);
    Texts.WriteInt (W, d, 1); Texts.Write (W, ".");
    Texts.WriteInt (W, mo, 1); Texts.Write (W, ".");
    Texts.WriteInt (W, y, 1); Texts.Write (W, " ");
    Texts.WriteInt (W, h, 1); Texts.Write (W, ":");
    Texts.WriteInt (W, m, 1); Texts.Write (W, ":");
    Texts.WriteInt (W, s, 1); Texts.WriteLn (W);
    Texts.Append (Log, W.buf)
  END Banner;

  PROCEDURE Close*;
  BEGIN Texts.Close (Log)
  END Close;

BEGIN EnsureLog; NEW(Log); Texts.Open (Log, OberonLog);
  Files.Set(Log.rider, Log.base, Files.Length (Log.base));
  Banner (d, t)
END Oberon.

(* vim:set ts=2 sw=2 et: *)
