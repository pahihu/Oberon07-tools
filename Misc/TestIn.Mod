MODULE TestInt;
  IMPORT In, Out;

  VAR d: LONGREAL;
      n: LONGINT;
      s: ARRAY 32 OF CHAR;
      i: INTEGER;

BEGIN Out.Open; In.Open;
    WHILE In.Done DO
      Out.String ("Enter a number: "); In.Int (i);
      IF ~In.Done THEN
        Out.String (" cannot read integer ");
      ELSE
        Out.String ("i=["); Out.Int (i, 0); Out.String ("]"); Out.Ln;
      END;
    END
END TestInt.

(* vim:set ts=2 sw=2 et: *)
