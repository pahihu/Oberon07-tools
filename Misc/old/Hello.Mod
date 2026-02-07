MODULE Hello;
  IMPORT Out, Objects, Buddies, Timer;

  TYPE
		T23 = POINTER TO T23Desc;
		T23Desc = RECORD
			i: LONGINT;
		END;

	TYPE
		T = RECORD END; P = POINTER TO T;
		T1 = RECORD (T) END; P1 = POINTER TO T1;
		T2 = RECORD (T) END; P2 = POINTER TO T2;

  VAR 
    bud: Buddies.Buddy;

  PROCEDURE MyProc(n: LONGINT);
	BEGIN Out.Int(n, 0); Out.Ln
	END MyProc;

	PROCEDURE Clarification23;
		VAR p: T23;
		  pProc: PROCEDURE (n: LONGINT);
			a: ARRAY 2 OF SHORTINT;
			s: SET;
			n: INTEGER;
	BEGIN 
		(* (1) de-referencing a NIL pointer: OK *)
		(* p := NIL; p^.i := 42; *)

		(* (2) calling procedure variable with a value NIL: FAILED *)
		(* pProc := NIL; pProc(42); *)

		(* (3a) type test with NIL pointer: OK *)
		(* p := NIL; IF p IS T THEN Out.String('got a T') END; *)

    (* (3b) type guard with NIL pointer: OK *)
    (* p := NIL; WITH p:T DO Out.String('got a T') END; *)

    (* (4) indexing an array with an index that is out-of-range: OK *)
	  (* a[3] := 42; *)

    (* (5) accessing a set element outside the range 0..MAX(SET): OK *)
		(* s := {1,2,8,27}; n := 32;
		   IF n IN s THEN Out.String('accessed 32th item') END; *)

    (* (6) applying SHORT() to an argument with value not in the range of the result type: FAILED *)
		n := 32767; a[1] := SHORT(n); Out.String('a[1] = '); Out.Int(a[1], 0); Out.Ln;

    (* (7) operations on strings that are not null terminated: *)
    (* (8) overflows *)
		n := MAX(INTEGER); INC(n); Out.String('n = '); Out.Int(n, 0); Out.Ln
	END Clarification23;

  (* (2.4) WITH and guarded variables *)
	PROCEDURE Clarification24;
		VAR p: P; p1: P1; p2: P2;
		PROCEDURE Y;
		BEGIN p := p2
		END Y;
	BEGIN 
		NEW(p); NEW(p1); NEW(p2); p := p1;
		WITH p: P1 DO
			Y; (* p is now of type P2 and not P1 *)
			IF p IS P1 THEN Out.String('p is P1')
			ELSE Out.String('p is NOT P1') END;
			Out.Ln
		END
	END Clarification24;

	PROCEDURE Clarification25;
		PROCEDURE Compare(a, b: ARRAY OF CHAR): INTEGER;
			VAR i: LONGINT;
		BEGIN i := 0;
			WHILE (a[i] # 0X) & (a[i] = b[i]) DO
				INC(i)
			END;
			RETURN ORD(a[i]) - ORD(b[i]);
		END Compare;
	BEGIN (* (2.5) String Comparison *)
			Out.String("Compare 'alpha' and 'beta' ");
			Out.Int(Compare('alpha','beta'), 0);
			Out.Ln
	END Clarification25;

	PROCEDURE Clarification27;
	BEGIN 
		Out.String('ORD("A")='); Out.Int(ORD("A"), 0);
		Out.String(' ORD(41X)='); Out.Int(ORD(41X), 0); Out.Ln
	END Clarification27;

  PROCEDURE Greet;
  BEGIN Out.String('Hello, world!'); Out.Ln
  END Greet;	

  PROCEDURE MakeBuddies(n: LONGINT);
    VAR b: Buddies.Buddy;
	   i: LONGINT;
     o: Objects.Object;
     cnt: LONGINT;
		 t: Timer.Timer;
     ms: LONGINT;
  BEGIN cnt := 0;
    Out.String('Making buddies... ');
		Timer.Start(t);
    FOR i := 1 TO n DO
      b := Buddies.New(i);
      o := b.Copy();
      IF o IS Buddies.Buddy THEN
        IF o.Equals(b) THEN INC(cnt) END
      END
    END;
    ms := Timer.Elapsed(t);
    Out.String('made ');
    Out.Int(cnt, 0);
    Out.String(' (');
    Out.Int(ms, 0);
    Out.String('ms)');
    Out.Ln
  END MakeBuddies;

BEGIN
  Clarification23;
	Clarification24;
	Clarification25;
	Clarification27;
  Greet;
  MakeBuddies(10000000);
  bud := Buddies.New(42);
  Out.String('bud is '); bud.Print; Out.Ln
END Hello.
