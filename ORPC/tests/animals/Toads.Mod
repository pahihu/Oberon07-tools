MODULE Toads;
  IMPORT Animals, Out;

  TYPE
    T* = POINTER TO TDesc;
    TDesc* = RECORD (Animals.TDesc) END ;

  VAR methods: Animals.Methods;

  PROCEDURE speak(self: Animals.T);
  BEGIN
    Out.Ln; Out.String("Croak, croak!")
  END speak;

  PROCEDURE New*(s: ARRAY OF CHAR): T;
    VAR p: T;
  BEGIN
    NEW(p);
    p.do := methods;
    p.do.init(p, s);
    RETURN p
  END New;

BEGIN
  NEW(methods);
  Animals.InitMethods(methods);
  methods.speak := speak
END Toads.
(* vim:set ts=2 sw=2 et: *)
