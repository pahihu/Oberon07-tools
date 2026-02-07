MODULE RayUtils;
  IMPORT MathL;

  TYPE
    Vector* = RECORD
      x*, y*, z*: LONGREAL
    END;

  PROCEDURE Square*(x: LONGREAL): LONGREAL;
  BEGIN RETURN x * x;
  END Square;

  PROCEDURE Magnitude*(x, y, z: LONGREAL): LONGREAL;
  BEGIN RETURN MathL.sqrt(Square(x) + Square(y) + Square(z));
  END Magnitude;

  PROCEDURE UnitVector*(x, y, z: LONGREAL; VAR out: Vector);
    VAR d: LONGREAL;
  BEGIN d := 1.0D0/Magnitude(x, y, z);
    out.x := x * d;
    out.y := y * d;
    out.z := z * d
  END UnitVector;

  PROCEDURE Min(a,b:LONGREAL):LONGREAL;
    VAR ret: LONGREAL;
  BEGIN IF a < b THEN ret := a ELSE ret := b END; RETURN ret
  END Min;

  PROCEDURE MinRoot*(a, b, c: LONGREAL): LONGREAL;
    VAR ret: LONGREAL;
        disc, discrt: LONGREAL;
  BEGIN ret := -1.0;
    IF a = 0.0 THEN ret := (-c)/a;
    ELSE
      disc := Square(b) - 4.0 * a * c;
	    IF disc >= 0.0 THEN
	      discrt := MathL.sqrt(disc);
	      ret := Min(-(b+discrt),discrt-b)/(2.0D0*a)
	    END
    END;
    RETURN ret
  END MinRoot;

END RayUtils.
