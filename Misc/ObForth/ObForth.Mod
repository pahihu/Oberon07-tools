MODULE ObForth;
  IMPORT VFC, SYSTEM, Out, Timer, Unix;

  CONST Forth = 0; Macro = 1;
    TAB = 9X; CR = 0DX; LF = 0AX;

  TYPE
    String = POINTER TO ARRAY OF CHAR;
    Word = POINTER TO WordDesc;
    WordDesc = RECORD
      link: Word;
      name: String;
      cfa: LONGINT;
    END;

  VAR ch: CHAR;
      Dict: ARRAY 2 OF Word;
      Current: INTEGER;
      Base: LONGINT;
      DoIt: PROCEDURE (VAR s:ARRAY OF CHAR);
      S: ARRAY 32 OF CHAR;
      debug: BOOLEAN;
      TIB: ARRAY 83 OF CHAR;
      INN: LONGINT;
      T: Timer.Timer;

  (* -------------------------- NUmber I/O -------------------------- *)

  PROCEDURE Dot;
    VAR s: ARRAY 128 OF CHAR;
        x, i, j, d: LONGINT;
        ch: CHAR;
        sign: BOOLEAN;
  BEGIN x := VFC.DPop();
    i := 0; sign := FALSE; IF x < 0 THEN sign := TRUE; x := -x END;
    REPEAT
      d := x MOD Base; x := x DIV Base;
      IF d > 9 THEN d := ORD("A")+d-10 ELSE d := ORD("0") + d END;
      s[i] := CHR(d); INC(i);
    UNTIL x = 0;
    IF sign THEN s[i] := "-"; INC(i) END;
    DEC(i); FOR j := 0 TO i DIV 2 DO
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
  BEGIN done := TRUE; b := Base; sign := FALSE;
    i := 0; x := 0;
    IF s[i] = "-" THEN sign := TRUE; INC(i) END;
    IF s[i] = "$" THEN b := 16; INC(i) END;
    WHILE (s[i] # 0X) & done DO
      ch := s[i]; INC(i);
      IF ch > "@" THEN d := ORD(ch) - ORD("A") ELSE d := ORD(ch) - ORD("0") END;
      IF (0 <= d) & (d < b) THEN x := b * x + d
      ELSE done := FALSE
      END;
    END;
    IF sign THEN x := -x END;
    RETURN done
  END IsNumber;

  PROCEDURE Hex(x: LONGINT);
    VAR sav: LONGINT;
  BEGIN sav := Base; Base := 16; VFC.DPush(x); Dot; Base := sav
  END Hex;

  (* ------------------------- Debug helpers ------------------------ *)

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

  (* ---------------------------- Parsing --------------------------- *)

  PROCEDURE Key(): CHAR;
    VAR ch: CHAR;
  BEGIN IF Unix.feof(Unix.stdin) # 0 THEN ch := 0X
    ELSE ch := CHR(Unix.fgetc(Unix.stdin))
    END;
    RETURN ch
  END Key;

  PROCEDURE X;
  BEGIN Out.String("OK ");
    ch := Key(); INN := 0;
    WHILE (INN < 80) & (ch # CR) & (ch # LF) DO
      TIB[INN] := ch; INC(INN); ch := Key()
    END;
    TIB[INN] := 20X; TIB[INN+1] := 0FFX; TIB[INN+2] := 20X;
    ch := TIB[0]; INN := 1;
  END X;

  PROCEDURE Skip;
  BEGIN WHILE (ch = " ") OR (ch = TAB) DO ch := TIB[INN]; INC(INN) END
  END Skip;

  PROCEDURE Scan(VAR s: ARRAY OF CHAR);
    VAR i: INTEGER;
  BEGIN i := 0; WHILE (ch # " ") & (ch # TAB) DO s[i] := ch; INC(i); ch := TIB[INN]; INC(INN) END; s[i] := 0X
  END Scan;

  PROCEDURE Parse(VAR s: ARRAY OF CHAR);
  BEGIN Skip; Scan(s)
  END Parse;

  PROCEDURE Length(VAR s: ARRAY OF CHAR): LONGINT;
    VAR i: LONGINT;
  BEGIN i := 0; WHILE (i < LEN(s)) & (s[i] # 0X) DO INC(i) END; RETURN i
  END Length;

  (* -------------------------- Definitions ------------------------- *)

  PROCEDURE Comma(x: LONGINT);
  BEGIN VFC.DPush(x); VFC.Comma
  END Comma;

  PROCEDURE CommaProc(x: VFC.Procedure);
  BEGIN VFC.DPushProc(x); VFC.Comma
  END CommaProc;

  PROCEDURE Header(VAR s: ARRAY OF CHAR);
    VAR d: Word;
  BEGIN NEW(d); NEW(d.name, Length(s) + 1); COPY(s, d.name^); d.link := Dict[Current];
    d.cfa := VFC.dictPtr; Dict[Current] := d;
    IF debug THEN Out.String("HEADER "); Out.String(s); Out.String(" @ "); Out.Int(VFC.dictPtr, 0) END
  END Header;

  PROCEDURE Define(s: ARRAY OF CHAR; op: LONGINT);
  BEGIN Header(s); IF debug THEN Out.String(" op="); Hex(op); Out.Ln; END;
    Comma(op); Comma(VFC.OpExit);
  END Define;

  PROCEDURE DefProc(s: ARRAY OF CHAR; op: VFC.Procedure);
  BEGIN Header(s); CommaProc(op); Comma(VFC.OpExit)
  END DefProc;

  PROCEDURE DefMacro(s: ARRAY OF CHAR; op: LONGINT);
  BEGIN Header(s); Comma(VFC.OpLit); Comma(op); CommaProc(VFC.Comma); Comma(VFC.OpExit)
  END DefMacro;

  (* ------------------------- Text Interpreter --------------------- *)

  PROCEDURE Err(VAR s: ARRAY OF CHAR);
  BEGIN Out.String(s); Out.String("? "); Out.Ln; Out.Flush
  END Err;

  PROCEDURE Find(dict: Word; VAR s: ARRAY OF CHAR): Word;
    VAR ret: Word;
  BEGIN ret := NIL;
    WHILE (dict # NIL) & (ret = NIL) DO
      IF s = dict.name^ THEN ret := dict END; dict := dict.link
    END;
    RETURN ret;
  END Find;

  PROCEDURE Interpret(VAR s: ARRAY OF CHAR);
    VAR w: Word;
        x: LONGINT;
  BEGIN w := Find(Dict[Forth], s);
    IF debug THEN Dump(w) END;
    IF w # NIL THEN VFC.Execute(w.cfa)
    ELSIF IsNumber(s, x) THEN VFC.DPush(x)
    ELSE Err(s)
    END
  END Interpret;

  PROCEDURE Compile(VAR s: ARRAY OF CHAR);
    VAR w: Word;
        x: LONGINT;
  BEGIN w := Find(Dict[Macro], s);
    IF w # NIL THEN VFC.Execute(w.cfa)
    ELSE
      w := Find(Dict[Forth], s);
      IF w # NIL THEN Comma(w.cfa)
      ELSIF IsNumber(s, x) THEN Comma(VFC.OpLit); Comma(x)
      ELSE Err(s)
      END
    END
  END Compile;

  (* ------------------------- Control words ------------------------ *)

  PROCEDURE Colon;
  BEGIN Parse(S); Header(S); DoIt := Compile;
  END Colon;

  PROCEDURE Exit;
  BEGIN Comma(VFC.OpExit)
  END Exit;

  PROCEDURE Semis;
  BEGIN Exit; DoIt := Interpret;
  END Semis;

  PROCEDURE Begin;
  BEGIN VFC.Here;
  END Begin;

  PROCEDURE Again;
  BEGIN Comma(VFC.OpBranch); VFC.Comma;
  END Again;

  PROCEDURE If;
  BEGIN Comma(VFC.Op0Branch); VFC.Here; Comma(0)
  END If;

  PROCEDURE Else;
  BEGIN Comma(VFC.OpBranch); VFC.Here; Comma(0); VFC.Swap;
    VFC.Here; VFC.Swap; VFC.Store
  END Else;

  PROCEDURE Then;
  BEGIN VFC.Here; VFC.Swap; VFC.Store
  END Then;

  PROCEDURE While;
  BEGIN If
  END While;

  PROCEDURE Repeat;
  BEGIN VFC.Swap; Again; Then;
  END Repeat;

  PROCEDURE For;
  BEGIN Comma(VFC.OpRPush); VFC.Here
  END For;

  PROCEDURE Next;
  BEGIN Comma(VFC.OpNext); VFC.Comma
  END Next;

  PROCEDURE Constant;
  BEGIN Parse(S); Header(S); Comma(VFC.OpLit); VFC.Comma; Comma(VFC.OpExit)
  END Constant;

  PROCEDURE Variable;
  BEGIN Parse(S); Header(S); Comma(VFC.OpLit);
    Comma(VFC.dictPtr+1); Comma(VFC.OpExit); Comma(0)
  END Variable;

  PROCEDURE FCounter;
  BEGIN Timer.Start(T); VFC.DPush(0)
  END FCounter;

  PROCEDURE FTimer;
    VAR W: LONGINT;
  BEGIN W := VFC.DPop(); VFC.DPush(Timer.Elapsed(T))
  END FTimer;

  (* --------------------------- Main loop -------------------------- *)

  PROCEDURE Loop;
    VAR w: Word;
        x: LONGINT;
  BEGIN DoIt := Interpret;
    X; Parse(S);
    WHILE S # "BYE" DO
      IF debug THEN Out.String(S); Out.Ln; END;
      DoIt(S); Parse(S)
    END
  END Loop;

  (* -------------------------- Dictionary -------------------------- *)

  PROCEDURE InitDict;
    VAR FFX: ARRAY 2 OF CHAR;
  BEGIN
    Current := Macro;
    DefProc(";", Semis);
    DefProc("EXIT", Exit);
    DefMacro(">R", VFC.OpRPush);
    DefMacro("I", VFC.OpRFetch);
    DefMacro("R>", VFC.OpRPop);
    DefProc("BEGIN", Begin);
    DefProc("AGAIN", Again);
    DefProc("IF", If);
    DefProc("ELSE", Else);
    DefProc("THEN", Then);
    DefProc("WHILE", While);
    DefProc("REPEAT", Repeat);
    DefProc("FOR", For);
    DefProc("NEXT", Next);

    DefMacro("@", VFC.OpFetch);
    DefMacro("!", VFC.OpStore);
    DefMacro("+", VFC.OpAdd);
    DefMacro("-", VFC.OpSub);
    DefMacro("*", VFC.OpMul);
    DefMacro("/", VFC.OpDiv);
    DefMacro("<", VFC.OpLess);
    DefMacro("=", VFC.OpEqual);
    DefMacro(">", VFC.OpGreater);
    DefMacro("MOD", VFC.OpMod);
    DefMacro("AND", VFC.OpAnd);
    DefMacro("OR", VFC.OpOr);
    DefMacro("XOR", VFC.OpXor);
    DefMacro("INVERT", VFC.OpInvert);
    DefMacro("DUP", VFC.OpDup);
    DefMacro("SWAP", VFC.OpSwap);
    DefMacro("OVER", VFC.OpOver);
    DefMacro("DROP", VFC.OpDrop);

    Current := Forth;
    Define("@", VFC.OpFetch);
    Define("!", VFC.OpStore);
    Define("+", VFC.OpAdd);
    Define("-", VFC.OpSub);
    Define("*", VFC.OpMul);
    Define("/", VFC.OpDiv);
    Define("<", VFC.OpLess);
    Define("=", VFC.OpEqual);
    Define(">", VFC.OpGreater);
    Define("MOD", VFC.OpMod);
    Define("AND", VFC.OpAnd);
    Define("OR", VFC.OpOr);
    Define("XOR", VFC.OpXor);
    Define("INVERT", VFC.OpInvert);
    Define("DUP", VFC.OpDup);
    Define("SWAP", VFC.OpSwap);
    Define("OVER", VFC.OpOver);
    Define("DROP", VFC.OpDrop);
    Define("KEY", VFC.OpKey);
    Define("EMIT", VFC.OpEmit);
    DefProc("CONSTANT", Constant);
    DefProc("VARIABLE", Variable);

    DefProc(":", Colon);
    DefProc(".", Dot);
    DefProc("COUNTER", FCounter);
    DefProc("TIMER", FTimer);
    FFX[0] := 0FFX; FFX[1] := 0X; DefProc(FFX, X);
  END InitDict;

  (* ---------------------------------------------------------------- *)

BEGIN debug := FALSE;
  Dict[Forth] := NIL; Dict[Macro] := NIL; InitDict;
  IF debug THEN DumpDict(Dict[Forth]); END;
  Base := 10;
  Loop
END ObForth.

(* vim:set ts=2 sw=2 et: *)
