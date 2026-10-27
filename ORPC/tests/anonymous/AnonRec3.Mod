MODULE AnonRec3;
  TYPE
    (*P0* = POINTER TO T0;  (*ERROR: invalid extension*)*)
    P0* = POINTER TO RECORD END; (*this works, due to hidden RECORD*)
    P1* = POINTER TO RECORD (P0) END;
    T0* = RECORD END ;

END AnonRec3.
(* vim:set ts=2 sw=2 et: *)
