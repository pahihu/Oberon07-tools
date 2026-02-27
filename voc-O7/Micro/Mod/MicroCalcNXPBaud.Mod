MODULE MicroCalcNXPBaud;

	(*
		Alexander Shiryaev, 2014.11

		Calculation of optimal DL and FDR UART parameters
			for NXP microcontrollers

		NOTE:
			baud * 16 = PCLK * M / ( DL * (M + D) )
			1 <= M <= 15
			0 <= D <= 14
			D < M
			D = 0:
				1 <= DL <= 65535
			ELSE:
				3 <= DL <= 65535
	*)

	IMPORT Log := StdLog;

	PROCEDURE Find0 (PCLK, baud: INTEGER; OUT DL, FDR: INTEGER);
	BEGIN
		FDR := 16;
		DL := (PCLK + 8 * baud) DIV (16 * baud)
	END Find0;

	PROCEDURE FindBest (PCLK, baud: INTEGER; OUT DL, FDR: INTEGER);
		VAR dl, m, d, c, cMin: INTEGER;
	BEGIN
		ASSERT(PCLK > 0, 20);
		ASSERT(PCLK <= 143165576, 21);
		baud := baud * 16;

		cMin := MAX(INTEGER);
		m := 1;
		WHILE m < 16 DO
			d := 0;
			WHILE d < m DO
				IF d = 0 THEN dl := 1 ELSE dl := 3 END;
				WHILE dl < 10000H DO
					c := ABS((m * PCLK) DIV (dl * (m + d)) - baud);
					IF c < cMin THEN
						cMin := c;
						DL := dl; FDR := m * 16 + d
					END;
					INC(dl)
				END;
				INC(d)
			END;
			INC(m)
		END
	END FindBest;

	PROCEDURE GCD (x, y: INTEGER): INTEGER;
	BEGIN
		WHILE x # y DO
			IF x > y THEN x := x - y
			ELSE y := y - x
			END
		END;
		RETURN x
	END GCD;

	PROCEDURE ActualBaud (PCLK, DL, FDR: INTEGER): REAL;
		VAR res: REAL;
			M, D, a, b, c: INTEGER;
	BEGIN
		ASSERT(PCLK > 0, 20);
		ASSERT(DL DIV 10000H = 0, 21);
		M := FDR DIV 10H; D := FDR MOD 10H;
		ASSERT(M >= 1, 100);
		ASSERT(M <= 15, 101);
		ASSERT(D <= 14, 102);
		ASSERT(D < M, 103);

		a := PCLK * M;
		ASSERT(a >= PCLK, 104);
		b := 16 * DL * (M + D);
		c := GCD(a, b);
		a := a DIV c;
		b := b DIV c;

		RETURN a / b
	END ActualBaud;

	PROCEDURE All*;
		CONST
			nBauds = 9;
			nPclks = 7;
		VAR
			bauds: ARRAY nBauds OF INTEGER;
			pclks: ARRAY nPclks OF INTEGER;
			i, j, baud, pclk, DL0, FDR0, DL, FDR: INTEGER;
	BEGIN
		bauds[0] := 1200;
		bauds[1] := 2400;
		bauds[2] := 4800;
		bauds[3] := 9600;
		bauds[4] := 19200;
		bauds[5] := 38400;
		bauds[6] := 57600;
		bauds[7] := 115200;
		bauds[8] := 230400;

		pclks[0] := 12000000;
		pclks[1] := 24000000;
		pclks[2] := 48000000;
		pclks[3] := 18000000;
		pclks[4] := 36000000;
		pclks[5] := 72000000;
		pclks[6] := 17971200;

		i := 0;
		WHILE i < nPclks DO
			pclk := pclks[i];
			j := 0;
			WHILE j < nBauds DO
				baud := bauds[j];
				Find0(pclk, baud, DL0, FDR0);
				FindBest(pclk, baud, DL, FDR);
				
				IF (DL # DL0) OR (FDR # FDR0) THEN
					Log.Char('*')
				END;
				Log.Int(pclk); Log.Int(baud); Log.Int(DL); Log.Int(FDR); Log.Ln;
				
				INC(j)
			END;
			INC(i)
		END
	END All;

END MicroCalcNXPBaud.

MicroCalcNXPBaud.All
