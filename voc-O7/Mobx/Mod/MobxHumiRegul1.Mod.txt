MODULE MobxHumiRegul1;

	(* Alexander Shiryaev, 2014.10 *)

	IMPORT Dialog, Math, TP := MicroTPorts, Log := StdLog;

	TYPE
		MessagesHandler = POINTER TO RECORD (TP.MessagesHandler) END;

	VAR
		device*: ARRAY 32 OF CHAR;
		measurements-: INTEGER;
		temp0-, humi0-: INTEGER;
		tempDegC-: REAL;
		RHLinear-, RH-: REAL;
		dewPoint-: REAL;
		p: TP.Port;
		mh: MessagesHandler;

	PROCEDURE (h: MessagesHandler) MessageReceived (id: SHORTCHAR; IN a: ARRAY OF SHORTCHAR; len: INTEGER);
		CONST
			d1DegC = -39.65; d2DegC = 0.01;
			c1 = -2.0468; c2 = 0.0367; c3 = -1.5955E-6;
			t1 = 0.01; t2 = 0.00008;
			Tn = 243.12 (* °C *); m = 17.62;
		VAR ok: BOOLEAN; i: INTEGER; k: REAL;
			s: ARRAY 3 + 6 + 4 * 255 + 1 OF CHAR;
	BEGIN
		ok := FALSE;
		IF id = 4X THEN
			IF (len = 5) & (a[0] = 0X) THEN ok := TRUE;
				temp0 := ORD(a[1]) + 100H * ORD(a[2]);
				Dialog.UpdateInt(temp0);

				tempDegC := d1DegC + d2DegC * temp0;
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

				INC(measurements);
				Dialog.UpdateInt(measurements)
			END
		END;
		IF ~ok THEN
			TP.MsgRepr(id, a, len, s); Log.String(s); Log.Ln
		END
	END MessageReceived;

	PROCEDURE Open*;
	BEGIN
		IF p = NIL THEN
			p := TP.NewPort(device, 19200, {}, mh)
		END
	END Open;

	PROCEDURE Close*;
	BEGIN
		TP.Close(p)
	END Close;

BEGIN
	device := "\\.\COM3";
	NEW(mh)
CLOSE
	Close
END MobxHumiRegul1.

"StdCmds.OpenAuxDialog('Mobx/Rsrc/HumiRegul1','HumiRegul1')"
