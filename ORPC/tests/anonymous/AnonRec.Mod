MODULE AnonRec;
  TYPE
    P0* = POINTER TO RECORD a*, b*: INTEGER END;
    P1* = POINTER TO RECORD (P0) c*, d*: INTEGER END;
    R2* = RECORD a*, b*: SET END;
    P2* = POINTER TO R2;

END AnonRec.
(* vim:set ts=2 sw=2 et syn=off: *)
