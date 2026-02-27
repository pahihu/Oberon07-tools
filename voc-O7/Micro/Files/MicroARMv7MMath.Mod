MODULE MicroARMv7MMath; (*Standard functions; NW 12.10.2013*)

	(*
		Alexander Shiryaev:
			2014.09: hardware sqrt
			2015.03: ln modified
	*)

	IMPORT SYSTEM;

	TYPE Proc0 = PROCEDURE (x: REAL): REAL;

	VAR sqrt*: Proc0;

(*
	PROCEDURE sqrt* (x: REAL): REAL;
		CONST c1 = 0.70710680;	 (* 1/sqrt(2) *)
			c2 = 0.590162067;
			c3 = 1.4142135;	(*sqrt(2)*)
		VAR s: REAL; e: INTEGER;
	BEGIN ASSERT(x >= 0.0);
		IF x > 0.0 THEN
			UNPK(x, e);
			s := c2*(x+c1);
			s := s + (x/s);
			s := 0.25*s + x/s;
			s := 0.5 * (s + x/s);
			IF ODD(e) THEN s := c3*s END ;
			PACK(s, e DIV 2)
		ELSE s := 0.0
		END;
		RETURN s
	END sqrt;
*)

	PROCEDURE exp* (x: REAL): REAL;
		CONST
			c1 = 1.4426951;	(*1/ln(2) *)
			p0 = 1.513864173E3;
			p1= 2.020170000E1;
			p2 = 2.309432127E-2;
			q0 = 4.368088670E3;
			q1 = 2.331782320E2;
		VAR n: INTEGER; p, y, yy: REAL;
	BEGIN y := c1*x;
		n := FLOOR(y + 0.5); y := y - FLT(n);
		yy := y*y;
		p := ((p2*yy + p1)*yy + p0)*y;
		p := p/((yy + q1)*yy + q0 - p) + 0.5;
		PACK(p, n+1); RETURN p
	END exp;

(*
	PROCEDURE ln* (x: REAL): REAL;
		CONST c1 = 0.70710680;	(* 1/sqrt(2) *)
			c2 =	0.69314720;	(* ln(2) *)
			p0 = -9.01746917E1;
			p1 =	9.34639006E1;
			p2 = -1.83278704E1;
			q0 = -4.50873458E1;
			q1 =	6.76106560E1;
			q2 = -2.07334879E1;
		VAR e: INTEGER; xx, y: REAL;
	BEGIN ASSERT(x > 0.0); UNPK(x, e);
		(* IF x < c1 THEN x := x*2.0; e := e-1 END ; *)
			IF x > 1.4142135623730951 (* sqrt(2) *) THEN x := x * 0.5; INC(e) END;
		x := (x-1.0)/(x+1.0);
		xx := x * x;
		y := c2*FLT(e) + x*((p2*xx + p1)*xx + p0) / (((xx + q2)*xx + q1)*xx + q0);
		RETURN y
	END ln;
*)

	(* http://en.wikipedia.org/wiki/Natural_logarithm *)
	PROCEDURE ln* (x: REAL): REAL;
		CONST ln2 = 0.6931471805599453;
			c0 = 0.6666666666666666; (* 2.0 / 3.0 *)
			c1 = 0.4; (* 2.0 / 5.0 *)
			c2 = 0.2857142857142857; (* 2.0 / 7.0 *)
			c3 = 0.2222222222222222; (* 2.0 / 9.0 *)
		VAR e: INTEGER; xx: REAL;
	BEGIN ASSERT(x > 0.0); UNPK(x, e);
		IF x > 1.5 THEN x := x * 0.5; INC(e) END;
		x := (x - 1.0) / (x + 1.0); xx := x * x
	RETURN FLT(e) * ln2 + x * (2.0 + xx * (c0 + xx * (c1 + xx * (c2 + xx * c3))))
	END ln;

	PROCEDURE sin* (x: REAL): REAL;
		CONST
			c1 =	6.3661977E-1; (*2/pi*)
			p0 =	7.8539816E-1;
			p1 = -8.0745512E-2;
			p2 =	2.4903946E-3;
			p3 = -3.6576204E-5;
			p4 =	3.1336162E-7;
			p5 = -1.7571493E-9;
			p6 =	6.8771004E-12;
			q0 =	9.9999999E-1;
			q1 = -3.0842514E-1;
			q2 =	1.5854344E-2;
			q3 = -3.2599189E-4;
			q4 =	3.5908591E-6;
			q5 = -2.4609457E-8;
			q6 =	1.1363813E-10;
		VAR n: INTEGER; y, yy, f: REAL;
	BEGIN y := c1*x;
		IF y >= 0.0 THEN n := FLOOR(y + 0.5) ELSE n := FLOOR(y - 0.5) END ;
		y := (y - FLT(n)) * 2.0; yy := y*y;
		IF ODD(n) THEN f := (((((q6*yy + q5)*yy + q4)*yy + q3)*yy + q2)*yy + q1)*yy + q0
		ELSE f := ((((((p6*yy + p5)*yy + p4)*yy + p3)*yy + p2)*yy + p1)*yy + p0)*y
		END;
		IF ODD(n DIV 2) THEN f := -f END ;
		RETURN f
	END sin;

	PROCEDURE cos* (x: REAL): REAL;
		CONST
			c1 =	6.3661977E-1; (*2/pi*)
			p0 =	7.8539816E-1;
			p1 = -8.0745512E-2;
			p2 =	2.4903946E-3;
			p3 = -3.6576204E-5;
			p4 =	3.1336162E-7;
			p5 = -1.7571493E-9;
			p6 = 6.8771004E-12;
			q0 =	9.9999999E-1;
			q1 = -3.0842514E-1;
			q2 =	1.5854344E-2;
			q3 = -3.2599189E-4;
			q4 =	3.5908591E-6;
			q5 = -2.4609457E-8;
			q6 =	1.1363813E-10;
		VAR n: INTEGER; y, yy, f: REAL;
	BEGIN y := c1*x;
		IF y >= 0.0 THEN n := FLOOR(y + 0.5) ELSE n := FLOOR(y - 0.5) END ;
		y := (y - FLT(n)) * 2.0; yy := y*y;
		IF ~ODD(n) THEN f := (((((q6*yy + q5)*yy + q4)*yy + q3)*yy + q2)*yy + q1)*yy + q0
		ELSE f := ((((((p6*yy + p5)*yy + p4)*yy + p3)*yy + p2)*yy + p1)*yy + p0)*y
		END;
		IF ODD((n+1) DIV 2) THEN f := -f END ;
		RETURN f
	END cos;

BEGIN
	sqrt := SYSTEM.VAL(Proc0,
		(* VMOV.F32 S0, R0; VSQRT.F32 S0, S0; VMOV.F32 R0, S0; BX LR *)
		SYSTEM.ADR($00 EE 10 0A B1 EE C0 0A 10 EE 10 0A 70 47$) + 1 (* Thumb *))
END MicroARMv7MMath.

O7ARMv7MTool.DecObj MicroARMv7MMath.a7m 
