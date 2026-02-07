MODULE Fib;
IMPORT Out, Timer;

CONST MaxCalls = 50;

VAR Calls: ARRAY MaxCalls OF LONGREAL;


PROCEDURE PrintFib (n: LONGINT; result: LONGREAL; elapsed: LONGINT);
BEGIN Out.String ('Fib('); Out.Int (n, 0); Out.String (')='); Out.LongReal (result, 0);
    IF elapsed # 0 THEN
        Out.String (' elapsed '); Out.Int (elapsed, 0); Out.String ('ms')
    END;
    Out.Ln
END PrintFib;


PROCEDURE Fibonacci (n: LONGINT): LONGINT;
    VAR ret: LONGINT;
BEGIN
    IF n < 2 THEN ret := n
    ELSE ret := Fibonacci (n - 1) + Fibonacci (n - 2)
    END;
    RETURN ret
END Fibonacci;

    
PROCEDURE InitCalls ();
    VAR i: INTEGER;
        a, b, c: LONGREAL;
BEGIN Calls[0] := 1.0D0; Calls[1] := 1.0D0;
    FOR i := 2 TO MaxCalls-1 DO
        Calls[i] := Calls[i-1] + Calls[i-2] + 1;
        PrintFib (i, Calls[i], 0);
    END
END InitCalls;


(*           Rizsa  M2Pro
    -MORs    1024M  2722M
    -MOs     1020M  2515M
    -M        446M   788M
*)
PROCEDURE BenchFib ();
    VAR n, nth, elapsed: LONGINT;
        t: Timer.Timer;
        callsPerSec: LONGINT;
BEGIN InitCalls;
    n := 9; elapsed := 0;
    WHILE elapsed < 1000 DO
        INC(n);
        Timer.Start (t); nth := Fibonacci (n); elapsed := Timer.Elapsed (t);
        PrintFib (n, nth, elapsed)
    END;
    callsPerSec := ENTIER (Calls[n] * 1000.0D0 / elapsed);
    Out.Int (callsPerSec, 0); Out.String (' calls/sec'); Out.Ln
END BenchFib;


BEGIN BenchFib
END Fib.
