MODULE MicroLPC1788PinCfg;

	(*
		Alexander Shiryaev, 2016.03

		UM10470,
			LPC178x/7x User manual

		LPC17{73,74,76,77,78,85,86,87,88}
	*)

	IMPORT SYSTEM;

	CONST
		P0* = 0; P1* = 1; P2* = 2; P3* = 3; P4* = 4; P5* = 5;

		(* modes *)
			inactive* = 0; pullDown* = 1; pullUp* = 2; repeater* = 3;

		IOCON = 4002C000H;

		(* IOCON registers bits: *)
			INV* = 6; (* D, A, I, W *)
			OD* = 10; (* D, A, W *)
			HYS* = 5; SLEW* = 9; (* D, W *)
			FILTER* = 8; (* A, W *)
			ADMODE* = 7; DACEN* = 16; (* A *)
			HS* = 8; HIDRIVE* = 9; (* I *)

		(* IOCON types *)
			D* = 0; A* = 1; U* = 2; I* = 3; W* = 4;

	PROCEDURE Type* (port, pin: INTEGER): INTEGER;
		VAR res: INTEGER;
	BEGIN
		IF port = P0 THEN
			IF pin IN {0..6,10,11,14..22} THEN res := D
			ELSIF pin IN {7..9} THEN res := W
			ELSIF pin IN {12,13,23..26} THEN res := A
			ELSIF pin IN {27,28} THEN res := I
			ELSIF pin IN {29..31} THEN res := U
			ELSE ASSERT(FALSE)
			END
		ELSIF port = P1 THEN
			IF pin < 30 THEN res := D ELSE res := A END
		ELSIF (port IN {P2,P3,P4}) THEN res := D
		ELSIF port = P5 THEN
			IF pin IN {0,1,4} THEN res := D
			ELSIF pin IN {2,3} THEN res := I
			ELSE ASSERT(FALSE)
			END
		ELSE ASSERT(FALSE)
		END
	RETURN res
	END Type;

	PROCEDURE Configure* (port, pin, func, mode: INTEGER; opts: SET);
		VAR type: INTEGER;
	BEGIN
		ASSERT(port >= P0);
		ASSERT(port <= P5);
		ASSERT(pin DIV 32 = 0);

		type := Type(port, pin);
		IF type = D THEN
			ASSERT(func DIV 8 = 0);
			ASSERT(mode DIV 4 = 0);
			ASSERT(opts * (-{HYS,INV,SLEW,OD}) = {})
		ELSIF type = A THEN
			ASSERT(func >= 0);
			ASSERT(func <= 5);
			ASSERT(mode DIV 4 = 0);
			ASSERT(opts * (-{INV,ADMODE,FILTER,OD,DACEN}) = {});
			IF DACEN IN opts THEN ASSERT((port = P0) & (pin = 26)) END
		ELSIF type = U THEN
			ASSERT(func >= 0);
			ASSERT(func <= 2);
			ASSERT(mode = 0);
			ASSERT(opts = {})
		ELSIF type = I THEN
			ASSERT(func >= 0);
			ASSERT(func <= 5);
			ASSERT(mode = 0);
			ASSERT(opts * (-{INV,HS,HIDRIVE}) = {});
			IF HIDRIVE IN opts THEN ASSERT((port = P5) & (pin IN {2,3})) END
		ELSIF type = W THEN
			ASSERT(func DIV 8 = 0);
			ASSERT(mode DIV 4 = 0);
			ASSERT(opts * (-{HYS,INV,FILTER,SLEW,OD}) = {});
			INCL(opts, 7)
		ELSE ASSERT(FALSE)
		END;

		SYSTEM.PUT(IOCON + port * 80H + pin * 4,
			func + mode * 8 + SYSTEM.VAL(INTEGER, opts))
	END Configure;

	PROCEDURE DefaultOpts* (port, pin: INTEGER): SET;
		VAR type: INTEGER;
			res: SET;
	BEGIN
		type := Type(port, pin);
		IF type IN {D,W} THEN res := {HYS}
		ELSIF type = A THEN res := {ADMODE,FILTER}
		ELSIF type IN {U,I} THEN res := {}
		ELSE ASSERT(FALSE)
		END
	RETURN res
	END DefaultOpts;

END MicroLPC1788PinCfg.
