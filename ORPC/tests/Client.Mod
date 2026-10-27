MODULE Client;
IMPORT R := Records, Basic;
VAR answer*: INTEGER; value*: R.Derived;
PROCEDURE Run*;
VAR p: R.Q; a: Basic.A;
BEGIN R.Test; Basic.Run;
  value.x := 3; value.y := 8;
  NEW(p); p.x := 2; p.y := 6;
  R.SetBase(p^); a[0] := p.x;
  answer := R.result + Basic.count + a[0] + value.y
END Run;
BEGIN answer := 100
END Client.
