MODULE RandomNumbers;

IMPORT T := Time;

CONST
(* Park-Miller 1993 *)
	a = 48271; m = 7FFFFFFFH; q = m DIV a; r = m MOD a;


VAR z*: LONGINT;

PROCEDURE Time (): LONGINT;
	VAR tv: T.Time;
BEGIN T.GetSysTime (tv); RETURN tv.tv_usec DIV 1000; END Time;

PROCEDURE Uniform* (): LONGREAL; (* returns a random nbr 0 < x < 1 *)
	(*   z = a * z MOD m   by Schrage's method *)
	BEGIN
		z := a*(z MOD q) - r*(z DIV q);
		IF z < 0 THEN INC(z, m) END;
	RETURN (z + 1.0D0) / (m + 1.0D0)
	END Uniform;

PROCEDURE RND* (max: LONGINT): LONGINT;	(* returns an integer in the range 0..max-1 *)
	BEGIN RETURN ENTIER(Uniform () * (max + 1.0D0))
	END RND;

PROCEDURE InitSeed* (seed: LONGINT);
	BEGIN
		IF seed = 0 THEN z := 1 ELSE z := seed END;
	END InitSeed;

BEGIN InitSeed (Time ())
END RandomNumbers.

ORP.Compile jr.RandomNumbers.Mod/s ~
System.Free RandomNumbers ~
