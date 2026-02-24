MODULE VFC;
  IMPORT SYSTEM, Logic, In, Out;

  CONST
    MaxStack = 64; MaxMem = 8192;
    OpHalt* = 0;
    OpFetch* = 1; OpStore* = 2; OpLit* = 3;
    OpAdd* = 4; OpSub* = 5; OpMul* = 6; OpDiv* = 7; OpMod* = 8;
    OpAnd* = 9; OpOr* = 10; OpXor* = 11; OpInvert* = 12;
    OpDup* = 13; OpSwap* = 14; OpOver* = 15; OpDrop* = 16; OpRPush* = 17; OpRFetch* = 18; OpRPop* = 19;
    OpKey* = 20; OpEmit* = 21;
    Op0Branch* = 22; OpBranch* = 23; OpNext* = 24; OpExit* = 25;
    OpLess* = 26; OpEqual* = 27; OpGreater* = 28;
    OpLast* = 31;

  TYPE
    Procedure* = PROCEDURE;
    WORD* = LONGINT;

  VAR T, sp, rp: WORD;
      S, R: ARRAY MaxStack OF WORD;
      M: ARRAY MaxMem OF WORD;
      dictPtr-: WORD;
      execLvl: WORD;
      debug-: BOOLEAN;

  PROCEDURE Get*(x: WORD): WORD;
  BEGIN RETURN M[x]
  END Get;

  PROCEDURE Put*(x, y: WORD);
  BEGIN M[x] := y
  END Put;

  PROCEDURE Push*(x: WORD);
  BEGIN INC(sp); S[sp] := x
  END Push;

  PROCEDURE Pop(): WORD;
    VAR x: WORD;
  BEGIN x := S[sp]; DEC(sp); RETURN x
  END Pop;

  PROCEDURE DPush*(x: WORD);
  BEGIN Push(T); T := x
  END DPush;

  PROCEDURE DPop*(): WORD;
    VAR x: WORD;
  BEGIN x := T; T := Pop(); RETURN x
  END DPop;

  PROCEDURE Here*;
  BEGIN DPush(dictPtr)
  END Here;

  PROCEDURE Comma*;
  BEGIN M[dictPtr] := DPop(); INC(dictPtr)
  END Comma;

  PROCEDURE DPushProc*(x: Procedure);
  BEGIN DPush(SYSTEM.VAL(WORD,x))
  END DPushProc;

  PROCEDURE RPush(x: WORD);
  BEGIN INC(rp); R[rp] := x
  END RPush;

  PROCEDURE RPop(): WORD;
    VAR x: WORD;
  BEGIN x := R[rp]; DEC(rp); RETURN x
  END RPop;

  PROCEDURE Swap*;
    VAR W: WORD;
  BEGIN W := S[sp]; S[sp] := T; T := W
  END Swap;

  PROCEDURE Store*;
    VAR W: WORD;
  BEGIN W := Pop(); M[T] := W; T := Pop()
  END Store;

  PROCEDURE Run*(pc: WORD);
    VAR op, P: WORD;
        W: WORD;
        done: BOOLEAN;
        ch: CHAR;
        proc: Procedure;
  BEGIN P := pc; done := FALSE;
    WHILE ~done DO
      op := M[P]; INC(P);
      IF debug THEN
        Out.String(" P="); Out.Int(P-1, 4);
        Out.String(" op="); Out.Int(op, 0); Out.Ln;
      END;
      CASE op OF
          OpHalt: done := TRUE
        | OpFetch: (*memory*) T := M[T]
        | OpStore: W := Pop(); M[T] := W; T := Pop()
        | OpLit: Push(T); T := M[P]; INC(P)
        | OpAdd: (*arithmetic*) W := Pop(); T := W + T
        | OpSub: W := Pop(); T := W - T
        | OpMul: W := Pop(); T := W * T
        | OpDiv: W := Pop(); T := W DIV T
        | OpMod: W := Pop(); T := W MOD T
        | OpAnd: (*logic*) W := Pop(); T := Logic.And(W, T)
        | OpOr: W := Pop(); T := Logic.Or(W, T)
        | OpXor: W := Pop(); T := Logic.Xor(W, T)
        | OpInvert: T := Logic.Not(T)
        | OpDup: (*stack*) Push(T)
        | OpSwap: W := S[sp]; S[sp] := T; T := W
        | OpOver: W := S[sp]; Push(T); T := W
        | OpDrop: T := Pop()
        | OpRPush: RPush(T); T := Pop()
        | OpRFetch: Push(T); T := R[rp]
        | OpRPop: Push(T); T := RPop()
        | OpKey: (*IO*) Push(T); In.Char(ch); T := ORD(ch)
        | OpEmit: Out.Char(CHR(T MOD 100H)); T := Pop()
        | Op0Branch: IF T = 0 THEN P := M[P] ELSE INC(P) END; T := Pop();
        | OpBranch: P := M[P]
        | OpNext: W := R[rp]; DEC(W); IF W # 0 THEN R[rp] := W; P := M[P] ELSE W := RPop(); INC(P) END
        | OpExit: P := RPop()
        | OpLess: W := Pop(); IF W < T THEN T := -1 ELSE T := 0 END
        | OpEqual: W := Pop(); IF W = T THEN T := -1 ELSE T := 0 END
        | OpGreater: W := Pop(); IF W > T THEN T := -1 ELSE T := 0 END
        ELSE
          IF (OpLast < op) & (op < MaxMem) THEN RPush(P); P := op
          ELSE proc := SYSTEM.VAL(Procedure,op); proc
          END
      END
    END
  END Run;

  PROCEDURE Execute*(cfa: WORD);
    VAR a: WORD;
  BEGIN ASSERT(execLvl >= 0);
    INC(execLvl);
      a := MaxMem - 2*execLvl;
      M[a] := cfa; M[a+1] := OpHalt; Run(a);
    DEC(execLvl);
  END Execute;

  PROCEDURE SetDebug*(flag: BOOLEAN);
  BEGIN debug := flag
  END SetDebug;

BEGIN sp := 0; rp := 0; T := 0;
  execLvl := 0; dictPtr := OpLast+1;
  debug := FALSE
END VFC.

(* vim:set ts=2 sw=2 et: *)
