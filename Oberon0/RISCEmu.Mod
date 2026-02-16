MODULE RISCEmu; (* Phu 13.2.2026 *)
  IMPORT Texts, Oberon, Disasm, Sys := System;

  CONST TAB = 09X;

  TYPE
    LONGINT = Sys.INT32;
    INTEGER = Sys.INT32;

  VAR
    verbose*: BOOLEAN;

  PROCEDURE Ln(VAR W: Texts.Writer);
  BEGIN Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
  END Ln;

  PROCEDURE OutHex(VAR W: Texts.Writer; r: LONGINT);
  BEGIN Texts.Write(W, "="); Texts.WriteHex(W, r); Texts.Write(W, " ")
  END OutHex;

  PROCEDURE Out(VAR W: Texts.Writer; s: ARRAY OF CHAR; r: LONGINT);
  BEGIN Texts.WriteString(W, s); OutHex(W, r)
  END Out;

  PROCEDURE OutReg(VAR W: Texts.Writer; i: INTEGER; r: LONGINT);
  BEGIN Disasm.WriteReg(W, i); OutHex(W, r)
  END OutReg;

  PROCEDURE OutFlag(VAR W: Texts.Writer; ch: CHAR; x: BOOLEAN);
  BEGIN IF x THEN Texts.Write(W, ch) ELSE Texts.Write(W, "-") END
  END OutFlag;

  PROCEDURE Status*(VAR W: Texts.Writer; PC, IR: LONGINT; R: ARRAY OF LONGINT; H: LONGINT; N,Z,Y,V: BOOLEAN);
    VAR i: INTEGER;
  BEGIN
    IF verbose THEN
      Texts.WriteString(W, " verbose="); Texts.WriteBoolean(W, verbose); Texts.WriteLn(W);
      Texts.WriteInt(W, PC, 4); Texts.Write(W, TAB); Texts.WriteHex(W, IR); Texts.Write(W, TAB);
      Disasm.Opcode(W, IR); Ln(W);
      Out(W, "  PC", PC); Out(W, "   H", H); (*PC,H*)
      Texts.WriteString(W, "  CC= "); (*Flags*)
      OutFlag(W, "N", N); OutFlag(W, "Z", Z);
      OutFlag(W, "C", Y); OutFlag(W, "V", V);
      FOR i := 0 TO 15 DO (*regs*)
        IF i MOD 4 = 0 THEN Ln(W) END;
        OutReg(W, i, R[i])
      END; Ln(W); Ln(W); Ln(W)
    END
  END Status;
    
BEGIN verbose := TRUE
END RISCEmu.

(* vim:set ts=2 sw=2 et: *)
