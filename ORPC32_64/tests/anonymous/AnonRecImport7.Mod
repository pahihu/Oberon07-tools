MODULE AnonRecImport7;
  IMPORT AnonRec7;

  VAR
    first, p: AnonRec7.List;
    afirst, ap: AnonRec7.AnonList;

BEGIN
  first := NIL;
  NEW(p); p.key := 42; p.next := first; first := p;
  afirst := NIL;
  NEW(ap); ap.key := -42; ap.next := afirst; afirst := ap
END AnonRecImport7.
(* vim:set ts=2 sw=2 et:*)
