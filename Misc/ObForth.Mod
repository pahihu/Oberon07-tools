	
	(*http://www.bradrodriguez.com/papers/moving2.htm*)
	CONST Immediate = 1; MaxStack = 32; MaxRStack = 32;
  TYPE
    String = POINTER TO ARRAY OF CHAR;
    REntry = RECORD
      w: Word;
      offs: LONGINT;
    END;
    Word = POINTER TO WordDesc;
    Primitive = PROCEDURE (w: Word);
    WordDesc = RECORD
      lfa: Word;
      name: String;
      flags: INTEGER;
      cfa: Primitive;
      pfa: LONGINT; (*dict. offset DP*)
    END;
  VAR S: ARRAY MaxStack OF LONGINT;
      T: LONGINT;
      A: LONGINT;
      R: ARRAY MaxRStack OF REntry;
      sp, rp: LONGINT;
      M: ARRAY MaxMem OF LONGINT;
      DP: LONGINT;
  
  PROCEDURE Push(x: LONGINT);
  BEGIN INC(sp); S[sp] := x
  END Push;
  
  PROCEDURE Pop(): LONGINT;
  BEGIN x := S[sp]; DEC(sp); RETURN x
  END Pop;
  
  PROCEDURE RPush(w: Word; x: LONGINT);
  BEGIN INC(rp); R[rp].w := w; R[rp].x := x
  END RPush;
  
  PROCEDURE RPop(VAR w: Word; VAR offs: LONGINT);
  BEGIN w := R[rp].w; offs := R[rp].offs; DEC(rp)
  END RPop;
  
  PROCEDURE PrimAdd;
  BEGIN INC(T, Pop())
  END PrimAdd;
  
  PROCEDURE PrimSub;
  BEGIN DEC(T, Pop())
  END PrimSub;
  
  PROCEDURE PrimMul;
  BEGIN T := T * Pop()
  END PrimMul;
  
  PROCEDURE PrimDiv;
  BEGIN T := Pop() DIV T
  END PrimDiv;
  
  PROCEDURE PrimRem;
  BEGIN T := Pop() REM T
  END PrimRem;
  
  PROCEDURE DoCon(w: Word);
  BEGIN Push(T); T := w.pfa   (* PFA holds the constant value *)
  END DoCon;

  PROCEDURE PrimConstant;
  BEGIN Define(Word(), DoCon, T); ; T := Pop();
  END PrimVariable;

  PROCEDURE DoVar(w: Word);
  BEGIN Push(T); T := w.pfa   (* PFA holds the address *)
  END DoVar;

  PROCEDURE PrimVariable;
  BEGIN Define(Word(), DoVar, DP); INC(DP)
  END PrimVariable;
  
  PROCEDURE DoCol(w: Word);
  BEGIN RPush(curWord, IP); curWord := w; IP := 0
  END DoCol;
  
  PROCEDURE SemiS(w: Word);
  BEGIN RPop(curWord, IP)
  END SemiS;
  
  PROCEDURE DoBra(w: Word);
  BEGIN disp := SYSTEM.VAL(LONGINT, curWord.code[IP]); INC(IP, disp)
  END DoBra;
  
  VAR curWord: Word;
      IP: LONGINT;
      
  REPEAT w := curWord.code[IP]; INC(IP); w.cfa(w) UNTIL FALSE;



: MOVE ( n s d) push a! for r@+ a!+ next ;
  SUB SP SP 4
  STW R SP 0
  MOV R T
  LDW T DP 0
  ADD DP DP 4
  MOV A T
  LDW T DP 0
  ADD DP DP 4
__for
  IOR I I 0
  BEQ xxx
  LDW W R 0
  ADD R R 4
  STW W A 0
  ADD A A 4
  B __for
  
  SUB SP SP 

: fib dup 2 < if exit then 1- dup recurse swap 1- recurse + ;

  CMP T 2         ; 2 <
  BGE xxx
  LDW LNK SP 0    ; exit
  ADD SP SP 4
  B LNK
xxx:
  SUB T T 1       ; 1-
  SUB DP DP 4     ; dup
  STW T DP 0
  BL __FIB        ; fib
  MOV W T         ; swap
  LDW T DP 0
  STW W DP 0
  SUB T T 1       ; 1-
  BL __FIB        ; fib
  LDW W DP 0      ; +
  ADD DP DP 4
  ADD T T W
  LDW LNK SP 0    ; ret
  ADD SP SP 4
  B LNK

	
; DUP
  SUB DP DP 4
  STW T DP 0
; DROP
  LDW T DP 0
  ADD DP DP 4
; NIP
  ADD DP DP 4
; +
  LDW W DP 0
  ADD DP DP 4
  ADD T T W
; -
  LDW W DP 0
  ADD DP DP 4
  SUB T T W
; /
  LDW W DP 0
  ADD DP DP 4
  DIV T W T
; MOD
  LDW W DP 0
  ADD DP DP 4
  DIV W W T
  MVH T
n
  SUB DP DP 4
  STW T DP 0
  MOV T n
  MVS T hi; IOR T T lo
; :
  SUB SP SP 4
  STW LNK SP 0
; EXIT
  LDW LNK SP 0
  ADD SP SP 4
  B LNK
; CALL
  BL word
; 1-
  SUB T T 1
; 1+
  ADD T T 1
; 2*
  LSL T T 1
; 2/
  ASR T T 1
; 

	
__PROLOG
	SUB SP SP 4
	STW LNK SP 0

	SUB W T 2
	BGE 0F
__RET
	LDW LNK SP 0
	ADD SP SP 4
	B LNK
0F:
	SUB T T 1
__DUP
	SUB DP DP 4
	STW T DP 0
	BL __FIB
__SWAP
  MOV W T
  LDW T DP 0
  STW W DP 0

	SUB T T 1
	BL __FIB
__BINOP
	LDW W DP 0
	ADD DP DP 4
	ADD T T W
__RET
  LDW LNK SP 0
  ADD SP SP 4
  B LNK
	
