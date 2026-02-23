MODULE TestInt;
  IMPORT In, Out;

  VAR d: LONGREAL;
      n: LONGINT;
      s: ARRAY 32 OF CHAR;
      i: INTEGER;

  PROCEDURE Mod(x, y: LONGINT): LONGINT;
    VAR q,r: LONGINT;
  BEGIN q := x DIV y; r := x - q*y; RETURN r
  END Mod;

BEGIN Out.Open; In.Open;
    WHILE In.Done DO
      Out.String ("Enter a number: "); In.Int (i);
      IF ~In.Done THEN
        Out.String (" cannot read integer ");
      ELSE
        Out.String ("i=["); Out.Int (i, 0); Out.String ("]"); Out.Ln;
        Out.String ("i MOD 10H="); Out.Int (-i MOD 10H, 0); Out.Ln;
        Out.String ("i Mod 10H="); Out.Int (Mod(-i, 10H), 0); Out.Ln;
      END;
    END
END TestInt.

(* vim:set ts=2 sw=2 et: *)
