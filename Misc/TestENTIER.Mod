MODULE TestENTIER;
  IMPORT In, Out, RealStr, Oberon, Texts;

  VAR d: LONGREAL;
      n: LONGINT;
      s: ARRAY 32 OF CHAR;
      i: INTEGER;
      S: Texts.Scanner;

BEGIN Out.Open; In.Open;
    Out.String ("Enter a real number: "); In.String (s);
    IF ~In.Done THEN
      Out.String (" cannot read string ");
    ELSE
      Out.String ("s=["); Out.String (s); Out.String ("]"); Out.Ln;
      d := RealStr.Value (s);
      Out.String ("ENTIER("); Out.LongReal (d, 0); Out.String (")=");
      n := ENTIER(d);
      Out.Int (n, 0); Out.Ln
    END;

    Texts.OpenScanner (S, Oberon.Par.text, Oberon.Par.pos);
    Texts.Scan (S);
    Out.String ("S.class="); Out.Int (S.class, 0); Out.Ln
END TestENTIER.

(* vim:set ts=2 sw=2 et: *)
