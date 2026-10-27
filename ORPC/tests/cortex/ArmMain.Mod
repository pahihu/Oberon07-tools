MODULE ArmMain;
IMPORT SYSTEM, A := ArmOps;
VAR n, high, spins: INTEGER; r: REAL; rec: A.Rec;
PROCEDURE LedValue ["board_led_value"](): INTEGER;
BEGIN
  ASSERT(SYSTEM.SIZE(INTEGER)=4); ASSERT(SYSTEM.SIZE(REAL)=4);
  ASSERT(SYSTEM.SIZE(A.Rec)=16); ASSERT(SYSTEM.SIZE(SET)=4);
  ASSERT((A.Min = LSL(1,31)) & (ROR(1,1)=A.Min));
  ASSERT(A.Max+1 = A.Min); ASSERT(A.Min-1 = A.Max);
  ASSERT(A.Max*2 = -2); ASSERT(-A.Min = A.Min);
  r := A.Three; rec.real := r; ASSERT(SYSTEM.VAL(INTEGER,rec.real)=40400000H);
  A.Registers;
  n := A.Overflow(-1,1); ASSERT(n=0); ASSERT(SYSTEM.COND(2));
  n := ADC(0,0); ASSERT(n=1); ASSERT(~SYSTEM.COND(2));
  n := SBC(0,0); ASSERT(n=-1); ASSERT(SYSTEM.COND(3));
  SYSTEM.LDREG(16,20000000H);
  n := SBC(0,0); ASSERT(n=0); ASSERT(SYSTEM.COND(0) & SYSTEM.COND(2));
  n := UML(-1,-1); high := SYSTEM.H(0);
  ASSERT((n=1) & (high=-2)); ASSERT(SYSTEM.COND(0));
  n := SYSTEM.H(1); ASSERT(n=60000000H);
  ASSERT(SYSTEM.COND(14) & ~SYSTEM.COND(15));
  LED(37); ASSERT(LedValue()=37);
  (* Pend SysTick. Volatile GET observes ISR writes independently of C caching. *)
  SYSTEM.LDREG(16,20000000H);
  SYSTEM.PUT(0E000ED04H,4000000H);
  spins := 0;
  REPEAT SYSTEM.GET(SYSTEM.ADR(A.ticks), n); INC(spins) UNTIL (n # 0) OR (spins=100000);
  ASSERT(n=1); ASSERT(A.realTicks=1.0);
  (* Establish a carry before a second interrupt and observe its saved/restored state.
     The polling increments above deliberately update arithmetic flags. *)
  SYSTEM.LDREG(16,20000000H);
  SYSTEM.PUT(0E000ED04H,4000000H);
  REPEAT SYSTEM.GET(SYSTEM.ADR(A.ticks), n) UNTIL n=2;
  n := ADC(0,0); ASSERT(n=1);
  LED(42)
END ArmMain.
