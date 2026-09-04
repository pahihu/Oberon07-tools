MODULE RISC;     (*NW 22.9.07 / 15.12.2013*)
  IMPORT SYSTEM, Texts, Oberon, Sys := System, In,
    RISCEmu, WA := WAddress, Timer, MemCtrl, Kernel;

  TYPE
    LONGINT = Sys.INT32;
    INTEGER = Sys.INT32;

  CONST
    MOV = 0; LSL = 1; ASR = 2; ROR = 3; AND = 4; ANN = 5; IOR = 6; XOR = 7;
    ADD = 8; SUB = 9;  MUL = 10; Div = 11; FAD = 12; FSB = 13; FML = 14;
    FDV = 15;
    MT = 12; SP = 14; LNK = 15;
    Debug = FALSE;

  VAR IR: LONGINT;   (*instruction register*)
    PC: LONGINT;   (*program counter*)
    N, Z, Y, V: BOOLEAN;  (*condition flags*)
    R: ARRAY 16 OF LONGINT;
    H: LONGINT;  (*aux register for division*)
    SPC: LONGINT; (*saved pc*)
    intPnd: BOOLEAN; (*INT pending*)
    intMd: BOOLEAN; (*INT mode*)
    intEnb: BOOLEAN; (*INT enabled*)
    clk: LONGINT; (*number of clks*)
    SW: INTEGER;
    absTime: BOOLEAN;
    delayTxCounter: INTEGER;
    DelayTX: INTEGER;

  (*text output utilities*)

  PROCEDURE Ln(VAR W: Texts.Writer);
  BEGIN Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
  END Ln;

  PROCEDURE String(VAR W: Texts.Writer; s: ARRAY OF CHAR);
  BEGIN Texts.WriteString(W, s)
  END String;

  PROCEDURE Hex(VAR W: Texts.Writer; x: LONGINT);
  BEGIN Texts.WriteHex(W, x)
  END Hex;

  PROCEDURE Int(VAR W: Texts.Writer; x: LONGINT);
  BEGIN Texts.WriteInt(W, x, 0)
  END Int;

  PROCEDURE ShowABC(VAR W: Texts.Writer; s: ARRAY OF CHAR; A, B, C: LONGINT);
  BEGIN
    Ln(W); String(W, s); String(W, "--->");
    Ln(W); Hex(W, A); Hex(W, B); Hex(W, C)
  END ShowABC;

  PROCEDURE ShowInt(VAR W: Texts.Writer; s: ARRAY OF CHAR; x: LONGINT);
  BEGIN Ln(W); String(W, s); Int(W, x)
  END ShowInt;

  PROCEDURE ShowHex(VAR W: Texts.Writer; s: ARRAY OF CHAR; x: LONGINT);
  BEGIN Ln(W); String(W, s); Hex(W, x)
  END ShowHex;

  (*arithmetic utilities*)

  PROCEDURE Sign(a: LONGINT): INTEGER;
    VAR ret: INTEGER;
  BEGIN IF a < 0 THEN ret := -1 ELSE ret := 0 END;
    RETURN ret
  END Sign;

  PROCEDURE InsertByte(VAR W: Texts.Writer; m, val, pos: LONGINT): LONGINT;
    VAR hi, lo: LONGINT;
        ret: LONGINT;
  BEGIN
    IF Debug THEN
      ShowHex(W, "  m=", m); ShowHex(W, "val=", val); ShowInt(W, "pos=", pos)
    END;
    CASE pos OF
      0: hi := 100H * (m DIV 100H); lo := 0 |
      1: lo := m MOD 100H; hi := 10000H * (m DIV 10000H) |
      2: lo := m MOD 10000H; hi := 1000000H * (m DIV 1000000H) |
      3: lo := m MOD 1000000H; hi := 0 |
    END;
    ret := hi + Sys.Ash(val, 8 * pos) + lo;
    IF Debug THEN ShowHex(W, "ret=", ret) END;
    RETURN ret
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

  PROCEDURE FSum(B, C: LONGINT; u, v: Sys.Address): LONGINT;
    VAR A: LONGINT;
  BEGIN
    IF ODD(u) THEN (*FLT*)
      (*denormalization omitted*)
      A := SYSTEM.VAL(LONGINT, 0.0 + SYSTEM.VAL(LONGINT, B));
    ELSIF ODD(v) THEN (*FLOOR*)
      (*post-normalization suppressed*)
      A := Sys.Short(ENTIER(SYSTEM.VAL(REAL, B)));
    ELSE A := SYSTEM.VAL(LONGINT, SYSTEM.VAL(REAL, B) + SYSTEM.VAL(REAL, C))
    END;
    RETURN A
  END FSum;

  PROCEDURE SplitReal(r: REAL; VAR s, e, m: LONGINT);
    VAR ur: LONGINT;
  BEGIN ur := SYSTEM.VAL(LONGINT, r);
    m := ur MOD 800000H; ur := ur DIV 800000H;
    e := ur MOD 100H; ur := ur DIV 100H;
    IF ODD(ur) THEN e := 1 ELSE e := 0 END
  END SplitReal;

  PROCEDURE ShowLEDs(VAR W: Texts.Writer; value: LONGINT);
  VAR n, i: INTEGER;
      ch: CHAR;
  BEGIN
    Texts.WriteLn(W); Texts.WriteString(W, "LEDs=");
    n := value;
    FOR i := 1 TO 8 DO
      IF n >= 128 THEN ch := "O"; DEC(n, 128) ELSE ch := "." END ;
      Texts.Write(W, ch);
      n := n * 2;
    END;
    Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf);
  END ShowLEDs;

  PROCEDURE Execute*(entry, pc: WA.ADDR; VAR S: Texts.Scanner; VAR W: Texts.Writer);
    VAR a, b, op, im: LONGINT;  (*instruction fields*)
      badr, adr, tmp, A, B, C: LONGINT;
      cond: BOOLEAN;
      d1: LONGINT;
      flags: SET;
      p,q,u,v: Sys.Address;
      TIM0: Timer.Timer;
      ch: CHAR;
      prevClk: LONGINT;
      done: BOOLEAN;
      hitRate: LONGREAL;
  BEGIN
    PC := entry.ToWords() (*0*); R[13] := pc.ToBytes();
    Timer.Start(TIM0);
    intEnb := FALSE; intMd := FALSE; intPnd := FALSE;
    REPEAT (*interpretation cycle*)
      prevClk := clk;
      IR := MemCtrl.Fetch(PC); INC(clk, MemCtrl.elapsedClks);
      RISCEmu.Status(W, PC, IR, R, H, Flags(), IntFlags()); INC(PC);
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
            MOV: IF ODD(u) THEN (*u=1 special*)
                   IF ODD(q) THEN (*F1*) A := Sys.Ash(C, 16);
                   ELSIF ODD(v) THEN A := SYSTEM.VAL(LONGINT,Flags()) (*F0,v=1*)
                   ELSE A := H (*F0,v=0*)
                   END
                 ELSE A := C (*u=0*)
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
                 Y := B < C;
                 V := (Sign(B) # Sign(C)) & (Sign(B) # Sign(A)); |
            MUL: Mul32(B, C, H, A, ODD(u)); INC(clk,32) |
            Div: A := B DIV C; H := B MOD C; INC(clk,32) |
            FAD, FSB:
                 IF op = FSB THEN C := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, -7FFFFFFFH-1) / SYSTEM.VAL(SET, C)) END;
                 A := FSum(B, C, u, v); INC(clk, 2) |
            FML: A := SYSTEM.VAL(LONGINT, SYSTEM.VAL(REAL, B) * SYSTEM.VAL(REAL, C)); INC(clk, 24) |
            FDV: A := SYSTEM.VAL(LONGINT, SYSTEM.VAL(REAL, B) / SYSTEM.VAL(REAL, C)); INC(clk, 25)
         END ;
         R[a] := A; N := A < 0; Z := A = 0
      ELSIF ~ODD(q) THEN (*p & ~q: memory instruction*)
        badr := R[b] + IR MOD 100000H; adr := badr DIV 4;
        IF adr >= MemCtrl.MaxMem THEN
          RISCEmu.verbose := TRUE;
          RISCEmu.Status(W, PC - 1, IR, R, H, Flags(), IntFlags());
          Ln(W); ShowHex(W, "Error: address out of range", badr); Ln(W);
          Kernel.Exit(1);
        END ;
        IF Debug THEN ShowHex(W, "badr=", badr); ShowHex(W, " adr=", adr) END ;
        IF ~ODD(u) THEN
          IF adr >= 0 THEN (*load*)
            A := MemCtrl.Read(adr); INC(clk, MemCtrl.elapsedClks);
            IF ODD(v) THEN (*v: byte access*)
              IF Debug THEN
                Ln(W); Hex(W, A); String(W, " @"); Hex(W, badr); Ln(W);
              END;
              A := Sys.Ash(A, -8*(badr MOD 4)) MOD 100H
            END;
            R[a] := A; N := A < 0; Z := A = 0
          ELSE (*input*)
               IF adr =  -1 THEN (* ReadInt *) Sys.InInt(R[a]); (*Texts.Scan(S); R[a] := S.i; *)
            ELSIF adr =  -2 THEN (* eot *) IF In.Done = TRUE THEN R[a] := Texts.Int ELSE R[a] := Texts.Inval END (*Z := S.class # Texts.Int*)
            ELSIF adr = -16 THEN (* msec counter *)
                IF absTime THEN R[a] := SHORT(Timer.Elapsed(TIM0))
                ELSE R[a] := MemCtrl.cntFetch DIV 12000 (*12MHz clock*)
                END
            ELSIF adr = -15 THEN (* switch *) R[a] := SW
            ELSIF adr = -14 THEN (* RS-232 RX *) In.Char(ch); IF In.Done THEN R[a] := ORD(ch) END
            ELSIF adr = -13 THEN (* RS-232 status, always rdyRx *)
              IF delayTxCounter = 0 THEN R[a] := 3 ELSE R[a] := 1 END
            END 
          END
        ELSE
          IF adr >= 0 THEN (*store*)
            IF entry.ToWords() # 0 THEN
              ASSERT(adr >= pc.ToWords()); (*read-only code*)
            END;
            IF ODD(v) THEN (*v: byte access*)
              IF Debug THEN
                Ln(W); Hex(W, A); String(W, " @"); Hex(W, badr); Ln(W);
              END;
              tmp := MemCtrl.Read(adr); INC(clk, MemCtrl.elapsedClks);
              MemCtrl.Write(adr, InsertByte(W, tmp, R[a] MOD 100H, badr MOD 4)); INC(clk, MemCtrl.elapsedClks)
            ELSE MemCtrl.Write(adr, R[a]); INC(clk, MemCtrl.elapsedClks)
            END
          ELSE (*output*);
               IF adr =  -1 THEN (* WriteInt *) Texts.WriteInt(W, R[a], 4)
            ELSIF adr =  -2 THEN (* WriteChar *) Texts.Write(W, CHR(R[a] MOD 80H))
            ELSIF adr =  -3 THEN (* WriteLn *) Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
            ELSIF adr = -15 THEN (* LEDs*) ShowLEDs(W, R[a] MOD 100H)
            ELSIF adr = -14 THEN (* RS-232 TX *)
              IF delayTxCounter = 0 THEN
                delayTxCounter := DelayTX;
                Texts.Write(W, CHR(R[a] MOD 80H));
                Texts.Append(Oberon.Log, W.buf)
              ELSE
                Texts.WriteString(W, "RS-232 TX busy");
                Texts.Append(Oberon.Log, W.buf)
              END
            ELSIF adr = -13 THEN (* RS-232 ctrl *)
              IF ~ODD(R[a] DIV 2) THEN delayTxCounter := 0 END
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
          cond :=    (a = 0) & N
                  OR (a = 1) & Z
                  OR (a = 2) & Y
                  OR (a = 3) & V
                  OR (a = 4) & (Y OR Z)
                  OR (a = 5) & (N # V)
                  OR (a = 6) & ((N # V) OR Z)
                  OR (a = 7);
          IF (b < 8) & cond OR (b > 7) & ~cond THEN
            IF ODD(v) THEN R[LNK] := PC * 4 END ;
            IF ODD(u) THEN PC := (PC + IR MOD 1000000H) MOD MemCtrl.MaxMem
            ELSIF d1 = 8 THEN PC := (PC + R[IR MOD 10H]) MOD MemCtrl.MaxMem (* Astrobe RISC5 Bcc PC,Rn *)
            ELSE PC := (R[IR MOD 10H] DIV 4) MOD MemCtrl.MaxMem
            END
          END
        END
      END; INC(clk);
      IF delayTxCounter # 0 THEN
        DEC(delayTxCounter, clk - prevClk);
        IF delayTxCounter < 0 THEN delayTxCounter := 0 END ;
      END ;
      IF intPnd & intEnb & ~intMd THEN (*check INT*)
        SPC := SYSTEM.VAL(LONGINT, Flags()) * 400000H + PC;
        PC := 1;
        intMd := TRUE
      END ;
      done := (IR = -18000001H); (*HALT B -1*)
      IF RISCEmu.verbose THEN
        done := done OR (MemCtrl.cntFetch > 10000);
      END
    UNTIL done;
    MemCtrl.Flush; INC(clk, MemCtrl.elapsedClks);

    ShowInt(W, "#clks=", clk);
    ShowInt(W, "  #instr=", MemCtrl.cntFetch);
    ShowInt(W, "  #memrd=", MemCtrl.cntMemRd);
    ShowInt(W, "  #memwr=", MemCtrl.cntMemWr);
    IF MemCtrl.enabled THEN
      ShowInt(W, "  #hit=", MemCtrl.cntHit);
      ShowInt(W, "  #miss=", MemCtrl.cntMiss);
      Ln(W); String(W, "  #efficiency="); Texts.WriteReal(W, MemCtrl.Efficiency(), 0)
    END ;
    Texts.Append(Oberon.Log, W.buf)
  END Execute;

  PROCEDURE SetReg*(i: INTEGER; v: LONGINT);
  BEGIN R[i] := v;
  END SetReg;

  PROCEDURE SetSW*(v: INTEGER);
  BEGIN SW := v
  END SetSW;

  PROCEDURE UseAbsTime*;
  BEGIN absTime := TRUE; DelayTX := 0
  END UseAbsTime;

BEGIN In.Open;
  absTime := FALSE;
  clk := 0;
  delayTxCounter := 0; DelayTX := 1042
END RISC.

(* vim:set ts=2 sw=2 et: *)
