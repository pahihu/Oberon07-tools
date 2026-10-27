MODULE ForeignMain;
IMPORT F := Foreign, E := ForeignExport;
VAR x: INTEGER; data: ARRAY 3 OF INTEGER; callback: F.Transform;
PROCEDURE Nested;
  PROCEDURE InnerExternal ["MyLib_Local"] (x: INTEGER): INTEGER;
BEGIN ASSERT(InnerExternal(4)=16)
END Nested;
BEGIN ASSERT(F.GetValue()=6);
  F.SetValue(10); ASSERT(F.Add(2, 3)=5); ASSERT(F.GetValue()=10);
  callback := F.Twice; ASSERT(callback(7)=14); ASSERT(F.Apply(F.Twice, 9)=18);
  x := 5; F.Adjust(x, 3); ASSERT(x=8);
  data[0] := 2; data[1] := 3; data[2] := 4; ASSERT(F.Sum(data)=9);
  ASSERT(F.Scale(2.0)=5.0); F.Touch; ASSERT(F.GetValue()=11);
  ASSERT(F.CApply(F.Twice, 10)=20); callback := F.GetCallback(); ASSERT(callback(11)=22);
  ASSERT(E.Add(8, 9)=17); E.SetValue(20); ASSERT(F.GetValue()=20);
  F.CheckLocal; Nested
END ForeignMain.
