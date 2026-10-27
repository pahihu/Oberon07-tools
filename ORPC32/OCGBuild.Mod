MODULE OCGBuild;
(* Import-header prepass. Collect finishes before the parser is invoked, so
   neither recursive graph traversal nor compilation suspends ORS's scanner. *)
IMPORT Texts, Oberon, ORS;
CONST maxModules = 1024;
TYPE
  Edge* = POINTER TO EdgeDesc;
  EdgeDesc* = RECORD name*: ORS.Ident; next*: Edge END;
  Node* = POINTER TO NodeDesc;
  NodeDesc = RECORD
    name*: ORS.Ident; path*: ORS.Path; text*: Texts.Text;
    next*: Node; allNext: Node; imports*: Edge; listed*: BOOLEAN; state: INTEGER
  END;
VAR all, first, last: Node; count: INTEGER; W: Texts.Writer;

PROCEDURE Error(message, name: ARRAY OF CHAR);
BEGIN Texts.WriteString(W, "  build: "); Texts.WriteString(W, message);
  Texts.WriteString(W, " "); Texts.WriteString(W, name);
  Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf); INC(ORS.errcnt)
END Error;

PROCEDURE Append(VAR path: ORS.Path; suffix: ARRAY OF CHAR);
  VAR i, j: INTEGER;
BEGIN i := 0; WHILE path[i] # 0X DO INC(i) END; j := 0;
  WHILE (suffix[j] # 0X) & (i < LEN(path)-1) DO path[i] := suffix[j]; INC(i); INC(j) END;
  path[i] := 0X;
  IF suffix[j] # 0X THEN Error("source path too long:", path) END
END Append;

PROCEDURE Lookup(name: ORS.Ident): Node;
  VAR p: Node;
BEGIN p := all; WHILE (p # NIL) & (p.name # name) DO p := p.allNext END;
  RETURN p
END Lookup;

PROCEDURE Header(p: Node);
  VAR sym, i: INTEGER; declared, name: ORS.Ident;
    edge, tail: Edge; options: ARRAY 26 OF BOOLEAN;
BEGIN FOR i := 0 TO 25 DO options[i] := ORS.options[i] END; ORS.Init(p.text, 0); ORS.Get(sym);
  IF sym # ORS.module THEN Error("MODULE expected in", p.path)
  ELSE ORS.Get(sym); IF sym = ORS.times THEN ORS.Get(sym) END;
    IF sym # ORS.ident THEN Error("module identifier expected in", p.path)
    ELSE declared := ORS.id;
      IF (p.name[0] # 0X) & (declared # p.name) THEN
        Error("module name does not match imported name:", p.path)
      ELSE p.name := declared END;
      ORS.Get(sym);
      IF sym # ORS.semicolon THEN Error("semicolon expected in", p.path)
      ELSE ORS.Get(sym);
        IF sym = ORS.import THEN
          tail := NIL;
          REPEAT ORS.Get(sym);
            IF sym # ORS.ident THEN Error("import identifier expected in", p.path)
            ELSE name := ORS.id; ORS.Get(sym);
              IF sym = ORS.becomes THEN ORS.Get(sym);
                IF sym = ORS.ident THEN name := ORS.id; ORS.Get(sym)
                ELSE Error("imported module name expected in", p.path) END
              END;
              IF name # "SYSTEM" THEN NEW(edge); edge.name := name;
                IF tail = NIL THEN p.imports := edge ELSE tail.next := edge END; tail := edge
              END
            END
          UNTIL (sym # ORS.comma) OR (ORS.errcnt # 0);
          IF (ORS.errcnt = 0) & (sym # ORS.semicolon) THEN Error("import semicolon expected in", p.path) END
        END
      END
    END
  END;
  FOR i := 0 TO 25 DO ORS.options[i] := options[i] END
END Header;

PROCEDURE Source(parent: Node; name: ORS.Ident): Node;
  VAR p: Node; path: ORS.Path; i, slash: INTEGER;
BEGIN p := NIL;
  IF count >= maxModules THEN Error("too many modules while loading", name)
  ELSE NEW(p); p.name := name; NEW(p.text);
    (* Prefer the importing source's directory, then the normal ORPRED paths. *)
    path := parent.path; i := 0; slash := -1;
    WHILE path[i] # 0X DO IF (path[i] = "/") OR (path[i] = "\") THEN slash := i END; INC(i) END;
    path[slash+1] := 0X; Append(path, name); Append(path, ".Mod");
    IF ORS.errcnt = 0 THEN Texts.Open(p.text, path) END;
    IF (ORS.errcnt = 0) & (p.text.len = 0) THEN
      COPY(name, path); Append(path, ".Mod"); ORS.ResolvePath(path); Texts.Open(p.text, path)
    END;
    IF ORS.errcnt = 0 THEN
      IF p.text.len = 0 THEN Error("missing or empty source for", name); p := NIL
      ELSE p.path := path; p.allNext := all; all := p; INC(count) END
    END
  END;
  RETURN p
END Source;

PROCEDURE Visit(p: Node);
  VAR edge: Edge; dependency: Node;
BEGIN
  IF p.state = 1 THEN Error("cyclic import involving", p.name)
  ELSIF p.state = 0 THEN p.state := 1; Header(p);
    edge := p.imports;
    WHILE (edge # NIL) & (ORS.errcnt = 0) DO
      dependency := Lookup(edge.name);
      IF dependency = NIL THEN dependency := Source(p, edge.name) END;
      IF (dependency # NIL) & (ORS.errcnt = 0) THEN Visit(dependency) END;
      edge := edge.next
    END;
    IF ORS.errcnt = 0 THEN p.state := 2;
      IF first = NIL THEN first := p ELSE last.next := p END; last := p
    END
  END
END Visit;

PROCEDURE Collect*(rootText: Texts.Text; rootPath: ORS.Path): Node;
  VAR root: Node;
BEGIN all := NIL; first := NIL; last := NIL; count := 1;
  NEW(root); root.text := rootText; root.path := rootPath; all := root;
  ORS.errcnt := 0; Visit(root);
  IF ORS.errcnt # 0 THEN first := NIL END;
  RETURN first
END Collect;

BEGIN Texts.OpenWriter(W)
END OCGBuild.
