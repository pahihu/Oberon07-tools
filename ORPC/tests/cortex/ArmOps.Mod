MODULE ArmOps;
IMPORT SYSTEM;
CONST Three* = 3.0; Min* = 80000000H; Max* = 7FFFFFFFH;
TYPE Rec* = RECORD ch*: CHAR; value*: INTEGER; real*: REAL END;
VAR ticks*: INTEGER; realTicks*: REAL;
PROCEDURE Overflow*(x,y: INTEGER): INTEGER;
BEGIN RETURN x+y END Overflow;
PROCEDURE Interrupt [-1];
BEGIN INC(ticks); realTicks := realTicks+1.0
END Interrupt;
PROCEDURE ExternalIRQ [5];
BEGIN INC(ticks)
END ExternalIRQ;
PROCEDURE Registers*;
VAR n: INTEGER;
BEGIN n := SYSTEM.REG(13); ASSERT(n # 0);
  n := SYSTEM.REG(16); n := SYSTEM.REG(17); n := SYSTEM.REG(18);
  n := SYSTEM.REG(19); n := SYSTEM.REG(20); n := SYSTEM.REG(21);
  n := SYSTEM.REG(25); ASSERT(n = 0);
  SYSTEM.LDPSR(0); n := SYSTEM.REG(22); ASSERT(n = 1);
  SYSTEM.LDPSR(1); n := SYSTEM.REG(22); ASSERT(n = 0);
  SYSTEM.LDREG(22, 1); n := SYSTEM.REG(22); ASSERT(n = 1);
  SYSTEM.LDREG(22, 0); SYSTEM.LDREG(25, 0);
  SYSTEM.LDREG(2, n);
  n := SYSTEM.REG(0); n := SYSTEM.REG(1); n := SYSTEM.REG(2);
  n := SYSTEM.REG(3); n := SYSTEM.REG(4); n := SYSTEM.REG(5);
  n := SYSTEM.REG(6); n := SYSTEM.REG(7); n := SYSTEM.REG(8);
  n := SYSTEM.REG(9); n := SYSTEM.REG(10); n := SYSTEM.REG(11);
  n := SYSTEM.REG(12); n := SYSTEM.REG(14); n := SYSTEM.REG(15)
END Registers;
END ArmOps.
