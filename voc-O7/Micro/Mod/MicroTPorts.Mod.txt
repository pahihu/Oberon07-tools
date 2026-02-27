MODULE MicroTPorts;

	(*
		A. V. Shiryaev, 2010, 2012, 2014.10

		Should be target-independent
	*)

	IMPORT
		CommV24, Services, Log, Strings;

	CONST
		DLE* = 10X; ETX* = 03X;
		(* maxInfoBytes* = 32; *)
		maxInfoBytes* = 40;

		trace = {2};

	TYPE
		Action = POINTER TO RECORD (Services.Action)
			p: Port
		END;
		TDeshifr = RECORD
			state: INTEGER;
			id: SHORTCHAR;
			a: ARRAY maxInfoBytes OF SHORTCHAR;
			i: INTEGER;
			h: MessagesHandler
		END;
		MessagesHandler* = POINTER TO ABSTRACT RECORD END;
		Stat* = POINTER TO LIMITED RECORD
			in-: RECORD
				bytes-: LONGINT;
				invalidMessages-: LONGINT
			END;
			out-: RECORD
				bytes-: LONGINT
			END
		END;
		Port* = POINTER TO LIMITED RECORD
			c: CommV24.Connection;
			td: TDeshifr;
			a: Action;
			closed: BOOLEAN;
			stat: Stat
		END;

	PROCEDURE (h: MessagesHandler) MessageReceived- (id: SHORTCHAR; IN a: ARRAY OF SHORTCHAR; len: INTEGER), NEW, ABSTRACT;

	PROCEDURE PutTDeshifr (VAR td: TDeshifr; x: SHORTCHAR;
		stat: Stat);
	BEGIN
		IF 0 IN trace THEN
			Log.Int(ORD(x))
		END;
		CASE td.state OF 0:
			IF x = DLE THEN
				td.state := 1
			END
		| 1:
			IF (x = DLE) OR (x = ETX) THEN
				td.state := 0;
				(* INC(stat.invalidMessages) *)
			ELSE
				td.id := x;
				td.i := 0;
				td.state := 2
			END
		| 2:
			IF x = DLE THEN
				td.state := 3
			ELSE
				IF td.i < maxInfoBytes THEN
					td.a[td.i] := x;
					INC(td.i)
				ELSE
					td.state := 0;
					INC(stat.in.invalidMessages)
				END
			END
		| 3:
			IF x = DLE THEN
				IF td.i < maxInfoBytes THEN
					td.a[td.i] := DLE;
					INC(td.i);
					td.state := 2
				ELSE
					td.state := 0;
					INC(stat.in.invalidMessages)
				END
			ELSIF x = ETX THEN
				td.state := 0;
				IF 0 IN trace THEN
					Log.Ln
				END;
				IF td.h # NIL THEN
					td.h.MessageReceived(td.id, td.a, td.i)
				END
			ELSE
				td.state := 0;
				INC(stat.in.invalidMessages)
			END
		END
	END PutTDeshifr;

	(* TODO: ReceiveBytes, buffer *)
	PROCEDURE (a: Action) Do;
		VAR x: INTEGER; b: BYTE;
	BEGIN
		IF ~a.p.closed THEN
			Services.DoLater(a, Services.now);
			x := CommV24.Available(a.p.c);
			WHILE x > 0 DO
				CommV24.ReceiveByte(a.p.c, b);
				INC(a.p.stat.in.bytes);
				PutTDeshifr(a.p.td, SHORT(CHR(b)), a.p.stat);
				DEC(x)
			END
		END
	END Do;

	PROCEDURE InitTDeshifr (OUT td: TDeshifr; h: MessagesHandler);
	BEGIN
		td.state := 0;
		td.h := h
	END InitTDeshifr;

	PROCEDURE NewStat (): Stat;
		VAR stat: Stat;
	BEGIN
		NEW(stat);
		stat.in.bytes := 0; stat.out.bytes := 0;
		stat.in.invalidMessages := 0;
		RETURN stat
	END NewStat;

	PROCEDURE NewPort* (IN device: ARRAY OF CHAR; baud: INTEGER; opts: SET; h: MessagesHandler): Port;
		VAR p: Port; c: CommV24.Connection;
	BEGIN
		CommV24.Open(device, baud, opts, c);
		IF c # NIL THEN
			CommV24.SetBuffers(c, 8192, 8192);

			(* for LPC2000 *)
			CommV24.SetRTS(c, FALSE);
			CommV24.SetDTR(c, FALSE);

			NEW(p);
			p.stat := NewStat();
			p.c := c;
			p.closed := FALSE;
			InitTDeshifr(p.td, h);
			NEW(p.a); p.a.p := p;
			Services.DoLater(p.a, Services.now);
			RETURN p
		ELSE
			RETURN NIL
		END
	END NewPort;

	PROCEDURE Close* (VAR p: Port);
	BEGIN
		IF p # NIL THEN
			p.closed := TRUE;
			CommV24.Close(p.c);
			Services.RemoveAction(p.a);
			p := NIL
		END
	END Close;

	PROCEDURE SendMessage* (p: Port; id: SHORTCHAR; IN a: ARRAY OF SHORTCHAR; len: INTEGER);
		VAR i: INTEGER;

		PROCEDURE Transmit (x: SHORTCHAR);
		BEGIN
			CommV24.SendByte(p.c, SHORT(ORD(x)));
			INC(p.stat.out.bytes)
		END Transmit;

		PROCEDURE Send (x: SHORTCHAR);
		BEGIN
			Transmit(x);
			IF x = DLE THEN
				Transmit(DLE)
			END
		END Send;

	BEGIN
		ASSERT(id # DLE); ASSERT(id # ETX);
		ASSERT(len >= 0); ASSERT(len <= maxInfoBytes);
		IF p # NIL THEN
			Transmit(DLE);
			Transmit(id);
			FOR i := 0 TO len - 1 DO
				Send(a[i])
			END;
			Transmit(DLE);
			Transmit(ETX)
		END
	END SendMessage;

	PROCEDURE (p: Port) FINALIZE-;
	BEGIN
		IF 2 IN trace THEN
			Log.String("TPorts: p.FINALIZE");
			Log.Ln
		END;
		IF ~p.closed THEN
			Close(p)
		END
	END FINALIZE;

	(* LPC2000 *)
	PROCEDURE ResetDevice* (p: Port);
		VAR x: INTEGER; b: BYTE;
	BEGIN
		IF p # NIL THEN
			CommV24.SetDTR(p.c, TRUE);

			(* clear RX buffer *)
			x := CommV24.Available(p.c);
			WHILE x > 0 DO
				CommV24.ReceiveByte(p.c, b);
				DEC(x)
			END;
			(* clear T DeShifr automation state *)
			p.td.state := 0;

			CommV24.SetDTR(p.c, FALSE)
		END
	END ResetDevice;

	PROCEDURE GetStat* (p: Port): Stat;
	BEGIN
		RETURN p.stat
	END GetStat;

	PROCEDURE MsgRepr* (id: SHORTCHAR; IN a: ARRAY OF SHORTCHAR; len: INTEGER; OUT s: ARRAY OF CHAR);
		VAR w, i: INTEGER;

		PROCEDURE WStr (IN s1: ARRAY OF CHAR);
			VAR i: INTEGER;
		BEGIN i := 0; WHILE i < LEN(s1$) DO s[w] := s1[i]; INC(w); INC(i) END
		END WStr;

		PROCEDURE WInt (x: INTEGER);
			VAR s1: ARRAY 12 OF CHAR;
		BEGIN Strings.IntToString(x, s1); WStr(s1)
		END WInt;

		PROCEDURE H (x: SHORTCHAR);
			PROCEDURE H0 (x: INTEGER);
			BEGIN
				IF x < 0AH THEN s[w] := CHR(ORD('0') + x)
				ELSE s[w] := CHR(ORD('A') + x - 0AH)
				END; INC(w)
			END H0;
		BEGIN s[w] := '$'; INC(w); H0(ORD(x) DIV 10H); H0(ORD(x) MOD 10H)
		END H;

	BEGIN w := 0; H(id); WStr(" ("); WInt(len); s[w] := ')'; INC(w);
		i := 0; WHILE i < len DO s[w] := ' '; INC(w); H(a[i]); INC(i) END;
		s[w] := 0X
	END MsgRepr;

END MicroTPorts.
