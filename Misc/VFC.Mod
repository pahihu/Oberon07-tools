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
    Op0Branch* = 22; OpBranch* = 23; OpCall* = 24; OpNext* = 25; OpExit* = 26;

  TYPE
    Procedure* = PROCEDURE;
    WORD* = LONGINT;

  VAR T*, sp, rp: WORD;
      S, R: ARRAY MaxStack OF WORD;
      M: ARRAY MaxMem OF WORD;

  PROCEDURE Put*(a, v: WORD);
  BEGIN M[a] := v
  END Put;

  PROCEDURE Get*(a: WORD): WORD;
  BEGIN RETURN M[a]
  END Get;

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

  PROCEDURE RPush(x: WORD);
  BEGIN INC(rp); R[rp] := x
  END RPush;

  PROCEDURE RPop(): WORD;
    VAR x: WORD;
  BEGIN x := R[rp]; DEC(rp); RETURN x
  END RPop;

  PROCEDURE Run*(pc: WORD);
    VAR op, P: WORD;
        W: WORD;
        done: BOOLEAN;
        ch: CHAR;
        proc: Procedure;
  BEGIN P := pc; done := FALSE;
    WHILE ~done DO
      Out.String(" P="); Out.Int(P, 4);
      op := M[P]; INC(P);
      Out.String(" op="); Out.Int(op, 0); Out.Ln;
      CASE op OF
          OpHalt: done := TRUE
        | OpFetch: (*memory*) T := M[T]
        | OpStore: W := Pop(); M[W] := T; T := Pop()
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
        | Op0Branch: IF T = 0 THEN P := P + M[P] ELSE INC(P) END
        | OpBranch: P := P + M[P]
        | OpCall: RPush(P); P := M[P];
        | OpNext: W := R[rp]; DEC(W); IF W # 0 THEN P := M[P] ELSE W := RPop(); INC(P) END
        | OpExit: P := RPop()
        ELSE proc := SYSTEM.VAL(Procedure,op); proc
      END
    END
  END Run;

  PROCEDURE Execute*(cfa: WORD);
    VAR LM: ARRAY 4 OF WORD;
  BEGIN M[0] := OpCall; M[1] := cfa; M[2] := OpHalt; Run(0)
  END Execute;

BEGIN sp := 0; rp := 0; T := 0
END VFC.

(* vim:set ts=2 sw=2 et: *)
