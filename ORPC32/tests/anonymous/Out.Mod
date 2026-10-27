MODULE Out; (*Phu 11.9.26*)
  (*no REALS, strings left-aligned, INTEGERs righ-aligned*)

  CONST
    crlf = $0D0A00$;
    Left* = 0; Right* = 1;

  VAR
    digits: ARRAY 37 OF CHAR;

  PROCEDURE* Char* ["emb_putchar"] (ch: CHAR);
  (* Wait until the UART transmit buffer is empty before sending the
     character ch *)

  PROCEDURE Pad(i, width: INTEGER);
  BEGIN
    WHILE i < width DO Char(" "); INC(i) END
  END Pad;

  PROCEDURE PutString(s: ARRAY OF CHAR; print: BOOLEAN): INTEGER;
    VAR i: INTEGER;
        ch: CHAR;
  BEGIN i := 0;
    WHILE s[i] # 0X DO
      IF print THEN Char(s[i]) END ;
      INC(i)
    END ;
    RETURN i
  END PutString;

  PROCEDURE Field*(s: ARRAY OF CHAR; width: INTEGER; align: INTEGER);
    VAR i: INTEGER;
  BEGIN
    IF align = Left THEN
      i := PutString(s, TRUE);
      Pad(i, width)
    ELSE
      i := PutString(s, FALSE);
      Pad(i, width);
      i := PutString(s, TRUE)
    END
  END Field;

  PROCEDURE String*(s: ARRAY OF CHAR);
  (* Writes all of the characters in s up to the terminating 0X *)
    VAR i: INTEGER;
  BEGIN Field(s, 0, 0)
  END String;

  PROCEDURE Ln*();
  (* Writes the carriage return / line feed pair of characters (0DX, 0AX) *)
  BEGIN String(crlf)
  END Ln;

  PROCEDURE RevField(s: ARRAY OF CHAR; i, width: INTEGER);
  BEGIN
    WHILE i < width DO Char(" "); DEC(width) END ;
    REPEAT DEC(i); Char(s[i]) UNTIL i = 0
  END RevField;

  PROCEDURE* IntToBased(VAR s: ARRAY OF CHAR; n, base: INTEGER): INTEGER;
    VAR i: INTEGER;
        sign: BOOLEAN;
  BEGIN i := 0; sign := FALSE;
    IF (base = 10) & (n < 0) THEN
      sign := TRUE; n := ABS(n)
    END ;
    REPEAT
      s[i] := digits[n MOD base]; INC(i);
      n := n DIV base
    UNTIL n = 0 ;
    IF sign THEN s[i] := "-"; INC(i) END ;
    RETURN i
  END IntToBased;

  PROCEDURE IntB*(n, width, base: INTEGER);
    VAR s: ARRAY 12 OF CHAR;
        i: INTEGER;
  BEGIN ASSERT((1 < base) & (base < 37), 10);
    IF (base = 10) & (n = 80000000H) THEN
      s := "-2147483648"; Field(s, width, 0)
    ELSE
      i := IntToBased(s, n, base); RevField(s, i, width)
    END
  END IntB;

  PROCEDURE Int*(n, width: INTEGER);
    VAR s: ARRAY 12 OF CHAR;
        i: INTEGER;
  BEGIN (*IntB(n, width, 10)*)
    IF n = 80000000H THEN
      s := "8463847412-"; i := 11
    ELSE
      i := 0;
      IF n < 0 THEN Char("-"); n := -n END ;
      REPEAT s[i] := CHR(n MOD 10 + ORD("0")); n := n DIV 10; INC(i) UNTIL n = 0 ;
    END ;
    RevField(s, i, width)
    (*REPEAT Char(" "); DEC(width) UNTIL width <= i ;
    REPEAT DEC(i); Char(s[i]) UNTIL i = 0*)
  END Int;

  PROCEDURE* IntToHex(VAR s: ARRAY OF CHAR; n: INTEGER);
    VAR i: INTEGER;
  BEGIN i := 0;
    REPEAT
      s[i] := digits[n MOD 16];
      n := n DIV 16; (* -1 DIV 16 = -1 !!! *)
      INC(i)
    UNTIL i = 8
  END IntToHex;

  PROCEDURE Hex*(n, width: INTEGER);
    VAR s: ARRAY 8 OF CHAR;
        i: INTEGER;
  BEGIN IntToHex(s, n); RevField(s, 8, width)
  END Hex;

BEGIN digits := "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";
END Out.
(* vim:set ts=2 sw=2 et: *)
