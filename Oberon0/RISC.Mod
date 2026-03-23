MODULE RISC;     (*NW 22.9.07 / 15.12.2013*)
  IMPORT SYSTEM, Texts, Oberon, Sys := System, In, RISCEmu, WA := WAddress;

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
    SPC: LONGINT; (*saved pc*)
    intPnd: BOOLEAN; (*INT pending*)
    intMd: BOOLEAN; (*INT mode*)
    intEnb: BOOLEAN; (*INT enabled*)
    cnt: LONGINT; (*number of instr.*)

  PROCEDURE Sign(a: LONGINT): INTEGER;
    VAR ret: INTEGER;
  BEGIN IF a < 0 THEN ret := -1 ELSE ret := 0 END;
    RETURN ret
  END Sign;

  PROCEDURE InsertByte(m, val, pos: LONGINT): LONGINT;
    VAR hi, lo: LONGINT;
  BEGIN pos := 8*pos; lo := m MOD Sys.Ash(100H, pos);
    IF pos = 24 THEN hi := 0
    ELSE hi := m DIV Sys.Ash(100H, pos+8)
    END;
    RETURN hi + Sys.Ash(val, pos) + lo
  END InsertByte;

  PROCEDURE Flags(): SET;
    VAR ret: SET;
  BEGIN ret := {};
    IF V THEN INCL(ret, RISCEmu.VV) END;
    IF Y THEN INCL(ret, RISCEmu.CC) END;
    IF Z THEN INCL(ret, RISCEmu.ZZ) END;
    IF N THEN INCL(ret, RISCEmu.NN) END;
    RETURN ret
  END Flags;

  PROCEDURE IntFlags(): SET;
    VAR ret: SET;
  BEGIN ret := {};
    IF intEnb THEN INCL(ret, RISCEmu.INTE) END;
    IF intPnd THEN INCL(ret, RISCEmu.INTP) END;
    IF intMd  THEN INCL(ret, RISCEmu.INTM) END;
    RETURN ret
  END IntFlags;

  PROCEDURE DivMod(a, b: LONGINT; VAR q, r: LONGINT);
  BEGIN q := a DIV b; r := a - q * b
  END DivMod;

  PROCEDURE Mul32(a, b: LONGINT; VAR hi, lo: LONGINT; unsigned: BOOLEAN);
    VAR hiA, loA, hiB, loB: LONGINT;
        p0, p1, p2: LONGINT;
        hiP1, loP1: LONGINT;
        loPart, hiPart: LONGINT;
        carry: LONGINT;
  BEGIN
    DivMod(a, 65536, hiA, loA);
    DivMod(b, 65536, hiB, loB);

    IF unsigned THEN
      IF loA < 0 THEN loA := loA + 65536 END;
      IF loB < 0 THEN loB := loB + 65536 END
    END;

    p0 := loA * loB;             (*fits in 32 bits*)
    p1 := hiA * loB + loA * hiB; (*fits in 32 bits*)
    p2 := hiA * hiB;             (*fits in 32 bits*)

    (*Now assemble the 64-bit result from p0, p1, p2*)

    (*Step 1: low 32 bits*)
    hiP1 := p1 DIV 65536; loP1 := p1 - hiP1 * 65536;
    loPart := p0 + loP1 * 65536;

    (*Detect carry from low part*)
    IF loPart < p0 THEN carry := 1 ELSE carry := 0 END;

    lo := loPart;

    (*Step 2: high 32 bits*)
    hi := p2 + hiP1 + carry;
  END Mul32;

  PROCEDURE SplitReal(r: REAL; VAR s, e, m: LONGINT);
    VAR ur: LONGINT;
  BEGIN ur := SYSTEM.VAL(LONGINT, r);
    m := ur MOD 800000H; ur := ur DIV 800000H;
    e := ur MOD 100H; ur := ur DIV 100H;
    IF ODD(ur) THEN e := 1 ELSE e := 0 END
  END SplitReal;

  PROCEDURE Execute*(VAR M: ARRAY OF LONGINT; entry, pc: WA.ADDR;
      VAR S: Texts.Scanner; VAR W: Texts.Writer);
    VAR a, b, op, im: LONGINT;  (*instruction fields*)
      badr, adr, A, B, C: LONGINT;
      MemSize: LONGINT;
      cond: BOOLEAN;
      d1: LONGINT;
      flags: SET;
      p,q,u,v: Sys.Address;
  BEGIN PC := entry.ToWords() (*0*); R[13] := pc.ToBytes(); R[14] := Sys.Short(LEN(M)*4);
    intEnb := FALSE; intMd := FALSE; intPnd := FALSE;
    REPEAT (*interpretation cycle*)
      IR := M[PC]; RISCEmu.Status(W, PC, IR, R, H, Flags(), IntFlags()); INC(PC);
      a := IR DIV 1000000H MOD 10H;
      b := IR DIV 100000H MOD 10H;
      op := IR DIV 10000H MOD 10H;
      im := IR MOD 10000H;
      p := ASH(IR, -31); q := ASH(IR, -30); u := ASH(IR, -29); v := ASH(IR, -28);
      IF ~ODD(p) THEN  (*~p:  register instruction*)
        B := R[b];
        IF ~ODD(q) THEN (*~q*) C := R[IR MOD 10H]
        ELSIF ~ODD(v) THEN (*q&~v*) C := im
        ELSE (*q&v*) C := Sys.BinOr(im, 0FFFF0000H)
        END ;
        CASE op OF
            MOV: IF ~ODD(u) THEN A := C (*u=0*)
                 ELSE (*u=1*)
                   IF ODD(q) THEN (*F1*) A := Sys.Ash(C, 16);
                   ELSIF ~ODD(v) THEN A := H (*F0,v=0*)
                   ELSE A := SYSTEM.VAL(LONGINT,Flags()) (*F0,v=1*)
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
                 IF ODD(u) & Y THEN INC(A) END;
                 Y := ((B < 0) & (C < 0)) OR
                      ((B < 0) & (A >= 0)) OR
                      ((C < 0) & (A >= 0));
                 V := (Sign(B) = Sign(C)) & (Sign(B) # Sign(A)); |
            SUB: A := B - C;
                 IF ODD(u) & ~Y THEN DEC(A) END;
                 Y := ~(B < C);
                 V := (Sign(B) # Sign(C)) & (Sign(B) # Sign(A)); |
            MUL: Mul32(B, C, H, A, ODD(u)); |
            Div: A := B DIV C; H := B MOD C |
            FAD: A := SYSTEM.VAL(LONGINT, SYSTEM.VAL(REAL, B) + SYSTEM.VAL(REAL, C)) |
            FSB: A := SYSTEM.VAL(LONGINT, SYSTEM.VAL(REAL, B) - SYSTEM.VAL(REAL, C)) |
            FML: A := SYSTEM.VAL(LONGINT, SYSTEM.VAL(REAL, B) * SYSTEM.VAL(REAL, C)) |
            FDV: A := SYSTEM.VAL(LONGINT, SYSTEM.VAL(REAL, B) / SYSTEM.VAL(REAL, C))
         END ;
         R[a] := A; N := A < 0; Z := A = 0
      ELSIF ~ODD(q) THEN (*p & ~q: memory instruction*)
        badr := R[b] + IR MOD 100000H; adr := badr DIV 4;
        IF ~ODD(u) THEN
          IF adr >= 0 THEN (*load*)
            A := M[adr];
            IF ODD(v) THEN (*v: byte access*)
              A := Sys.Ash(A, -8*(badr MOD 4)) MOD 100H
            END;
            R[a] := A; N := A < 0; Z := A = 0
          ELSE (*input*)
            IF adr = -1 THEN (*ReadInt*) Sys.InInt(R[a]); (*Texts.Scan(S); R[a] := S.i; *)
            ELSIF adr = -2 THEN (*eot*)  IF In.Done = TRUE THEN R[a] := Texts.Int ELSE R[a] := Texts.Inval END (*Z := S.class # Texts.Int*)
            END 
          END
        ELSE
          IF adr >= 0 THEN (*store*)
            ASSERT(adr >= pc.ToWords()); (*read-only code*)
            IF ODD(v) THEN (*v: byte access*)
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
        d1 := IR DIV 10H MOD 10H;
        IF ~ODD(u) & ~ODD(v) & ((d1 = 2) OR (d1 = 1)) THEN
          IF d1 = 1 THEN (*RTI*)
            PC := SPC MOD 400000H; flags := SYSTEM.VAL(SET, SPC DIV 400000H);
            N := RISCEmu.NN IN flags;
            Z := RISCEmu.ZZ IN flags;
            Y := RISCEmu.CC IN flags;
            V := RISCEmu.VV IN flags;
            intMd := FALSE;
          ELSE intEnb := ODD(IR) END
        ELSE
          b := a; a := a MOD 8;
          cond := (a = 0) & N OR (a = 1) & Z OR (a = 2) & Y OR (a = 3) & V OR
                  (a = 4) & (~Y OR Z) OR (a = 5) & (N # V) OR (a = 6) & ((N # V) OR Z) OR (a = 7);
          IF (b < 8) & cond OR (b > 7) & ~cond THEN
            IF ODD(v) THEN R[15] := PC * 4 END ;
            IF ODD(u) THEN PC := (PC + (IR MOD 1000000H)) MOD 40000H
            ELSE PC := R[IR MOD 10H] DIV 4
            END
          END
        END
      END; INC(cnt);
      IF intPnd & intEnb & ~intMd THEN (*check INT*)
        SPC := SYSTEM.VAL(LONGINT, Flags()) * 400000H + PC;
        PC := 1;
        intMd := TRUE
      END
    UNTIL IR = -18000001H; (*HALT B -1*)
    Texts.WriteString(W, "#instr="); Texts.WriteInt(W, cnt, 0); Texts.WriteLn(W);
    Texts.Append(Oberon.Log, W.buf)
  END Execute;

BEGIN cnt := 0; In.Open
END RISC.

(* vim:set ts=2 sw=2 et: *)
