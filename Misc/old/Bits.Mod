(* Convert LONGINT to SET and back *)
MODULE Bits;
    IMPORT Out;

    VAR i: LONGINT;
        s: SET;


    PROCEDURE BITVAL(s: SET): LONGINT;
        VAR pow2, n, i: LONGINT;
    BEGIN i := 0; pow2 := 1;
        FOR n := MIN(SET) TO MAX(SET) DO
            IF n IN s THEN INC(i, pow2) END;
            pow2 := pow2 * 2
        END;
        RETURN i
    END BITVAL;

    PROCEDURE BITS(i: LONGINT): SET;
        VAR s: SET;
            n: LONGINT;
    BEGIN s := {};
        FOR n := 0 TO 31 DO IF ODD(i) THEN INCL(s, n) END; i := i DIV 2 END;
        RETURN s
    END BITS;


    (* Insert v with width w into i at position p *)
    PROCEDURE BFI(i: LONGINT; p: LONGINT; v: LONGINT; w: LONGINT): LONGINT;
        VAR mask: LONGINT;
	        bv: LONGINT;
	        si, smask: SET;
    BEGIN mask := ASH(1, w);
        bv := ASH(v MOD mask, p); (* cut v to w bits, then shift to p *)
        si := BITS(i); smask := BITS(ASH(mask - 1, p));
        si := si * (-smask);
        RETURN BITVAL(si) + bv
    END BFI;


    (* Extract w bits from i at position p *)
    PROCEDURE BFX(i: LONGINT; p: LONGINT; w: LONGINT): LONGINT;
    BEGIN RETURN i DIV ASH(1, p) MOD ASH(1, w)
    END BFX;
	

    (* Print set on Out *)
    PROCEDURE Set(s: SET);
        VAR i, n: LONGINT;
            printed: BOOLEAN;
    BEGIN i := BITVAL(s); printed := FALSE;
        Out.Char("{");
        FOR n := 0 TO 31 DO
            IF ODD(i) THEN
                IF printed THEN Out.Char(",") END;
                Out.Int(n, 2);
                printed := TRUE
            END;
            i := i DIV 2
        END;
        Out.Char("}")
    END Set;

    PROCEDURE ShowInt(msg: ARRAY OF CHAR; i: LONGINT);
    BEGIN Out.String(msg); Out.Int(i, 10); Out.Ln
    END ShowInt;

    PROCEDURE ShowSet(msg: ARRAY OF CHAR; s: SET);
    BEGIN Out.String(msg); Set(s); Out.Ln
    END ShowSet;

BEGIN s := {0 ..1}; i := BITVAL(s);
    Out.String("Convert SET to INTEGER"); Out.Ln;
    ShowInt("i = ", i);
    ShowSet("s = ", s);
    Out.String("Convert INTEGER to SET"); Out.Ln;
    s := BITS(i);
    ShowInt("i = ", i);
    ShowSet("s = ", s);
    Out.Flush
END Bits.
