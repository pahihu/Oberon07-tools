MODULE SPI;

  IMPORT Texts, Oberon, SYSTEM, Sys := System, Kernel;

  CONST BufLen = 1024;
        Idle = 0; Input = 1; Output = 2; (*controller state*)
        Undef = 0FFX;
        Word = 4; Fast = 3; SPI1 = 1; SPI0 = 0; (*ctrl*)
        BitDelayFast = 3; BitDelaySlow = 29;
        Ready = 0; (*status*)
        debug = FALSE;

  TYPE
      INTEGER = Sys.INT32;
      LONGINT = Sys.INT32;
      BYTE* = CHAR;
      Slave* = POINTER TO SlaveDesc;
      Handler* = PROCEDURE(slave: Slave);
      Detector* = PROCEDURE (slave: Slave; b: BYTE);
      SlaveDesc* = RECORD
        buf: ARRAY BufLen OF BYTE;
        pos, len: INTEGER;
        state: INTEGER; (*controller state: Idle, Input, Output*)

        response: BYTE;
        ioHandle: Handler;
        detector: Detector;

        status-: SET;
        ctrl: SET;
        delayRx-: LONGINT;
        delayTx-: LONGINT;
        dataRx, dataTx: LONGINT;
      END ;

  VAR W: Texts.Writer;


  (*logging*)
  PROCEDURE Warning(s: ARRAY OF CHAR; x: LONGINT);
  BEGIN
    IF debug THEN
      Texts.WriteLn(W);
      Texts.WriteString(W, "-W-SPI: ");
      Texts.WriteString(W, s);
      Texts.Write(W, " ");
      Texts.WriteInt(W, x, 0);
      Texts.Append(Oberon.Log, W.buf)
    END
  END Warning;

  PROCEDURE Log(s: ARRAY OF CHAR; x: LONGINT);
  BEGIN
    IF debug THEN
      Texts.WriteLn(W);
      Texts.WriteString(W, "-I-SPI: ");
      Texts.WriteString(W, s);
      IF 0 <= x THEN
        Texts.Write(W, " ");
        Texts.WriteInt(W, x, 0)
      END ;
      Texts.Append(Oberon.Log, W.buf)
    END
  END Log;

  PROCEDURE ResetBuffer*(slave: Slave);
  BEGIN
    Log("ResetBuffer", slave.len);
    ASSERT(slave.pos = slave.len, 10); (*empty*)
    slave.pos := 0; slave.len := 0; slave.state := Idle
  END ResetBuffer;

  (*command handling*)

  PROCEDURE SetDetector*(slave: Slave; det: Detector; arg: INTEGER);
  BEGIN
    ASSERT(det # NIL, 10);
    Log("SetDetector", arg);
    slave.detector := det
  END SetDetector;

  PROCEDURE Recv*(slave: Slave; n: INTEGER; b: BYTE);
    VAR i: INTEGER;
  BEGIN (*prepare buf for RX*)
    ASSERT((slave.state = Idle) OR (slave.state = Input), 10);
    slave.state := Input;
    FOR i := 0 TO n - 1 DO slave.buf[slave.len] := b; INC(slave.len) END
  END Recv;

  PROCEDURE Send*(slave: Slave; b: BYTE);
  BEGIN (*prepare buf for TX*)
    ASSERT((slave.state = Idle) OR (slave.state = Output), 10);
    slave.state := Output;
    slave.buf[slave.len] := b; INC(slave.len);
  END Send;

  PROCEDURE DoNothing*(slave: Slave);
  BEGIN Log("DoNothing", -1);
    slave.state := Idle;
  END DoNothing;

  PROCEDURE DoRespond*(slave: Slave);
  BEGIN
    Log("DoRespond", ORD(slave.response));
    ResetBuffer(slave); slave.ioHandle := DoNothing;
    Send(slave, slave.response)
  END DoRespond;

  PROCEDURE Respond*(slave: Slave; b: BYTE);
  BEGIN
    slave.ioHandle := DoRespond;
    slave.response := b
  END Respond;

  PROCEDURE Get4*(slave: Slave; i: INTEGER): LONGINT;
    VAR ret: LONGINT;
  BEGIN
    ASSERT((0 <= i) & (i + 4 <= slave.len), 10);
    ret := ((ORD(slave.buf[i+3]) * 100H + ORD(slave.buf[i+2])) * 100H + ORD(slave.buf[i+1])) * 100H + ORD(slave.buf[i]);
    RETURN ret
  END Get4;

  PROCEDURE GetCommandArg*(slave: Slave; i: INTEGER): LONGINT;
    VAR ret: LONGINT;
  BEGIN
    ASSERT((0 <= i) & (i + 4 <= slave.len), 10);
    ret := ((ORD(slave.buf[i]) * 100H + ORD(slave.buf[i+1])) * 100H + ORD(slave.buf[i+2])) * 100H + ORD(slave.buf[i+3]);
    RETURN ret
  END GetCommandArg;

  PROCEDURE CalcDelay*(slave: Slave; numBits: INTEGER): LONGINT;
    VAR ret: LONGINT;
  BEGIN
    IF Fast IN slave.ctrl THEN
      ret := numBits * BitDelayFast
    ELSE
      ret := numBits * BitDelaySlow
    END ;
    RETURN ret
  END CalcDelay;

  PROCEDURE DoCommand(slave: Slave);
  BEGIN
  END DoCommand;

  PROCEDURE DetectCommand(slave: Slave; b: BYTE);
  BEGIN
    IF b # Undef THEN (*lock CMD*)
      Log("Lock CMD", ORD(b));
      ResetBuffer(slave);
      Recv(slave, 6, Undef);
      slave.ioHandle := DoCommand
    END
  END DetectCommand;

  PROCEDURE Cycle*(slave: Slave);
    VAR ret: BYTE;
        ret4: LONGINT;
        inp: BYTE;
        noBits: INTEGER;
  BEGIN
    (*ASSERT((delayRx = 0) OR (delayTx = 0), 10);*)
    (*Log("Cycle", bufState);*)
    IF Ready IN slave.status THEN
    ELSE
      (*Log("delayRx", delayRx);
      Log("delayTx", delayTx);*)
      IF slave.delayRx # 0 THEN DEC(slave.delayRx) END ;
      IF slave.delayTx # 0 THEN DEC(slave.delayTx) END ;
      inp := CHR(slave.dataRx MOD 100H);
      ret := Undef;
      noBits := 8;
      CASE slave.state OF
        Idle, Input:
          IF (slave.state = Idle) & (slave.delayRx = 0) THEN
            slave.detector(slave, inp)
          END ;
          IF slave.delayRx = 0 THEN
            INCL(slave.status, Ready);
            Log("Recv", ORD(inp));
            Log("state", slave.state);
            Log("RecvPos", slave.pos);
            Log("RecvLen", slave.len);
            IF slave.pos < slave.len THEN
              IF slave.buf[slave.pos] # Undef THEN
                IF slave.buf[slave.pos] # inp THEN Warning("input mismatch ", slave.pos); Kernel.Exit(1) END
              END ;
              slave.buf[slave.pos] := inp; INC(slave.pos)
            END ;
            IF slave.pos = slave.len THEN
              Log("Input handle BEGIN", -1);
              slave.ioHandle(slave);
              Log("Input handle END", -1);
            END
          END
        | Output:
          IF slave.delayTx = 0 THEN
            INCL(slave.status, Ready);
            Log("Send", -1);
            Log("state", slave.state);
            IF slave.pos < slave.len THEN
              Log("Send!", ORD(slave.buf[slave.pos]));
              Log("SendPos", slave.pos);
              Log("SendLen", slave.len);
              IF Word IN slave.ctrl THEN
                ret4 := Get4(slave, slave.pos); INC(slave.pos, 4); noBits := 32;
              ELSE
                ret := slave.buf[slave.pos]; INC(slave.pos)
              END
            END ;
            IF slave.pos = slave.len THEN
              Log("Output handle BEGIN", -1);
              slave.ioHandle(slave);
              Log("Output handle END", -1);
            END
          END ;
      END ; (*CASE*)
      IF slave.delayTx = 0 THEN
        IF noBits = 32 THEN
          Log("DataTx32", ret4);
          slave.dataTx := ret4;
        ELSE
          Log("DataTx8", ORD(ret));
          slave.dataTx := ORD(ret)
        END ;
        slave.delayTx := CalcDelay(slave, noBits);
      END (*CASE*)
    END (*Ready*)
  END Cycle;

  PROCEDURE WriteControl*(slave: Slave; s: SET);
    VAR x: LONGINT;
  BEGIN
    x := SYSTEM.VAL(LONGINT, s);
    (*Log("WriteControl", x);*)
    slave.ctrl := s
  END WriteControl;

  PROCEDURE WriteData*(slave: Slave; x: LONGINT);
  BEGIN
    ASSERT(Ready IN slave.status);
    Log("WriteData", x);
    slave.dataRx := x;
    slave.delayRx := CalcDelay(slave, 8);
    (*Log("delayRx", delayRx);*)
    EXCL(slave.status, Ready)
  END WriteData;

  PROCEDURE ReadData*(slave: Slave): LONGINT;
  BEGIN
    ASSERT(Ready IN slave.status);
    (*Log("ReadData", dataTx);
    Log("delayTx", delayTx);*)
    RETURN slave.dataTx
  END ReadData;

  PROCEDURE Reset*(slave: Slave);
  BEGIN slave.status := {Ready}; slave.ctrl := {};
    ResetBuffer(slave);
    slave.ioHandle := DoNothing; slave.state := Idle;
    slave.detector := NIL
  END Reset;

BEGIN Texts.OpenWriter(W)
END SPI.
(* vim:set ts=2 sw=2 et: *)
