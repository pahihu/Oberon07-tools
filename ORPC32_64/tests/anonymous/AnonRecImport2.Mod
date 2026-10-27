MODULE AnonRecImport2;
  IMPORT AnonRec2, Out;

  VAR
    p1: AnonRec2.P1;
    i: INTEGER;
    h, n: AnonRec2.Node;

BEGIN 
  Out.Ln;
  IF AnonRec2.p # NIL THEN
    Out.String("AnonRec2.p.i="); Out.Int(AnonRec2.p.i, 0)
  ELSE
    Out.String("empty")
  END ;
  (*ERROR: if base record type not exported, then it is an opaque pointer
  NEW(p1)*)
  h := NIL;
  FOR i := 1 TO 10 DO
    NEW(n); n.value := i; n.next := h; h := n
  END ;
  n := h;
  WHILE n # NIL DO Out.Char(" "); Out.Int(n.value, 0); n := n.next END
END AnonRecImport2.
(* vim:set ts=2 sw=2 et: *)
