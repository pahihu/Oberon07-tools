MODULE NamedBaseType;
  CONST
    NameLen* = 32;
  TYPE
    Q* = RECORD i*: INTEGER END ;
    R* = RECORD
      a*, b*: Q
    END ;
    Font* = POINTER TO FontDesc;
    FontName* = ARRAY NameLen OF CHAR;
    FontDesc* = RECORD
      name*: FontName
    END ;
    HMSProc* = PROCEDURE(VAR hrs, mins, secs: INTEGER);
    Descriptor = RECORD END;
  VAR
    GetHMS*: HMSProc;
    dsc*: Descriptor;

  PROCEDURE AssignDsc*(a, b: INTEGER; d: Descriptor);
  BEGIN
  END AssignDsc;

END NamedBaseType.
(* vim:set ts=2 sw=2 et syn=off:*)
