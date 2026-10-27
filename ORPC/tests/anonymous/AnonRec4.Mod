MODULE AnonRec4; (*Ch.Burrows 17.10.26*)
  TYPE
    R* = RECORD
      a*, b*: RECORD i*: INTEGER END  (*NB. the report say variables in the list has the same type*)
    END ;
    Font* = POINTER TO FontDesc;
    FontDesc* = RECORD
      name*: ARRAY 32 OF CHAR
    END ;
  VAR
    GetHMS*: PROCEDURE(VAR hrs, mins, secs: INTEGER);
END AnonRec4.
(* vim:set ts=2 sw=2 et syn=off:*)
