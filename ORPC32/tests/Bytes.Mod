MODULE Bytes;
TYPE T* = RECORD a*: BYTE; b*: BYTE; r*: REAL END;
VAR value*: T; result*: INTEGER;
PROCEDURE init*;
BEGIN value.a := 255; value.b := 2;
 result := value.a+300+1;
 ASSERT(result=556); result := 7FFFFFFFH; INC(result);
 ASSERT(result=80000000H)
END init;
END Bytes.
