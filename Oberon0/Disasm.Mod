MODULE Disasm; (* from ORTool.Mod / Phu 13.2.2026 *)
  IMPORT Texts;

  VAR mnemo0, mnemo1: ARRAY 16, 4 OF CHAR;  (*mnemonics*)
      specmov: ARRAY 4, 4 OF CHAR; (*spec. MOV*)
      specop: ARRAY 3, 4 OF CHAR; (*ADC,SBC,MLU*)
      memop: ARRAY 4, 4 OF CHAR; (*memory instr.*)

  PROCEDURE WriteReg*(VAR W: Texts.Writer; r: LONGINT);
  BEGIN Texts.Write(W, " ");
    IF r < 12 THEN 
      IF r < 10 THEN Texts.Write(W, " ") END;
      Texts.WriteString(W, "R"); Texts.WriteInt(W, r MOD 10H, 1);
    ELSIF r = 12 THEN Texts.WriteString(W, " MT")
    ELSIF r = 13 THEN Texts.WriteString(W, " SB")
    ELSIF r = 14 THEN Texts.WriteString(W, " SP")
    ELSIF r = 15 THEN Texts.WriteString(W, "LNK")
    END
  END WriteReg;

  PROCEDURE WriteMnemo0(VAR W: Texts.Writer; u, op, x: LONGINT);
  BEGIN
    IF u = 1 THEN
      IF op = 0 THEN Texts.WriteString(W, specmov[x]);
      ELSIF (8 <= op) & (op <= 10) THEN Texts.WriteString(W, specop[op-8])
      ELSE Texts.Write(W, "'")
      END
    ELSE Texts.WriteString(W, mnemo0[op])
    END
  END WriteMnemo0;

  PROCEDURE WriteRegB(VAR W: Texts.Writer; op, b: LONGINT);
  BEGIN IF op = 0 THEN Texts.WriteString(W, "    ")
    ELSE WriteReg(W, b)
    END
  END WriteRegB;

  PROCEDURE Opcode*(VAR W: Texts.Writer; w: LONGINT);
    VAR k, op, u, v, a, b, c: LONGINT;
  BEGIN
      k := w DIV 40000000H MOD 4;
      a := w DIV 1000000H MOD 10H;
      b := w DIV 100000H MOD 10H;
      op := w DIV 10000H MOD 10H;
      u := w DIV 10000000H MOD 4; v := u MOD 2; u := u DIV 2;
      IF k = 0 THEN
        WriteMnemo0(W, u, op, 2*k+v);
        WriteReg(W, a); WriteRegB(W, op, b); WriteReg(W, w MOD 10H)
      ELSIF k = 1 THEN
        WriteMnemo0(W, u, op, 2*k+v);
        WriteReg(W, a); WriteRegB(W, op, b); w := w MOD 10000H;
        IF w >= 8000H THEN w := w - 10000H END ;
        Texts.WriteInt(W, w, 8)
      ELSIF k = 2 THEN  (*LDR/STR*)
        Texts.WriteString(W, memop[2*u + v]);
        WriteReg(W, a); WriteReg(W, b); w := w MOD 100000H;
        IF w >= 80000H THEN w := w - 100000H END ;
        Texts.WriteInt(W, w, 8)
      ELSIF k = 3 THEN  (*Branch instr*)
        Texts.Write(W, "B");
        IF ODD(w DIV 10000000H) THEN Texts.WriteString(W, "L  ") ELSE Texts.WriteString(W, "   ") END ;
        Texts.WriteString(W, mnemo1[a]);
        IF u = 0 THEN WriteReg(W, w MOD 10H) ELSE
          w := w MOD 100000H;
          IF w >= 80000H THEN w := w - 100000H END ;
          Texts.WriteInt(W, w, 8)
        END
      END
  END Opcode;

BEGIN
  mnemo0[0] := "MOV";
  mnemo0[1] := "LSL";
  mnemo0[2] := "ASR";
  mnemo0[3] := "ROR";
  mnemo0[4] := "AND";
  mnemo0[5] := "ANN";
  mnemo0[6] := "IOR";
  mnemo0[7] := "XOR";
  mnemo0[8] := "ADD";
  mnemo0[9] := "SUB";
  mnemo0[10] := "MUL";
  mnemo0[11] := "DIV";
  mnemo0[12] := "FAD";
  mnemo0[13] := "FSB";
  mnemo0[14] := "FML";
  mnemo0[15] := "FDV";
  mnemo1[0] := " MI"; mnemo1[8] := " PL";
  mnemo1[1] := " EQ"; mnemo1[9] := " NE";
  mnemo1[2] := " CS"; mnemo1[10] := " CC";
  mnemo1[3] := " VS"; mnemo1[11] := " VC";
  mnemo1[4] := " LS"; mnemo1[12] := " HI";
  mnemo1[5] := " LT"; mnemo1[13] := " GE";
  mnemo1[6] := " LE"; mnemo1[14] := " GT";
  mnemo1[7] := "   "; mnemo1[15] := " NO";
  
  specmov[0] := "MVH";
  specmov[1] := "MVF";
  specmov[2] := "MVS";
  specmov[3] := "MVS";

  specop[0] := "ADC";
  specop[1] := "SBC";
  specop[2] := "MLU";

  memop[0] := "LDR";
  memop[1] := "LDB";
  memop[2] := "STR";
  memop[3] := "STB";
END Disasm.

(* vim:set ts=2 sw=2 et: *)
