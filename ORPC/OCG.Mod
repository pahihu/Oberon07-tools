MODULE OCG;
(* C11 backend for the supplied ORP; OCB is the C symbol-table variant. See README.md for the parser hooks.
   Items contain immutable C expression trees. Statements and branch fixups
   are retained until Close; procedure scopes survive ORB.CloseScope. *)
IMPORT SYSTEM, Files := Files07, ORS, ORB := OCB, Sys := System, OCGFiles, Target := OCGTarget;
CONST RegI* = 11; Reg = 10; maxCode = 65536;
TYPE
  LONGINT = Sys.INT32; INTEGER = Sys.INT32; Native = Target.Int; REAL = Target.Real;
  Text = POINTER TO TextDesc;
  TextDesc = RECORD a, b: Text; s: ARRAY 256 OF CHAR END;
  Item* = RECORD
    mode*: INTEGER; type*: ORB.Type; obj*: ORB.Object;
    a*: Native; b*: LONGINT; rdo*: BOOLEAN; varRecord: BOOLEAN;
    e, length: Text; link: LONGINT
  END;
  LabelRange* = RECORD low*, high*: Native; label*: INTEGER END;
  Symbol = POINTER TO SymbolDesc;
  SymbolDesc = RECORD obj: ORB.Object; typ: ORB.Type; name: Text;
    owner: ORB.Object; value: Text; length: LONGINT; param: BOOLEAN; next: Symbol END;
  CType = POINTER TO CTypeDesc;
  CTypeDesc = RECORD typ: ORB.Type; name: Text; state: INTEGER; layout: BOOLEAN;
    next: CType END;
  Proc = POINTER TO ProcDesc;
  ProcDesc = RECORD obj, scope: ORB.Object; first, limit: LONGINT; external: BOOLEAN;
    next: Proc END;
  Instruction = RECORD text: Text; target, chain: LONGINT;
    branch, used: BOOLEAN END;
  CallFrame = POINTER TO CallDesc;
  CallDesc = RECORD prev: CallFrame; args, callee: Text;
    formal: ORB.Object; remaining: INTEGER END;
VAR
  WordSize*: INTEGER; pc*: LONGINT; astrobe*, mainProgram*: BOOLEAN;
  code: ARRAY maxCode OF Instruction;
  symbols: Symbol; types, lastType: CType; procs, lastProc, active: Proc;
  calls: CallFrame; moduleScope: ORB.Object; moduleName: ORS.Ident;
  typeSerial, procSerial, tempSerial, sectionStart: LONGINT;
  declarationOwner: ORB.Object;
  R: Files.Rider;

PROCEDURE S(s: ARRAY OF CHAR): Text;
  VAR t: Text;
BEGIN NEW(t); COPY(s, t.s); RETURN t END S;
PROCEDURE Cat(a, b: Text): Text;
  VAR t: Text;
BEGIN NEW(t); t.a := a; t.b := b; RETURN t END Cat;
PROCEDURE C(a: Text; b: ARRAY OF CHAR): Text;
BEGIN RETURN Cat(a, S(b)) END C;
PROCEDURE N(n: Native): Text;
  VAR t: Text; i, j: INTEGER; d: Native; a: ARRAY 32 OF CHAR;
BEGIN
  IF n = Target.Min() THEN
    IF WordSize = 8 THEN RETURN S("(-9223372036854775807LL-1)")
    ELSE RETURN S("(-2147483647-1)") END
  END;
  NEW(t); i := 0;
  (* Work in the negative half of the range, including MIN(INTEGER). *)
  IF n > 0 THEN n := -n ELSE IF n < 0 THEN t.s[0] := "-" END END;
  REPEAT d := n MOD 10;
    IF d # 0 THEN d := 10-d END;
    (* Truncate toward zero without overflowing the minimum integer. *)
    a[i] := CHR(ORD("0") + d); INC(i);
    n := (n + d) DIV 10
  UNTIL n = 0;
  IF t.s[0] = "-" THEN j := 1 ELSE j := 0 END;
  WHILE i > 0 DO DEC(i); t.s[j] := a[i]; INC(j) END;
  t.s[j] := 0X; RETURN t
END N;
PROCEDURE Out(t: Text);
  VAR i: INTEGER;
BEGIN IF t # NIL THEN
  IF t.a # NIL THEN Out(t.a); Out(t.b)
  ELSE i := 0; WHILE t.s[i] # 0X DO Files.Write(R, t.s[i]); INC(i) END END
END END Out;
PROCEDURE Line(t: Text);
BEGIN Out(t); Files.Write(R, 0AX) END Line;
PROCEDURE Wrap(a: ARRAY OF CHAR; t: Text; b: ARRAY OF CHAR): Text;
BEGIN RETURN C(Cat(S(a), t), b) END Wrap;
PROCEDURE Binary(a: Text; op: ARRAY OF CHAR; b: Text): Text;
BEGIN RETURN C(Cat(C(Wrap("(", a, ")"), op), Wrap("(", b, ")")), "") END Binary;
PROCEDURE Invoke(name: ARRAY OF CHAR; a, b: Text): Text;
  VAR t: Text;
BEGIN t := Cat(S(name), Wrap("(", a, ""));
  IF b # NIL THEN t := Cat(C(t, ", "), b) END;
  RETURN C(t, ")")
END Invoke;
PROCEDURE Emit(t: Text);
BEGIN IF pc < maxCode THEN code[pc].text := t; code[pc].branch := FALSE;
  code[pc].target := 0; code[pc].chain := 0; INC(pc)
ELSE ORS.Mark("OCG: too many statements") END END Emit;
PROCEDURE Jump(t: Text; target, chain: LONGINT): LONGINT;
  VAR at: LONGINT;
BEGIN at := pc; Emit(t); code[at].branch := TRUE; code[at].target := target;
  code[at].chain := chain; RETURN at
END Jump;
PROCEDURE FixAt(L, destination: LONGINT);
  VAR next: LONGINT;
BEGIN WHILE L # 0 DO next := code[L].chain; code[L].target := destination;
  code[destination].used := TRUE; L := next END
END FixAt;
PROCEDURE FixLink*(L: LONGINT);
BEGIN FixAt(L, pc) END FixLink;
PROCEDURE FixOne*(L: LONGINT);
BEGIN FixAt(L, pc) END FixOne;
PROCEDURE Here*(): LONGINT;
BEGIN RETURN pc END Here;
PROCEDURE FJump*(VAR L: LONGINT);
BEGIN L := Jump(S("goto "), 0, L) END FJump;
PROCEDURE BJump*(L: LONGINT);
  VAR at: LONGINT;
BEGIN at := Jump(S("goto "), L, 0); code[L].used := TRUE END BJump;
PROCEDURE ModulePrefix(mno: INTEGER): Text;
  VAR obj: ORB.Object; t: Text;
