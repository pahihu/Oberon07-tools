MODULE ComplexConv;
  IMPORT Complex, ComplexL;

  PROCEDURE Short*(VAR z: ComplexL.LONGCOMPLEX; VAR w: Complex.COMPLEX);
	BEGIN Complex.init(w, SHORT(z.re), SHORT(z.im))
	END Short;

	PROCEDURE Long*(VAR z: Complex.COMPLEX; VAR w: ComplexL.LONGCOMPLEX);
	BEGIN ComplexL.init(w, LONG(z.re), LONG(z.im))
	END Long;
	
END ComplexConv.

(* vim:set ts=2 sw=2 et: *)
