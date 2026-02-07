MODULE Sizes;
  IMPORT Out, SYSTEM;

  CONST
		width = 23;

BEGIN
	Out.String("MAX(SET)      = "); Out.Int(MAX(SET), width); Out.Ln;
	Out.String("MIN(CHAR)     = "); Out.Int(MIN(CHAR), width); Out.Ln;
	Out.String("MAX(CHAR)     = "); Out.Int(MAX(CHAR), width); Out.Ln;
	(* Out.String("MIN(BYTE)     = "); Out.Int(MIN(SYSTEM.BYTE), width); Out.Ln;
	Out.String("MAX(BYTE)     = "); Out.Int(MAX(SYSTEM.BYTE), width); Out.Ln; *)
	Out.String("MIN(SHORTINT) = "); Out.Int(MIN(SHORTINT), width); Out.Ln;
	Out.String("MAX(SHORTINT) = "); Out.Int(MAX(SHORTINT), width); Out.Ln;
	Out.String("MIN(INTEGER)  = "); Out.Int(MIN(INTEGER), width); Out.Ln;
	Out.String("MAX(INTEGER)  = "); Out.Int(MAX(INTEGER), width); Out.Ln;
	Out.String("MIN(LONGINT)  = "); Out.Int(MIN(LONGINT), width); Out.Ln;
	Out.String("MAX(LONGINT)  = "); Out.Int(MAX(LONGINT), width); Out.Ln;
	Out.String("MIN(REAL)     = "); Out.Real(MIN(REAL), width); Out.Ln;
	Out.String("MAX(REAL)     = "); Out.Real(MAX(REAL), width); Out.Ln;
	Out.String("MIN(LONGREAL) = "); Out.LongReal(MIN(LONGREAL), width); Out.Ln;
	Out.String("MAX(LONGREAL) = "); Out.LongReal(MAX(LONGREAL), width); Out.Ln;
END Sizes.
