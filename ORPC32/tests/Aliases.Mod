MODULE Aliases;
TYPE Hidden* = RECORD n*: INTEGER END;
 R* = Hidden; R2* = R;
 D* = RECORD (R) m*: INTEGER END;
 P* = POINTER TO R; Q* = POINTER TO D;
VAR root*: P; child*: Q;
PROCEDURE Get*(): P;
RETURN child
END Get;
PROCEDURE Test*;
BEGIN NEW(child); root := Get(); ASSERT(root = child)
END Test;
END Aliases.
