MODULE Hello;
IMPORT Out, Random := RandomNumbers;

VAR x: LONGREAL;
    i: LONGINT;

PROCEDURE Range (msg: ARRAY OF CHAR; min, max: LONGINT);
BEGIN Out.String (msg); Out.String ('=[');
    Out.Int (min, 0); Out.Char (','); Out.Int (max, 0); Out.Char (']');
    Out.Ln
END Range;

PROCEDURE RealRange (msg: ARRAY OF CHAR; min, max: LONGREAL);
BEGIN Out.String (msg); Out.String ('=[');
    Out.LongReal (min, 0); Out.Char (','); Out.LongReal (max, 0); Out.Char (']');
    Out.Ln
END RealRange;

PROCEDURE Sizes ();
BEGIN
        Range ('     SET', MIN (SET),      MAX (SET));
        Range ('    CHAR', MIN (CHAR),     MAX (CHAR));
        Range ('SHORTINT', MIN (SHORTINT), MAX (SHORTINT));
        Range (' INTEGER', MIN (INTEGER),  MAX (INTEGER));
        Range (' LONGINT', MIN (LONGINT),  MAX (LONGINT));
    RealRange ('    REAL', MIN (REAL),     MAX (REAL));
    RealRange ('LONGREAL', MIN (LONGREAL), MAX (LONGREAL))
END Sizes;

PROCEDURE RollDice ();
    VAR i: INTEGER;
BEGIN FOR i := 1 TO 5 DO Out.Int (Random.RND (10), 0); Out.Ln END
END RollDice;

BEGIN x := 3.1245D0; i := 31415369;
   Random.InitSeed (i);
   Sizes; Out.Ln; Out.String('Hello, World!'); Out.Ln;
   RollDice;
   Out.String ('ENTIER(1.23)='); Out.Int (ENTIER (1.23), 0); Out.Ln;
   Out.String ('ENTIER(-1.23)='); Out.Int (ENTIER (-1.23), 0); Out.Ln;
   Out.String ('ENTIER(x)='); Out.Int (ENTIER (x), 0); Out.Ln;
   x := LONGREAL (i); Out.LongReal (x, 0); Out.Ln
END Hello.