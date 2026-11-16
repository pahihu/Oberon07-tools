MODULE TCPMMIOTest;
  IMPORT SYSTEM, Main, MainDebug, O := COberon, TCPNet, Out;
  VAR ticks, port: INTEGER;
    data, reply: ARRAY 256 OF BYTE;

  PROCEDURE Tick;
  BEGIN INC(ticks)
  END Tick;

  PROCEDURE Check;
    VAR c: TCPNet.Connection;
      i, n, total, before: INTEGER;
  BEGIN
    ASSERT(TCPNet.Init(5000) = TCPNet.OK);
    ASSERT(TCPNet.Join("virtual,ssid", "no password needed", 5000) = TCPNet.OK);
    ASSERT(TCPNet.Open("localhost", port, 15000, c) = TCPNet.OK);
    FOR i := 0 TO 255 DO data[i] := i END;
    ASSERT(TCPNet.Send(c, data, 256, 5000, n) = TCPNet.OK); ASSERT(n = 256);
    total := 0; before := ticks;
    REPEAT
      ASSERT(TCPNet.Receive(c, reply, 256, 5000, n) = TCPNet.OK);
      FOR i := 0 TO n - 1 DO ASSERT(reply[i] = data[total + i]) END;
      INC(total, n)
    UNTIL total = 256;
    ASSERT(ticks > before);
    ASSERT(TCPNet.Receive(c, reply, 256, 5000, n) = TCPNet.Closed);
    ASSERT(TCPNet.Close(c, 5000) = TCPNet.OK);
    Out.String("TCPMMIOTest PASS"); Out.Ln; Main.Abort
  END Check;
BEGIN
  SYSTEM.GET(-60, port); ticks := 0;
  O.InstallHi(O.NewTask(Tick, 1, 0));
  O.InstallLo(O.NewTask(Check, 0, 0)); O.Loop
END TCPMMIOTest.
