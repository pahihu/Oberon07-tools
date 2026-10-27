MODULE ReferenceBridge;
IMPORT R := ReferenceABI;
PROCEDURE Read*(a: ARRAY OF INTEGER; r: R.Rec): INTEGER;
RETURN R.ReadBoth(a, r)
END Read;
PROCEDURE Write*(VAR a: ARRAY OF INTEGER; VAR r: R.Rec);
BEGIN R.WriteBoth(a, r)
END Write;
PROCEDURE ThroughReader*(f: R.Reader; a: ARRAY OF INTEGER; r: R.Rec): INTEGER;
RETURN f(a, r)
END ThroughReader;
PROCEDURE ThroughWriter*(f: R.Writer; VAR a: ARRAY OF INTEGER; VAR r: R.Rec);
BEGIN f(a, r)
END ThroughWriter;
END ReferenceBridge.
