MODULE MicroSTM32F10xPinCfg;

	(*
		Alexander Shiryaev, 2016.02

		STM32F10{0,1,2,3,5,7}

		RM0041, Reference manual (STM32F100xx)
		RM0008, Reference manual (STM32F10{1,2,3,5,7}xx)
	*)

	IMPORT SYSTEM;

	CONST
		(* ports *)
			A* = 0; B* = 1; C* = 2; D* = 3; E* = 4; F* = 5; G* = 6;

		(* configurations *)
			analog* = 0;
			outputPushPull10MHz* = 1;
			outputPushPull2MHz* = 2;
			outputPushPull50MHz* = 3;
			inputFloating* = 4;
			outputOpenDrain10MHz* = 5;
			outputOpenDrain2MHz* = 6;
			outputOpenDrain50MHz* = 7;
			inputPullDown* = 8;
			afOutputPushPull10MHz* = 9;
			afOutputPushPull2MHz* = 10;
			afOutputPushPull50MHz* = 11;
			inputPullUp* = 12;
			afOpenDrain10MHz* = 13;
			afOpenDrain2MHz* = 14;
			afOpenDrain50MHz* = 15;

	PROCEDURE Configure* (port, pin, conf: INTEGER);
		CONST
			RCC = 40021000H;
				RCCAPB2ENR = RCC + 18H;
					IOPAEN = 2;
			GPIOA = 40010800H; portSpacing = 400H;
				CRL = 0; BSRR = 10H;
		VAR x: SET;
			r, y, z: INTEGER;
	BEGIN
		ASSERT(port >= A);
		ASSERT(port <= G);
		ASSERT(pin DIV 16 = 0);
		ASSERT(conf DIV 16 = 0);

		IF conf = inputPullUp THEN
			conf := inputPullDown;
			z := 0
		ELSE
			z := 16
		END;

		(* enable clock for pin port *)
			SYSTEM.GET(RCCAPB2ENR, x);
			SYSTEM.PUT(RCCAPB2ENR, x + {port + IOPAEN});

		y := (pin * 4) MOD 32;
		r := GPIOA + CRL + pin DIV 8 * 4 + port * portSpacing;
		SYSTEM.GET(r, x);
		SYSTEM.PUT(r, SYSTEM.VAL(INTEGER, x - {y..y+3}) + LSL(conf, y));

		IF conf = inputPullDown THEN
			SYSTEM.PUT(GPIOA + BSRR + port * portSpacing, {pin + z})
		END
	END Configure;

END MicroSTM32F10xPinCfg.
