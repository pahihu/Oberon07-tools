MODULE Complex;
  IMPORT Math;

  TYPE
    COMPLEX* = RECORD
      re-: REAL;
      im-: REAL
    END;

  PROCEDURE init*(VAR z: COMPLEX; re, im: REAL);
  BEGIN z.re := re; z.im := im
  END init;

	PROCEDURE add*(VAR z: COMPLEX; VAR w: COMPLEX);
	BEGIN
		z.re := z.re + w.re;
		z.im := z.im + w.im
	END add;

	PROCEDURE sub*(VAR z: COMPLEX; VAR w: COMPLEX);
	BEGIN
		z.re := z.re - w.re;
		z.im := z.im - w.im
	END sub;

	PROCEDURE mul*(VAR z: COMPLEX; VAR w: COMPLEX);
		VAR re, im: REAL;
	BEGIN
		re := z.re * w.re - z.im * w.im;
		im := z.re * w.im + z.im * w.re;
		z.re := re; z.im := im
	END mul;

	PROCEDURE reciprocal*(VAR w: COMPLEX; VAR z: COMPLEX);
		VAR re, im, x2y2: REAL;
	BEGIN x2y2 := z.re * z.re + z.im * z.im;
		w.re := z.re / x2y2;
		w.im := -1.0 * z.im / x2y2
	END reciprocal;
	
	PROCEDURE div*(VAR z: COMPLEX; VAR w: COMPLEX);
		VAR w1: COMPLEX;
	BEGIN reciprocal(w1, w); mul(z, w1)
	END div;

	PROCEDURE abs*(z: COMPLEX): REAL;
	BEGIN RETURN (z.re * z.re + z.im * z.im)
	END abs;

	PROCEDURE arg*(VAR z: COMPLEX): REAL;
		VAR r: REAL;
	BEGIN
		IF z.re > 0.0 THEN
			r := Math.arctan(z.im / z.re)
		ELSIF (z.re < 0.0) & (z.im >= 0.0) THEN
			r := Math.arctan(z.im / z.re) + Math.pi
		ELSIF (z.re < 0.0) & (z.im < 0.0) THEN
			r := Math.arctan(z.im / z.re) - Math.pi
		ELSIF (z.re = 0.0) & (z.im > 0.0) THEN
			r := 0.5 * Math.pi;
		ELSIF (z.re = 0.0) & (z.im < 0.0) THEN
			r := -0.5 * Math.pi
		ELSE ASSERT(FALSE, 1)
		END
	END arg;

	PROCEDURE conj*(VAR w: COMPLEX; VAR z: COMPLEX);
	BEGIN
		w.re := z.re;
		w.im := 0.0 - z.im
	END conj;

	PROCEDURE ln*(VAR w: COMPLEX; VAR z: COMPLEX);
	BEGIN
		w.re := Math.ln(abs(z));
		w.im := arg(z)
	END ln;

END Complex.

(* vim:set ts=2 sw=2 et: *)
