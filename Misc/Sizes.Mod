MODULE Sizes;
IMPORT Out;

VAR x: LONGREAL;
    i: LONGINT;

PROCEDURE Range (msg: ARRAY OF CHAR; min, max: LONGINT);
BEGIN Out.Ln; Out.String (msg); Out.String ('=[');
    Out.Int (min, 0); Out.Char (','); Out.Int (max, 0); Out.Char (']')
END Range;

PROCEDURE RealRange (msg: ARRAY OF CHAR; min, max: LONGREAL);
BEGIN Out.Ln; Out.String (msg); Out.String ('=[');
    Out.LongReal (min, 0); Out.Char (','); Out.LongReal (max, 0); Out.Char (']')
END RealRange;

PROCEDURE PrintSizes ();
BEGIN
        (*Range ('    BYTE', MIN(SYSTEM.BYTE), MAX(SYSTEM.BYTE));*)
        Range ('     SET', MIN (SET),      MAX (SET));
        Range ('    CHAR', MIN (CHAR),     MAX (CHAR));
        Range ('SHORTINT', MIN (SHORTINT), MAX (SHORTINT));
        Range (' INTEGER', MIN (INTEGER),  MAX (INTEGER));
        Range (' LONGINT', MIN (LONGINT),  MAX (LONGINT));
    RealRange ('    REAL', MIN (REAL),     MAX (REAL));
    RealRange ('LONGREAL', MIN (LONGREAL), MAX (LONGREAL))
END PrintSizes;

BEGIN PrintSizes
END Sizes.