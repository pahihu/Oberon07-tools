MODULE InOut;
IMPORT Out;

VAR HexDigits: ARRAY 17 OF CHAR;

PROCEDURE Hex* (x: LONGINT);
    VAR s: ARRAY 17 OF CHAR;
        i, j, y: INTEGER;
        c: CHAR;
BEGIN i := 0;
    REPEAT y := SHORT(x MOD 16);
        IF y < 10 THEN s[i] := CHR(y + ORD('0')) ELSE s[i] := CHR(y + ORD('A') - 10) END;
        x := x DIV 16; INC(i)
    UNTIL x = 0;
    (* REPEAT DEC(i); Out.Char (s[i]) UNTIL i = 0 *)
    s[i] := 0X; DEC(i);
    FOR j := 0 TO i DIV 2 DO
        c := s[j]; s[j] := s[i-j]; s[i-j] := c
    END;
    Out.String (s)
END Hex;

(* CONST string cannot be indexed *)
(* the difference between indexing and calculating is 3%, or w/o run-time checks 6% *)
PROCEDURE Hex2* (x: LONGINT);
    VAR s: ARRAY 17 OF CHAR;
        i, j, y: INTEGER;
        c: CHAR;
BEGIN i := 0;
    REPEAT y := SHORT(x MOD 16);
        s[i] := HexDigits[y];
        x := x DIV 16; INC(i)
    UNTIL x = 0;
    (* REPEAT DEC(i); Out.Char (s[i]) UNTIL i = 0 *)
    s[i] := 0X; DEC(i);
    FOR j := 0 TO i DIV 2 DO
        c := s[j]; s[j] := s[i-j]; s[i-j] := c
    END;
    Out.String (s)
END Hex2;

(* using PrintFmt is about 43% slower than writing out the Out.XXX calls *)
PROCEDURE PrintFmt* (s: ARRAY OF CHAR; i1, i2: LONGINT; str: ARRAY OF CHAR);
(* supported format %[length]type, type = d, i, x or s, and escape characters \n, \t *)
    VAR n, j, len, par, x: LONGINT; ch, nxCh: CHAR;
BEGIN
    par := 1; n := 0; ch := s[0];
    WHILE (ch # 0X) & (n < LEN(s)) DO
        j := n+1; nxCh := s[j];
        IF ch = "%" THEN 				(* handle format *)
            len := 0;
            WHILE ("0" <= nxCh) & (nxCh <= "9") DO len := len * 10 + ORD(nxCh) - ORD("0"); INC(j); nxCh := s[j] END;
            IF nxCh = "s" THEN Out.String(str); INC(j)
            ELSIF (nxCh # "d") & (nxCh # "i") & (nxCh # "x") THEN Out.Char("%")
            ELSE
            	x := i2; IF par = 1 THEN x := i1 END; INC(par);
            	IF nxCh = "x" THEN Hex(x) ELSE (* i, d *) Out.Int(x, len) END;
            	INC(j)
            END
        ELSIF ch = "\" THEN			(* handle escape characters *)
            IF nxCh = "n" THEN Out.Ln; INC(j)
            ELSIF nxCh = "t" THEN Out.Char(9X); INC(j)
            ELSE Out.Char("\")
            END
        ELSE
            Out.Char(ch)
        END;
        n := j; ch := s[n]
    END
END PrintFmt;

BEGIN HexDigits := '0123456789ABCDEF'
END InOut.