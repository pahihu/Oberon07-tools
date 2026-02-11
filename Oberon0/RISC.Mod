MODULE RISC;     (*NW 22.9.07 / 15.12.2013*)
  IMPORT SYSTEM, Texts, Oberon, Sys := System, In, OSG;

  TYPE
    LONGINT = Sys.INT32;
    INTEGER = Sys.INT32;

  CONST
    MOV = 0; LSL = 1; ASR = 2; ROR = 3; AND = 4; ANN = 5; IOR = 6; XOR = 7;
    ADD = 8; SUB = 9;  MUL = 10; Div = 11;

  VAR IR: LONGINT;   (*instruction register*)
    PC: LONGINT;   (*program counter*)
    N, Z: BOOLEAN;  (*condition flags*)
    R: ARRAY 16 OF LONGINT;
    H: LONGINT;  (*aux register for division*)

  PROCEDURE Ln;
  BEGIN Texts.WriteLn(OSG.W); Texts.Append(Oberon.Log, OSG.W.buf)
  END Ln;

  PROCEDURE OutHex(r: LONGINT);
  BEGIN Texts.Write(OSG.W, "="); Texts.WriteHex(OSG.W, r); Texts.Write(OSG.W, " ")
  END OutHex;

  PROCEDURE Out(s: ARRAY OF CHAR; r: LONGINT);
  BEGIN Texts.WriteString(OSG.W, s); OutHex(r)
  END Out;

  PROCEDURE WriteReg(i: INTEGER);
  BEGIN
    IF i < 10 THEN Texts.Write(OSG.W, " "); END;
       IF i < 12 THEN Texts.Write(OSG.W, "R"); Texts.WriteInt(OSG.W, i, 0);
    ELSIF i = 12 THEN Texts.WriteString(OSG.W, " MT");
    ELSIF i = 13 THEN Texts.WriteString(OSG.W, " SB");
    ELSIF i = 14 THEN Texts.WriteString(OSG.W, " SP");
    ELSE Texts.WriteString(OSG.W, "LNK")
    END
  END WriteReg;

  PROCEDURE OutReg(i: INTEGER; r: LONGINT);
  BEGIN WriteReg(i); OutHex(r)
  END OutReg;

  PROCEDURE Status;
    VAR i: INTEGER;
  BEGIN Out(" PC", PC);
    FOR i := 0 TO 15 DO
      IF i MOD 4 = 0 THEN Ln END;
      OutReg(i, R[i])
    END; Ln; Ln; Ln
  END Status;
    
  PROCEDURE Execute*(VAR M: ARRAY OF LONGINT; pc: LONGINT;
      VAR S: Texts.Scanner; VAR pW: Texts.Writer);
    VAR a, b, op, im: LONGINT;  (*instruction fields*)
      adr, A, B, C: LONGINT;
      MemSize: LONGINT;
  BEGIN PC := pc (*0*); R[13] := pc * 4; R[14] := LEN(M)*4;
    REPEAT (*interpretation cycle*)
      IR := M[PC]; OSG.Decode1(PC, IR); Ln; Status; INC(PC);
      a := IR DIV 1000000H MOD 10H;
      b := IR DIV 100000H MOD 10H;
      op := IR DIV 10000H MOD 10H;
      im := IR MOD 10000H;
      IF ~ODD(ASH(IR, -31)) THEN  (*~p:  register instruction*)
        B := R[b];
        IF ~ODD(ASH(IR, -30)) THEN (*~q*) C := R[IR MOD 10H]
        ELSIF ~ODD(ASH(IR, -28)) THEN (*q&~v*) C := im 
        ELSE (*q&v*) C := im + 0FFFF0000H
        END ;
        CASE op OF
            MOV: IF ~ODD(ASH(IR, -29)) THEN A := C ELSE A := H END |
            LSL: A := SYSTEM.LSH(B, C) |
            ASR: A := ASH(B, -C) |
            ROR: A := SYSTEM.ROT(B, -C) |
            AND: A := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, B) * SYSTEM.VAL(SET, C)) |
            ANN: A := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, B) - SYSTEM.VAL(SET, C)) |
            IOR: A := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, B) + SYSTEM.VAL(SET, C)) |
            XOR: A := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, B) / SYSTEM.VAL(SET, C)) |
            ADD: A := B + C |
            SUB: A := B - C |
            MUL: A := B * C |
            Div: A := B DIV C; H := B MOD C
         END ;
         R[a] := A; N := A < 0; Z := A = 0
      ELSIF ~ODD(ASH(IR, -30)) THEN (*p & ~q: memory instruction*)
        adr := (R[b] + IR MOD 100000H) DIV 4;
        IF ~ODD(ASH(IR, -29)) THEN
          IF adr >= 0 THEN (*load*) R[a] := M[adr]; N := A < 0; Z := A = 0
          ELSE (*input*)
            IF adr = -1 THEN (*ReadInt*) In.LongInt(R[a]); (*Texts.Scan(S); R[a] := S.i; *)
            ELSIF adr = -2 THEN (*eot*)  Z := In.Done = FALSE (*S.class # Texts.Int*)
            END 
          END
        ELSE
          IF adr >= 0 THEN (*store*) M[adr] := R[a];
          ELSE (*output*);
            IF adr = -1 THEN Texts.WriteInt(OSG.W, R[a], 4)
            ELSIF adr = -2 THEN Texts.Write(OSG.W, CHR(R[a] MOD 80H))
            ELSIF adr = -3 THEN Texts.WriteLn(OSG.W); Texts.Append(Oberon.Log, OSG.W.buf)
            END
          END
        END
      ELSE (* p & q: branch instruction*)
        IF (a = 0) & N OR (a = 1) & Z OR (a = 5) & N OR (a = 6) & (N OR Z) OR (a = 7) OR
            (a = 8) & ~N OR (a = 9) & ~Z OR (a = 13) & ~N OR (a = 14) & ~(N OR Z) THEN
          IF ODD(ASH(IR, -28)) THEN R[15] := PC * 4 END ;
          IF ODD(ASH(IR, -29)) THEN PC := (PC + (IR MOD 1000000H)) MOD 40000H 
          ELSE PC := R[IR MOD 10H] DIV 4
          END
        END
      END
    UNTIL PC = 0;
    Texts.Append(Oberon.Log, OSG.W.buf)
  END Execute;
END RISC.

(* vim:set ts=2 sw=2 et: *)
