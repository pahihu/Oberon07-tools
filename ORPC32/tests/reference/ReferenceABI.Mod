MODULE ReferenceABI;
TYPE Rec* = RECORD n*: INTEGER END;
  Fixed* = ARRAY 3 OF INTEGER;
  Reader* = PROCEDURE (a: ARRAY OF INTEGER; r: Rec): INTEGER;
  Writer* = PROCEDURE (VAR a: ARRAY OF INTEGER; VAR r: Rec);
PROCEDURE ReadOpen*(a: ARRAY OF INTEGER): INTEGER;
RETURN LEN(a)*100+a[0]+a[LEN(a)-1]
END ReadOpen;
PROCEDURE ForwardRead*(a: ARRAY OF INTEGER): INTEGER;
RETURN ReadOpen(a)
END ForwardRead;
PROCEDURE ReadFixed*(a: Fixed): INTEGER;
RETURN ForwardRead(a)
END ReadFixed;
PROCEDURE ReadRec*(r: Rec): INTEGER;
RETURN r.n
END ReadRec;
PROCEDURE ForwardRec*(r: Rec): INTEGER;
RETURN ReadRec(r)
END ForwardRec;
PROCEDURE ReadBoth*(a: ARRAY OF INTEGER; r: Rec): INTEGER;
RETURN ForwardRead(a)+ForwardRec(r)
END ReadBoth;
PROCEDURE WriteOpen*(VAR a: ARRAY OF INTEGER);
BEGIN INC(a[0])
END WriteOpen;
PROCEDURE ForwardWrite*(VAR a: ARRAY OF INTEGER);
BEGIN WriteOpen(a)
END ForwardWrite;
PROCEDURE WriteFixed*(VAR a: Fixed);
BEGIN ForwardWrite(a)
END WriteFixed;
PROCEDURE WriteRec*(VAR r: Rec);
BEGIN INC(r.n)
END WriteRec;
PROCEDURE ForwardWriteRec*(VAR r: Rec);
BEGIN WriteRec(r)
END ForwardWriteRec;
PROCEDURE WriteBoth*(VAR a: ARRAY OF INTEGER; VAR r: Rec);
BEGIN ForwardWrite(a); ForwardWriteRec(r)
END WriteBoth;
PROCEDURE ObserveArray*(a: Fixed; VAR same: Fixed): INTEGER;
BEGIN INC(same[0], 10)
RETURN a[0]
END ObserveArray;
PROCEDURE ObserveRec*(r: Rec; VAR same: Rec): INTEGER;
BEGIN INC(same.n, 10)
RETURN r.n
END ObserveRec;
PROCEDURE CopyOpen*(VAR dst: ARRAY OF INTEGER; src: ARRAY OF INTEGER);
BEGIN dst := src
END CopyOpen;
PROCEDURE CharLength*(s: ARRAY OF CHAR): INTEGER;
BEGIN ASSERT(s[0]="a")
RETURN LEN(s)
END CharLength;
PROCEDURE ForwardChars*(s: ARRAY OF CHAR): INTEGER;
RETURN CharLength(s)
END ForwardChars;
END ReferenceABI.
