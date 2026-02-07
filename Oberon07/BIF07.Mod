MODULE BIF07;
  IMPORT SYSTEM, Sys := System;

  PROCEDURE FLT* (n: LONGINT): REAL;
  BEGIN RETURN n + 0.0E0
  END FLT;
  
  PROCEDURE ASR* (x: Sys.Integer; y: Sys.Integer): Sys.Integer;
  BEGIN RETURN Sys.Short(ASH(x, -y))
  END ASR;

  PROCEDURE ROR* (x: Sys.Integer; y: Sys.Integer): Sys.Integer;
  BEGIN RETURN SYSTEM.ROT(x, -y)
  END ROR;

  PROCEDURE LSL* (x: Sys.Integer; y: Sys.Integer): Sys.Integer;
  BEGIN RETURN SYSTEM.LSH(x, y)
  END LSL;

  PROCEDURE FLOOR* (x: REAL): LONGINT;
  BEGIN RETURN ENTIER(x)
  END FLOOR;

  PROCEDURE FLOORL* (x: LONGREAL): LONGINT;
  BEGIN RETURN ENTIER(x)
  END FLOORL;

END BIF07.

(* vim:set ts=2 sw=2 et: *)
