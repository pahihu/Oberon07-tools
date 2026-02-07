MODULE TestInt1;
  IMPORT SYSTEM, C := CType, Out, InOut, DynLoad;
  CONST a = 1234567890;
        b = 2134567890;
        c = 23456;
        MI = MAX(INTEGER);
        mI = -MIN(INTEGER);
        MLI = MAX(LONGINT);
        mLI = MIN(LONGINT);
  VAR h: LONGINT;
      ret: LONGINT;
      msg: C.charPtr1d;
      cmd: C.Proc;

  PROCEDURE Greet*;
  BEGIN Out.String("Ola!"); Out.Ln
  END Greet;

BEGIN Out.Int(a, 0); Out.Ln;
  Out.Int(b, 0); Out.Ln;
  Out.Int(c, 0); Out.Ln;
  Out.Int(MI, 0); Out.Ln;
  Out.Int(mI, 0); Out.Ln;
  h := DynLoad.dlopen(NIL, DynLoad.RTLD_NOW);
  IF h # 0 THEN
    Out.String("handle="); InOut.Hex(h); Out.Ln;
    cmd := SYSTEM.VAL(C.Proc,DynLoad.dlsym(h, "TestInt1_Greet"));
    Out.String("TestInt1_Greet="); InOut.Hex(SYSTEM.VAL(LONGINT,cmd)); Out.Ln;
    Out.String("calling TestInt1_Greet()..."); Out.Ln;
    cmd;
    ret := DynLoad.dlclose(h);
  ELSE
    msg := DynLoad.dlerror();
    Out.String("dlopen error: "); Out.String(msg^); Out.Ln
  END
END TestInt1.
(* vim:set ts=2 sw=2 et: *)
