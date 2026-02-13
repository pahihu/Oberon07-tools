MODULE Disasm; (* from ORTool.Mod / Phu 13.2.2026 *)
  IMPORT Texts;

  VAR mnemo0, mnemo1: ARRAY 16, 4 OF CHAR;  (*mnemonics*)

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

  PROCEDURE Opcode*(VAR W: Texts.Writer; w: LONGINT);
    VAR k, op, u, a, b, c: LONGINT;
  BEGIN
      k := w DIV 40000000H MOD 4;
      a := w DIV 1000000H MOD 10H;
      b := w DIV 100000H MOD 10H;
      op := w DIV 10000H MOD 10H;
      u := w DIV 20000000H MOD 2;
      IF k = 0 THEN
        Texts.WriteString(W, mnemo0[op]);
        IF u = 1 THEN Texts.Write(W, "'") END ;
        WriteReg(W, a); WriteReg(W, b); WriteReg(W, w MOD 10H)
      ELSIF k = 1 THEN
        Texts.WriteString(W, mnemo0[op]);
        IF u = 1 THEN Texts.Write(W, "'") END ;
        WriteReg(W, a); WriteReg(W, b); w := w MOD 10000H;
        IF w >= 8000H THEN w := w - 10000H END ;
        Texts.WriteInt(W, w, 8)
      ELSIF k = 2 THEN  (*LDR/STR*)
        IF u = 1 THEN Texts.WriteString(W, "STR") ELSE Texts.WriteString(W, "LDR") END ;
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
  mnemo1[0] := " MI";
  mnemo1[8] := " PL";
  mnemo1[1] := " EQ";
  mnemo1[9] := " NE";
  mnemo1[2] := " LS";
  mnemo1[10] := " HI";
  mnemo1[5] := " LT";
  mnemo1[13] := " GE";
  mnemo1[6] := " LE";
  mnemo1[14] := " GT";
  mnemo1[15] := " NO";
  
  mnemo1[3] := "   ";
  mnemo1[4] := "   ";
  mnemo1[7] := "   ";
  mnemo1[11] := "   ";
  mnemo1[12] := "   ";
END Disasm.

(* vim:set ts=2 sw=2 et: *)