BEGIN t := S(moduleName);
  IF mno > 0 THEN obj := moduleScope.next;
    WHILE (obj # NIL) & ~((obj.class = ORB.Mod) & (obj.lev = mno)) DO obj := obj.next END;
    IF obj # NIL THEN t := S(obj(ORB.Module).orgname)
    ELSE ORS.Mark("OCG: unknown import") END
  END;
  RETURN C(Cat(S("O_"), t), "_")
END ModulePrefix;
PROCEDURE FindSymbol(obj: ORB.Object): Symbol;
  VAR p: Symbol;
BEGIN p := symbols; WHILE (p # NIL) & (p.obj # obj) DO p := p.next END;
  RETURN p
END FindSymbol;
PROCEDURE Bind(obj, owner: ORB.Object; param: BOOLEAN): Symbol;
  VAR p: Symbol;
BEGIN p := FindSymbol(obj);
  IF p = NIL THEN NEW(p); p.obj := obj; p.typ := obj.type;
    p.owner := owner; p.param := param;
    IF obj.externalName[0] # 0X THEN p.name := S(obj.externalName)
    ELSIF obj.lev < 0 THEN p.name := Cat(ModulePrefix(-obj.lev), S(obj.name))
    ELSIF owner = NIL THEN p.name := Cat(ModulePrefix(0), S(obj.name))
    ELSE p.name := Cat(C(Cat(ModulePrefix(0), N(procSerial)), "_"), S(obj.name)) END;
    p.next := symbols; symbols := p
  END;
  RETURN p
END Bind;
PROCEDURE TypeName(t: ORB.Type): Text;
  VAR p: CType; name: Text; sym: Symbol;
BEGIN
  CASE t.form OF
    ORB.Byte, ORB.Char: name := S("uint8_t") |
    ORB.Bool: name := S("bool") |
    ORB.Int: IF t.size = 1 THEN name := S("uint8_t") ELSE IF WordSize = 8 THEN name := S("int64_t") ELSE name := S("int32_t") END END |
    ORB.Real: IF WordSize = 8 THEN name := S("double") ELSE name := S("float") END |
    ORB.Set: name := S("uint32_t") |
    ORB.NilTyp: name := S("void *") |
    ORB.NoTyp: name := S("void") |
    ORB.String: name := S("uint8_t *")
  ELSE
    p := types; WHILE (p # NIL) & (p.typ # t) DO p := p.next END;
    IF p = NIL THEN NEW(p); p.typ := t; p.state := 0;
      IF t.typobj # NIL THEN
        IF t.mno > 0 THEN p.name := Cat(ModulePrefix(t.mno), S(t.typobj.name))
        ELSE sym := FindSymbol(t.typobj);
          IF sym = NIL THEN sym := Bind(t.typobj, declarationOwner, FALSE) END;
          p.name := sym.name
        END
      ELSE INC(typeSerial); p.name := Cat(C(ModulePrefix(0), "t_"), N(typeSerial)) END;
      IF types = NIL THEN types := p ELSE lastType.next := p END; lastType := p
    END;
    name := p.name
  END;
  RETURN name
END TypeName;
PROCEDURE QualifiedType(t: ORB.Type; readonly: BOOLEAN): Text;
  VAR name: Text;
BEGIN name := TypeName(t);
  IF readonly THEN name := Cat(S("const "), name) END;
  RETURN name
END QualifiedType;
PROCEDURE RegisterType(t: ORB.Type);
  VAR p: CType; o: ORB.Object; i: INTEGER; dummy: Text;
BEGIN IF t # NIL THEN
  dummy := TypeName(t);
  IF t.form >= ORB.Proc THEN
    p := types; WHILE (p # NIL) & (p.typ # t) DO p := p.next END;
    IF (p # NIL) & (p.state = 0) THEN p.state := 1;
      IF (t.mno <= 0) OR (t.typobj = NIL) THEN
        RegisterType(t.base);
        IF t.form = ORB.Record THEN o := t.dsc;
          WHILE o # NIL DO RegisterType(o.type); o := o.next END
        ELSIF t.form = ORB.Proc THEN o := t.dsc; i := 0;
          WHILE (o # NIL) & (i < t.nofpar) DO RegisterType(o.type); o := o.next; INC(i) END
        END
      END
    END
  ELSIF t.form = ORB.Pointer THEN
    p := types; WHILE (p # NIL) & (p.typ # t) DO p := p.next END;
    IF p.state = 0 THEN p.state := 1; IF (t.mno <= 0) OR (t.typobj = NIL) THEN RegisterType(t.base) END END
  END
END END RegisterType;
PROCEDURE Capture(scope, owner: ORB.Object; npar: INTEGER);
  VAR o: ORB.Object; p: Symbol; i: INTEGER;
BEGIN declarationOwner := owner; o := scope.next; i := 0;
  WHILE o # NIL DO
    IF o.class # ORB.Mod THEN p := Bind(o, owner, i < npar); RegisterType(o.type) END;
    o := o.next; INC(i)
  END
END Capture;
PROCEDURE SetTarget*(core: INTEGER);
BEGIN Target.Configure(core); WordSize := Target.WordSize END SetTarget;
PROCEDURE SetModule*(name: ORS.Ident);
BEGIN moduleName := name; moduleScope := ORB.topScope END SetModule;
PROCEDURE BeginProc*(obj: ORB.Object);
  VAR p, parent: Proc; s: Symbol; owner: ORB.Object;
BEGIN owner := NIL; parent := procs;
  WHILE parent # NIL DO IF parent.scope = ORB.topScope.dsc THEN owner := parent.obj END; parent := parent.next END;
  s := Bind(obj, owner, FALSE); INC(procSerial);
  NEW(p); p.obj := obj; p.scope := ORB.topScope;
  IF procs = NIL THEN procs := p ELSE lastProc.next := p END; lastProc := p;
  Capture(p.scope, obj, obj.type.nofpar)
END BeginProc;
PROCEDURE BeginExternal*(obj: ORB.Object);
BEGIN BeginProc(obj); lastProc.external := TRUE END BeginExternal;
PROCEDURE SelectProc*(obj: ORB.Object);
  VAR p: Proc;
BEGIN p := procs; WHILE (p # NIL) & (p.obj # obj) DO p := p.next END;
  active := p; active.first := pc
END SelectProc;
PROCEDURE Temp(t: ORB.Type): Text;
  VAR name: Text;
BEGIN INC(tempSerial); name := Cat(S("ocg_v"), N(tempSerial));
  Emit(C(C(Cat(C(TypeName(t), " "), name), " = {0}"), ";"));
  RETURN name
END Temp;
PROCEDURE Freeze*(VAR x: Item);
  VAR name: Text;
BEGIN IF (x.mode IN {ORB.Var, ORB.Par, Reg, RegI}) & (x.type.form < ORB.Array) THEN
  IF x.type.form = ORB.Int THEN name := Temp(ORB.intType) ELSE name := Temp(x.type) END; Emit(C(Binary(name, " = ", x.e), ";")); x.e := name; x.mode := Reg
END END Freeze;
PROCEDURE SetValue(value: SET): Native;
  VAR n: Native;
BEGIN n := SYSTEM.VAL(Sys.INT32, value);
  IF (WordSize = 8) & (n < 0) THEN n := n+MAX(Sys.INT32); n := n+MAX(Sys.INT32)+2 END;
  RETURN n
END SetValue;
PROCEDURE MakeConstItem*(VAR x: Item; typ: ORB.Type; val: Native);
BEGIN x.mode := ORB.Const; x.type := typ;
  IF (typ.form = ORB.Int) & (typ.size > 1) THEN val := Target.Normalize(val) END; x.a := val; x.b := 0; x.obj := NIL;
  x.rdo := FALSE; x.varRecord := FALSE; x.link := 0; x.length := NIL;
  IF typ.form = ORB.NilTyp THEN x.e := S("NULL") ELSE x.e := N(val) END
END MakeConstItem;
PROCEDURE MakeRealItem*(VAR x: Item; val: REAL);
BEGIN MakeConstItem(x, ORB.realType, Target.RealBits(val));
  x.e := Invoke("ocg_real", N(x.a), NIL)
END MakeRealItem;
PROCEDURE MakeStringItem*(VAR x: Item; len: LONGINT);
  VAR i: INTEGER; t: Text;
BEGIN MakeConstItem(x, ORB.strType, 0); x.b := len; x.a := ORD(ORS.str[0]);
  t := S("((uint8_t[]){"); i := 0;
  WHILE i < len DO IF i > 0 THEN t := C(t, ",") END;
    t := Cat(t, N(ORD(ORS.str[i]))); INC(i) END;
  x.e := C(t, "})"); x.length := N(len)
END MakeStringItem;
PROCEDURE MakeItem*(VAR x: Item; obj: ORB.Object; curlev: LONGINT);
  VAR p: Symbol;
BEGIN MakeConstItem(x, obj.type, obj.val); x.obj := obj; x.rdo := obj.rdo;
  x.varRecord := (obj.class = ORB.Par) & (obj.type.form = ORB.Record) & ~obj.rdo;
  IF (obj.class = ORB.Const) & (obj.type.form # ORB.Proc) THEN
    IF obj.type.form = ORB.Real THEN x.e := Invoke("ocg_real", N(obj.val), NIL) END;
    IF obj.type.form = ORB.String THEN
      p := FindSymbol(obj);
      IF p # NIL THEN x.e := p.value; x.b := p.length; x.length := N(p.length)
      ELSE ORS.Mark("OCG: imported string constant is not in the symbol ABI") END
    END
  ELSE
    p := FindSymbol(obj); IF p = NIL THEN p := Bind(obj, NIL, FALSE) END;
    x.mode := obj.class; x.e := p.name;
    IF p.param & (obj.class = ORB.Par) THEN
      IF (obj.type.form = ORB.Array) & (obj.type.len < 0) THEN
        x.length := C(p.name, "_len")
      ELSE x.e := Wrap("(*", x.e, ")") END
    END;
    IF (obj.type.form = ORB.Array) & (obj.type.len < 0) THEN x.length := C(p.name, "_len") END;
    IF (obj.lev > 0) & (obj.lev # curlev) & (obj.class # ORB.Const) THEN ORS.Mark("OCG: nonlocal variable") END;
    IF p.typ # obj.type THEN
      IF obj.type.form = ORB.Pointer THEN x.e := C(Cat(Wrap("((", TypeName(obj.type), ")"), x.e), ")")
      ELSIF obj.type.form = ORB.Record THEN
        x.e := C(Cat(Wrap("(*( ", QualifiedType(obj.type, x.rdo), " *)&"), Wrap("(", x.e, ")")), ")")
      END
    END
  END
END MakeItem;
PROCEDURE SaveConst*(obj: ORB.Object; x: Item);
  VAR p: Symbol;
BEGIN IF obj.expo & (obj.type.form = ORB.String) THEN ORS.Mark("OCG: exported string constants are not supported by the symbol format") END;
  IF (obj.type.form = ORB.Proc) & (x.obj # NIL) THEN COPY(x.obj.externalName, obj.externalName) END;
  p := Bind(obj, NIL, FALSE); p.value := x.e; p.length := x.b END SaveConst;
PROCEDURE ArrayLen(x: Item): Text;
BEGIN IF x.type.form = ORB.String THEN RETURN N(x.b)
  ELSIF x.type.len >= 0 THEN RETURN N(x.type.len)
  ELSE RETURN x.length END
END ArrayLen;
PROCEDURE Field*(VAR x: Item; obj: ORB.Object);
  VAR t: ORB.Type;
BEGIN t := x.type; x.varRecord := FALSE;
  WHILE (t.base # NIL) & (obj.val < t.base.size) DO x.e := Wrap("(", x.e, ").ocg_base"); t := t.base END;
  x.e := Cat(Wrap("(", x.e, ").f_"), S(obj.name)); x.mode := RegI
END Field;
PROCEDURE Index*(VAR x, y: Item);
  VAR index: Text;
BEGIN Freeze(y); index := y.e; x.varRecord := FALSE;
  IF ORS.GetOption("X") THEN index := Invoke("ocg_index", index, ArrayLen(x)) END;
  x.e := C(Cat(Wrap("(", x.e, ")["), index), "]"); x.mode := RegI
END Index;
PROCEDURE DeRef*(VAR x: Item);
BEGIN Freeze(x); x.varRecord := FALSE; IF ORS.GetOption("P") THEN x.e := C(Cat(Wrap("((", TypeName(x.type), ")"), Invoke("ocg_nonnull", x.e, NIL)), ")") END;
  x.e := Wrap("(*(", x.e, "))"); x.mode := RegI
END DeRef;
PROCEDURE BuildTD*(t: ORB.Type; VAR dc: LONGINT);
BEGIN RegisterType(t) END BuildTD;
PROCEDURE TypeTest*(VAR x: Item; t: ORB.Type; varpar, guard: BOOLEAN);
  VAR test: Text;
BEGIN
  IF t = NIL THEN test := S("true")
  ELSE
    IF varpar OR (x.type.form = ORB.Record) THEN test := Wrap("&(", x.e, ")") ELSE test := x.e END;
    test := Invoke("ocg_is", test, Wrap("&", C(TypeName(t), "_tag"), ""))
  END;
  IF guard THEN
    IF ORS.GetOption("T") THEN Emit(C(Invoke("ocg_assert", test, NIL), ";")) END;
    IF t # NIL THEN
      IF x.type.form = ORB.Record THEN x.e := C(Cat(Wrap("(*(", QualifiedType(t, x.rdo), " *)&"), Wrap("(", x.e, ")")), ")")
      ELSE x.e := C(Cat(Wrap("((", TypeName(t), " *)"), x.e), ")") END
    END
  ELSE x.e := test; x.mode := Reg; x.type := ORB.boolType END
END TypeTest;
PROCEDURE Unary(VAR x: Item; prefix, suffix: ARRAY OF CHAR);
BEGIN x.e := Wrap(prefix, x.e, suffix); x.mode := Reg END Unary;
PROCEDURE Not*(VAR x: Item);
BEGIN IF x.mode = ORB.Const THEN x.a := 1-x.a; x.e := N(x.a)
  ELSE Unary(x, "!(", ")") END END Not;
PROCEDURE CFJump*(VAR x: Item);
BEGIN x.link := Jump(Wrap("if (!(", x.e, ")) goto "), 0, 0) END CFJump;
PROCEDURE Fixup*(VAR x: Item);
BEGIN FixAt(x.link, pc) END Fixup;
PROCEDURE CBJump*(VAR x: Item; L: LONGINT);
  VAR at: LONGINT;
BEGIN at := Jump(Wrap("if (!(", x.e, ")) goto "), L, 0); code[L].used := TRUE END CBJump;
PROCEDURE And1*(VAR x: Item);
  VAR name: Text;
BEGIN name := Temp(ORB.boolType); Emit(C(Binary(name, " = ", x.e), ";")); x.e := name;
  x.link := Jump(Wrap("if (!(", name, ")) goto "), 0, 0)
END And1;
PROCEDURE And2*(VAR x, y: Item);
BEGIN Emit(C(Binary(x.e, " = ", y.e), ";")); FixAt(x.link, pc); x.mode := Reg END And2;
PROCEDURE Or1*(VAR x: Item);
  VAR name: Text;
BEGIN name := Temp(ORB.boolType); Emit(C(Binary(name, " = ", x.e), ";")); x.e := name;
  x.link := Jump(Wrap("if (", name, ") goto "), 0, 0)
END Or1;
PROCEDURE Or2*(VAR x, y: Item);
BEGIN And2(x, y) END Or2;
PROCEDURE Neg*(VAR x: Item);
BEGIN IF x.mode = ORB.Const THEN
    IF x.type.form = ORB.Set THEN x.a := SetValue(-SYSTEM.VAL(SET, Sys.Short(x.a)))
    ELSIF x.type.form = ORB.Real THEN x.a := Target.RealBits(-Target.BitsReal(x.a))
    ELSE
      IF ORS.GetOption("V") & (x.a = Target.Min()) THEN ORS.Mark("INTEGER overflow") END;
      x.a := Target.Neg(x.a) END;
    IF x.type.form = ORB.Real THEN x.e := Invoke("ocg_real", N(x.a), NIL) ELSE x.e := N(x.a) END
  ELSIF x.type.form = ORB.Set THEN Unary(x, "~(uint32_t)(", ")")
  ELSIF x.type.form = ORB.Real THEN Unary(x, "-(", ")")
  ELSIF ORS.GetOption("V") THEN x.e := Invoke("ocg_subv", S("0"), x.e); x.mode := Reg
  ELSIF Target.Cortex # 0 THEN x.e := Invoke("ocg_sub", S("0"), x.e); x.mode := Reg
  ELSE Unary(x, "(ocg_int)(0-(ocg_uint)(", "))") END
END Neg;
PROCEDURE IntOp(op: LONGINT; VAR x, y: Item);
  VAR f: ARRAY 16 OF CHAR;
BEGIN
  IF (x.mode = ORB.Const) & (y.mode = ORB.Const) THEN
    IF ORS.GetOption("V") THEN
      IF (op = ORS.plus) & Target.AddOverflow(x.a, y.a) OR
        (op = ORS.minus) & Target.SubOverflow(x.a, y.a) OR
        (op = ORS.times) & Target.MulOverflow(x.a, y.a) THEN ORS.Mark("INTEGER overflow") END
    END;
    CASE op OF ORS.plus: x.a := Target.Add(x.a, y.a) | ORS.minus: x.a := Target.Sub(x.a, y.a) |
      ORS.times: x.a := Target.Mul(x.a, y.a) |
      ORS.div: IF y.a > 0 THEN x.a := x.a DIV y.a ELSE ORS.Mark("bad divisor") END |
      ORS.mod: IF y.a > 0 THEN x.a := x.a MOD y.a ELSE ORS.Mark("bad divisor") END
    END; x.e := N(x.a)
  ELSE
    CASE op OF ORS.plus: f := "ocg_add" | ORS.minus: f := "ocg_sub" |
      ORS.times: f := "ocg_mul" | ORS.div: f := "ocg_div" | ORS.mod: f := "ocg_mod" END;
    IF ORS.GetOption("V") & (op IN {ORS.plus, ORS.minus, ORS.times}) THEN
      CASE op OF ORS.plus: f := "ocg_addv" | ORS.minus: f := "ocg_subv" | ORS.times: f := "ocg_mulv" END
    END;
    x.e := Invoke(f, x.e, y.e); x.mode := Reg
  END
END IntOp;
PROCEDURE AddOp*(op: LONGINT; VAR x, y: Item);
BEGIN IntOp(op, x, y) END AddOp;
PROCEDURE MulOp*(VAR x, y: Item);
BEGIN IntOp(ORS.times, x, y) END MulOp;
PROCEDURE DivOp*(op: LONGINT; VAR x, y: Item);
BEGIN IntOp(op, x, y) END DivOp;
PROCEDURE RealOp*(op: INTEGER; VAR x, y: Item);
  VAR a, b: REAL; oper: ARRAY 4 OF CHAR;
BEGIN IF (x.mode = ORB.Const) & (y.mode = ORB.Const) THEN
    a := Target.BitsReal(x.a); b := Target.BitsReal(y.a);
    CASE op OF ORS.plus: a := a+b | ORS.minus: a := a-b | ORS.times: a := a*b | ORS.rdiv: a := a/b END;
    MakeRealItem(x, a)
  ELSE CASE op OF ORS.plus: oper := "+" | ORS.minus: oper := "-" | ORS.times: oper := "*" | ORS.rdiv: oper := "/" END;
    x.e := Binary(x.e, oper, y.e); x.mode := Reg
  END
END RealOp;
PROCEDURE Singleton*(VAR x: Item);
BEGIN IF x.mode = ORB.Const THEN x.a := SetValue({Sys.Short(x.a)}); x.e := N(x.a)
  ELSE x.e := Invoke("ocg_single", x.e, NIL); x.mode := Reg END
END Singleton;
PROCEDURE Set*(VAR x, y: Item);
  VAR i: Native; s: SET;
BEGIN IF (x.mode = ORB.Const) & (y.mode = ORB.Const) THEN
    s := {}; FOR i := x.a TO y.a DO INCL(s, Sys.Short(i)) END; x.a := SetValue(s); x.e := N(x.a)
  ELSE x.e := Invoke("ocg_range", x.e, y.e); x.mode := Reg END
END Set;
PROCEDURE SetOp*(op: LONGINT; VAR x, y: Item);
  VAR a, b: SET; oper: ARRAY 4 OF CHAR;
BEGIN IF (x.mode = ORB.Const) & (y.mode = ORB.Const) THEN
    a := SYSTEM.VAL(SET, Sys.Short(x.a)); b := SYSTEM.VAL(SET, Sys.Short(y.a));
    CASE op OF ORS.plus: a := a+b | ORS.minus: a := a-b | ORS.times: a := a*b | ORS.rdiv: a := a/b END;
    x.a := SYSTEM.VAL(LONGINT, a); x.e := N(x.a)
  ELSE CASE op OF ORS.plus: oper := "|" | ORS.minus: oper := "&~" | ORS.times: oper := "&" | ORS.rdiv: oper := "^" END;
    x.e := Binary(x.e, oper, y.e); x.mode := Reg
  END
END SetOp;
PROCEDURE In*(VAR x, y: Item);
BEGIN x.e := Invoke("ocg_in", x.e, y.e); x.mode := Reg END In;
PROCEDURE Relation(op: INTEGER; VAR x, y: Item);
  VAR oper: ARRAY 4 OF CHAR;
BEGIN CASE op OF ORS.eql: oper := "==" | ORS.neq: oper := "!=" |
  ORS.lss: oper := "<" | ORS.leq: oper := "<=" | ORS.gtr: oper := ">" | ORS.geq: oper := ">=" END;
  x.e := Binary(x.e, oper, y.e); x.mode := Reg
END Relation;
PROCEDURE IntRelation*(op: INTEGER; VAR x, y: Item);
BEGIN IF (x.type.form = ORB.Pointer) & (y.type.form = ORB.Pointer) THEN
    x.e := Wrap("((void *)(", x.e, "))"); y.e := Wrap("((void *)(", y.e, "))")
  END;
  Relation(op, x, y) END IntRelation;
PROCEDURE RealRelation*(op: INTEGER; VAR x, y: Item);
BEGIN Relation(op, x, y) END RealRelation;
PROCEDURE StringRelation*(op: INTEGER; VAR x, y: Item);
  VAR z: Item;
BEGIN x.e := Invoke("ocg_strcmp", Cat(C(x.e, ", "), ArrayLen(x)), Cat(C(y.e, ", "), ArrayLen(y))); MakeConstItem(z, ORB.intType, 0); Relation(op, x, z) END StringRelation;
PROCEDURE StrToChar*(VAR x: Item);
BEGIN x.e := Wrap("(", x.e, ")[0]"); x.type := ORB.charType END StrToChar;
PROCEDURE Store*(VAR x, y: Item);
  VAR rhs: Text;
BEGIN rhs := y.e;
  IF x.type.form = ORB.Pointer THEN rhs := C(Cat(Wrap("((", TypeName(x.type), ")"), rhs), ")") END;
  Emit(C(Binary(x.e, " = ", rhs), ";"))
END Store;
PROCEDURE StoreStruct*(VAR x, y: Item);
  VAR args: Text;
BEGIN
  IF x.type.form = ORB.Array THEN
    args := Cat(C(ArrayLen(x), ", "), y.e);
    args := Cat(C(args, ", "), ArrayLen(y));
    args := Cat(C(args, ", "), Wrap("sizeof(", TypeName(x.type.base), ")"));
    Emit(C(Invoke("ocg_arraycopy", x.e, args), ";"))
  ELSE
    args := Cat(C(Wrap("&(", y.e, ")"), ", "), Wrap("sizeof(", TypeName(x.type), ")"));
    IF x.varRecord & ORS.GetOption("T") THEN
      args := Cat(C(args, ", "), Wrap("&", C(TypeName(x.type), "_tag"), ""));
      Emit(C(Invoke("ocg_recordassign", Wrap("&(", x.e, ")"), args), ";"))
    ELSE Emit(C(Invoke("ocg_recordcopy", Wrap("&(", x.e, ")"), args), ";")) END
  END
END StoreStruct;
PROCEDURE CopyString*(VAR x, y: Item);
BEGIN Emit(C(Invoke("ocg_string", x.e, Cat(C(Cat(C(ArrayLen(x), ", "), y.e), ", "), ArrayLen(y))), ";")) END CopyString;
PROCEDURE PrepCall*(VAR x: Item; VAR r: LONGINT);
  VAR f: CallFrame;
BEGIN Freeze(x);
  IF ORS.GetOption("P") & (x.mode # ORB.Const) THEN
    Emit(C(Invoke("ocg_assert", Binary(x.e, " != ", S("NULL")), NIL), ";"))
  END;
  NEW(f); f.prev := calls; calls := f; f.callee := x.e;
  f.formal := x.type.dsc; f.remaining := x.type.nofpar; r := 0
END PrepCall;
PROCEDURE Argument(value: Text);
BEGIN IF calls.args # NIL THEN calls.args := Cat(C(calls.args, ", "), value)
  ELSE calls.args := value END
END Argument;
PROCEDURE NextParam;
BEGIN calls.formal := calls.formal.next; DEC(calls.remaining) END NextParam;
PROCEDURE ReferenceParam(VAR x: Item; ftype: ORB.Type);
  VAR value: Text;
BEGIN
  IF (ftype.form = ORB.Array) & (ftype.len < 0) THEN
    (* An open-array actual already denotes its elements, never &pointer.
       The length belongs to the actual and must survive arbitrary forwarding. *)
    value := C(Cat(Wrap("((", QualifiedType(ftype.base, calls.formal.rdo), " *)("), x.e), "))");
    Argument(value); Argument(ArrayLen(x))
  ELSIF ftype = x.type THEN
    (* Preserve the defining header's C type, including private imported types. *)
    Argument(Wrap("&(", x.e, ")"))
  ELSE
    value := C(Cat(Wrap("((", QualifiedType(ftype, calls.formal.rdo), " *)&"), Wrap("(", x.e, ")")), ")");
    Argument(value)
  END;
  NextParam
END ReferenceParam;
PROCEDURE ValueParam*(VAR x: Item);
  VAR value: Text; p: ORB.Object;
BEGIN p := calls.formal;
  IF p.type.form IN {ORB.Array, ORB.Record} THEN ReferenceParam(x, p.type)
  ELSE Freeze(x); value := x.e;
    IF p.type.form = ORB.Pointer THEN value := C(Cat(Wrap("((", TypeName(p.type), ")"), value), ")") END;
    Argument(value); NextParam
  END
END ValueParam;
PROCEDURE VarParam*(VAR x: Item; ftype: ORB.Type);
BEGIN ReferenceParam(x, ftype) END VarParam;
PROCEDURE OpenArrayParam*(VAR x: Item);
BEGIN ReferenceParam(x, calls.formal.type) END OpenArrayParam;
PROCEDURE StringParam*(VAR x: Item);
BEGIN ReferenceParam(x, calls.formal.type) END StringParam;
PROCEDURE Call*(VAR x: Item; r: LONGINT);
  VAR value, name: Text;
BEGIN value := C(Cat(C(calls.callee, "("), calls.args), ")"); calls := calls.prev;
  IF x.type.base.form = ORB.NoTyp THEN Emit(C(value, ";"))
  ELSE name := Temp(x.type.base); Emit(C(Binary(name, " = ", value), ";")); x.e := name; x.mode := Reg END
END Call;
PROCEDURE For0*(VAR x, y: Item);
BEGIN Freeze(y); Store(x, y) END For0;
PROCEDURE For1*(VAR x, y, z, w: Item; VAR L: LONGINT);
  VAR cond: Text;
BEGIN IF w.a > 0 THEN cond := Binary(x.e, " > ", z.e)
  ELSIF w.a < 0 THEN cond := Binary(x.e, " < ", z.e)
  ELSE ORS.Mark("zero increment"); cond := S("true") END;
  L := Jump(Wrap("if (", cond, ") goto "), 0, 0)
END For1;
PROCEDURE For2*(VAR x, y, w: Item);
BEGIN Emit(C(Binary(x.e, " = ", Invoke("ocg_add", x.e, w.e)), ";")) END For2;
PROCEDURE Enter*(parblksize, locblksize: LONGINT; int, leaf: BOOLEAN);
  VAR irq: INTEGER;
BEGIN IF int THEN
  IF Target.Cortex = 0 THEN ORS.Mark("OCG: interrupt procedure needs Cortex-M target")
  ELSIF active.obj.lev # 0 THEN ORS.Mark("interrupt procedure must be global")
  ELSE irq := active.obj.irq;
    IF (irq # -999) & ~((irq >= 0) & (irq < 240) OR
      (irq = -14) OR (irq = -13) OR (irq = -12) OR (irq = -11) OR (irq = -10) OR (irq = -5) OR (irq = -4) OR (irq = -2) OR (irq = -1)) THEN
      ORS.Mark("invalid Cortex-M IRQ number")
    ELSIF (Target.Cortex = 1) & ((irq >= 32) OR (irq = -12) OR (irq = -11) OR (irq = -10) OR (irq = -4)) THEN
      ORS.Mark("IRQ unavailable on Cortex-M0") END
  END
END END Enter;
PROCEDURE Return*(form: INTEGER; VAR x: Item; size: LONGINT; int, leaf: BOOLEAN);
BEGIN IF (form = ORB.Pointer) & (x.type.form = ORB.Pointer) THEN
    x.e := C(Cat(Wrap("((", TypeName(active.obj.type.base), ")"), x.e), ")")
  END;
  IF active.obj.interrupt & (Target.Cortex # 0) THEN
    Emit(S("ocg_arm_cpu.apsr = ocg_irq_saved.apsr; ocg_arm_cpu.high = ocg_irq_saved.high;"))
  END;
  IF form # ORB.NoTyp THEN Emit(C(Cat(S("return "), x.e), ";")) ELSE Emit(S("return;")) END;
  active.limit := pc; active := NIL
END Return;
PROCEDURE CaseHead*(VAR x: Item; VAR L0: LONGINT);
BEGIN Freeze(x); L0 := pc; Emit(x.e) END CaseHead;
PROCEDURE CaseTail*(L0, L1: LONGINT; n: INTEGER; VAR tab: ARRAY OF LabelRange);
  VAR t, cond: Text; i: INTEGER;
BEGIN t := S("");
  FOR i := 0 TO n-1 DO
    cond := Binary(Binary(code[L0].text, " >= ", N(tab[i].low)), " && ", Binary(code[L0].text, " <= ", N(tab[i].high)));
    t := Cat(t, C(Cat(Wrap("if (", cond, ") goto ocg_L"), N(tab[i].label)), ";")); t := Cat(t, S(0AX));
    code[tab[i].label].used := TRUE
  END;
  IF L1 = 0 THEN t := C(t, 'ocg_fail("CASE");' )
  ELSE t := C(Cat(C(t, "goto ocg_L"), N(L1)), ";"); code[L1].used := TRUE END;
  code[L0].text := t
END CaseTail;
PROCEDURE Increment*(upordown: LONGINT; VAR x, y: Item);
  VAR name: ARRAY 16 OF CHAR;
BEGIN IF y.type = ORB.noType THEN MakeConstItem(y, ORB.intType, 1) END;
  IF upordown = 0 THEN
    IF ORS.GetOption("V") THEN name := "ocg_addv" ELSE name := "ocg_add" END
  ELSE IF ORS.GetOption("V") THEN name := "ocg_subv" ELSE name := "ocg_sub" END END;
  Emit(C(Binary(x.e, " = ", Invoke(name, x.e, y.e)), ";"))
END Increment;
PROCEDURE Include*(inorex: LONGINT; VAR x, y: Item);
BEGIN Singleton(y); IF inorex = 0 THEN Emit(C(Binary(x.e, " |= ", y.e), ";"))
  ELSE Emit(C(Binary(x.e, " &= ~", y.e), ";")) END
END Include;
PROCEDURE Assert*(VAR x: Item);
BEGIN Emit(C(Invoke("ocg_assert", x.e, NIL), ";")) END Assert;
PROCEDURE New*(VAR x: Item);
  VAR t: Text;
BEGIN t := TypeName(x.type.base);
  Emit(C(Binary(x.e, " = ", Invoke("ocg_alloc", C(Cat(S("sizeof("), t), ")"), NIL)), ";"));
  Emit(C(Invoke("ocg_settag", x.e, Wrap("&", C(t, "_tag"), "")), ";"));
  Emit(C(Cat(C(t, "_init("), Wrap("", x.e, ");")), ""))
END New;
PROCEDURE Dispose*(VAR x: Item);
BEGIN Emit(C(Invoke("OCG_FREE", x.e, NIL), ";")); Emit(C(Binary(x.e, " = ", S("NULL")), ";")) END Dispose;
PROCEDURE Pack*(VAR x, y: Item);
BEGIN Emit(C(Binary(x.e, " = ", Invoke("ocg_ldexp", x.e, y.e)), ";")) END Pack;
PROCEDURE Unpk*(VAR x, y: Item);
BEGIN Emit(C(Binary(x.e, " = ", Invoke("ocg_unpk", x.e, Wrap("&(", y.e, ")"))), ";")) END Unpk;
PROCEDURE Get*(VAR x, y: Item);
BEGIN Emit(C(Binary(y.e, " = ", C(Cat(Wrap("(*(volatile ", TypeName(y.type), " *)(uintptr_t)(ocg_uint)("), x.e), "))")), ";")) END Get;
PROCEDURE Put*(VAR x, y: Item);
BEGIN Emit(C(Binary(C(Cat(Wrap("(*(volatile ", TypeName(y.type), " *)(uintptr_t)(ocg_uint)("), x.e), "))"), " = ", y.e), ";")) END Put;
PROCEDURE Copy*(VAR x, y, z: Item);
BEGIN Emit(C(Invoke("memmove", Wrap("(void *)(uintptr_t)(ocg_uint)(", y.e, ")"), Cat(C(Wrap("(void *)(uintptr_t)(ocg_uint)(", x.e, ")"), ", "), Invoke("ocg_bytes", z.e, NIL))), ";")) END Copy;
PROCEDURE Clear*(VAR x: Item);
BEGIN Emit(C(Invoke("memset", Wrap("&(", x.e, ")"), Cat(S("0, "), Wrap("sizeof(", x.e, ")"))), ";")) END Clear;
PROCEDURE Unsupported;
BEGIN ORS.Mark("OCG: RISC-specific operation has no portable C equivalent") END Unsupported;
PROCEDURE Led*(VAR x: Item);
BEGIN IF Target.Cortex = 0 THEN Unsupported
  ELSE Emit(C(Invoke("ocg_cortex_led", x.e, NIL), ";")) END
END Led;
PROCEDURE LDPSR*(VAR x: Item);
BEGIN IF Target.Cortex = 0 THEN Unsupported
  ELSIF (x.a < 0) OR (x.a > 1) THEN ORS.Mark("LDPSR expects 0 (disable) or 1 (enable)")
  ELSE Emit(C(Invoke("ocg_arm_interrupts", x.e, NIL), ";")) END
END LDPSR;
PROCEDURE RegisterName(n: Native): Text;
  VAR name: Text;
BEGIN name := NIL;
  IF (n >= 0) & (n < 16) THEN name := Cat(S("r"), N(n))
  ELSE CASE Sys.Short(n) OF
    16: name := S("APSR") | 17: name := S("IPSR") | 18: name := S("EPSR") |
    19: name := S("xPSR") | 20: name := S("MSP") | 21: name := S("PSP") |
    22: name := S("PRIMASK") | 23: name := S("BASEPRI") |
    24: name := S("FAULTMASK") | 25: name := S("CONTROL")
  ELSE END END;
  IF name = NIL THEN ORS.Mark("invalid Cortex-M register")
  ELSIF (Target.Cortex = 1) & ((n = 23) OR (n = 24)) THEN
    ORS.Mark("register unavailable on Cortex-M0")
  END;
  RETURN name
END RegisterName;
PROCEDURE LDREG*(VAR x, y: Item);
  VAR name, text: Text;
BEGIN IF Target.Cortex = 0 THEN Unsupported
  ELSE Freeze(y); name := RegisterName(x.a);
    IF (x.a >= 17) & (x.a <= 19) THEN ORS.Mark("read-only Cortex-M status register")
    ELSE
      IF x.a = 15 THEN
        text := S('__asm__ volatile ("bx %0" :: "r"((uint32_t)(');
        Emit(C(Cat(text, y.e), ')) : "memory"); __builtin_unreachable();'))
      ELSE
        IF x.a = 16 THEN
          Emit(C(Binary(S("ocg_arm_cpu.apsr"), " = ", y.e), ";")); name := S("APSR_nzcvq")
        END;
        IF x.a < 16 THEN text := S('__asm__ volatile ("mov ')
        ELSE text := S('__asm__ volatile ("msr ') END;
        text := Cat(text, name); text := C(text, ', %0" :: "r"((uint32_t)(');
        text := Cat(text, y.e); text := C(text, ')) : ');
        IF (x.a < 13) OR (x.a = 14) THEN text := Cat(text, C(Wrap('"', name, '"'), ', ')) END;
        Emit(C(text, '"cc", "memory");'));
        IF x.a = 25 THEN Emit(S('__asm__ volatile ("isb" ::: "memory");')) END
      END
    END
  END
END LDREG;
PROCEDURE ADC*(VAR x, y: Item);
BEGIN IF Target.Cortex = 0 THEN Unsupported
  ELSE x.e := Invoke("ocg_arm_adc", x.e, y.e); x.mode := Reg END
END ADC;
PROCEDURE SBC*(VAR x, y: Item);
BEGIN IF Target.Cortex = 0 THEN Unsupported
  ELSE x.e := Invoke("ocg_arm_sbc", x.e, y.e); x.mode := Reg END
END SBC;
PROCEDURE UML*(VAR x, y: Item);
BEGIN IF Target.Cortex = 0 THEN Unsupported
  ELSE x.e := Invoke("ocg_arm_uml", x.e, y.e); x.mode := Reg END
END UML;
PROCEDURE Register*(VAR x: Item);
  VAR name, text: Text;
BEGIN IF Target.Cortex = 0 THEN Unsupported
  ELSE name := RegisterName(x.a);
    IF x.a < 16 THEN text := S('({ uint32_t ocg_reg; __asm__ volatile ("mov %0, ')
    ELSE text := S('({ uint32_t ocg_reg; __asm__ volatile ("mrs %0, ') END;
    x.e := C(Cat(text, name), '" : "=r"(ocg_reg) :: "memory"); (ocg_int)ocg_reg; })');
    x.mode := Reg
  END
END Register;
PROCEDURE H*(VAR x: Item);
BEGIN IF Target.Cortex = 0 THEN Unsupported
  ELSIF x.a = 0 THEN x.e := S("((ocg_int)ocg_arm_cpu.high)"); x.mode := Reg
  ELSIF x.a = 1 THEN x.e := S("((ocg_int)ocg_arm_cpu.apsr)"); x.mode := Reg
  ELSE ORS.Mark("H expects 0 (UML high word) or 1 (status flags)") END
END H;
PROCEDURE Condition*(VAR x: Item);
BEGIN IF Target.Cortex = 0 THEN Unsupported
  ELSIF (x.a < 0) OR (x.a > 15) THEN ORS.Mark("invalid ARM condition code")
  ELSE x.e := Invoke("ocg_arm_condition", x.e, NIL); x.mode := Reg END
END Condition;
PROCEDURE Abs*(VAR x: Item);
BEGIN IF x.mode = ORB.Const THEN
    IF x.type.form = ORB.Real THEN MakeRealItem(x, ABS(Target.BitsReal(x.a)))
    ELSE IF x.a = Target.Min() THEN ORS.Mark("ABS overflow") ELSE MakeConstItem(x, x.type, ABS(x.a)) END END
  ELSIF x.type.form = ORB.Real THEN x.e := Invoke("ocg_fabs", x.e, NIL)
  ELSE x.e := Invoke("ocg_abs", x.e, NIL) END;
  IF x.mode # ORB.Const THEN x.mode := Reg END END Abs;
PROCEDURE Odd*(VAR x: Item);
BEGIN IF x.mode = ORB.Const THEN x.a := x.a MOD 2; x.e := N(x.a)
  ELSE Unary(x, "((", ") & 1)") END END Odd;
PROCEDURE Floor*(VAR x: Item);
  VAR real: REAL;
BEGIN IF x.mode = ORB.Const THEN
    real := Target.BitsReal(x.a);
    IF (real >= Target.Min()*1.0D0) & (real < -(Target.Min()*1.0D0)) THEN
      MakeConstItem(x, ORB.intType, ENTIER(real))
    ELSE ORS.Mark("FLOOR range"); MakeConstItem(x, ORB.intType, 0) END
  ELSE x.e := Invoke("ocg_floor", x.e, NIL); x.mode := Reg END END Floor;
PROCEDURE Float*(VAR x: Item);
BEGIN IF x.mode = ORB.Const THEN MakeRealItem(x, x.a*1.0D0)
  ELSE Unary(x, "((ocg_real_t)(", "))") END END Float;
PROCEDURE Ord*(VAR x: Item);
BEGIN IF x.type.form = ORB.Real THEN
    IF x.mode = ORB.Const THEN x.e := N(x.a)
    ELSE x.e := Invoke("ocg_bits", x.e, NIL); x.mode := Reg END
  ELSIF x.type.form = ORB.Pointer THEN
    x.e := Invoke("ocg_address", x.e, NIL); x.mode := Reg
  ELSIF x.type.form = ORB.NilTyp THEN MakeConstItem(x, ORB.intType, 0)
  ELSIF x.type.form = ORB.Proc THEN
    x.e := Wrap("((ocg_int)(uintptr_t)(", x.e, "))"); x.mode := Reg
  ELSIF x.type.form = ORB.Set THEN
    IF x.mode = ORB.Const THEN x.a := SetValue(SYSTEM.VAL(SET, Sys.Short(x.a))); x.e := N(x.a)
    ELSE x.e := Wrap("((ocg_int)(uint32_t)(", x.e, "))"); x.mode := Reg END
  END END Ord;
PROCEDURE Len*(VAR x: Item);
  VAR t: Text;
BEGIN t := ArrayLen(x); IF x.type.len >= 0 THEN MakeConstItem(x, ORB.intType, x.type.len)
  ELSE x.e := t; x.mode := Reg END
END Len;
PROCEDURE Shift*(fct: LONGINT; VAR x, y: Item);
  VAR name: ARRAY 16 OF CHAR; set: Sys.INT32;
BEGIN
  IF x.type.form = ORB.Set THEN
    CASE fct OF 0: name := "ocg_set_lsl" | 1: name := "ocg_set_asr" | 2: name := "ocg_set_ror" | 14: name := "ocg_set_lsr" END
  ELSE CASE fct OF 0: name := "ocg_lsl" | 1: name := "ocg_asr" | 2: name := "ocg_ror" | 14: name := "ocg_lsr" END END;
  IF (x.mode = ORB.Const) & (y.mode = ORB.Const) THEN
    IF x.type.form = ORB.Set THEN
      set := Sys.Short(x.a);
      CASE fct OF 0: set := SYSTEM.LSH(set, Sys.Short(y.a MOD 32)) |
        1: set := Sys.Short(ASH(set, -Sys.Short(y.a MOD 32))) |
        2: set := SYSTEM.ROT(set, -Sys.Short(y.a MOD 32)) |
        14: set := SYSTEM.LSH(set, -Sys.Short(y.a MOD 32)) END;
      x.a := SetValue(SYSTEM.VAL(SET, set))
    ELSE x.a := Target.Shift(fct, x.a, y.a) END;
    x.e := N(x.a)
  ELSE x.e := Invoke(name, x.e, y.e); x.mode := Reg END
END Shift;
PROCEDURE Bit*(VAR x, y: Item);
BEGIN x.e := Invoke("ocg_bit", x.e, y.e); x.mode := Reg END Bit;
PROCEDURE Adr*(VAR x: Item);
BEGIN x.e := Invoke("ocg_address", Wrap("&(", x.e, ")"), NIL); x.mode := Reg END Adr;
PROCEDURE Alignment(t: ORB.Type): LONGINT;
  VAR align, a: LONGINT; o: ORB.Object;
BEGIN align := 1;
  CASE t.form OF
    ORB.Int: IF t.size = 1 THEN align := 1 ELSE align := WordSize END |
    ORB.Real: align := WordSize |
    ORB.Set: align := 4 |
    ORB.Pointer, ORB.Proc, ORB.NilTyp: align := WordSize |
    ORB.Record:
      align := WordSize; o := t.dsc;
      WHILE o # NIL DO a := Alignment(o.type); IF a > align THEN align := a END; o := o.next END |
    ORB.Array: align := Alignment(t.base)
  ELSE END;
  RETURN align
END Alignment;
PROCEDURE HostSize(t: ORB.Type): LONGINT;
  VAR size, align, off: LONGINT; o: ORB.Object;
BEGIN size := t.size;
  IF t.mno > 0 THEN RETURN size END;
  CASE t.form OF
    ORB.Pointer, ORB.Proc, ORB.NilTyp: size := WordSize |
    ORB.Array: size := t.len * HostSize(t.base) |
    ORB.Record:
      IF t.base = NIL THEN size := WordSize ELSE size := HostSize(t.base) END;
      off := 0;
      WHILE off < t.size DO o := t.dsc;
        WHILE o # NIL DO
          IF (o.val = off) & ((t.base = NIL) OR (o.val >= t.base.size)) THEN
            align := Alignment(o.type); size := (size+align-1) DIV align * align + HostSize(o.type)
          END;
          o := o.next
        END; INC(off)
      END;
      align := Alignment(t); size := (size+align-1) DIV align * align
  ELSE END;
  RETURN size
END HostSize;
PROCEDURE IsOwnField(t: ORB.Type; field: ORB.Object): BOOLEAN;
  VAR o: ORB.Object;
BEGIN o := NIL; IF t.base # NIL THEN o := t.base.dsc END;
  WHILE (o # NIL) & (o # field) DO o := o.next END;
  RETURN o = NIL
END IsOwnField;
PROCEDURE Layout(t: ORB.Type);
  VAR p: CType; dummy: Text; size, align: LONGINT;
  PROCEDURE Fields(o: ORB.Object);
    VAR a: LONGINT;
  BEGIN IF o # NIL THEN Fields(o.next);
    IF IsOwnField(t, o) THEN
      Layout(o.type); a := Alignment(o.type); size := (size+a-1) DIV a*a;
      o.val := size; size := size+o.type.size
    END
  END END Fields;
BEGIN IF (t # NIL) & (t.mno <= 0) & (t.form IN {ORB.Pointer, ORB.Array, ORB.Record, ORB.Proc}) THEN
  dummy := TypeName(t); p := types;
  WHILE (p # NIL) & (p.typ # t) DO p := p.next END;
  IF ~p.layout THEN p.layout := TRUE;
    CASE t.form OF
      ORB.Pointer, ORB.Proc: t.size := WordSize |
      ORB.Array: Layout(t.base); IF t.len >= 0 THEN t.size := t.len*t.base.size END |
      ORB.Record:
        IF t.base = NIL THEN size := WordSize
        ELSE Layout(t.base); size := t.base.size END;
        Fields(t.dsc); align := Alignment(t); t.size := (size+align-1) DIV align*align
    END
  END
END END Layout;
PROCEDURE Seal*;
  VAR p: CType;
BEGIN p := types; WHILE p # NIL DO Layout(p.typ); p := p.next END END Seal;
PROCEDURE Size*(VAR x: Item);
BEGIN MakeConstItem(x, ORB.intType, HostSize(x.type)) END Size;
PROCEDURE Reinterpret*(VAR x: Item; target: ORB.Type);
BEGIN
  IF (x.type.form IN {ORB.Pointer, ORB.Proc}) OR (target.form IN {ORB.Pointer, ORB.Proc}) THEN
    IF x.type.form = ORB.Real THEN x.e := Invoke("ocg_bits", x.e, NIL) END;
    IF target.form = ORB.Real THEN x.e := Invoke("ocg_real", Wrap("((ocg_int)(uintptr_t)(", x.e, "))"), NIL)
    ELSE x.e := C(Cat(Wrap("((", TypeName(target), ")(uintptr_t)(ocg_uint)("), x.e), "))") END;
    x.mode := Reg
  ELSIF (x.type.form = ORB.Real) & (target.form # ORB.Real) THEN
    IF x.mode = ORB.Const THEN x.e := N(x.a)
    ELSE x.e := Invoke("ocg_bits", x.e, NIL) END
  ELSIF (target.form = ORB.Real) & (x.type.form # ORB.Real) THEN
    x.e := Invoke("ocg_real", x.e, NIL)

  ELSE
    IF (x.mode = ORB.Const) & ((target.form = ORB.Set) OR (x.type.form = ORB.Set)) THEN
      x.a := SetValue(SYSTEM.VAL(SET, Sys.Short(x.a))); x.e := N(x.a)
    END;
    x.e := C(Cat(Wrap("((", TypeName(target), ")"), Wrap("(", x.e, ")")), ")")
  END;
  IF x.mode = ORB.Const THEN
    IF target.form = ORB.Set THEN x.a := SetValue(SYSTEM.VAL(SET, Sys.Short(x.a))); x.e := N(x.a)
    ELSIF (target.form IN {ORB.Byte, ORB.Char}) OR (target.form = ORB.Int) & (target.size = 1) THEN
      x.a := x.a MOD 256; x.e := N(x.a)
    END
  END
END Reinterpret;
PROCEDURE BeginSection*;
BEGIN sectionStart := pc END BeginSection;
PROCEDURE EndSection*(drop: BOOLEAN);
BEGIN IF drop THEN pc := sectionStart END END EndSection;
PROCEDURE CheckRegs*; BEGIN END CheckRegs;
PROCEDURE Open*(v: INTEGER);
  VAR i: INTEGER;
BEGIN FOR i := 0 TO maxCode-1 DO code[i].used := FALSE END; ORS.SetOption("P", ORS.GetOption("C")); ORS.SetOption("T", ORS.GetOption("C"));
  ORS.SetOption("X", ORS.GetOption("C"));
  pc := 1; symbols := NIL; types := NIL; lastType := NIL;
  procs := NIL; lastProc := NIL; active := NIL; calls := NIL;
  typeSerial := 0; procSerial := 0; tempSerial := 0; declarationOwner := NIL;
  IF v = 0 THEN ORS.Mark("OCG: MODULE* is a RISC image") END
END Open;
PROCEDURE SetDataSize*(dc: LONGINT);
BEGIN Capture(moduleScope, NIL, 0) END SetDataSize;
PROCEDURE Header*;
  VAR p: Proc;
BEGIN NEW(p); p.first := pc; p.scope := moduleScope; p.obj := NIL;
  IF procs = NIL THEN procs := p ELSE lastProc.next := p END;
  lastProc := p; active := p
END Header;

PROCEDURE Params(t: ORB.Type; names: BOOLEAN): Text;
  VAR o: ORB.Object; i: INTEGER; result, name, part: Text; p: Symbol;
BEGIN result := NIL; o := t.dsc; i := 0;
  WHILE (o # NIL) & (i < t.nofpar) DO
    p := FindSymbol(o);
    IF names & (p # NIL) THEN name := p.name ELSE name := Cat(S("ocg_p"), N(i)) END;
    IF (o.type.form = ORB.Array) & (o.type.len < 0) THEN
      part := Cat(C(QualifiedType(o.type.base, o.rdo), " *"), name);
      part := Cat(C(part, ", ocg_int "), C(name, "_len"))
    ELSE
      IF o.type.form IN {ORB.Array, ORB.Record} THEN
        part := C(QualifiedType(o.type, o.rdo), " *")
      ELSE part := TypeName(o.type);
        IF o.class = ORB.Par THEN part := C(part, " *") ELSE part := C(part, " ") END
      END;
      part := Cat(part, name)
    END;
    IF result = NIL THEN result := part ELSE result := Cat(C(result, ", "), part) END;
    o := o.next; INC(i)
  END;
  IF result = NIL THEN result := S("void") END;
  RETURN result
END Params;
PROCEDURE Definition(t: ORB.Type);
  VAR p: CType; o: ORB.Object; i: INTEGER; part: Text;
BEGIN IF t # NIL THEN
  p := types; WHILE (p # NIL) & (p.typ # t) DO p := p.next END;
  IF (p # NIL) & (p.state # 2) & ((t.mno <= 0) OR (t.typobj = NIL)) THEN
    IF p.state = 3 THEN ORS.Mark("OCG: recursive C type definition")
    ELSE p.state := 3;
      CASE t.form OF
        ORB.Pointer:
          IF t.base.form # ORB.Record THEN Definition(t.base) END;
          Line(C(Cat(C(Cat(S("typedef "), TypeName(t.base)), " *"), p.name), ";")) |
        ORB.Array:
          Definition(t.base);
          IF t.len < 0 THEN
            Line(C(Cat(C(Cat(S("typedef "), TypeName(t.base)), " *"), p.name), ";"))
          ELSE
            Line(C(Cat(C(Cat(C(Cat(S("typedef "), TypeName(t.base)), " "), p.name), "["), N(t.len)), "];"))
          END |
        ORB.Record:
          Definition(t.base); o := t.dsc;
          WHILE o # NIL DO IF (t.base = NIL) OR (o.val >= t.base.size) THEN Definition(o.type) END; o := o.next END;
          Line(C(Cat(S("struct "), p.name), " {"));
          IF t.base # NIL THEN Line(C(Cat(C(S("  "), ""), C(TypeName(t.base), " ocg_base;")), ""))
          ELSE Line(S("  const ocg_type *ocg_tag;")) END;
          (* Field lists are in reverse declaration order. Offset order preserves
             base prefixes and stable layout independently of symbol-file order. *)
          i := 0;
          WHILE i < t.size DO o := t.dsc;
            WHILE o # NIL DO
              IF (o.val = i) & ((t.base = NIL) OR (o.val >= t.base.size)) THEN
                Line(C(Cat(C(Cat(S("  "), TypeName(o.type)), " f_"), S(o.name)), ";"))
              END;
              o := o.next
            END; INC(i)
          END;
          Line(S("};")) |
        ORB.Proc:
          Definition(t.base); o := t.dsc; i := 0;
          WHILE (o # NIL) & (i < t.nofpar) DO Definition(o.type); o := o.next; INC(i) END;
          part := Cat(C(Cat(S("typedef "), TypeName(t.base)), " (*"), p.name);
          Line(C(Cat(C(part, ")("), Params(t, FALSE)), ");"))
      END;
      p.state := 2
    END
  END
END END Definition;
PROCEDURE Initializer(t: ORB.Type; value: Text);
  VAR o: ORB.Object; e, index: Text;
BEGIN IF t.form = ORB.Record THEN
    IF (t.mno > 0) & (t.typobj # NIL) THEN
      (* The defining module knows private base names and hidden fields. *)
      Line(C(Cat(C(TypeName(t), "_init("), Wrap("&(", value, ")")), ");"))
    ELSE
      IF t.base # NIL THEN Initializer(t.base, Wrap("(", value, ").ocg_base")) END;
      o := t.dsc;
      WHILE o # NIL DO
        IF (t.base = NIL) OR (o.val >= t.base.size) THEN
          Initializer(o.type, Cat(Wrap("(", value, ").f_"), S(o.name)))
        END; o := o.next
      END;
      Line(C(Invoke("ocg_settag", Wrap("&(", value, ")"), Wrap("&", C(TypeName(t), "_tag"), "")), ";"))
    END
  ELSIF (t.form = ORB.Array) & (t.len > 0) THEN
    IF (t.base.form = ORB.Record) OR (t.base.form = ORB.Array) THEN
      INC(tempSerial); index := Cat(S("ocg_i"), N(tempSerial));
      e := Cat(C(Cat(S("for (ocg_int "), index), "=0; "), Binary(index, " < ", N(t.len)));
      Line(C(Cat(C(e, "; ++"), index), ") {"));
      Initializer(t.base, C(Cat(Wrap("(", value, ")["), index), "]")); Line(S("}"))
    END
  END
END Initializer;
PROCEDURE IRQName(irq: INTEGER): Text;
BEGIN IF irq >= 0 THEN RETURN C(Cat(S("OCG_IRQ_"), N(irq)), "_Handler")
  ELSE RETURN C(Cat(S("OCG_Exception_"), N(irq+16)), "_Handler") END
END IRQName;
PROCEDURE Signature(obj: ORB.Object): Text;
  VAR p: Symbol; result: Text;
BEGIN p := FindSymbol(obj);
  result := C(Cat(C(Cat(C(TypeName(obj.type.base), " "), p.name), "("), Params(obj.type, TRUE)), ")");
  IF obj.interrupt THEN result := Cat(S("OCG_INTERRUPT "), result) END;
  RETURN result
END Signature;
PROCEDURE Variables(scope, owner: ORB.Object; header: BOOLEAN);
  VAR o: ORB.Object; p: Symbol; t: Text;
BEGIN o := scope.next;
  WHILE o # NIL DO p := FindSymbol(o);
    IF (o.class = ORB.Var) & (p # NIL) & ~p.param THEN
      IF header THEN
        IF o.expo THEN Line(C(Cat(C(Cat(S("extern "), TypeName(o.type)), " "), p.name), ";")) END
      ELSE t := C(Cat(C(TypeName(o.type), " "), p.name), " = {0};");
        IF (owner = NIL) & ~o.expo THEN t := Cat(S("static "), t) END;
        Line(t)
      END
    END; o := o.next
  END
END Variables;
PROCEDURE Body(p: Proc);
  VAR i: LONGINT;
BEGIN i := p.first;
  WHILE i < p.limit DO
    IF code[i].used THEN Line(C(Cat(S("ocg_L"), N(i)), ":;")) END;
    IF code[i].branch THEN
      IF code[i].target = 0 THEN ORS.Mark("OCG: unresolved branch") END;
      Line(C(Cat(C(code[i].text, "ocg_L"), N(code[i].target)), ";"))
    ELSE Line(code[i].text) END;
    INC(i)
  END;
  IF code[p.limit].used THEN Line(C(Cat(S("ocg_L"), N(p.limit)), ":;")) END
END Body;
PROCEDURE Close*(VAR modid: ORS.Ident; key, nofent: LONGINT);
  VAR file: Files.File; name: ARRAY 80 OF CHAR; i: INTEGER;
    p: Proc; ct: CType; o: ORB.Object; s: Symbol; t: Text;
BEGIN active.limit := pc; Emit(S(";"));
  (* Derive branch labels after all fixups, including targets emitted later. *)
  FOR i := 1 TO pc-1 DO IF code[i].branch & (code[i].target > 0) THEN code[code[i].target].used := TRUE END END;
  COPY(modid, name); i := 0; WHILE name[i] # 0X DO INC(i) END;
  name[i] := "."; name[i+1] := "h"; name[i+2] := 0X;
  file := Files.New(name); IF file = NIL THEN ORS.Mark("OCG: cannot create header") ELSE
    Files.Set(R, file, 0);
    Line(C(Cat(S("#ifndef OCG_"), S(modid)), "_H"));
    Line(C(Cat(S("#define OCG_"), S(modid)), "_H"));
    IF Target.Cortex # 0 THEN
      Line(C(Cat(S("#if defined(OCG_CORTEX_M) && OCG_CORTEX_M != "), N(Target.Cortex)), ""));
      Line(S('#error "mixed Cortex-M targets"')); Line(S("#endif"));
      Line(C(Cat(S("#define OCG_CORTEX_M "), N(Target.Cortex)), ""))
    END;
    Line(S("#ifdef OCG_RUNTIME_HEADER"));
    Line(S("#include OCG_RUNTIME_HEADER"));
    Line(S("#else")); Line(S('#include "ocg_runtime.h"')); Line(S("#endif"));
    Line(C(Cat(S('_Static_assert(sizeof(void *) == '), N(WordSize)), ', "OCG native pointer ABI");'));
    o := moduleScope.next;
    WHILE o # NIL DO IF (o.class = ORB.Mod) & (o.dsc # ORB.system) THEN
      Line(C(Cat(S('#include "'), S(o(ORB.Module).orgname)), '.h"')) END; o := o.next END;
    ct := types;
    WHILE ct # NIL DO IF (ct.typ.form = ORB.Record) & (ct.typ.mno <= 0) THEN
      Line(C(Cat(C(Cat(S("typedef struct "), ct.name), " "), ct.name), ";")) END; ct := ct.next END;
    ct := types; WHILE ct # NIL DO Definition(ct.typ); ct := ct.next END;
    s := symbols;
    WHILE s # NIL DO
      IF (s.obj.class = ORB.Typ) & (s.obj.lev >= 0) THEN
        t := TypeName(s.typ);
        IF s.name # t THEN
          Line(C(Cat(C(Cat(S("typedef "), t), " "), s.name), ";"));
          IF s.typ.form = ORB.Record THEN
            Line(Cat(C(Cat(S("#define "), s.name), "_tag "), C(t, "_tag")));
            Line(Cat(C(Cat(S("#define "), s.name), "_init "), C(t, "_init")))
          END
        END
      END;
      s := s.next
    END;
    ct := types;
    WHILE ct # NIL DO IF (ct.typ.form = ORB.Record) & (ct.typ.mno <= 0) THEN
      Line(C(Cat(S("extern const ocg_type "), ct.name), "_tag;"));
      Line(C(Cat(C(Cat(C(S("static inline void "), ""), ct.name), "_init("), C(ct.name, " *p")), ");"))
    END; ct := ct.next END;
    ct := types;
    WHILE ct # NIL DO IF (ct.typ.form = ORB.Record) & (ct.typ.mno <= 0) THEN
      Line(C(Cat(C(Cat(S("static inline void "), ct.name), "_init("), C(ct.name, " *p")), ") {"));
      Initializer(ct.typ, S("(*p)")); Line(S("}"))
    END; ct := ct.next END;
    Variables(moduleScope, NIL, TRUE); o := moduleScope.next;
    WHILE o # NIL DO
      IF (o.expo OR o.interrupt) & (o.class = ORB.Const) & (o.type.form = ORB.Proc) THEN
        IF o.externalName[0] # 0X THEN
          Line(C(Cat(S("extern "), Signature(o)), ";"));
          Line(Cat(C(Cat(S("#define "), Cat(ModulePrefix(0), S(o.name))), " "), S(o.externalName)))
        ELSE Line(C(Signature(o), ";")) END
      END;
      o := o.next
    END;
    o := moduleScope.next;
    WHILE o # NIL DO
      IF o.interrupt & (o.irq # -999) THEN
        Line(C(Cat(S("OCG_INTERRUPT void "), IRQName(o.irq)), "(void);"))
      END; o := o.next
    END;
    Line(C(Cat(S("void "), C(ModulePrefix(0), "_init")), "(void);"));
    Line(S("#endif")); OCGFiles.Publish(name, file)
  END;
  name[i+1] := "c"; file := Files.New(name);
  IF file = NIL THEN ORS.Mark("OCG: cannot create C file") ELSE
    Files.Set(R, file, 0); Line(C(Cat(S('#include "'), S(modid)), '.h"'));
    ct := types;
    WHILE ct # NIL DO IF (ct.typ.form = ORB.Record) & (ct.typ.mno <= 0) THEN
      IF ct.typ.base # NIL THEN t := Wrap("&", C(TypeName(ct.typ.base), "_tag"), "") ELSE t := S("NULL") END;
      Line(C(Cat(C(Cat(S("const ocg_type "), ct.name), "_tag = {"), t), "};"))
    END; ct := ct.next END;
    Variables(moduleScope, NIL, FALSE);
    p := procs;
    WHILE p # NIL DO IF p.obj # NIL THEN
      t := Signature(p.obj);
      IF p.external THEN t := Cat(S("extern "), t)
      ELSIF ~p.obj.interrupt & (~p.obj.expo OR (p.obj.lev > 0)) THEN t := Cat(S("static "), t) END;
      Line(C(t, ";"))
    END; p := p.next END;
    p := procs;
    WHILE p # NIL DO
      IF p.obj # NIL THEN
        IF ~p.external THEN
          t := Signature(p.obj); IF ~p.obj.interrupt & (~p.obj.expo OR (p.obj.lev > 0)) THEN t := Cat(S("static "), t) END;
          Line(C(t, " {"));
          IF p.obj.interrupt THEN Line(S("ocg_arm_state ocg_irq_saved = {ocg_arm_cpu.apsr, ocg_arm_cpu.high};")) END;
          Variables(p.scope, p.obj, FALSE);
          o := p.scope.next;
          WHILE o # NIL DO s := FindSymbol(o);
            IF (s # NIL) & (o.class = ORB.Var) & ~s.param THEN Initializer(o.type, s.name) END;
            o := o.next
          END;
          Body(p); Line(S("}"));
          IF p.obj.interrupt & (p.obj.irq # -999) THEN
            t := C(IRQName(p.obj.irq), '(void) __attribute__((alias("');
            s := FindSymbol(p.obj);
            Line(C(Cat(Cat(S("OCG_INTERRUPT void "), t), s.name), '")));'))
          END
        END
      ELSE
        Line(C(Cat(S("void "), C(ModulePrefix(0), "_init")), "(void) {"));
        Line(S("static unsigned char state;")); Line(S("if (state) return;")); Line(S("state = 1;"));
        o := moduleScope.next;
        WHILE o # NIL DO
          IF (o.class = ORB.Mod) & (o.dsc # ORB.system) THEN
            Line(C(Cat(C(S("O_"), ""), C(S(o(ORB.Module).orgname), "__init")), "();"))
          END; o := o.next
        END;
        o := moduleScope.next;
        WHILE o # NIL DO s := FindSymbol(o);
          IF (s # NIL) & (o.class = ORB.Var) THEN Initializer(o.type, s.name) END;
          o := o.next
        END;
        Body(p); Line(S("state = 2;")); Line(S("}"))
      END;
      p := p.next
    END;
    IF mainProgram THEN
      Line(S("int main(void) {"));
      Line(C(C(ModulePrefix(0), "_init"), "();"));
      Line(S("return 0;")); Line(S("}"))
    END;
    OCGFiles.Publish(name, file)
  END
END Close;
BEGIN SetTarget(0)
END OCG.
