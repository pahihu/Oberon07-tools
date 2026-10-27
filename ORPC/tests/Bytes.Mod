MODULE Bytes;
IMPORT SYSTEM;
TYPE T* = RECORD a*: BYTE; b*: BYTE; r*: REAL END;
VAR value*: T; result*: INTEGER;
PROCEDURE init*;
BEGIN value.a := 255; value.b := 2;
 result := value.a+300+1;
 ASSERT(result=556); result := -1; result := result-LSL(1, SYSTEM.SIZE(INTEGER)*8-1); INC(result);
 ASSERT(result=LSL(1, SYSTEM.SIZE(INTEGER)*8-1))
END init;
END Bytes.
