MODULE Hello;
IMPORT Out, Kernal, C := CType, SYSTEM;

TYPE
  StringPtr = C.charPtr1d;
  R0* = RECORD i*: INTEGER END;
  R1* = RECORD (R0) j*: INTEGER END;

VAR
  adr: C.address;
  p: StringPtr;
  tmp: ARRAY 1024 OF CHAR;

PROCEDURE Exchange(src: R0; VAR dst: R0; msg: ARRAY OF CHAR);
BEGIN Out.Ln; Out.String("--- "); Out.String(msg); Out.String(" ---");
  dst(R0) := src;
  Out.Ln; Out.String("--- END ---");
END Exchange;

PROCEDURE PrintR0(r0: R0);
BEGIN Out.Ln; Out.String("r0.i="); Out.Int(r0.i, 0)
END PrintR0;

PROCEDURE PrintR1(r1: R1);
BEGIN
  Out.Ln; Out.String("r1.i="); Out.Int(r1.i, 0);
  Out.String(" r1.j="); Out.Int(r1.j, 0);
END PrintR1;

PROCEDURE TestExchange;
  VAR s0, r0: R0;
      s1, r1: R1;
BEGIN
  s0.i := 1;
  s1.i := 11;
  s1.j := 12;
  Exchange(s0, r0, "0>0"); PrintR0(r0);
  Exchange(s1, r0, "1>0"); PrintR0(r0);
  Exchange(s1, r1, "1>1"); PrintR1(r1);
  Exchange(s0, r1, "0>1"); PrintR0(r0);
END TestExchange;

PROCEDURE StrCopy(VAR dst: ARRAY OF CHAR; src: StringPtr);
  VAR i: INTEGER;
BEGIN i := 0;
  WHILE src[i] # 0X DO dst[i] := src[i]; INC(i) END ;
  dst[i] := 0X
END StrCopy;


BEGIN Out.String('Hello, World!'); Out.Ln;
    adr := Kernal.getenv("PATH");
    IF adr # 0 THEN
        Out.Int(adr, 0); Out.Ln;
        p := SYSTEM.VAL(StringPtr, adr);
        StrCopy(tmp, p);
        Out.String(tmp); Out.Ln
    END ;
    TestExchange
END Hello.
