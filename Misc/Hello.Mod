MODULE Hello;
IMPORT Out, Kernal, C := CType, SYSTEM;

TYPE StringPtr = C.charPtr1d;
VAR adr: C.address;
    p: StringPtr;
    tmp: ARRAY 1024 OF CHAR;

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
END Hello.
