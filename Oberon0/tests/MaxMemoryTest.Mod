MODULE MaxMemoryTest;
  IMPORT Main, MainDebug, Out, UART, SYSTEM;
  CONST StackRegister = 14; Switches = -60;
  VAR sp, stackTop, memoryTop, value: INTEGER;
BEGIN
  Out.Init(UART.PutCh);
  SYSTEM.GET(12, memoryTop); SYSTEM.GET(24, stackTop);
  ASSERT((memoryTop = 1C000H) & (Main.MemLim = memoryTop));
  ASSERT(Main.stackOrg = stackTop);
  sp := SYSTEM.REG(StackRegister);
  ASSERT((sp <= stackTop) & (sp >= stackTop - 256));
  IF SYSTEM.BIT(Switches, 0) THEN
    ASSERT(stackTop = 1C000H);
    SYSTEM.PUT(1B000H, 12345678H); SYSTEM.GET(1B000H, value);
    ASSERT(value = 12345678H)
  ELSE ASSERT(stackTop = 18000H)
  END;
  Out.String("MaxMemoryTest PASS"); Out.Ln; Main.Abort
END MaxMemoryTest.
