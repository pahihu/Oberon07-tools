MODULE AnonRecImport6;
  IMPORT AnonRec6;

  TYPE
    (*P2 = POINTER TO AnonRec6.R1; (*ERROR: external base type not implemented*)*)

  VAR
    r1: AnonRec6.R1;
    (*p2: P2; *)

BEGIN (*NEW(p2)*)
END AnonRecImport6.
(* vim:set ts=2 sw=2 et:*)
