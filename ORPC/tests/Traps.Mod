MODULE Traps;
IMPORT SYSTEM;
TYPE T = RECORD n: INTEGER END; P = POINTER TO T;
  U = RECORD (T) m: INTEGER END; Q = POINTER TO U;
  F = PROCEDURE;
VAR answer*: INTEGER;
PROCEDURE Bounds*;
VAR a: ARRAY 2 OF INTEGER; n: INTEGER;
BEGIN n := 2; answer := a[n]
END Bounds;
PROCEDURE Nil*;
VAR p: P;
BEGIN answer := p.n
END Nil;
PROCEDURE DivZero*;
VAR n: INTEGER;
BEGIN n := 0; answer := 7 DIV n
END DivZero;
PROCEDURE Guard*(p: P);
BEGIN answer := p(Q).m
END Guard;
PROCEDURE Assertion*;
BEGIN ASSERT(FALSE)
END Assertion;
PROCEDURE Overflow*;
VAR n: INTEGER;
BEGIN (*$V+*) n := -1; n := n-LSL(1, SYSTEM.SIZE(INTEGER)*8-1); INC(n)
END Overflow;
(*$V-*)
PROCEDURE NilCall*;
VAR f: F;
BEGIN f
END NilCall;
END Traps.
