MODULE ObForth;
  IMPORT SYSTEM, Out, Unix, CharInfo, VFC;

  TYPE
    String = POINTER TO ARRAY OF CHAR;
    Word = POINTER TO WordDesc;
    WordDesc = RECORD
      link: Word;
      name: String;
      cfa: LONGINT;
    END;

  VAR ch: CHAR;
      dictPtr: LONGINT;
      current, macro: Word;
      base: LONGINT;

  PROCEDURE Hex(x: LONGINT);
    VAR s: ARRAY 32 OF CHAR;
        i, j, d: LONGINT;
        ch: CHAR;
  BEGIN i := 0;
    REPEAT
      d := x MOD 10H; x := x DIV 10H;
      IF d < 0 THEN d := d + 16 END; (*XXX temporary fix*)
      IF d > 9 THEN ch := CHR(ORD("A") + d - 10) ELSE ch := CHR(ORD("0") + d) END;
      s[i] := ch; INC(i);
    UNTIL x = 0;
    DEC(i);
    FOR j := 0 TO i DIV 2 DO
      ch := s[j]; s[j] := s[i-j]; s[i-j] := ch
    END;
    s[i+1] := 0X;
    Out.String(s);
  END Hex;

  PROCEDURE Dump(w: Word);
  BEGIN IF w # NIL THEN
      Out.String(" link="); Hex(SYSTEM.VAL(LONGINT,w.link)); Out.Ln;
      Out.String(" name="); Out.String(w.name^); Out.Ln;
      Out.String("  cfa="); Hex(w.cfa); Out.Ln;
      Out.String("   op="); Hex(VFC.Get(w.cfa)); Out.Ln;
    ELSE Out.String(" NIL")
    END; Out.Ln
  END Dump;

  PROCEDURE DumpDict(w: Word);
  BEGIN WHILE w # NIL DO Dump(w); w := w.link END
  END DumpDict;

  PROCEDURE Log(s: ARRAY OF CHAR);
  BEGIN Out.String(s); Out.Flush
  END Log;

  (* ---------------------------------------------------------------- *)

  PROCEDURE Next;
  BEGIN IF Unix.feof(Unix.stdin) # 0 THEN ch := 0X
    ELSE ch := CHR(Unix.fgetc(Unix.stdin))
    END
  END Next;

  PROCEDURE IsDelim(ch: CHAR): BOOLEAN;
  BEGIN RETURN CharInfo.IsSpace(ch) OR CharInfo.IsControl(ch)
  END IsDelim;

  PROCEDURE Skip;
  BEGIN WHILE IsDelim(ch) DO Next END
  END Skip;

  PROCEDURE Scan(VAR s: ARRAY OF CHAR);
    VAR i: INTEGER;
  BEGIN i := 0; WHILE ~IsDelim(ch) DO s[i] := ch; INC(i); Next END; s[i] := 0X
  END Scan;

  PROCEDURE Parse(VAR s: ARRAY OF CHAR);
  BEGIN Skip; Scan(s)
  END Parse;

  PROCEDURE Length(VAR s: ARRAY OF CHAR): LONGINT;
    VAR i: LONGINT;
  BEGIN i := 0; WHILE (i < LEN(s)) & (s[i] # 0X) DO INC(i) END; RETURN i
  END Length;

  PROCEDURE Define(s: ARRAY OF CHAR; op: LONGINT);
    VAR d: Word;
  BEGIN NEW(d); NEW(d.name, Length(s) + 1); COPY(s, d.name^); d.link := current;
    d.cfa := dictPtr;
    Out.String("DEFINE "); Out.String(s); Out.Char(" "); Hex(op); Out.String(" @ "); Out.Int(dictPtr, 0); Out.Ln;
    VFC.Put(dictPtr, op); VFC.Put(dictPtr+1, VFC.OpExit); INC(dictPtr, 2);
    current := d
  END Define;

  PROCEDURE DefineProc(s: ARRAY OF CHAR; op: VFC.Procedure);
  BEGIN Define(s, SYSTEM.VAL(LONGINT,op))
  END DefineProc;

  PROCEDURE Find(dict: Word; VAR s: ARRAY OF CHAR): Word;
    VAR ret: Word;
  BEGIN ret := NIL;
    WHILE (dict # NIL) & (ret = NIL) DO
      IF s = dict.name^ THEN ret := dict END; dict := dict.link
    END;
    RETURN ret;
  END Find;

  PROCEDURE Dot;
    VAR s: ARRAY 128 OF CHAR;
        x, i, j, d: LONGINT;
        ch: CHAR;
        sign: BOOLEAN;
  BEGIN x := VFC.DPop();
    i := 0; sign := FALSE; IF x < 0 THEN sign := TRUE; x := -x END;
    REPEAT
      d := x MOD base;
      IF d < 0 THEN INC(d, base) END;
      IF d > 9 THEN ch := CHR(ORD("A")+d-10) ELSE ch := CHR(ORD("0") + d) END;
      s[i] := ch; INC(i);
      x := x DIV base;
    UNTIL x = 0;
    IF sign THEN s[i] := "-"; INC(i) END;
    DEC(i);
    FOR j := 0 TO i DIV 2 DO
      ch := s[j]; s[j] := s[i-j]; s[i-j] := ch
    END;
    s[i+1] := 0X;
    Out.String(s); Out.Char(" ")
  END Dot;

  PROCEDURE IsNumber(VAR s: ARRAY OF CHAR; VAR x: LONGINT): BOOLEAN;
    VAR done: BOOLEAN;
        i, b, d: LONGINT;
        sign: BOOLEAN;
        ch: CHAR;
  BEGIN done := TRUE; b := base; sign := FALSE;
    i := 0; x := 0;
    IF s[i] = "-" THEN sign := TRUE; INC(i) END;
    IF s[i] = "$" THEN b := 16; INC(i) END;
    WHILE (s[i] # 0X) & done DO
      ch := s[i]; INC(i);
      IF ch > "@" THEN d := ORD(ch) - ORD("A") ELSE d := ORD(ch) - ORD("0") END;
      IF (0 < d) & (d < b) THEN x := b * x + d
      ELSE done := FALSE
      END;
    END;
    IF sign THEN x := -x END;
    RETURN done
  END IsNumber;

  PROCEDURE Test;
    VAR s: ARRAY 32 OF CHAR;
        w: Word;
        x: LONGINT;
  BEGIN Next; Parse(s);
    WHILE s # "BYE" DO
      Out.String(s); Out.Ln;
      w := Find(current, s);
      Dump(w);
      IF w # NIL THEN VFC.Execute(w.cfa)
      ELSIF IsNumber(s, x) THEN VFC.DPush(x)
      ELSE Out.String(s); Out.String(" ?")
      END;
      Parse(s)
    END
  END Test;

  PROCEDURE InitDict;
  BEGIN Define("+", VFC.OpAdd); DefineProc(".", Dot)
  END InitDict;

BEGIN base := 10; dictPtr := 4; current := NIL; macro := NIL;
  InitDict; DumpDict(current); Test
END ObForth.

(* vim:set ts=2 sw=2 et: *)
