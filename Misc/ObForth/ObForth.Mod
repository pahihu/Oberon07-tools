MODULE ObForth;
  IMPORT VFC, SYSTEM, Out, Timer, Unix;

  CONST Forth = 0; Macro = 1;
    NUL = 0FFX; TAB = 9X; CR = 0DX; LF = 0AX; MaxLine = 83;

  TYPE
    String = POINTER TO ARRAY OF CHAR;
    Word = POINTER TO WordDesc;
    WordDesc = RECORD
      link: Word;
      name: String;
      cfa: LONGINT;
    END;

  VAR Dict: ARRAY 2 OF Word;
      Current: INTEGER;
      Base: LONGINT;
      DoIt: PROCEDURE (VAR s:ARRAY OF CHAR);
      S: ARRAY 32 OF CHAR;
      debug: BOOLEAN;
      TIB: ARRAY MaxLine OF CHAR;
      INN: LONGINT;
      T: Timer.Timer;

  (* -------------------------- NUmber I/O -------------------------- *)

  PROCEDURE Print(x, y, base: LONGINT);
    VAR s: ARRAY 128 OF CHAR;
        i, j, d: LONGINT;
        ch: CHAR;
        sign: BOOLEAN;
  BEGIN i := 0; sign := FALSE; IF x < 0 THEN sign := TRUE; x := -x END;
    REPEAT
      d := x MOD base; x := x DIV base;
      IF d > 9 THEN d := ORD("A")+d-10 ELSE d := ORD("0") + d END;
      s[i] := CHR(d); INC(i);
    UNTIL x = 0;
    IF sign THEN s[i] := "-"; INC(i) END;
    DEC(i); FOR j := 0 TO i DIV 2 DO
      ch := s[j]; s[j] := s[i-j]; s[i-j] := ch
    END; INC(i);
    WHILE i < y DO s[i] := " "; INC(i) END;
    s[i] := 0X;
    Out.String(s); Out.Char(" ")
  END Print;

  PROCEDURE IsNumber(VAR s: ARRAY OF CHAR; VAR x: LONGINT): BOOLEAN;
    VAR done: BOOLEAN;
        i, b, d: LONGINT;
        sign: BOOLEAN;
        ch: CHAR;
  BEGIN done := TRUE; b := Base; sign := FALSE;
    i := 0; x := 0;
    IF s[i] = "-" THEN sign := TRUE; INC(i) END;
    IF s[i] = "$" THEN b := 16; INC(i) END;
    IF s[i] = "#" THEN b := 10; INC(i) END;
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
  BEGIN Print(x, 0, 16)
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
    VAR ch: CHAR;
  BEGIN Out.String("OK ");
    ch := Key(); INN := 0;
    WHILE (INN < 80) & (ch # CR) & (ch # LF) DO
      IF ch = TAB THEN ch := " " END;
      TIB[INN] := ch; INC(INN); ch := Key()
    END;
    TIB[INN] := 20X; TIB[INN+1] := NUL; TIB[INN+2] := 20X;
    INN := 0;
    IF debug THEN Out.Ln; Out.String("X=["); Out.String(TIB); Out.String("]"); END
  END X;

  PROCEDURE Skip;
  BEGIN WHILE TIB[INN] = " " DO INC(INN) END
  END Skip;

  PROCEDURE Scan(VAR s: ARRAY OF CHAR; delim: CHAR);
    VAR i: INTEGER;
  BEGIN i := 0; WHILE TIB[INN] # delim DO s[i] := TIB[INN]; INC(i); INC(INN) END; s[i] := 0X;
    IF debug THEN Out.Ln; Out.String("Scan=["); Out.String(s); Out.String("] "); END
  END Scan;

  PROCEDURE Parse(VAR s: ARRAY OF CHAR);
  BEGIN Skip; Scan(s, " ")
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

  PROCEDURE FColon;
  BEGIN Parse(S); Header(S); DoIt := Compile;
  END FColon;

  PROCEDURE FExit;
  BEGIN Comma(VFC.OpExit)
  END FExit;

  PROCEDURE FSemis;
  BEGIN FExit; DoIt := Interpret;
  END FSemis;

  PROCEDURE FHere;
  BEGIN VFC.Here;
  END FHere;

  PROCEDURE FAgain;
  BEGIN Comma(VFC.OpBranch); VFC.Comma;
  END FAgain;

  PROCEDURE FIf;
  BEGIN Comma(VFC.Op0Branch); VFC.Here; Comma(0)
  END FIf;

  PROCEDURE FElse;
  BEGIN Comma(VFC.OpBranch); VFC.Here; Comma(0); VFC.Swap;
    VFC.Here; VFC.Swap; VFC.Store
  END FElse;

  PROCEDURE FThen;
  BEGIN VFC.Here; VFC.Swap; VFC.Store
  END FThen;

  PROCEDURE FWhile;
  BEGIN FIf
  END FWhile;

  PROCEDURE FRepeat;
  BEGIN VFC.Swap; FAgain; FThen;
  END FRepeat;

  PROCEDURE FFor;
  BEGIN Comma(VFC.OpRPush); VFC.Here
  END FFor;

  PROCEDURE FNext;
  BEGIN Comma(VFC.OpNext); VFC.Comma
  END FNext;

  PROCEDURE FConstant;
  BEGIN Parse(S); Header(S); Comma(VFC.OpLit); VFC.Comma; Comma(VFC.OpExit)
  END FConstant;

  PROCEDURE FCreate;
  BEGIN Parse(S); Header(S); Comma(VFC.OpLit);
    Comma(VFC.dictPtr+2); Comma(VFC.OpExit)
  END FCreate;

  PROCEDURE FAllot;
  BEGIN VFC.Allot(VFC.DPop())
  END FAllot;

  PROCEDURE FVariable;
  BEGIN FCreate; Comma(0)
  END FVariable;

  PROCEDURE FLParen;
    VAR s: ARRAY MaxLine OF CHAR;
  BEGIN Scan(s, ")"); INC(INN)
  END FLParen;

  PROCEDURE FDecimal;
  BEGIN Base := 10
  END FDecimal;

  PROCEDURE FHex;
  BEGIN Base := 16
  END FHex;

  PROCEDURE FEmit;
    VAR ch: CHAR;
  BEGIN ch := CHR(VFC.DPop() MOD 100H); Out.Char(ch)
  END FEmit;

  PROCEDURE FKey;
  BEGIN VFC.DPush(ORD(Key()))
  END FKey;

  PROCEDURE FDot;
    VAR x: LONGINT;
  BEGIN x := VFC.DPop(); Print(x, 0, Base)
  END FDot;

  PROCEDURE FDotR;
    VAR x,y: LONGINT;
  BEGIN y := VFC.DPop(); x := VFC.DPop(); Print(x, y, Base)
  END FDotR;

  PROCEDURE FForth;
  BEGIN Current := Forth
  END FForth;

  PROCEDURE FMacro;
  BEGIN Current := Macro
  END FMacro;

  PROCEDURE FCounter;
  BEGIN Timer.Start(T); VFC.DPush(0)
  END FCounter;

  PROCEDURE FPTimer;
    VAR W: LONGINT;
  BEGIN W := VFC.DPop(); VFC.DPush(Timer.Elapsed(T))
  END FPTimer;

  PROCEDURE FWords;
    VAR w: Word;
  BEGIN w := Dict[Current];
    WHILE w # NIL DO Out.String(w.name^); Out.Char(" "); w := w.link END
  END FWords;

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
    VAR NulStr: ARRAY 2 OF CHAR;
  BEGIN NulStr[0] := NUL; NulStr[1] := 0X;
    Current := Macro;
    DefProc(NulStr, X);
    DefProc(";", FSemis);
    DefProc("EXIT", FExit);
    DefMacro(">R", VFC.OpRPush);
    DefMacro("I", VFC.OpRFetch);
    DefMacro("R>", VFC.OpRPop);
    DefProc("BEGIN", FHere);
    DefProc("AGAIN", FAgain);
    DefProc("IF", FIf);
    DefProc("ELSE", FElse);
    DefProc("THEN", FThen);
    DefProc("WHILE", FWhile);
    DefProc("REPEAT", FRepeat);
    DefProc("FOR", FFor);
    DefProc("NEXT", FNext);

    DefProc("(", FLParen);

    DefMacro("+", VFC.OpAdd);
    DefMacro("-", VFC.OpSub);
    DefMacro("*", VFC.OpMul);
    DefMacro("/", VFC.OpDiv);
    DefMacro("MOD", VFC.OpMod);
    DefMacro("MIN", VFC.OpMin);
    DefMacro("MAX", VFC.OpMax);

    DefMacro("<", VFC.OpLess);
    DefMacro("=", VFC.OpEqual);
    DefMacro(">", VFC.OpGreater);

    DefMacro("AND", VFC.OpAnd);
    DefMacro("OR", VFC.OpOr);
    DefMacro("XOR", VFC.OpXor);
    DefMacro("NEGATE", VFC.OpNegate);
    DefMacro("ABS", VFC.OpAbs);
    DefMacro("NOT", VFC.OpNot);

    DefMacro("DUP", VFC.OpDup);
    DefMacro("DROP", VFC.OpDrop);
    DefMacro("SWAP", VFC.OpSwap);
    DefMacro("OVER", VFC.OpOver);

    DefMacro("@", VFC.OpFetch);
    DefMacro("!", VFC.OpStore);
    DefMacro("1+", VFC.OpInc);
    DefMacro("1-", VFC.OpDec);


    Current := Forth;
    DefProc(NulStr, X);
    Define("+", VFC.OpAdd);
    Define("-", VFC.OpSub);
    Define("*", VFC.OpMul);
    Define("/", VFC.OpDiv);
    Define("MOD", VFC.OpMod);
    Define("MIN", VFC.OpMin);
    Define("MAX", VFC.OpMax);

    Define("<", VFC.OpLess);
    Define("=", VFC.OpEqual);
    Define(">", VFC.OpGreater);

    Define("AND", VFC.OpAnd);
    Define("OR", VFC.OpOr);
    Define("XOR", VFC.OpXor);
    Define("NEGATE", VFC.OpNegate);
    Define("ABS", VFC.OpAbs);
    Define("NOT", VFC.OpNot);

    Define("DUP", VFC.OpDup);
    Define("DROP", VFC.OpDrop);
    Define("SWAP", VFC.OpSwap);
    Define("OVER", VFC.OpOver);

    DefProc("DECIMAL", FDecimal);
    DefProc("HEX", FHex);
    DefProc(".", FDot);
    DefProc(".R", FDotR);
    DefProc("EMIT", FEmit);
    DefProc("CR", Out.Ln);
    DefProc("KEY", FKey);

    DefProc("VARIABLE", FVariable);
    DefProc("CONSTANT", FConstant);
    DefProc("CREATE", FCreate);
    DefProc("ALLOT", FAllot);
    DefProc(",", VFC.Comma);
    Define("@", VFC.OpFetch);
    Define("!", VFC.OpStore);

    Define("1+", VFC.OpInc);
    Define("1-", VFC.OpDec);

    DefProc(":", FColon);
    DefProc("COUNTER", FCounter);
    DefProc("(TIMER)", FPTimer);
    DefProc("(", FLParen);
    DefProc("HERE", FHere);
    DefProc("WORDS", FWords);
    DefProc("FORTH", FForth);
    DefProc("MACRO", FMacro);
  END InitDict;

  (* ---------------------------------------------------------------- *)

BEGIN debug := FALSE;
  Dict[Forth] := NIL; Dict[Macro] := NIL; InitDict;
  IF debug THEN DumpDict(Dict[Forth]); END;
  Base := 10;
  Loop
END ObForth.

(* vim:set ts=2 sw=2 et: *)
