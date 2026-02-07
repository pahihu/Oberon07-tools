MODULE ComplexL;
	IMPORT MathL;

	TYPE
		LONGCOMPLEX* = RECORD
			re-: LONGREAL;
			im-: LONGREAL
		END;

  PROCEDURE init*(VAR z: LONGCOMPLEX; re, im: LONGREAL);
  BEGIN z.re := re; z.im := im
  END init;

	PROCEDURE add*(VAR z: LONGCOMPLEX; VAR w: LONGCOMPLEX);
	BEGIN
		z.re := z.re + w.re;
		z.im := z.im + w.im
	END add;

	PROCEDURE sub*(VAR z: LONGCOMPLEX; VAR w: LONGCOMPLEX);
	BEGIN
		z.re := z.re - w.re;
		z.im := z.im - w.im
	END sub;

	PROCEDURE mul*(VAR z: LONGCOMPLEX; VAR w: LONGCOMPLEX);
		VAR re, im: LONGREAL;
	BEGIN
		re := z.re * w.re - z.im * w.im;
		im := z.re * w.im + z.im * w.re;
		z.re := re; z.im := im
	END mul;

	PROCEDURE reciprocal*(VAR z: LONGCOMPLEX; VAR w: LONGCOMPLEX);
		VAR re, im, x2y2: LONGREAL;
	BEGIN x2y2 := w.re * w.re + w.im * w.im;
		z.re := w.re / x2y2;
		z.im := -1.0 * w.im / x2y2
	END reciprocal;
	
	PROCEDURE div*(VAR z: LONGCOMPLEX; VAR w: LONGCOMPLEX);
		VAR w1: LONGCOMPLEX;
	BEGIN reciprocal(w1, w); mul(z, w1)
	END div;

	PROCEDURE abs*(VAR z: LONGCOMPLEX): LONGREAL;
	BEGIN RETURN (z.re * z.re + z.im * z.im)
	END abs;

	PROCEDURE arg*(VAR z: LONGCOMPLEX): LONGREAL;
		VAR r: LONGREAL;
	BEGIN
		IF z.re > 0.0 THEN
			r := MathL.arctan(z.im / z.re)
		ELSIF (z.re < 0.0) & (z.im >= 0.0) THEN
			r := MathL.arctan(z.im / z.re) + MathL.pi
		ELSIF (z.re < 0.0) & (z.im < 0.0) THEN
			r := MathL.arctan(z.im / z.re) - MathL.pi
		ELSIF (z.re = 0.0) & (z.im > 0.0) THEN
			r := 0.5 * MathL.pi;
		ELSIF (z.re = 0.0) & (z.im < 0.0) THEN
			r := -0.5 * MathL.pi
		ELSE ASSERT(FALSE, 1)
		END
	END arg;

	PROCEDURE conj*(VAR z: LONGCOMPLEX);
	BEGIN z.im := 0 - z.im
	END conj;

END ComplexL.

(* vim:set ts=2 sw=2 et: *)
