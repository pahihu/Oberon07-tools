MODULE Texts;
  IMPORT SYSTEM, Files, RealStr, Out, ConvTypes, Sys := System;

  CONST (*scanner symbol classes*)
    Inval* = 0;         (*invalid symbol*)
    Name* = 1;          (*name s (length len)*)
    String* = 2;        (*literal string s (length len)*)
    Int* = 3;           (*integer i (decimal or hexadecimal)*)
    Real* = 4;          (*real number x*)
    Char* = 6;          (*special character c*)

    (* TextBlock = TextTag offset run {run} "0" len {AsciiCode}.
      run = fnt [name] col voff len. *)

    TAB = 9X; CR = 0DX; LF = 0AX;
    TextTag = 0F1X;
    replace* = 0; insert* = 1; delete* = 2; unmark* = 3;  (*op-codes*)

    dos = FALSE;
    int64Precision = 19;
    int32Precision = 10;

  (*------------------------------------------------------------------*)
  TYPE
    Text* = POINTER TO TextDesc;
    TextDesc* = RECORD
      len*: LONGINT;
      base*: Files.File;
      rider*: Files.Rider;
    END;

    Reader* = RECORD
      eot*: BOOLEAN;
      rider: Files.Rider
    END;

    Scanner* = RECORD (Reader)
      nextCh*: CHAR;
      line*, class*: INTEGER;
      i*: LONGINT;
      x*: REAL;
      y*: LONGREAL;
      c*: CHAR;
      len*: INTEGER;
      s*: ARRAY 32 OF CHAR
    END;
    
    StringPtr = POINTER TO ARRAY OF CHAR;

    Buffer* = POINTER TO BufDesc;
    BufDesc* = RECORD
      len*: LONGINT;
      cap: LONGINT;
      s: StringPtr;
    END;

    Writer* = RECORD
      buf*: Buffer;
      rider-: Files.Rider
    END;
    
  (*------------------------------------------------------------------*)
  VAR
    LIntPrecision: INTEGER;
    HexDigits: INTEGER;
    EOL: CHAR;

  (*------------------------------------------------------------------*)

  PROCEDURE OpenFile (VAR T: Text; F: Files.File);
  BEGIN T.len := 0; T.base := F;
    IF T.base # NIL THEN
      T.len := Files.Length (T.base);
      Files.Set (T.rider, T.base, 0)
    END
  END OpenFile;

  PROCEDURE OpenRider* (VAR T: Text; R: Files.Rider);
  BEGIN OpenFile(T, Files.Base(R))
  END OpenRider;

  PROCEDURE Open* (VAR T: Text; s: ARRAY OF CHAR);
  BEGIN OpenFile(T, Files.Old(s))
  END Open;

  PROCEDURE Close* (VAR T: Text);
  BEGIN Files.Close (T.base); T := NIL
  END Close;

  (*------------------------------------------------------------------*)

  PROCEDURE OpenReader* (VAR R: Reader; T: Text; pos: LONGINT);
  BEGIN Files.Set (R.rider, T.base, pos); R.eot := FALSE
  END OpenReader;

  PROCEDURE IsLineEnd(ch: CHAR): BOOLEAN;
  BEGIN RETURN (ch = CR) OR (ch = LF)
  END IsLineEnd;
  
  PROCEDURE Read* (VAR R: Reader; VAR ch: CHAR);
  BEGIN
    IF R.eot THEN ch := 0FFX
    ELSE Files.Read (R.rider, ch);
      WHILE ~R.rider.eof & IsLineEnd(ch) & (ch # EOL) DO Files.Read (R.rider, ch) END;
      R.eot := R.rider.eof
    END
  END Read;
  
  PROCEDURE Pos* (VAR R: Reader): LONGINT;
  BEGIN RETURN Files.Pos (R.rider)
  END Pos;
  
  (*------------------------------------------------------------------*)

  PROCEDURE OpenScanner* (VAR S: Scanner; T: Text; pos: LONGINT);
  BEGIN OpenReader(S, T, pos); S.line := 0; S.nextCh := " "
  END OpenScanner;

  PROCEDURE Scan* (VAR S: Scanner);
    VAR ch: CHAR;
      neg, negE, hex: BOOLEAN;
      i, h, d, n: INTEGER;
      x: REAL;
      s: ARRAY 64 OF CHAR;
      
    PROCEDURE Save;
    BEGIN s[i] := ch; INC(i)
    END Save;
    
  BEGIN ch := S.nextCh; i := 0;
    WHILE (ch = " ") OR (ch = TAB) OR (ch = EOL) DO
      IF ch = EOL THEN INC(S.line) END ;
      Read(S, ch)
    END ;
    IF ("A" <= ch) & (ch <= "Z") OR ("a" <= ch) & (ch <= "z") THEN (*name*)
      REPEAT S.s[i] := ch; INC(i); Read(S, ch)
      UNTIL ((ch < "0") & (ch # ".") OR ("9" < ch) & (ch < "A") OR ("Z" < ch) & (ch < "a") OR ("z" < ch)) OR (i = 31);
      S.s[i] := 0X; S.len := i; S.class := Name
    ELSIF ch = 22X THEN (*string*)
      Read(S, ch);
      WHILE (ch # 22X) & (ch >= " ") & (i # 31) DO S.s[i] := ch; INC(i); Read(S, ch) END;
      S.s[i] := 0X; S.len := i+1; Read(S, ch); S.class := String
    ELSE hex := FALSE;
      IF ch = "-" THEN neg := TRUE; Save; Read(S, ch) ELSE neg := FALSE END ;
      IF ("0" <= ch) & (ch <= "9") THEN (*number*)
        n := ORD(ch) - 30H; h := n; Save; Read(S, ch);
        WHILE ("0" <= ch) & (ch <= "9") OR ("A" <= ch) & (ch <= "F") DO
          IF ch <= "9" THEN d := ORD(ch) - 30H ELSE d := ORD(ch) - 37H; hex := TRUE END ;
          n := 10*n + d; h := 10H*h + d; Save; Read(S, ch)
        END ;
        IF ch = "H" THEN (*hex integer*) Read(S, ch); S.i := h; S.class := Int  (*neg?*)
        ELSIF ch = "." THEN (*real number*)
          Save; Read(S, ch);
          WHILE ("0" <= ch) & (ch <= "9") DO  (*fraction*)
            Save; Read(S, ch)
          END ;
          IF ch = "E" THEN (*scale factor*)
            Save; Read(S, ch);
            IF ch = "-" THEN negE := TRUE; Save; Read(S, ch)
            ELSE negE := FALSE;
              IF ch = "+" THEN Save; Read(S, ch) END
            END ;
            WHILE ("0" <= ch) & (ch <= "9") DO
              Save; Read(S, ch)
            END ;
          END ;
          s[i] := 0X; x := SHORT(RealStr.Value (s));
          IF hex THEN S.class := 0 ELSE S.class := Real END
        ELSE (*decimal integer*)
          IF neg THEN S.i := -n ELSE S.i := n END;
          IF hex THEN S.class := Inval ELSE S.class := Int END
        END
      ELSE (*spectal character*) S.class := Char;
        IF neg THEN S.c := "-" ELSE S.c := ch; Read(S, ch) END
      END
    END ;
    S.nextCh := ch
  END Scan;
  
  (*------------------------------------------------------------------*)
  
  PROCEDURE OpenWriter* (VAR W: Writer);
  BEGIN NEW(W.buf); W.buf.cap := 64; W.buf.len := 0; NEW(W.buf.s, W.buf.cap);
    Files.Set(W.rider, Files.New(""), 0)
  END OpenWriter;
  
  PROCEDURE Write* (VAR W: Writer; ch: CHAR);
    VAR s: StringPtr;
        i: LONGINT;
  BEGIN
    IF W.buf.len + 2 > W.buf.cap THEN (*take 0X into account*)
      W.buf.cap := W.buf.cap + (W.buf.cap DIV 2);
      NEW(s, W.buf.cap);
      FOR i := 0 TO W.buf.len-1 DO s[i] := W.buf.s[i] END;
      W.buf.s := s;
    END;
    W.buf.s[W.buf.len] := ch; INC(W.buf.len);
    Files.Write (W.rider, ch);
  END Write;
  
  PROCEDURE WriteLn* (VAR W: Writer);
  BEGIN Write (W, EOL)
  END WriteLn;

  PROCEDURE WriteString* (VAR W: Writer; s: ARRAY OF CHAR);
    VAR i: LONGINT;
  BEGIN i := 0; WHILE s[i] # 0X DO Write (W, s[i]); INC(i) END
  END WriteString;
  
  PROCEDURE WriteInt* (VAR W: Writer; x, n: LONGINT);
    VAR i: INTEGER; x0: LONGINT;
      a: POINTER TO ARRAY OF CHAR;
  BEGIN NEW(a, LIntPrecision+1);
    IF SYSTEM.ROT(x, -31) = 1 THEN WriteString(W, " -2147483648")
    ELSE i := 0;
      IF x < 0 THEN DEC(n); x0 := -x ELSE x0 := x END;
      REPEAT
        a[i] := CHR(x0 MOD 10 + 30H); x0 := x0 DIV 10; INC(i)
      UNTIL x0 = 0;
      WHILE n > i DO Write(W, " "); DEC(n) END;
      IF x < 0 THEN Write(W, "-") END;
      REPEAT DEC(i); Write(W, a[i]) UNTIL i = 0
    END
  END WriteInt;
  
  PROCEDURE WriteHex* (VAR W: Writer; x: LONGINT);
    VAR i: INTEGER; y: LONGINT;
        a: POINTER TO ARRAY OF CHAR;
  BEGIN NEW(a, HexDigits+1); i := 0; Write(W, " ");
    REPEAT y := x MOD 10H;
      IF y < 10 THEN a[i] := CHR(y + 30H) ELSE a[i] := CHR(y + 37H) END;
      x := x DIV 10H; INC(i)
    UNTIL i = HexDigits;
    REPEAT DEC(i); Write(W, a[i]) UNTIL i = 0
  END WriteHex;

  PROCEDURE WritePair(VAR W: Writer; ch: CHAR; x: LONGINT);
  BEGIN Write(W, ch);
    Write(W, CHR(x DIV 10 + 30H)); Write(W, CHR(x MOD 10 + 30H))
  END WritePair;

  PROCEDURE WriteDate* (VAR W: Writer; t, d: LONGINT);
    VAR yr, mo, dy, hh, mm, ss: LONGINT;
  BEGIN 
    hh := t DIV 4096; mm := t DIV 64 MOD 64; ss := t MOD 64;
    yr := (d DIV 512) MOD 100; mo := d DIV 32 MOD 16; dy := d MOD 32;
    WritePair(W, " ", dy); WritePair(W, ".", mo); WritePair(W, ".", yr);
    WritePair(W, " ", hh); WritePair(W, ":", mm); WritePair(W, ":", ss)
  END WriteDate;

  (* PO2013 version *)
  PROCEDURE WriteClock* (VAR W: Writer; d: LONGINT);
  BEGIN
    WritePair(W, " ", d DIV 20000H MOD 20H);   (*day*)
    WritePair(W, ".", d DIV 400000H MOD 10H); (*month*)
    WritePair(W, ".", d DIV 4000000H MOD 40H);   (*year*)
    WritePair(W, " ", d DIV 1000H MOD 20H);   (*hour*)
    WritePair(W, ":", d DIV 40H MOD 40H);  (*min*)
    WritePair(W, ":", d MOD 40H)  (*sec*)
  END WriteClock;

  PROCEDURE WriteReal* (VAR W: Writer; x: LONGREAL; n: LONGINT);
    VAR s: ARRAY 32 OF CHAR;
  BEGIN RealStr.GiveFloat(s, x, 7, 0, ConvTypes.right); WriteString(W, s)
  END WriteReal;

  PROCEDURE OutChar (T: Text; ch: CHAR);
  BEGIN Files.Write (T.rider, ch); Out.Char (ch)
  END OutChar;

  PROCEDURE Append* (T: Text; B: Buffer);
    VAR i: LONGINT;
        ch: CHAR;
  BEGIN
    FOR i := 0 TO B.len-1 DO
      ch := B.s[i];
      OutChar (T, ch);
      IF (ch = EOL) & dos THEN
        OutChar (T, LF)
      END;
    END;
    B.len := 0
  END Append;

  (** set print precision *)
  PROCEDURE SetPrecision*(sizeLInt: INTEGER);
  BEGIN
    IF 8 = sizeLInt THEN
      LIntPrecision := int64Precision;
      HexDigits := 16
    ELSE
      LIntPrecision := int32Precision;
      HexDigits := 8
    END
  END SetPrecision;

BEGIN SetPrecision(4);
  IF dos THEN EOL := CR ELSE EOL := LF END
END Texts.

(* vim:set ts=2 sw=2 et: *)
