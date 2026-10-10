MODULE RISCEmu; (* Phu 13i2.2026 *)
  IMPORT Texts, Oberon, Disasm, Sys := System,
         In, Strings, MemCtrl;

  CONST
    TAB = 09X;
    NN* = 8; ZZ* = 4; CC* = 2; VV* = 1;
    INTE* = 8; INTP* = 4; INTM* = 1;
    NumCmds = 8; CR = 0DX; LF = 0AX;
  TYPE
    LONGINT = Sys.INT32;
    INTEGER = Sys.INT32;
    Registers* = ARRAY 16 OF LONGINT;
    MachineState* = RECORD
      PC*, IR*: LONGINT;
      R*: Registers;
      H*: LONGINT;
      flags*, intFlags*: SET;
      brkpt*: LONGINT;
      step*: LONGINT;
      quit*: BOOLEAN;
    END ;
    String16 = ARRAY 16 OF CHAR;
    CmdProc = PROCEDURE(nofArgs: INTEGER; VAR args: ARRAY OF LONGINT);

  VAR
    verbose*: BOOLEAN;
    hexDigits: ARRAY 17 OF CHAR;
    W: Texts.Writer;
    rs: MachineState;
    cmds: ARRAY NumCmds OF RECORD
      name: String16;
      nofArgs: INTEGER;
      do: CmdProc
    END;
    cmdIdx: INTEGER;
    cmdEndLoop: BOOLEAN;
    cmdPrev: String16;


  PROCEDURE Flush(VAR W: Texts.Writer);
  BEGIN Texts.Append(Oberon.Log, W.buf)
  END Flush;

  PROCEDURE Ln(VAR W: Texts.Writer);
  BEGIN Texts.WriteLn(W); Flush(W)
  END Ln;

  PROCEDURE String(VAR W: Texts.Writer; s: ARRAY OF CHAR);
  BEGIN Texts.WriteString(W, s)
  END String;

  PROCEDURE Write(VAR W: Texts.Writer; ch: CHAR);
  BEGIN Texts.Write(W, ch)
  END Write;

  PROCEDURE Int(VAR W: Texts.Writer; i, w: LONGINT);
  BEGIN Texts.WriteInt(W, i, w)
  END Int;

  PROCEDURE WriteHex(VAR W: Texts.Writer; r, w: LONGINT);
    VAR s: ARRAY 9 OF CHAR;
        i, x: INTEGER;
  BEGIN s[w] := 0X; x := w;
    FOR i := 1 TO w DO
      DEC(x); s[x] := hexDigits[r MOD 16]; r := r DIV 16
    END ;
    String(W, s)
  END WriteHex;

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

  PROCEDURE CmdBreak(nofArgs: INTEGER; VAR args: ARRAY OF LONGINT);
    VAR adr: LONGINT;
  BEGIN
    IF (nofArgs = 0) & (rs.brkpt # -1) THEN
      String(W, "break at "); WriteHex(W, rs.brkpt * 4, 5); Ln(W)
    ELSE
      adr := args[0] DIV 4;
      IF rs.brkpt = adr THEN
        rs.brkpt := -1 
      ELSE
        rs.brkpt := adr
      END
    END ;
  END CmdBreak;

  PROCEDURE CmdDisasm(nofArgs: INTEGER; VAR args: ARRAY OF LONGINT);
    VAR i: INTEGER;
        m: LONGINT;
  BEGIN
    IF args[0] = -1 THEN
      args[0] := rs.PC
    ELSE
      IF nofArgs # 0 THEN args[0] := args[0] DIV 4 END ;
    END ;
    IF args[1] = -1 THEN args[1] := 16 END ;
    FOR i := 1 TO args[1] DO
      m := MemCtrl.M[args[0]];
      WriteHex(W, args[0] * 4, 5); Write(W, TAB); WriteHex(W, m, 8); Write(W, TAB);
      Disasm.Opcode(W, m); Ln(W);
      INC(args[0])
    END ;
  END CmdDisasm;

  PROCEDURE CmdDump(nofArgs: INTEGER; VAR args: ARRAY OF LONGINT);
    VAR i: INTEGER;
        m: LONGINT;
  BEGIN
    IF args[0] = -1 THEN
      args[0] := rs.PC
    ELSE
      IF nofArgs # 0 THEN args[0] := args[0] DIV 4 END
    END ;
    IF args[1] = -1 THEN args[1] := 32    END ;
    FOR i := 1 TO args[1] DO
      IF (i - 1) MOD 4 = 0 THEN
        Ln(W); WriteHex(W, args[0] * 4, 5); String(W, "   ")
      END ;
      m := MemCtrl.M[args[0]];
      WriteHex(W, m, 8); String(W, " "); INC(args[0])
    END
  END CmdDump;

  PROCEDURE CmdContinue(nofArgs: INTEGER; VAR args: ARRAY OF INTEGER);
  BEGIN cmdEndLoop := TRUE
  END CmdContinue;

  PROCEDURE CmdHelp(nofArgs: INTEGER; VAR args: ARRAY OF INTEGER);
  BEGIN
    Ln(W); String(W, "break [adr]            - break at adr, show");
    Ln(W); String(W, "cont                   - continue");
    Ln(W); String(W, "disasm [from] [len]    - disassemble (from=PC,len=24)");
    Ln(W); String(W, "dump [from] [len]      - dump (from=PC,len=24)");
    Ln(W); String(W, "help                   - print help");
    Ln(W); String(W, "quit                   - quit");
    Ln(W); String(W, "regs                   - show regs");
    Ln(W); String(W, "step [n]               - step instructions (n=1)")
  END CmdHelp;

  PROCEDURE CmdQuit(nofArgs: INTEGER; VAR args: ARRAY OF INTEGER);
  BEGIN rs.quit := TRUE; cmdEndLoop := TRUE
  END CmdQuit;

  PROCEDURE CmdStep(nofArgs: INTEGER; VAR args: ARRAY OF INTEGER);
  BEGIN
    (*Ln(W); String(W, "step="); Int(W, args[0], 0); Flush(W);*)
    IF args[0] = -1 THEN args[0] := 1 END ;
    rs.step := args[0];
    cmdEndLoop := TRUE
  END CmdStep;

  PROCEDURE SamePrefix(d, s: ARRAY OF CHAR): BOOLEAN;
    VAR i, n, m: INTEGER;
        ret: BOOLEAN;
  BEGIN n := Strings.Length(d); m := Strings.Length(s);
    IF n < m THEN
      ret := FALSE
    ELSE
      i := 0;
      WHILE (i < m) & (d[i] = s[i]) DO INC(i) END ;
      ret := i = m
    END ;
    RETURN ret
  END SamePrefix;

  PROCEDURE SearchCmd(name: String16): INTEGER;
    VAR i: INTEGER;
  BEGIN i := 0;
    WHILE (i < NumCmds) & ~SamePrefix(cmds[i].name, name) DO
      INC(i)
    END ;
    RETURN i
  END SearchCmd;

  PROCEDURE ReadString(VAR s: ARRAY OF CHAR): BOOLEAN;
    VAR i: INTEGER;
        ch: CHAR;
  BEGIN i := 0;
    In.Char(ch);
    WHILE (i < LEN(s) - 1) & In.Done & (ch # ' ') & (ch # LF) DO
      s[i] := ch; INC(i); In.Char(ch)
    END ;
    s[i] := 0X;
    RETURN ch = LF
  END ReadString;

  PROCEDURE IsDigit(ch: CHAR): BOOLEAN;
  BEGIN RETURN ('0' <= ch) & (ch <= '9')
  END IsDigit;

  PROCEDURE StrToInt(VAR s: ARRAY OF CHAR; VAR ret: INTEGER): BOOLEAN;
    VAR i, n, base: INTEGER;
        ch: CHAR;
        digit: INTEGER;
        err: BOOLEAN;
  BEGIN Strings.Cap(s); n := Strings.Length(s); base := 10;
    IF s[n - 1] = "H" THEN base := 16; DEC(n) END ;
    i := 0; ret := 0; err := FALSE;
    WHILE (i < n) & ~err DO
      ch := s[i];
      IF IsDigit(ch) THEN
        digit := ORD(ch) - ORD("0")
      ELSIF ("A" <= ch) & (ch <= "F") THEN
        digit := ORD(ch) - ORD("A") + 10
      ELSE
        err := TRUE
      END ;
      IF digit >= base THEN
        err := TRUE
      ELSE
        ret := ret * base + digit
      END ;
      INC(i)
    END ;
    RETURN err
  END StrToInt;

  PROCEDURE CmdLoop;
    VAR s: String16;
        args: ARRAY 2 OF INTEGER;
        i, j, arg, nofWords: INTEGER;
        eol, err: BOOLEAN;
        words: ARRAY 3 OF String16;
  BEGIN args[0] := -1; args[1] := -1;
    cmdEndLoop := FALSE;
    REPEAT
      Ln(W); String(W, "> "); Flush(W);
      nofWords := 0;
      REPEAT
        eol := ReadString(s); 
        IF s[0] # 0X THEN
          (*Out.Ln; Out.String("["); Out.String(s); Out.String("]");*)
          IF nofWords < LEN(words) THEN
            words[nofWords] := s; INC(nofWords)
          END
        END
      UNTIL eol ;
      (*Ln(W); Int(W, nofWords, 0);*)
      IF nofWords = 0 THEN
        s := cmdPrev
      ELSE
        s := words[0]; DEC(nofWords);
        FOR i := nofWords TO LEN(args) - 1 DO args[i] := -1 END ;
      END ;
      IF s[0] # 0X THEN
        (*Out.Ln; Out.String("["); Out.String(s); Out.String("]");*)
        i := SearchCmd(s);
        IF i = NumCmds THEN
          err := TRUE
        ELSE
          (*read args*)
          IF nofWords <= cmds[i].nofArgs THEN
            j := 1; err := FALSE;
            WHILE (j <= nofWords) & ~err DO
              err := StrToInt(words[j], arg);
              IF ~err THEN args[j - 1] := arg; INC(j) END ;
            END ;
          ELSE
            err := TRUE
          END ;
        END ;
        IF err THEN
          String(W, " ?")
        ELSE
          cmds[i].do(nofWords, args)
        END ;
        cmdPrev := words[0]
      END
    UNTIL cmdEndLoop
  END CmdLoop;

  PROCEDURE AddCmd(name: String16; nofArgs: INTEGER; P: CmdProc);
  BEGIN
    cmds[cmdIdx].name := name;
    cmds[cmdIdx].nofArgs := nofArgs;
    cmds[cmdIdx].do := P;
    INC(cmdIdx)
  END AddCmd;

  PROCEDURE CmdRegs(nofArgs: INTEGER; VAR args: ARRAY OF INTEGER);
    VAR i: INTEGER;
  BEGIN
    Out(W, "  PC", rs.PC * 4); Out(W, "   H", rs.H); (*PC,H*)
    Texts.WriteString(W, "  CC= "); (*Flags*)
    OutFlag(W, "N", NN IN rs.flags); OutFlag(W, "Z", ZZ IN rs.flags);
    OutFlag(W, "C", CC IN rs.flags); OutFlag(W, "V", VV IN rs.flags);
    Texts.WriteString(W, "      INT= "); (*INT flags*)
    OutFlag(W, "E", INTE IN rs.intFlags);
    OutFlag(W, "P", INTP IN rs.intFlags);
    OutFlag(W, "M", INTM IN rs.intFlags);
    FOR i := 0 TO 15 DO (*regs*)
      IF i MOD 4 = 0 THEN Ln(W) END;
      OutReg(W, i, rs.R[i])
    END; Ln(W); Ln(W);
    WriteHex(W, rs.PC * 4, 5); Texts.Write(W, TAB); Texts.WriteHex(W, rs.IR); Texts.Write(W, TAB);
    Disasm.Opcode(W, rs.IR); Ln(W); Ln(W); Ln(W)
  END CmdRegs;

  PROCEDURE Status*(VAR XW: Texts.Writer; VAR s: MachineState);
    VAR dummy: ARRAY 1 OF INTEGER;
  BEGIN
    IF verbose THEN
      rs := s; W := XW;
      CmdRegs(0, dummy);
      CmdLoop; s := rs
    END
  END Status;
    
BEGIN verbose := TRUE; hexDigits := "0123456789ABCDEF";
  In.Open;
  cmdIdx := 0; cmdPrev := "";
  AddCmd("break",  1, CmdBreak);
  AddCmd("cont", 0, CmdContinue);
  AddCmd("disasm", 2, CmdDisasm);
  AddCmd("dump",   2, CmdDump);
  AddCmd("help", 0, CmdHelp);
  AddCmd("quit", 0, CmdQuit);
  AddCmd("regs", 0, CmdRegs);
  AddCmd("step", 1, CmdStep)
END RISCEmu.

(* vim:set ts=2 sw=2 et: *)
