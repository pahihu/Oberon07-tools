MODULE TCPNet;
  (*Host-side ESP-AT emulator, distinct from the guest TCPNet module.
    All protocol buffers are static. Only TCPSockets touches the host network.*)
  IMPORT TCPSockets, Sys := System;
  CONST Links = 5; QueueSize = 8192; Reserve = 1024; SendSize = 1460;
  VAR
    rx: ARRAY QueueSize OF CHAR;
    head, count: INTEGER;
    command: ARRAY 512 OF CHAR;
    length, pos: INTEGER;
    echo, joined, discard, ipInfo: BOOLEAN;
    connected, udp: ARRAY Links OF BOOLEAN;
    (*C arguments use CType's platform mapping; results stay native LONGINT.*)
    opening, sending, wanted, collected, sent: Sys.INT32;
    payload: ARRAY SendSize OF CHAR;
    received: ARRAY SendSize OF CHAR;
    peer: ARRAY 6 OF CHAR;
    sendHost: ARRAY 256 OF CHAR;
    sendPort: Sys.INT32;

  PROCEDURE Put(ch: CHAR);
  BEGIN
    ASSERT(count < QueueSize);
    rx[(head + count) MOD QueueSize] := ch; INC(count)
  END Put;

  PROCEDURE Text(s: ARRAY OF CHAR);
    VAR i: INTEGER;
  BEGIN i := 0;
    WHILE (i < LEN(s)) & (s[i] # 0X) DO Put(s[i]); INC(i) END
  END Text;

  PROCEDURE Number(n: LONGINT);
    VAR a: ARRAY 12 OF CHAR; i: INTEGER;
  BEGIN i := 0;
    REPEAT a[i] := CHR(n MOD 10 + 30H); n := n DIV 10; INC(i) UNTIL n = 0;
    WHILE i > 0 DO DEC(i); Put(a[i]) END
  END Number;

  PROCEDURE Line(s: ARRAY OF CHAR);
  BEGIN Text(s); Put(0DX); Put(0AX)
  END Line;

  PROCEDURE Reply(ok: BOOLEAN);
  BEGIN
    Put(0DX); Put(0AX);
    IF ok THEN Line("OK") ELSE Line("ERROR") END
  END Reply;

  PROCEDURE Event(id: LONGINT; s: ARRAY OF CHAR);
  BEGIN Put(0DX); Put(0AX); Number(id); Put(","); Line(s)
  END Event;

  PROCEDURE Skip;
  BEGIN WHILE (pos < length) & (command[pos] = " ") DO INC(pos) END
  END Skip;

  PROCEDURE Match(s: ARRAY OF CHAR): BOOLEAN;
    VAR i: INTEGER; ok: BOOLEAN;
  BEGIN i := 0; ok := TRUE;
    WHILE (i < LEN(s)) & (s[i] # 0X) & ok DO
      ok := (pos < length) & (command[pos] = s[i]);
      IF ok THEN INC(pos); INC(i) END
    END;
    RETURN ok
  END Match;

  PROCEDURE Decimal(VAR n: Sys.INT32): BOOLEAN;
    VAR start: INTEGER; ok: BOOLEAN;
  BEGIN Skip; start := pos; n := 0; ok := TRUE;
    WHILE (pos < length) & (command[pos] >= "0") & (command[pos] <= "9") & ok DO
      IF n > 6553 THEN ok := FALSE
      ELSE n := n * 10 + ORD(command[pos]) - 30H; INC(pos)
      END
    END;
    RETURN ok & (pos > start) & (n <= 65535)
  END Decimal;

  PROCEDURE Comma(): BOOLEAN;
  BEGIN Skip; RETURN Match(",")
  END Comma;

  PROCEDURE Quoted(VAR s: ARRAY OF CHAR): BOOLEAN;
    VAR n: INTEGER; ok, closed: BOOLEAN; ch: CHAR;
  BEGIN Skip; n := 0; closed := FALSE; ok := Match('"');
    WHILE ok & ~closed & (pos < length) DO
      ch := command[pos]; INC(pos);
      IF ch = '"' THEN closed := TRUE
      ELSE
        IF ch = 5CX THEN
          IF pos < length THEN ch := command[pos]; INC(pos) ELSE ok := FALSE END
        END;
        IF ok & (ch >= 20X) & (n < LEN(s) - 1) THEN s[n] := ch; INC(n)
        ELSE ok := FALSE END
      END
    END;
    s[n] := 0X;
    RETURN ok & closed
  END Quoted;

  PROCEDURE End(): BOOLEAN;
  BEGIN Skip; RETURN pos = length
  END End;

  PROCEDURE Close*;
    VAR i: INTEGER;
  BEGIN
    TCPSockets.CloseAll;
    FOR i := 0 TO Links - 1 DO connected[i] := FALSE; udp[i] := FALSE END;
    opening := -1; sending := -1; wanted := 0; collected := 0; sent := 0
  END Close;

  PROCEDURE Reset*;
  BEGIN
    Close; head := 0; count := 0; length := 0; pos := 0;
    echo := TRUE; joined := TRUE; discard := FALSE; ipInfo := FALSE
  END Reset;

  PROCEDURE Execute;
    VAR id, port, n, local, udpMode: Sys.INT32; result, i: LONGINT;
        host, mode: ARRAY 256 OF CHAR;
        password: ARRAY 256 OF CHAR;
        ok: BOOLEAN;
  BEGIN
    command[length] := 0X;
    IF echo THEN Text(command); Put(0DX); Put(0AX) END;
    pos := 0;
    IF (command = "AT") OR (command = "ATE0") OR (command = "ATE1") THEN
      IF command = "ATE0" THEN echo := FALSE
      ELSIF command = "ATE1" THEN echo := TRUE END;
      Reply(TRUE)
    ELSIF (command = "AT+CIPDINFO=0") OR (command = "AT+CIPDINFO=1") THEN
      ipInfo := command = "AT+CIPDINFO=1"; Reply(TRUE)
    ELSIF (command = "AT+CWMODE=1") OR (command = "AT+CIPMODE=0") OR
          (command = "AT+CIPMUX=1") OR
          (command = "AT+CIPRECVMODE=0") THEN Reply(TRUE)
    ELSIF command = "AT+RST" THEN Reset; Reply(TRUE); Line("ready")
    ELSIF command = "AT+CWQAP" THEN
      FOR i := 0 TO Links - 1 DO
        IF connected[i] THEN Event(i, "CLOSED") END
      END;
      Close; joined := FALSE; Line("WIFI DISCONNECT"); Reply(TRUE)
    ELSIF Match("AT+CWJAP=") THEN
      ok := Quoted(host) & Comma() & Quoted(password) & End();
      IF ok THEN joined := TRUE; Line("WIFI CONNECTED"); Line("WIFI GOT IP") END;
      Reply(ok)
    ELSE
      pos := 0;
      IF Match("AT+CIPSTART=") THEN
        ok := Decimal(id) & Comma() & Quoted(mode) & Comma() &
              Quoted(host) & Comma() & Decimal(port);
        ok := ok & (id >= 0) & (id < Links) & (port > 0) & joined;
        IF ok THEN ok := ~connected[id] END;
        IF ok & (mode = "UDP") THEN
          local := 0; udpMode := 0;
          IF ~End() THEN
            ok := Comma() & Decimal(local);
            IF ok & ~End() THEN ok := Comma() & Decimal(udpMode) END
          END;
          ok := ok & End();
          IF ok THEN ok := TCPSockets.UDPStart(id, host, port, local, udpMode) = 0 END;
          IF ok THEN udp[id] := TRUE; connected[id] := TRUE; Event(id, "CONNECT") END;
          Reply(ok)
        ELSIF ok & (mode = "TCP") & End() THEN
          result := TCPSockets.Start(id, host, port);
          IF result = 0 THEN opening := id; udp[id] := FALSE ELSE Reply(FALSE) END
        ELSE Reply(FALSE) END
      ELSE
        pos := 0;
        IF Match("AT+CIPSEND=") THEN
          ok := Decimal(id) & Comma() & Decimal(n);
          ok := ok & (id >= 0) & (id < Links) & (n > 0) & (n <= SendSize);
          sendHost[0] := 0X; sendPort := 0;
          IF ok THEN ok := connected[id] END;
          IF ok & ~End() THEN
            ok := udp[id] & Comma() & Quoted(sendHost) & (sendHost[0] # 0X) &
                  Comma() & Decimal(sendPort) & (sendPort > 0) & End()
          END;
          IF ok THEN
            sending := id; wanted := n; collected := 0; sent := 0;
            Reply(TRUE); Text("> ")
          ELSE Reply(FALSE) END
        ELSE
          pos := 0;
          IF Match("AT+CIPCLOSE=") THEN
            ok := Decimal(id) & End() & (id >= 0) & (id < Links);
            IF ok THEN ok := connected[id] END;
            IF ok THEN
              TCPSockets.Close(id); connected[id] := FALSE;
              Event(id, "CLOSED")
            END;
            Reply(ok)
          ELSE Reply(FALSE) END
        END
      END
    END;
    length := 0
  END Execute;

  PROCEDURE Cycle*;
    VAR id, n, i: Sys.INT32; senderPort: LONGINT;
  BEGIN
    IF QueueSize - count >= Reserve THEN
      IF opening >= 0 THEN
        n := TCPSockets.Poll(opening);
        IF n # 0 THEN
          IF n = 1 THEN
            connected[opening] := TRUE; Event(opening, "CONNECT"); Reply(TRUE)
          ELSE TCPSockets.Close(opening); Reply(FALSE) END;
          opening := -1
        END
      END;
      IF (sending >= 0) & (collected = wanted) THEN
        IF connected[sending] THEN
          IF udp[sending] THEN
            n := TCPSockets.UDPSend(sending, payload, wanted, sendHost, sendPort);
            IF n # 0 THEN
              IF n > 0 THEN Line("SEND OK") ELSE Line("SEND FAIL") END;
              sending := -1
            END
          ELSE
            n := TCPSockets.Send(sending, payload, sent, wanted - sent);
            IF n >= 0 THEN
              INC(sent, n);
              IF sent = wanted THEN Line("SEND OK"); sending := -1 END
            ELSE
              TCPSockets.Close(sending); connected[sending] := FALSE;
              Event(sending, "CLOSED"); Line("SEND FAIL"); sending := -1
            END
          END
        ELSE Line("SEND FAIL"); sending := -1 END
      END
    END;
    FOR id := 0 TO Links - 1 DO
      IF connected[id] THEN
        (*-2 idle, -1 socket failure, 0 a valid empty UDP datagram.*)
        n := -2;
        IF udp[id] THEN
          IF QueueSize - count >= SendSize + 64 THEN
            n := TCPSockets.UDPReceive(id, received, peer);
            IF n = 0 THEN n := -2 ELSIF n > 0 THEN DEC(n) END
          END
        ELSIF QueueSize - count >= Reserve THEN
          n := TCPSockets.Receive(id, received, 512);
          IF n = 0 THEN n := -2 END
        END;
        IF n >= 0 THEN
          Put(0DX); Put(0AX); Text("+IPD,"); Number(id); Put(","); Number(n);
          IF udp[id] & ipInfo THEN
            Text(',"');
            FOR i := 0 TO 3 DO
              IF i > 0 THEN Put(".") END;
              Number(ORD(peer[i]))
            END;
            senderPort := ORD(peer[4]);
            Text('",'); Number(senderPort * 256 + ORD(peer[5]))
          END;
          Put(":");
          FOR i := 0 TO n - 1 DO Put(received[i]) END
        ELSIF n = -1 THEN
          TCPSockets.Close(id); connected[id] := FALSE; Event(id, "CLOSED")
        END
      END
    END
  END Cycle;

  PROCEDURE Status*(): INTEGER;
    VAR status: INTEGER;
  BEGIN Cycle; status := 0;
    IF count > 0 THEN INC(status) END;
    IF (QueueSize - count >= Reserve) & (opening < 0) &
        ((sending < 0) OR (collected < wanted)) THEN INC(status, 2) END;
    RETURN status
  END Status;

  PROCEDURE Read*(): INTEGER;
    VAR b: INTEGER;
  BEGIN Cycle; b := 0;
    IF count > 0 THEN b := ORD(rx[head]); head := (head + 1) MOD QueueSize; DEC(count) END;
    RETURN b
  END Read;

  PROCEDURE Write*(b: LONGINT): BOOLEAN;
    VAR ready: BOOLEAN; ch: CHAR;
  BEGIN ready := ODD(Status() DIV 2);
    IF ready THEN
      ch := CHR(b MOD 100H);
      IF sending >= 0 THEN
        payload[collected] := ch; INC(collected)
      ELSIF ch = 0AX THEN
        IF discard THEN Reply(FALSE); discard := FALSE; length := 0
        ELSE
          IF (length > 0) & (command[length - 1] = 0DX) THEN DEC(length) END;
          Execute
        END
      ELSIF ~discard THEN
        IF (ch < 20X) & (ch # 0DX) THEN discard := TRUE
        ELSIF length < LEN(command) - 1 THEN command[length] := ch; INC(length)
        ELSE discard := TRUE END
      END
    END;
    RETURN ready
  END Write;

BEGIN Reset
END TCPNet.
