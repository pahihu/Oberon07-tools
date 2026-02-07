MODULE TestInt;
  IMPORT SYSTEM, Oberon, Texts, Modules, Out;
  CONST a = 1234567890;
        b = 2146123467;
        c = 23456;
        MI = MAX(INTEGER);
        mI = MIN(INTEGER);
        MLI = MAX(LONGINT);
        mLI = MIN(LONGINT);
  TYPE
    L1 = RECORD END;
    L2 = RECORD (L1) i2: INTEGER END;
    L3 = RECORD (L2) i3: INTEGER END;
    L4 = RECORD (L3) i4: INTEGER END;
    L5 = RECORD (L4) i5: INTEGER END;
    L6 = RECORD (L5) i6: INTEGER END;

  VAR mod: Modules.Module;
      cmd: Modules.Command;
      W: Texts.Writer;

  PROCEDURE Greet*;
  BEGIN Texts.WriteString(W, "Ola!"); Texts.WriteLn(W)
  END Greet;

  PROCEDURE TestInts;
  BEGIN
    Texts.WriteInt(W, a, 0); Texts.WriteLn(W);
    Texts.WriteInt(W, b, 0); Texts.WriteLn(W);
    Texts.WriteInt(W, c, 0); Texts.WriteLn(W);
    Texts.WriteInt(W, MI, 0); Texts.WriteLn(W);
    Texts.WriteInt(W, mI, 0); Texts.WriteLn(W);
    Texts.Append(Oberon.Log, W.buf)
  END TestInts;

  PROCEDURE TestCmd;
    VAR mod: Modules.Module;
  BEGIN
    mod := Modules.ThisMod(Modules.main);
    IF mod # NIL THEN
      Texts.WriteString(W, "module=");
      Texts.WriteHex(W, SYSTEM.VAL(LONGINT,mod)); Texts.WriteLn(W);
      cmd := Modules.ThisCommand(mod, Modules.cmd);
      IF cmd # NIL THEN
        Texts.Write(W, "[");
        Texts.WriteString(W, Modules.main);
        Texts.Write(W, "_");
        Texts.WriteString(W, Modules.cmd);
        Texts.WriteString(W, "]=");
        Texts.WriteHex(W, SYSTEM.VAL(LONGINT,cmd)); Texts.WriteLn(W);
        Texts.WriteString(W, "calling..."); Texts.WriteLn(W);
        cmd;
      ELSE
        Texts.WriteString(W, Modules.main);
        Texts.Write(W, "_");
        Texts.WriteString(W, Modules.cmd);
        Texts.WriteString(W, " not found"); Texts.WriteLn(W)
      END
    ELSE
      Texts.WriteString(W, Modules.main);
      Texts.WriteString(W, " module not found"); Texts.WriteLn(W)
    END;
    Texts.Append(Oberon.Log, W.buf);
    Texts.WriteString(W, "main="); Texts.WriteString(W, Modules.main);
    Texts.WriteString(W, " cmd="); Texts.WriteString(W, Modules.cmd);
    Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
  END TestCmd;

  PROCEDURE TestL1(VAR y:L1);
  BEGIN IF y IS L6 THEN Out.String("Level 6"); Out.Ln END
  END TestL1;

  PROCEDURE TestExtension;
    VAR x: L5; y: L6;
  BEGIN y.i6 := 42; Out.Int(y.i6, 0); Out.Ln; TestL1(y);
  END TestExtension;

BEGIN Texts.OpenWriter(W);
  TestInts; TestCmd; TestExtension;
  Oberon.Close
END TestInt.
(* vim:set ts=2 sw=2 et: *)
Some.Thing ~
