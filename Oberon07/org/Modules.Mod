MODULE Modules ["C"] EXTERNAL [""];
  CONST MnLength* = 32;
  
  TYPE
    Module* = POINTER TO ModDesc;
    ModuleName* = ARRAY MnLength OF CHAR;
    ModDesc* = RECORD
      name*: ModuleName;
      next*: Module;
      key*, num*, size*, refcnt*: LONGINT;
      data*, code*, imp*, cmd*, ent*, ptr*, unused*: LONGINT  (*addresses*)
    END ;
END Modules.
