MODULE Kernal ["C"] EXTERNAL ["Kernal.c"];
  IMPORT Files, C := CType;

  CONST
    IdentSize* = 48;
  
  TYPE
    Type* = POINTER TO TypeDesc;
    Module* = POINTER TO ModuleDesc;

    TypeDesc* = RECORD
      name-: ARRAY IdentSize OF CHAR;
      module-: Module;
      level-: INTEGER;
      size-: LONGINT;
      next-: Type
    END;

    Name* = ARRAY IdentSize OF CHAR;
    ModuleId* = INTEGER;
    ModuleDesc* = RECORD
      next-: Module;
      name-: Name;
      key-: ModuleId;
      tdlist-: Type
    END;

  PROCEDURE GetModuleList* ["get_module_list"] (): Module;
  (*PROCEDURE AddModule* ["add_module"] (name: ARRAY OF CHAR): ModuleId;*)
  (*PROCEDURE GetModule* ["get_module"] (id: ModuleId): Module;*)
  PROCEDURE GetO2Time* ["get_o2time"] (sec: C.int; VAR t, d: C.longint);

END Kernal.
(* vim:set ts=2 sw=2 et: *)
