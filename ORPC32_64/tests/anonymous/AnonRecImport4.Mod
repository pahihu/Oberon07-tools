MODULE AnonRecImport4;
  IMPORT AnonRec4;

  VAR x*, y*: AnonRec4.R;

BEGIN
  (*ERROR: illegal assignment*)
  x.b.i := 42;
  x.a := x.b
END AnonRecImport4.
(* vim:set ts=2 sw=2 et syn=off:*)
