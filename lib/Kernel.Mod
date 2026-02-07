MODULE Kernel;
  IMPORT SYSTEM, Unix, Kernal, DynLoad, C := CType, Sys := System;

  CONST
    IdentSize* = Kernal.IdentSize;

  TYPE
    TerminationHandler* = PROCEDURE;
    Module* = Kernal.Module;
    ModuleDesc* = Kernal.ModuleDesc;
    Name* = Kernal.Name;

  VAR
    termHandler: TerminationHandler;
    GCenabled-: BOOLEAN;
    modules-: Module;

  PROCEDURE EmptyHandler;
  END EmptyHandler;

  PROCEDURE Exit*(err: INTEGER);
  BEGIN termHandler; Unix.exit(err)
  END Exit;

  PROCEDURE FreeLibrary*(this: LONGINT);
    VAR res: LONGINT;
  BEGIN res := DynLoad.dlclose(this)
  END FreeLibrary;

  PROCEDURE GC*;
  BEGIN SYSTEM.COLLECT
  END GC;

  PROCEDURE GetAdr*(lib: LONGINT; symbol: ARRAY OF CHAR; VAR adr: LONGINT);
  BEGIN adr := DynLoad.dlsym(lib, symbol)
  END GetAdr;

  PROCEDURE GetClock* (VAR time, date: LONGINT);
    VAR sec: LONGINT;
  BEGIN sec := Unix.time(0); Kernal.GetO2Time(Sys.Short(sec), time, date)
  END GetClock;

  PROCEDURE InstallTermHandler*(h: TerminationHandler);
  BEGIN termHandler := h;
  END InstallTermHandler;

  PROCEDURE LoadLibrary*(file: ARRAY OF CHAR): LONGINT;
    VAR p: C.charPtr1d;
  BEGIN p := NIL; IF file[0] # 0X THEN p := SYSTEM.ADR(file) END;
    RETURN DynLoad.dlopen(p, DynLoad.RTLD_NOW)
  END LoadLibrary;

BEGIN GCenabled := SYSTEM.GC;
  modules := Kernal.GetModuleList();
  termHandler := EmptyHandler;
END Kernel.
(* vim:set ts=2 sw=2 et: *)
