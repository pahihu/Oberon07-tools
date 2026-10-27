MODULE Animals;
  IMPORT Out;

  CONST NameLen = 16; MaxAge = 125;

  TYPE
      T* = POINTER TO TDesc;
      Methods* = POINTER TO MDesc;
      MDesc* = RECORD
        init*: PROCEDURE(self: T; s: ARRAY OF CHAR);
        speak*: PROCEDURE(self: T);
        setAge*: PROCEDURE(self: T; n: INTEGER);
        introduce*: PROCEDURE(self: T)
      END ;
      TDesc* = RECORD
        do*: Methods;
        name*: ARRAY NameLen OF CHAR;
        age*: INTEGER
      END;

  VAR methods: Methods;

  PROCEDURE InitMethods*(m: Methods);
  BEGIN m^ := methods^
  END InitMethods;

  PROCEDURE speak(self: T);
  BEGIN Out.Ln; Out.String("Dunno what to do...")
  END speak;

  PROCEDURE init(self: T; s: ARRAY OF CHAR);
  BEGIN
    ASSERT(LEN(s) <= NameLen);
    self.name := s
  END init;

  PROCEDURE setAge(self: T; n: INTEGER);
  BEGIN
    ASSERT((0 <= n) & (n < MaxAge), 10);
    self.age := n
  END setAge;

  PROCEDURE introduce(self: T);
  BEGIN
    Out.Ln; Out.String("My name is "); Out.String(self.name);
    Out.String(", I am "); Out.Int(self.age, 0); Out.Char(".");
    self.do.speak(self)
  END introduce;

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
  methods.init := init;
  methods.speak := speak;
  methods.setAge := setAge;
  methods.introduce := introduce
END Animals.
(* vim:set ts=2 sw=2 et: *)
