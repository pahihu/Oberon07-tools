MODULE Tests;

IMPORT Timer,M:=MathL;

CONST
  CALIBLOOPS*=10000000;

VAR
  glob:ARRAY 6,6 OF LONGINT;
  T: Timer.Timer;
  Loops-: LONGINT;

TYPE
  Test=RECORD 
  END;
  TestP=POINTER TO Test;

PROCEDURE SetLoops*(x: LONGINT);
BEGIN Loops := x
END SetLoops;

PROCEDURE (obj:TestP) Method;
VAR
BEGIN
END Method;

PROCEDURE Test1*(VAR ticksNeeded:LONGINT; VAR iterations:LONGINT);
VAR
  i:LONGINT;
  lr:LONGREAL;
  LOOPS: LONGINT;
BEGIN LOOPS := Loops;
  Timer.Start(T);
  FOR i:=1 TO LOOPS DO
    lr:=46.6;
    lr:=M.cos(lr);
    lr:=M.tan(lr);
  END;
  ticksNeeded:=Timer.Elapsed(T);
  iterations:=LOOPS; 
END Test1;

PROCEDURE Test2*(VAR ticksNeeded:LONGINT; VAR iterations:LONGINT);
VAR
  i:LONGINT;
  r1,r2:LONGREAL;
  LOOPS: LONGINT;
BEGIN LOOPS := Loops;
  Timer.Start(T);
  FOR i:=1 TO LOOPS DO
    r1:=45.5;
    r2:=34.4;
    r1:=r1+r2;
    r2:=(r1 + r2) * 4.5;
  END;
  ticksNeeded:=Timer.Elapsed(T);
  iterations:=LOOPS; 
END Test2;

PROCEDURE Test3*(VAR ticksNeeded:LONGINT; VAR iterations:LONGINT);
VAR
  i:LONGINT;
  r1,r2:LONGINT;
  b:BOOLEAN;
  LOOPS: LONGINT;
BEGIN LOOPS := 10*Loops;
  Timer.Start(T);
  FOR i:=1 TO LOOPS DO
    r1:=45;
    r2:=34;
    r1:=r1+r2;
    r2:=(r1 + r2) * 4;
    b:=r1 < r2;
  END;
  ticksNeeded:=Timer.Elapsed(T);
  iterations:=LOOPS; 
END Test3;

PROCEDURE Test4*(VAR ticksNeeded:LONGINT; VAR iterations:LONGINT);
VAR
  i,j:LONGINT;
  b:BOOLEAN;
  LOOPS: LONGINT;
BEGIN LOOPS := 5*Loops;
  Timer.Start(T);
  FOR j:=1 TO 5 DO
    FOR j:=1 TO 5 DO
      glob[j,j]:=j+j*6;
    END;
  END;
  j:=3;
  FOR i:=1 TO LOOPS DO
    b:=(glob[j,5-j]+glob[5-j,j])*2 < glob[j,j];
  END;
  ticksNeeded:=Timer.Elapsed(T);
  iterations:=LOOPS; 
END Test4;

PROCEDURE Test5*(VAR ticksNeeded:LONGINT; VAR iterations:LONGINT);
VAR
  i:LONGINT;
  p:TestP;
  LOOPS: LONGINT;
BEGIN LOOPS := 5*Loops;
  NEW(p);
  Timer.Start(T);
  FOR i:=1 TO LOOPS DO
    p.Method;
  END;
  ticksNeeded:=Timer.Elapsed(T);
  iterations:=LOOPS; 
END Test5;

PROCEDURE CalibLoop*(VAR ticksNeeded,iterations:LONGINT);
VAR
  i:LONGINT;
  p:TestP;
BEGIN
  NEW(p);
  Timer.Start(T);
  FOR i:=1 TO CALIBLOOPS DO
  END;
  ticksNeeded:=Timer.Elapsed(T);
  iterations := CALIBLOOPS
END CalibLoop;


BEGIN Loops := 1000000;
END Tests.
