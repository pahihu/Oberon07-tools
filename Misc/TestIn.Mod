MODULE TestIn;
  IMPORT In, Out, Strings;

  CONST
    NumCmds = 8;
    CR = 0DX; LF = 0AX;
    CmdQuit = 5;

  TYPE
    String = ARRAY 16 OF CHAR;
    CmdProc = PROCEDURE(nofArgs: INTEGER; VAR args: ARRAY OF INTEGER);

  VAR d: LONGREAL;
      n: LONGINT;
      s: ARRAY 32 OF CHAR;
      i: INTEGER;
      c: CHAR;

      cmds: ARRAY NumCmds OF RECORD
        name: String;
        nofArgs: INTEGER;
        do: CmdProc
      END;
      cmdIdx: INTEGER;

  PROCEDURE Mod(x, y: LONGINT): LONGINT;
    VAR q,r: LONGINT;
  BEGIN q := x DIV y; r := x - q*y; RETURN r
  END Mod;

  PROCEDURE Test;
  BEGIN
    WHILE In.Done DO
      Out.String ("Enter a number: "); In.Int (i);
      IF ~In.Done THEN
        Out.String (" cannot read integer ");
      ELSE
        Out.String ("i=["); Out.Int (i, 0); Out.String ("]"); Out.Ln;
        Out.String ("i MOD 10H="); Out.Int ((-i) MOD 10H, 0); Out.Ln;
        Out.String ("i Mod 10H="); Out.Int (Mod(-i, 10H), 0); Out.Ln;
      END;
      Out.String ("Enter a string: "); In.String (s);
      IF ~In.Done THEN
        Out.String (" cannot read string ");
      ELSE
        Out.String ("s=["); Out.String (s); Out.String ("]"); Out.Ln;
      END;
      Out.String ("Enter a name: "); In.Name (s);
      IF ~In.Done THEN
        Out.String (" cannot read name ");
      ELSE
        Out.String ("s=["); Out.String (s); Out.String ("]"); Out.Ln;
      END;
      In.Char (c); (*read EOL*)
      Out.String ("Enter a char: "); In.Char (c);
      IF ~In.Done THEN
        Out.String (" cannot read char ");
      ELSE
        Out.String ("c=["); Out.Int (ORD(c), 0); Out.String ("]"); Out.Ln;
      END
    END
  END Test;

  PROCEDURE Break(nofArgs: INTEGER; VAR args: ARRAY OF INTEGER);
  BEGIN Out.Ln; Out.String("Break "); Out.Int(nofArgs, 0)
  END Break;

  PROCEDURE Disasm(nofArgs: INTEGER; VAR args: ARRAY OF INTEGER);
  BEGIN Out.Ln; Out.String("Disasm "); Out.Int(nofArgs, 0)
  END Disasm;

  PROCEDURE Dump(nofArgs: INTEGER; VAR args: ARRAY OF INTEGER);
  BEGIN Out.Ln; Out.String("Dump "); Out.Int(nofArgs, 0)
  END Dump;

  PROCEDURE Go(nofArgs: INTEGER; VAR args: ARRAY OF INTEGER);
  BEGIN Out.Ln; Out.String("Go "); Out.Int(nofArgs, 0)
  END Go;

  PROCEDURE Help(nofArgs: INTEGER; VAR args: ARRAY OF INTEGER);
  BEGIN Out.Ln; Out.String("Help "); Out.Int(nofArgs, 0)
  END Help;

  PROCEDURE Quit(nofArgs: INTEGER; VAR args: ARRAY OF INTEGER);
  BEGIN Out.Ln; Out.String("Quit "); Out.Int(nofArgs, 0)
  END Quit;

  PROCEDURE Regs(nofArgs: INTEGER; VAR args: ARRAY OF INTEGER);
  BEGIN Out.Ln; Out.String("Regs "); Out.Int(nofArgs, 0)
  END Regs;

  PROCEDURE Step(nofArgs: INTEGER; VAR args: ARRAY OF INTEGER);
  BEGIN Out.Ln; Out.String("Step "); Out.Int(nofArgs, 0)
  END Step;

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

  PROCEDURE SearchCmd(name: String): INTEGER;
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
    VAR p, s: String;
        args: ARRAY 2 OF INTEGER;
        i, j, arg, nofWords: INTEGER;
        eol, err: BOOLEAN;
        words: ARRAY 3 OF String;
  BEGIN p := "";
    REPEAT
      Out.Ln; Out.String("> ");
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
      Out.Ln; Out.Int(nofWords, 0);
      IF nofWords = 0 THEN
        s := p
      ELSE
        s := words[0]; DEC(nofWords)
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
          Out.String(" ?")
        ELSE
          cmds[i].do(nofWords, args)
        END ;
        p := words[0]
      END
    UNTIL i = CmdQuit
  END CmdLoop;

  PROCEDURE AddCmd(name: String; nofArgs: INTEGER; P: CmdProc);
  BEGIN
    cmds[cmdIdx].name := name;
    cmds[cmdIdx].nofArgs := nofArgs;
    cmds[cmdIdx].do := P;
    INC(cmdIdx)
  END AddCmd;

BEGIN Out.Open; In.Open;
  cmdIdx := 0;
  AddCmd("break", 1, Break);
  AddCmd("disasm", 2, Disasm);
  AddCmd("dump", 2, Dump);
  AddCmd("go", 1, Go);
  AddCmd("help", 0, Help);
  AddCmd("quit", 0, Quit);
  AddCmd("regs", 0, Regs);
  AddCmd("step", 1, Step);
  CmdLoop
END TestIn.

(* vim:set ts=2 sw=2 et: *)
