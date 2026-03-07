MODULE ObForth;
  IMPORT VFC, SYSTEM, IO, Timer;

  CONST Forth = 0; Macro = 1; MaxStr = 7;
    NUL = 0FFX; TAB = 9X; CR = 0DX; LF = 0AX; MaxLine = 83;

  TYPE
    String = ARRAY MaxStr+1 OF CHAR;
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
      L: INTEGER;
      S: ARRAY 32 OF CHAR;
      debug: BOOLEAN;
      TIB: ARRAY MaxLine OF CHAR;
      INN: LONGINT;
      T: Timer.Timer;

  (* -------------------------- Number I/O -------------------------- *)

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
  BEGIN IO.Print(x, 0, 16)
  END Hex;

  (* ------------------------- Debug helpers ------------------------ *)

  PROCEDURE Dump(w: Word);
  BEGIN IF w # NIL THEN
      IO.Type(" link="); Hex(SYSTEM.VAL(LONGINT,w.link)); IO.Cr;
      IO.Type(" name="); IO.Type(w.name); IO.Cr;
      IO.Type("  cfa="); Hex(w.cfa); IO.Cr;
      IO.Type("   op="); Hex(VFC.Get(w.cfa)); IO.Cr;
    ELSE IO.Type(" NIL")
    END; IO.Cr
  END Dump;

  PROCEDURE DumpDict(w: Word);
  BEGIN WHILE w # NIL DO Dump(w); w := w.link END
  END DumpDict;

  PROCEDURE Log(s: ARRAY OF CHAR);
  BEGIN IO.Type(s); IO.Flush
  END Log;

  (* ---------------------------- Parsing --------------------------- *)

  PROCEDURE X;
    VAR ch: CHAR;
  BEGIN IO.Type("OK ");
    ch := IO.Key(); INN := 0;
    WHILE (INN < 80) & (ch # CR) & (ch # LF) DO
      IF ch = TAB THEN ch := " " END;
      TIB[INN] := ch; INC(INN); ch := IO.Key()
    END;
    TIB[INN] := 20X; TIB[INN+1] := NUL; TIB[INN+2] := 20X;
    INN := 0;
    IF debug THEN IO.Cr; IO.Type("X=["); IO.Type(TIB); IO.Type("]"); END
  END X;

  PROCEDURE Skip;
  BEGIN WHILE TIB[INN] = " " DO INC(INN) END
  END Skip;

  PROCEDURE Scan(VAR s: ARRAY OF CHAR; delim: CHAR): INTEGER;
    VAR i: INTEGER;
  BEGIN i := 0; WHILE TIB[INN] # delim DO s[i] := TIB[INN]; INC(i); INC(INN) END; s[i] := 0X;
    IF debug THEN IO.Cr; IO.Type("Scan=["); IO.Type(s); IO.Type("] "); END;
    RETURN i
  END Scan;

  PROCEDURE Parse;
  BEGIN Skip; L := Scan(S, " ")
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

  PROCEDURE Pack(src: ARRAY OF CHAR; VAR dst: String);
    VAR i, j: INTEGER;
  BEGIN j := 1; i := 0;
    WHILE (src[i] # 0X) DO
      IF j < LEN(dst)-1 THEN dst[j] := src[i]; INC(j); END;
      INC(i);
    END;
    WHILE j < LEN(dst) DO dst[j] := 0X; INC(j) END;
    dst[0] := CHR(i)
  END Pack;

  PROCEDURE Pack2(s: ARRAY OF CHAR; VAR offs: INTEGER): LONGINT;
    VAR r: LONGINT;
        i, j: INTEGER;
  BEGIN r := 0; i := 0; j := offs;
    WHILE (i < 4) & (s[j] # 0X) DO
      r := 64 * r + ORD(s[j]) - 32;
    END;
    offs := j; RETURN r
  END Pack2;

  PROCEDURE Header2(s: ARRAY OF CHAR);
  BEGIN Comma(Dict[Current]); 
  END Header2;

  PROCEDURE Header(s: ARRAY OF CHAR);
    VAR d: Word;
  BEGIN NEW(d); Pack(s, d.name); d.link := Dict[Current];
    d.cfa := VFC.dictPtr; Dict[Current] := d;
    IF debug THEN IO.Type("HEADER "); IO.Type(s); IO.Type(" @ "); IO.Print(VFC.dictPtr, 0, 10) END
  END Header;

  PROCEDURE Define(s: ARRAY OF CHAR; op: LONGINT);
  BEGIN Header(s); IF debug THEN IO.Type(" op="); Hex(op); IO.Cr; END;
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
  BEGIN IO.Type(s); IO.Type("? "); IO.Cr; IO.Flush
  END Err;

  PROCEDURE Find(dict: Word; VAR s: String): Word;
    VAR ret: Word;
  BEGIN ret := NIL;
    WHILE (dict # NIL) & (ret = NIL) DO
      IF s = dict.name THEN ret := dict END; dict := dict.link
    END;
    RETURN ret
  END Find;

  PROCEDURE Interpret(VAR s: ARRAY OF CHAR);
    VAR w: Word;
        x: LONGINT;
        P: String;
  BEGIN Pack(s, P);
    w := Find(Dict[Forth], P);
    IF debug THEN Dump(w) END;
    IF w # NIL THEN VFC.Execute(w.cfa)
    ELSIF IsNumber(s, x) THEN VFC.DPush(x)
    ELSE Err(s)
    END
  END Interpret;

  PROCEDURE Compile(VAR s: ARRAY OF CHAR);
    VAR w: Word;
        x: LONGINT;
        P: String;
  BEGIN Pack(s, P);
    w := Find(Dict[Macro], P);
    IF w # NIL THEN VFC.Execute(w.cfa)
    ELSE
      w := Find(Dict[Forth], P);
      IF w # NIL THEN Comma(w.cfa)
      ELSIF IsNumber(s, x) THEN Comma(VFC.OpLit); Comma(x)
      ELSE Err(s)
      END
    END
  END Compile;

  (* ------------------------- Control words ------------------------ *)

  PROCEDURE FColon;
  BEGIN Parse; Header(S); DoIt := Compile;
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
  BEGIN Parse; Header(S); Comma(VFC.OpLit); VFC.Comma; Comma(VFC.OpExit)
  END FConstant;

  PROCEDURE FCreate;
  BEGIN Parse; Header(S); Comma(VFC.OpLit);
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
        l: INTEGER;
  BEGIN l := Scan(s, ")"); INC(INN)
  END FLParen;

  PROCEDURE FDecimal;
  BEGIN Base := 10
  END FDecimal;

  PROCEDURE FHex;
  BEGIN Base := 16
  END FHex;

  PROCEDURE FEmit;
    VAR ch: CHAR;
  BEGIN ch := CHR(VFC.DPop() MOD 100H); IO.Emit(ch)
  END FEmit;

  PROCEDURE FKey;
  BEGIN VFC.DPush(ORD(IO.Key()))
  END FKey;

  PROCEDURE FDot;
    VAR x: LONGINT;
  BEGIN x := VFC.DPop(); IO.Print(x, 0, Base)
  END FDot;

  PROCEDURE FDotR;
    VAR x,y: LONGINT;
  BEGIN y := VFC.DPop(); x := VFC.DPop(); IO.Print(x, y, Base)
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

  PROCEDURE PrintID(VAR s: String);
    VAR i: INTEGER;
  BEGIN i := 1; WHILE s[i] # 0X DO IO.Emit(s[i]); INC(i) END;
    IF ORD(s[0]) > 6 THEN IO.Emit("$") END
  END PrintID;

  PROCEDURE FWords;
    VAR w: Word;
  BEGIN w := Dict[Current];
    WHILE w # NIL DO PrintID(w.name); IO.Emit(" "); w := w.link END
  END FWords;

  (* --------------------------- Main loop -------------------------- *)

  PROCEDURE Loop;
    VAR w: Word;
        x: LONGINT;
  BEGIN DoIt := Interpret;
    X; Parse;
    WHILE S # "BYE" DO
      IF debug THEN IO.Type(S); IO.Cr; END;
      DoIt(S); Parse
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
    DefMacro("*/", VFC.OpMulDiv);


    Current := Forth;
    DefProc(NulStr, X);
    Define("+", VFC.OpAdd);
    Define("-", VFC.OpSub);
    Define("*", VFC.OpMul);
    Define("/", VFC.OpDiv);
    Define("MOD", VFC.OpMod);
    Define("MIN", VFC.OpMin);
    Define("MAX", VFC.OpMax);
    Define("*/", VFC.OpMulDiv);

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
    DefProc("CR", IO.Cr);
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
