MODULE AnonRecImport;
  IMPORT AnonRec, Storage, Out, SYSTEM;

  CONST SP = 14;

  TYPE
    R0* = RECORD i*: INTEGER END;
    R1 = RECORD (R0) j: INTEGER END;
    R2 = RECORD (R1) k: INTEGER END;
    R3 = RECORD (R1) l: INTEGER END;
    R4 = RECORD (AnonRec.R2) z: SET END;
    P0 = POINTER TO R0;
    P1 = POINTER TO R1;

  PROCEDURE Exchange(from: R0; VAR to: R0; msg: ARRAY OF CHAR);
  BEGIN
    Out.Ln; Out.String("--- "); Out.String(msg); Out.String(" ---");
    CASE to OF
      R1: Out.Ln; Out.String("Exchange R1")
    | R0: Out.Ln; Out.String("Exchange R0")
    END ;
    to := from;
    Out.Ln; Out.String("--- END ---")
  END Exchange;

  PROCEDURE Exxchange(from: R0; VAR to: R0; msg: ARRAY OF CHAR);
    VAR sp: LONGINT;
        fromTag, fromSize, toTag, toSize: LONGINT;
  BEGIN
    Out.Ln; Out.String("--- X"); Out.String(msg); Out.String("X ---");
    CASE to OF
      R1: Out.Ln; Out.String("Exxchange R1")
    | R0: Out.Ln; Out.String("Exxchange R0")
    END ;
    (*sp := SYSTEM.REG(SP);*)
    SYSTEM.GET(sp +  8, fromTag); SYSTEM.GET(fromTag, fromSize);
    SYSTEM.GET(sp + 16, toTag); SYSTEM.GET(toTag, toSize);
    DEC(fromSize, 8); DEC(toSize, 8);
    ASSERT(fromSize >= toSize);
    (*SYSTEM.COPY(SYSTEM.ADR(from), SYSTEM.ADR(to), toSize DIV 4);*)
    Out.Ln; Out.String("--- END ---")
  END Exxchange;

  PROCEDURE PrintR0(r0: R0);
  BEGIN Out.Ln; Out.String("r0.i="); Out.Int(r0.i, 0)
  END PrintR0;

  PROCEDURE PrintR1(r1: R1);
  BEGIN
    Out.Ln; Out.String("r1.i="); Out.Int(r1.i, 0);
    Out.String(" r1.j="); Out.Int(r1.j, 0)
  END PrintR1;

  PROCEDURE PrintAdrX(r: R0);
    VAR tag, size: LONGINT;
        sp: LONGINT;
        i, base, len, dcw, mno: INTEGER;
  BEGIN Out.Ln; Out.String("--- PrintAdr ---");
    Out.Ln; Out.String("ADR(r)="); Out.Hex(SYSTEM.ADR(r), 0);
    (*sp := SYSTEM.REG(SP); SYSTEM.GET(sp + 8, tag);*)
    Out.Ln; Out.String("tag="); Out.Hex(tag, 0);
    SYSTEM.GET(tag, size);
    Out.Ln; Out.String("size="); Out.Hex(size, 0);
    FOR i := 4 TO 16 BY 4 DO
      SYSTEM.GET(tag + i, base);
      IF base # -1 THEN
        (*dcw := base MOD 1000H; base := base DIV 1000H;
        len := base MOD 1000H; mno := base DIV 1000H;
        Out.Ln; Out.String("mno="); Out.Int(mno, 2);
        Out.String(" len="); Out.Int(len, 3);
        Out.String(" dcw="); Out.Hex(dcw, 0)*)
        Out.Ln; Out.String("base="); Out.Hex(base, 0)
      END
    END
  END PrintAdrX;

  PROCEDURE PrintAdrAR2X(r: AnonRec.R2);
    VAR tag, size: LONGINT;
        sp: LONGINT;
        i, base, len, dcw, mno: INTEGER;
  BEGIN Out.Ln; Out.String("--- PrintAdr ---");
    Out.Ln; Out.String("ADR(r)="); Out.Hex(SYSTEM.ADR(r), 0);
    (*sp := SYSTEM.REG(SP); SYSTEM.GET(sp + 8, tag);*)
    Out.Ln; Out.String("tag="); Out.Hex(tag, 0);
    SYSTEM.GET(tag, size);
    Out.Ln; Out.String("size="); Out.Hex(size, 0);
    FOR i := 4 TO 16 BY 4 DO
      SYSTEM.GET(tag + i, base);
      IF base # -1 THEN
        dcw := base MOD 1000H; base := base DIV 1000H;
        len := base MOD 1000H; mno := base DIV 1000H;
        Out.Ln; Out.String("mno="); Out.Int(mno, 2);
        Out.String(" len="); Out.Int(len, 3);
        Out.String(" dcw="); Out.Hex(dcw, 0)
      END
    END
  END PrintAdrAR2X;

  PROCEDURE PrintVarAdrX(VAR ref: R0);
    VAR tag, size: LONGINT;
        sp: LONGINT;
  BEGIN Out.Ln; Out.String("--- PrintVarAdr ---");
    Out.Ln; Out.String("ADR(ref)="); Out.Hex(SYSTEM.ADR(ref), 0);
    (*sp := SYSTEM.REG(SP); SYSTEM.GET(sp + 8, tag);*)
    Out.Ln; Out.String("tag="); Out.Hex(tag, 0);
    SYSTEM.GET(tag, size);
    Out.Ln; Out.String("size="); Out.Hex(size, 0)
  END PrintVarAdrX;

  PROCEDURE PrintAdrPtrX(r: P0);
    VAR tag, size: LONGINT;
  BEGIN Out.Ln; Out.String("--- PrintAdrPtr ---");
    (*Out.Ln; Out.String("ADR(r)="); Out.Hex(SYSTEM.VAL(LONGINT,r), 0);
    SYSTEM.GET(SYSTEM.VAL(LONGINT,r) - 8, tag);*)
    Out.Ln; Out.String("tag="); Out.Hex(tag, 0);
    SYSTEM.GET(tag, size);
    Out.Ln; Out.String("size="); Out.Hex(size, 0)
  END PrintAdrPtrX;

  PROCEDURE PrintVarAdrPtrX(VAR ref: P0);
    VAR tag, size: LONGINT;
  BEGIN Out.Ln; Out.String("--- PrintVarAdrPtr ---");
    (*Out.Ln; Out.String("ADR(ref)="); Out.Hex(SYSTEM.VAL(LONGINT,ref), 0);
    SYSTEM.GET(SYSTEM.VAL(LONGINT,ref) - 8, tag);*)
    Out.Ln; Out.String("tag="); Out.Hex(tag, 0);
    SYSTEM.GET(tag, size);
    Out.Ln; Out.String("size="); Out.Hex(size, 0)
  END PrintVarAdrPtrX;

  PROCEDURE CheckType(VAR r: R0; msg: ARRAY OF CHAR);
    VAR typ: ARRAY 3 OF CHAR;
  BEGIN Out.Ln; Out.String("--- CheckType ---");
    Out.Ln; Out.String("type=");
    CASE r OF
      R1: typ := "R1"
    | R0: typ := "R0"
    END ;
    Out.String(typ);
    IF msg # typ THEN Out.String(" FAILED") ELSE Out.String(" PASSED") END
  END CheckType;

  PROCEDURE LocalVar;
    VAR s0, r0: R0;
        s1, r1: R1;
        r2: R2;
        r3: R3;
        r4: R4;
        ptr, tag, size: LONGINT;
        p0: P0;
        p1: P1;
  BEGIN Out.Ln; Out.String("--- LocalVar ---");
    (*Out.Ln; Out.String("ADR(r0) ="); Out.Hex(SYSTEM.ADR(r0), 0);*)
    Out.Ln; Out.String("SIZE(r0)="); Out.Hex(SYSTEM.SIZE(R0), 0);
    Out.Ln; Out.String("ADR(r1) ="); Out.Hex(SYSTEM.ADR(r1), 0);
    (*Out.Ln; Out.String("SIZE(r1)="); Out.Hex(SYSTEM.SIZE(R1), 0);*)

    (*PrintVarAdr(r0);
    PrintAdr(r0);

    PrintVarAdr(r1);
    PrintAdr(r1);*)

    CheckType(r0, "R0");
    CheckType(r1, "R1");

    Out.Ln; Out.String("--- using POINTERs ---");
    NEW(p0); NEW(p1);
    (*Out.Ln; Out.String("p0="); Out.Hex(SYSTEM.VAL(LONGINT, p0), 0);
    Out.Ln; Out.String("p1="); Out.Hex(SYSTEM.VAL(LONGINT, p1), 0);
    PrintVarAdrPtr(p0);
    PrintAdrPtr(p0);
    (*PrintVarAdrPtr(p1); (*ERROR: incompatible parameters*)*)
    PrintAdrPtr(p1);*)

    (*PrintAdr(p0^);
    PrintAdr(p1^);
    PrintVarAdr(p0^);
    PrintVarAdr(p1^);*)

    CheckType(p0^, "R0");
    CheckType(p1^, "R1");
    p0 := p1;
    CheckType(p0^, "R1");

    (*PrintAdr(p0^);
    PrintVarAdr(p0^);

    PrintAdr(r2);
    PrintAdr(r3);
    PrintAdrAR2(r4);*)

    s0 := r1;
    s0.i := 1;
    s1.i := 11; s1.j := 12;

    Exxchange(s0, r0, "0>0"); PrintR0(r0);
    ASSERT(r0.i = s0.i);
    Exxchange(s1, r0, "1>0"); PrintR0(r0);
    ASSERT(r0.i = s1.i);
    (*Exxchange(s0, r1, "0>1"); PrintR1(r1);*)
    Exxchange(s1, r1, "1>1"); PrintR1(r1);
    ASSERT(r1.i = s1.i);
    ASSERT(r1.j = s1.j);

    Exchange(s0, r0, "0>0"); PrintR0(r0);
    ASSERT(r0.i = s0.i);
    Exchange(s1, r0, "1>0"); PrintR0(r0);
    ASSERT(r0.i = s1.i);
    Exchange(s0, r1, "0>1"); PrintR1(r1);
    Exchange(s1, r1, "1>1"); PrintR1(r1);
  END LocalVar;

  PROCEDURE Dispose(VAR ptr: LONGINT);
    VAR tag, size: LONGINT;
  BEGIN ASSERT(ptr # 0);
    Out.Ln; Out.String("--- Dispose ---");
    Out.Ln; Out.String("ptr="); Out.Hex(ptr, 8);
    SYSTEM.GET(ptr - 8, tag);
    Out.Ln; Out.String("tag="); Out.Hex(tag, 8);
    SYSTEM.GET(tag, size);
    Out.Ln; Out.String("size="); Out.Hex(size, 8);
    (*Out.Ln; Out.String("heapOrg="); Out.Hex(Storage.heapOrg, 8);
    (*Storage.Free(ptr, tag);*)
    Out.Ln; Out.String("heapOrg="); Out.Hex(Storage.heapOrg, 8);*)
  END Dispose;

  PROCEDURE TestAnonRec;
    VAR p0: AnonRec.P0;
        p1: AnonRec.P1;
        p2: AnonRec.P2;
        a0, a1, tag, size: LONGINT;
  BEGIN Out.Ln; Out.String("--- TestAnonRec ---");
    Out.Ln; Out.String("--- P0 ---");
    NEW(p0);
    ASSERT(p0 IS AnonRec.P0);
    p0.a := 1;
    p0.b := 2;
    (*a0 := SYSTEM.ADR(p0); (*adr. of local*)
    Out.Ln; Out.String("ADR(p0)="); Out.Hex(a0, 8);
    SYSTEM.GET(a0, a1); (*the ptr*)
    Out.Ln; Out.String("p0="); Out.Hex(a1, 8);
    SYSTEM.GET(a1 - 8, tag);
    Out.Ln; Out.String("tag="); Out.Hex(tag, 8);
    SYSTEM.GET(tag, size);
    Out.Ln; Out.String("size="); Out.Hex(size, 8);
    (*Dispose(SYSTEM.VAL(LONGINT, p0));*)

    Out.Ln; Out.String("heapOrg="); Out.Hex(Storage.heapOrg, 8);
    (*Storage.Dispose(SYSTEM.VAL(LONGINT, p0));*)*)
    DISPOSE(p0);
    (*Out.Ln; Out.String("heapOrg="); Out.Hex(Storage.heapOrg, 8);
    Out.Ln; Out.String("p0="); Out.Hex(SYSTEM.VAL(LONGINT,p0), 8);*)

    Out.Ln; Out.String("--- P1 ---");
    NEW(p1); p0 := p1;
    ASSERT(p0 IS AnonRec.P1);
    ASSERT(p0 IS AnonRec.P0);
    p1.a := 11;
    p1.b := 12;
    p1.c := 13;
    p1.d := 14;

    Out.Ln; Out.String("--- P2 ---");
    NEW(p2);
    ASSERT(p2 IS AnonRec.P2);
    p2.a := {21};
    p2.b := {22};

    Out.Ln; Out.String("---  ---")
  END TestAnonRec;

BEGIN TestAnonRec; LocalVar
END AnonRecImport.
(* vim:set ts=2 sw=2 et syn=off:*)

