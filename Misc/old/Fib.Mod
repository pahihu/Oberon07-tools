MODULE Fib;
IMPORT Out, Timer, Rts, IntStr;

VAR elapsed: LONGINT;
    result, n: LONGINT;
    t: Timer.Timer;

PROCEDURE Fibonacci (n: LONGINT): LONGINT;
    VAR ret: LONGINT;
BEGIN
    IF n < 2 THEN
        ret := n
    ELSE
        ret := Fibonacci (n - 1) + Fibonacci (n - 2)
    END;
    RETURN ret
END Fibonacci;

PROCEDURE Usage ();
BEGIN Out.String ('usage: Fib <N>'); Out.Ln; Rts.Terminate
END Usage;

PROCEDURE GetArg (): LONGINT;
    VAR ret: LONGINT;
        arg: ARRAY 64 OF CHAR;
BEGIN ret := 0;
    IF 1 # Rts.ArgNumber () THEN
        Usage
    ELSE
        Rts.GetArg (1, arg);
        ret := IntStr.Value (arg)
    END;
    RETURN ret
END GetArg;

BEGIN n := GetArg ();
    Timer.Start (t);
    result := Fibonacci (n);
    elapsed := Timer.Elapsed (t);
    Out.String ('Fibonacci('); Out.Int (n, 0); Out.String (')='); Out.Int(result, 0);
    Out.String (' elapsed time '); Out.Int (elapsed, 0); Out.String ('ms'); Out.Ln
END Fib.
