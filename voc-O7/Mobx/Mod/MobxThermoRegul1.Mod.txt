MODULE MobxThermoRegul1;

	(* Alexander Shiryaev, 2014.11 *)

	IMPORT Dialog, Math, TP := MicroTPorts, Log := StdLog;

	TYPE
		MessagesHandler = POINTER TO RECORD (TP.MessagesHandler) END;

	CONST
		idTrap = 0D0X;
		idSHT1x = 4X;
		idState0 = 5X;
		idTempZad = 6X;

	VAR
		device*: ARRAY 32 OF CHAR;
		portIsOpen-: BOOLEAN;
		p: TP.Port;
		mh: MessagesHandler;

		measurements-: INTEGER;
		temp0-, humi0-: INTEGER;
		tempDegC-: REAL;
		RHLinear-, RH-: REAL;
		dewPoint-: REAL;
		heating-: BOOLEAN;
		thermoIntLocked-: BOOLEAN;
		thermoIntLimited-: BOOLEAN;
		thermoIntELimited-: BOOLEAN;
		controlZad-: INTEGER;
		tempZad-: REAL;
		thermoInt-: REAL;
		effTempDegC-: REAL;
		tZadDegC*: REAL;
		tZadIsEff*: BOOLEAN;

	PROCEDURE ToDegC (temp0: INTEGER): REAL;
		CONST d1DegC = -39.65; d2DegC = 0.01;
	BEGIN
		RETURN d1DegC + d2DegC * temp0
	END ToDegC;

	PROCEDURE FromDegC (temp: REAL): INTEGER;
	BEGIN
		RETURN SHORT(ENTIER(temp * 100.0)) + 3965
	END FromDegC;

	PROCEDURE TZadDegCLimit (x: REAL): REAL;
	BEGIN
		IF x > 200.0 THEN
			x := 200.0
		ELSIF x < -200.0 THEN
			x := -200.0
		END;
		RETURN x
	END TZadDegCLimit;

	PROCEDURE SendTempZad (temp0: INTEGER);
		VAR a: ARRAY 2 OF SHORTCHAR;
	BEGIN
		a[0] := SHORT(CHR(temp0));
		a[1] := SHORT(CHR(temp0 DIV 100H));
		TP.SendMessage(p, idTempZad, a, 2)
	END SendTempZad;

	PROCEDURE (h: MessagesHandler) MessageReceived (id: SHORTCHAR; IN a: ARRAY OF SHORTCHAR; len: INTEGER);
		VAR ok: BOOLEAN;
			s: ARRAY 3 + 6 + 4 * 255 + 1 OF CHAR;

		PROCEDURE GotSHT1x (IN a: ARRAY OF SHORTCHAR);
			CONST
				c1 = -2.0468; c2 = 0.0367; c3 = -1.5955E-6;
				t1 = 0.01; t2 = 0.00008;
				Tn = 243.12 (* °C *); m = 17.62;
			VAR i: INTEGER; k: REAL;
		BEGIN
			temp0 := ORD(a[1]) + 100H * ORD(a[2]);
			Dialog.UpdateInt(temp0);

			tempDegC := ToDegC(temp0);
			Dialog.UpdateReal(tempDegC);

			humi0 := ORD(a[3]) + 100H * ORD(a[4]);
			Dialog.UpdateInt(humi0);

			RHLinear := c1 + c2 * humi0 + c3 * humi0 * humi0;
			Dialog.UpdateReal(RHLinear);
			RH := (tempDegC - 25) * (t1 + t2 * humi0) + RHLinear;
			Dialog.UpdateReal(RH);

			k := Math.Ln(RH / 100.0) + m * tempDegC / (Tn + tempDegC);
			dewPoint := Tn * k / (m - k);
			Dialog.UpdateReal(dewPoint);

			(* http://method.meteorf.ru/publ/tr/tr347/tkachuk.pdf *)
			effTempDegC := tempDegC
				- 0.4 * (tempDegC - 10.0) * (1.0 - RH / 100.0);
			Dialog.UpdateReal(effTempDegC);

			INC(measurements);
			Dialog.UpdateInt(measurements);

			IF tZadIsEff THEN
				i := FromDegC(TZadDegCLimit(tZadDegC) + tempDegC - effTempDegC)
			ELSE
				i := FromDegC(TZadDegCLimit(tZadDegC))
			END;
			SendTempZad(i)
		END GotSHT1x;

		PROCEDURE GotState0 (IN a: ARRAY OF SHORTCHAR);
			VAR s: SET;
				x: INTEGER;
		BEGIN
			s := BITS(ORD(a[0]));
			heating := 0 IN s; Dialog.UpdateBool(heating);
			thermoIntLocked := 1 IN s; Dialog.UpdateBool(thermoIntLocked);
			thermoIntLimited := 2 IN s; Dialog.UpdateBool(thermoIntLimited);
			thermoIntELimited := 3 IN s; Dialog.UpdateBool(thermoIntELimited);
			controlZad := ORD(a[1]); Dialog.UpdateInt(controlZad);
			tempZad := ToDegC(ORD(a[2]) + 100H * ORD(a[3]));
				Dialog.UpdateReal(tempZad);
			x := ORD(a[4]) + 100H * ORD(a[5]);
				IF x >= 8000H THEN DEC(x, 10000H) END;
				thermoInt := x * 0.01; Dialog.UpdateReal(thermoInt)
		END GotState0;

	BEGIN
		ok := FALSE;
		IF id = idSHT1x THEN
			IF (len = 5) & (a[0] = 0X) THEN ok := TRUE;
				GotSHT1x(a)
			END
		ELSIF id = idState0 THEN
			IF len = 6 THEN ok := TRUE;
				GotState0(a)
			END
		END;
		IF ~ok THEN
			TP.MsgRepr(id, a, len, s); Log.String(s); Log.Ln
		END
	END MessageReceived;

	PROCEDURE Open*;
	BEGIN
		IF p = NIL THEN
			p := TP.NewPort(device, 19200, {}, mh);
			portIsOpen := p # NIL; Dialog.UpdateBool(portIsOpen)
		END
	END Open;

	PROCEDURE Close*;
	BEGIN
		TP.Close(p);
		portIsOpen := p # NIL; Dialog.UpdateBool(portIsOpen)
	END Close;

BEGIN
	controlZad := -1;
	tempZad := -INF;
	tZadDegC := 24.0; tZadIsEff := FALSE;
	device := "\\.\COM8";
	NEW(mh)
CLOSE
	Close
END MobxThermoRegul1.

"StdCmds.OpenAuxDialog('Mobx/Rsrc/ThermoRegul1','ThermoRegul1')"
