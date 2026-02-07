MODULE TestFib;
IMPORT Out, Timer, Rts, IntStr, InOut, Args;

CONST MaxCalls = 50;

VAR elapsed: LONGINT;
    t: Timer.Timer;
    n, result: LONGINT;
    Calls: ARRAY MaxCalls OF LONGREAL;


PROCEDURE PrintFib (n: LONGINT; result: LONGREAL; elapsed: LONGINT);
BEGIN Out.Ln; Out.String ('Fib('); Out.Int (n, 0); Out.String (')='); Out.LongReal (result, 0);
    IF elapsed # 0 THEN
        Out.String (' elapsed '); Out.Int (elapsed, 0); Out.String ('ms')
    END
END PrintFib;

PROCEDURE PrintFibFmt (n, result: LONGINT);
BEGIN InOut.PrintFmt ('\nFib(%d)=%d', n, result, '')
END PrintFibFmt;

PROCEDURE PrintFibReal (n: LONGINT; result: LONGREAL);
BEGIN Out.Ln; Out.String ('Fib('); Out.Int (n, 0); Out.String (')='); Out.LongReal (result, 0)
END PrintFibReal;

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


(* -MORs    1024M
   -MOs     1020M
   -M        446M
*)
PROCEDURE BenchFib ();
    VAR n, nth, elapsed: LONGINT;
        callsPerSec: LONGINT;
BEGIN InitCalls;
    n := 9; elapsed := 0;
    WHILE elapsed < 1000 DO
        INC(n);
        Timer.Start (t); nth := Fibonacci (n); elapsed := Timer.Elapsed (t);
        PrintFib (n, nth, elapsed)
    END;
    callsPerSec := ENTIER (Calls[n] * 1000.0D0 / elapsed);
    Out.Ln; Out.Int (callsPerSec, 0); Out.String (' calls/sec')
END BenchFib;


PROCEDURE PrintArgs ();
    VAR i: INTEGER;
        arg: ARRAY 64 OF CHAR;
BEGIN
    FOR i := 0 TO Args.argc DO
        Args.GetArg (i, arg);
        InOut.PrintFmt ('\nArg%d=%s', i, 0, arg);
    END
END PrintArgs;

PROCEDURE GetArg (): LONGINT;
    VAR arg: ARRAY 64 OF CHAR;
        n: LONGINT;
BEGIN n := 0;
    IF 1 # Args.argc THEN
        Out.String ('usage: Fib <N>'); Rts.Terminate
    ELSE
        Args.GetArg (1, arg);
        n := IntStr.Value (arg)
    END;
    RETURN n
END GetArg;

PROCEDURE TestPrintFmt (n: LONGINT);
    VAR i, elapsed1, elapsed2: LONGINT;
BEGIN
    Timer.Start (t);
    FOR i := 0 TO n-1 DO PrintFib (41, 165580141, 0) END;
    elapsed1 := Timer.Elapsed (t);
    
    Timer.Start (t);
    FOR i := 0 TO n-1 DO PrintFibFmt (41, 165580141) END;
    elapsed2 := Timer.Elapsed (t);
    InOut.PrintFmt ('\nOut=%dms vs PrintFmt=%dms', elapsed1, elapsed2, '')
END TestPrintFmt;

PROCEDURE TestHex (n: LONGINT);
    VAR i, elapsed1, elapsed2: LONGINT;
BEGIN
    Timer.Start (t);
    FOR i := 0 TO n-1 DO InOut.Hex (165580141) END;
    elapsed1 := Timer.Elapsed (t);
    
    Timer.Start (t);
    FOR i := 0 TO n-1 DO InOut.Hex2 (165580141) END;
    elapsed2 := Timer.Elapsed (t);
    InOut.PrintFmt ('\nHex=%dms vs Hex2=%dms', elapsed1, elapsed2, '')
END TestHex;

BEGIN n := GetArg ();
    Timer.Start (t); result := Fibonacci (n); elapsed := Timer.Elapsed (t);
    PrintFib (n, result, elapsed);
    BenchFib;
    (* TestPrintFmt (1000); TestHex (5000); *)
END TestFib.