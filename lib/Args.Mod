MODULE Args;
IMPORT Rts, IntStr, RealStr;

VAR argc-: INTEGER;

PROCEDURE GetArg* (n: INTEGER; VAR s: ARRAY OF CHAR);
BEGIN Rts.GetArg (n, s)
END GetArg;

PROCEDURE GetInt* (n: INTEGER): LONGINT;
  VAR s: ARRAY 32 OF CHAR;
BEGIN Rts.GetArg (n, s); RETURN IntStr.Value (s)
END GetInt;

PROCEDURE GetReal* (n: INTEGER): LONGREAL;
  VAR s: ARRAY 32 OF CHAR;
BEGIN Rts.GetArg (n, s); RETURN RealStr.Value (s)
END GetReal;

BEGIN argc := Rts.ArgNumber ()
END Args.
