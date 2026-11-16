MODULE TCPHostTest;
  (*Test bridge: stdin/stdout expose the simulated second UART, without CPU.*)
  IMPORT TCPNet, ConsoleIO;
  VAR pending, b, result: INTEGER; accepted: BOOLEAN;
BEGIN
  TCPNet.Reset; result := ConsoleIO.Open(); pending := -1;
  LOOP
    IF pending < 0 THEN pending := ConsoleIO.Read() END;
    IF pending >= 0 THEN
      accepted := TCPNet.Write(pending);
      IF accepted THEN pending := -1 END
    END;
    WHILE ODD(TCPNet.Status()) DO
      b := TCPNet.Read();
      REPEAT result := ConsoleIO.Write(b) UNTIL result # 0
    END
  END
END TCPHostTest.
