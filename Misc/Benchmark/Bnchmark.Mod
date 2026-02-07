MODULE Bnchmark;

IMPORT Out,IFS,T:=Tests;

CONST
  (*NPOINTS = 100000; LOOPS = 1000000;*)
  NPOINTS = 500000; LOOPS = 5000000;

VAR
  looptime:LONGINT;

PROCEDURE WriteTime(txt:ARRAY OF CHAR; time,loops:LONGINT);
VAR
  corr:LONGINT;
BEGIN
  corr:=ENTIER((looptime*(loops DIV 100000)) / (T.CALIBLOOPS DIV 100000));
  Out.String(txt); Out.String(": "); Out.Int(time,0); Out.Char(" "); Out.Int(corr,0);
  Out.Ln;
END WriteTime;


PROCEDURE ProgMain*;
VAR 
  time,iterations:LONGINT;
  diff:LONGINT;
BEGIN
  T.SetLoops(LOOPS);
  IFS.Init;
  IFS.Draw(NPOINTS,diff,time);
  Out.String("xi - eta               : "); Out.Int(diff,0); Out.Ln;
  Out.String("msec needed for fern   : "); Out.Int(time,0); Out.Ln;
  T.CalibLoop(looptime,iterations); 
  WriteTime("empty loop             ",looptime,iterations);
  T.Test1(time,iterations); WriteTime("module Float functions ",time,iterations);
  T.Test2(time,iterations); WriteTime("float expression       ",time,iterations);
  T.Test3(time,iterations); WriteTime("int expression         ",time,iterations);
  T.Test4(time,iterations); WriteTime("global array access    ",time,iterations);
  T.Test5(time,iterations); WriteTime("method invocation      ",time,iterations);
END ProgMain;

BEGIN ProgMain
END Bnchmark.
