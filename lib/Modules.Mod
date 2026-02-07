MODULE Modules;
  IMPORT SYSTEM, Kernel, Args;

  CONST
    ModNameLen* = Kernel.IdentSize;
    cmdNotFound* = 6;
    done* = 0;
    modNotFound* = 5;
  
  TYPE
    Command* = PROCEDURE;
    Module* = Kernel.Module;
    ModuleDesc* = Kernel.ModuleDesc;
    ModuleName* = Kernel.Name;

  VAR
    hMain: LONGINT;
    res*: INTEGER;
    main*: ModuleName;
    cmd*: ARRAY Kernel.IdentSize OF CHAR;

  PROCEDURE InitMain;
    VAR i, j, lastDot: INTEGER;
        s: ARRAY 256 OF CHAR;
  BEGIN Args.GetArg(0, s);
    i := 0; j := 0; lastDot := -1;
    WHILE s[i] # 0X DO
      IF (s[i] = "/") OR (s[i] = "\") THEN
        j := 0; lastDot := -1; INC(i)
      ELSE
        IF s[i] = "." THEN lastDot := j END;
        s[j] := s[i];
        INC(i); INC(j);
      END
    END;
    IF lastDot > 0 THEN
      s[lastDot] := 0X
    ELSE
      s[j] := 0X
    END;
    IF j >= ModNameLen THEN s[ModNameLen-1] := 0X END;
    COPY(s, main)
  END InitMain;

  PROCEDURE InitCmd;
    VAR i: INTEGER;
        s: ARRAY 256 OF CHAR;
  BEGIN cmd[0] := 0X;
    IF Args.argc > 0 THEN
      Args.GetArg(1, s);
      i := 0;
      WHILE (s[i] # 0X) & (i < Kernel.IdentSize-1) DO
        cmd[i] := s[i]; INC(i)
      END;
      cmd[i] := 0X
    END
  END InitCmd;

  PROCEDURE MakeExtName(VAR s: ARRAY OF CHAR;
                          modName: Kernel.Name; cmdName: ARRAY OF CHAR);
    VAR i, j: INTEGER;
  BEGIN j := 0; i := 0;
    WHILE modName[i] # 0X DO s[j] := modName[i]; INC(i); INC(j) END;
    s[j] := "_"; INC(j);
    i := 0;
    WHILE cmdName[i] # 0X DO s[j] := cmdName[i]; INC(i); INC(j) END;
    s[j] := 0X
  END MakeExtName;

  PROCEDURE ThisCommand*(mod: Module; name: ARRAY OF CHAR): Command;
    VAR s: ARRAY 2*ModNameLen+2 OF CHAR;
        adr: LONGINT;
  BEGIN res := cmdNotFound;
    MakeExtName(s, mod.name, name);
    Kernel.GetAdr(hMain, s, adr);
    IF adr # 0 THEN res := done END;
    RETURN SYSTEM.VAL(Command,adr)
  END ThisCommand;

  PROCEDURE ThisMod*(name: ARRAY OF CHAR): Module;
    VAR p, ret: Module;
  BEGIN res := modNotFound;
    ret := NIL; p := Kernel.modules;
    WHILE (p # NIL) & (ret = NIL) DO
      IF name = p.name THEN ret := p; res := done END;
      p := p.next
    END; RETURN ret
  END ThisMod;

BEGIN InitMain; InitCmd; hMain := Kernel.LoadLibrary("")
END Modules.
(* vim:set ts=2 sw=2 et: *)
