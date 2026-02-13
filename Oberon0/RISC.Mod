MODULE RISC;     (*NW 22.9.07 / 15.12.2013*)
  IMPORT SYSTEM, Texts, Oberon, Sys := System, In, RISCEmu;

  TYPE
    LONGINT = Sys.INT32;
    INTEGER = Sys.INT32;

  CONST
    MOV = 0; LSL = 1; ASR = 2; ROR = 3; AND = 4; ANN = 5; IOR = 6; XOR = 7;
    ADD = 8; SUB = 9;  MUL = 10; Div = 11; FAD = 12; FSB = 13; FML = 14;
    FDV = 15;

  VAR IR: LONGINT;   (*instruction register*)
    PC: LONGINT;   (*program counter*)
    N, Z, Y, V: BOOLEAN;  (*condition flags*)
    R: ARRAY 16 OF LONGINT;
    H: LONGINT;  (*aux register for division*)

  PROCEDURE Sign(a: LONGINT): INTEGER;
    VAR ret: INTEGER;
  BEGIN IF a < 0 THEN ret := -1 ELSE ret := 0 END;
    RETURN ret
  END Sign;

  PROCEDURE InsertByte(m, val, pos: LONGINT): LONGINT;
    VAR hi, lo: LONGINT;
  BEGIN pos := 8*pos; lo := m MOD ASH(100H, pos);
    IF pos = 24 THEN hi := 0
    ELSE hi := m DIV ASH(100H, pos+8)
    END;
    RETURN hi + ASH(val, pos) + lo
  END InsertByte;

  PROCEDURE Flags(): LONGINT;
    VAR ret: LONGINT;
  BEGIN ret := 0;
    IF V THEN ret := ret + 1 END;
    IF Y THEN ret := ret + 2 END;
    IF Z THEN ret := ret + 4 END;
    IF N THEN ret := ret + 8 END;
    RETURN ret
  END Flags;

  PROCEDURE Execute*(VAR M: ARRAY OF LONGINT; pc: LONGINT;
      VAR S: Texts.Scanner; VAR W: Texts.Writer);
    VAR a, b, op, im: LONGINT;  (*instruction fields*)
      badr, adr, A, B, C: LONGINT;
      MemSize: LONGINT;
      cond: BOOLEAN;
  BEGIN PC := pc (*0*); R[13] := pc * 4; R[14] := Sys.Short(LEN(M)*4);
    REPEAT (*interpretation cycle*)
      IR := M[PC]; RISCEmu.Status(W, PC, IR, R, H, N, Z); INC(PC);
      a := IR DIV 1000000H MOD 10H;
      b := IR DIV 100000H MOD 10H;
      op := IR DIV 10000H MOD 10H;
      im := IR MOD 10000H;
      IF ~ODD(ASH(IR, -31)) THEN  (*~p:  register instruction*)
        B := R[b];
        IF ~ODD(ASH(IR, -30)) THEN (*~q*) C := R[IR MOD 10H]
        ELSIF ~ODD(ASH(IR, -28)) THEN (*q&~v*) C := im 
        ELSE (*q&v*) C := Sys.BinOr(im, 0FFFF0000H)
        END ;
        CASE op OF
            MOV: IF ~ODD(ASH(IR, -29)) THEN A := C (*u=0*)
                 ELSE (*u=1*)
                   IF ODD(ASH(IR, -30)) THEN (*F1*) A := ASH(C, 16);
                   ELSIF ~ODD(ASH(IR, -28)) THEN A := H (*F0,v=0*)
                   ELSE A := Flags() (*F0,v=1*)
                   END
                 END |
            LSL: A := SYSTEM.LSH(B, C) |
            ASR: A := Sys.Short(ASH(B, -C)) |
            ROR: A := SYSTEM.ROT(B, -C) |
            AND: A := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, B) * SYSTEM.VAL(SET, C)) |
            ANN: A := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, B) - SYSTEM.VAL(SET, C)) |
            IOR: A := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, B) + SYSTEM.VAL(SET, C)) |
            XOR: A := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, B) / SYSTEM.VAL(SET, C)) |
            ADD: A := B + C;
                 IF ODD(ASH(IR,-29)) & Y THEN INC(A) END;
                 Y := ((B < 0) & (C < 0)) OR
                      ((B < 0) & (A >= 0)) OR
                      ((C < 0) & (A >= 0));
                 V := (Sign(B) = Sign(C)) & (Sign(B) # Sign(A)); |
            SUB: A := B - C;
                 IF ODD(ASH(IR,-29)) & ~Y THEN DEC(A) END;
                 Y := ~(B < C);
                 V := (Sign(B) # Sign(C)) & (Sign(B) # Sign(A)); |
            MUL: A := B * C |
            Div: A := B DIV C; H := B MOD C |
            FAD: A := SYSTEM.VAL(LONGINT, SYSTEM.VAL(REAL, B) + SYSTEM.VAL(REAL, C)) |
            FSB: A := SYSTEM.VAL(LONGINT, SYSTEM.VAL(REAL, B) - SYSTEM.VAL(REAL, C)) |
            FML: A := SYSTEM.VAL(LONGINT, SYSTEM.VAL(REAL, B) * SYSTEM.VAL(REAL, C)) |
            FDV: A := SYSTEM.VAL(LONGINT, SYSTEM.VAL(REAL, B) / SYSTEM.VAL(REAL, C))
         END ;
         R[a] := A; N := A < 0; Z := A = 0
      ELSIF ~ODD(ASH(IR, -30)) THEN (*p & ~q: memory instruction*)
        badr := R[b] + IR MOD 100000H; adr := badr DIV 4;
        IF ~ODD(ASH(IR, -29)) THEN
          IF adr >= 0 THEN (*load*)
            A := M[adr];
            IF ODD(ASH(IR,-28)) THEN (*v: byte access*)
              A := ASH(A, -8*(badr MOD 4)) MOD 100H
            END;
            R[a] := A; N := A < 0; Z := A = 0
          ELSE (*input*)
            IF adr = -1 THEN (*ReadInt*) In.LongInt(R[a]); (*Texts.Scan(S); R[a] := S.i; *)
            ELSIF adr = -2 THEN (*eot*)  Z := In.Done = FALSE (*S.class # Texts.Int*)
            END 
          END
        ELSE
          IF adr >= 0 THEN (*store*)
            IF ODD(ASH(IR,-28)) THEN (*v: byte access*)
              M[adr] := InsertByte(M[adr], R[a] MOD 100H, badr MOD 4)
            ELSE M[adr] := R[a];
            END
          ELSE (*output*);
            IF adr = -1 THEN Texts.WriteInt(W, R[a], 4)
            ELSIF adr = -2 THEN Texts.Write(W, CHR(R[a] MOD 80H))
            ELSIF adr = -3 THEN Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
            END
          END
        END
      ELSE (* p & q: branch instruction*)
        b := a; a := a MOD 8;
        cond := (a = 0) & N OR (a = 1) & Z OR (a = 2) & Y OR (a = 3) & V OR
                (a = 4) & (~Y OR Z) OR (a = 5) & (N # V) OR (a = 6) & ((N # V) OR Z) OR (a = 7);
        IF (b < 8) & cond OR (b > 7) & ~cond THEN
          IF ODD(ASH(IR, -28)) THEN R[15] := PC * 4 END ;
          IF ODD(ASH(IR, -29)) THEN PC := (PC + (IR MOD 1000000H)) MOD 40000H 
          ELSE PC := R[IR MOD 10H] DIV 4
          END
        END
      END
    UNTIL PC = 0;
    Texts.Append(Oberon.Log, W.buf)
  END Execute;
END RISC.

(* vim:set ts=2 sw=2 et: *)
