MODULE Porto;
  IMPORT SYSTEM;

  CONST
    CharMask* = 100H;

  TYPE
    Address* = LONGINT;

  PROCEDURE Bits*(x: LONGINT): SET;
  BEGIN RETURN SYSTEM.VAL(SET, x)
  END Bits;

  PROCEDURE Ord*(x: SET): LONGINT;
  BEGIN RETURN SYSTEM.VAL(LONGINT, x)
  END Ord;

  PROCEDURE ExtractChar*(x, y: LONGINT): LONGINT;
  BEGIN RETURN ASH(x, -8 * y) MOD CharMask
  END ExtractChar;

END Porto.
(* vim:set ts=2 sw=2 et:*)
