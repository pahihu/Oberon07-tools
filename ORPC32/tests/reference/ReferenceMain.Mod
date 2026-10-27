MODULE ReferenceMain;
IMPORT R := ReferenceABI, B := ReferenceBridge;
VAR a: R.Fixed; r: R.Rec; short: ARRAY 2 OF INTEGER;
  reader: R.Reader; writer: R.Writer;
BEGIN a[0] := 2; a[1] := 3; a[2] := 4; r.n := 7;
  ASSERT(R.ReadFixed(a)=306); ASSERT(R.ForwardRec(r)=7);
  ASSERT(B.Read(a, r)=313);
  R.WriteFixed(a); R.ForwardWriteRec(r); ASSERT((a[0]=3) & (r.n=8));
  B.Write(a, r); ASSERT((a[0]=4) & (r.n=9));
  reader := R.ReadBoth; writer := R.WriteBoth;
  ASSERT(B.ThroughReader(reader, a, r)=317);
  B.ThroughWriter(writer, a, r); ASSERT((a[0]=5) & (r.n=10));
  ASSERT(R.ObserveArray(a, a)=15); ASSERT(R.ObserveRec(r, r)=20);
  short[0] := 91; short[1] := 92;
  R.CopyOpen(a, short); ASSERT((a[0]=91) & (a[1]=92) & (a[2]=4));
  ASSERT(R.ForwardChars("abc")=4)
END ReferenceMain.
