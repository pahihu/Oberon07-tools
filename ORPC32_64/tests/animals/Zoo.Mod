MODULE Zoo;
  IMPORT Main, Storage, Animals, Ducks, Dogs, Toads, Out;

  VAR a: Animals.T;
      o: Dogs.T;
      u: Ducks.T;
      t: Toads.T;

  PROCEDURE Check(a: Animals.T);
  BEGIN
    IF a IS Dogs.T THEN
        Out.Ln; Out.String("It is a Dog.")
    ELSIF a IS Ducks.T THEN
        Out.Ln; Out.String("It is a Duck.")
    ELSIF a IS Toads.T THEN
        Out.Ln; Out.String("It is a Toad.")
    END ;
    CASE a OF
      Dogs.T:
        Out.Ln; Out.String("It is a Dog.") |
      Ducks.T:
        Out.Ln; Out.String("It is a Duck.") |
      Toads.T:
        Out.Ln; Out.String("It is a Toad.")
    END
  END Check;

BEGIN
  a := Animals.New("Gibberish");
  a.do.setAge(a, 99);
  a.do.introduce(a);

  o := Dogs.New("Scooby Doo");
  o.do.setAge(o, 51);
  o.do.introduce(o);

  u := Ducks.New("Donald Duck");
  u.do.setAge(u, 87);
  u.do.introduce(u);

  t := Toads.New("Ed Bighead");
  t.do.setAge(t, 28);
  t.do.introduce(t);

  Check(o);
  Check(u);
  Check(t)

END Zoo.
(* vim:set ts=2 sw=2 et: *)
