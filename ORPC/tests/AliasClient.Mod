MODULE AliasClient;
IMPORT A := Aliases, SYSTEM;
TYPE Reexport* = A.R2;
VAR size*: INTEGER; p*: A.P;
BEGIN A.Test; NEW(p); p.n := 42; size := SYSTEM.SIZE(A.P)
END AliasClient.
