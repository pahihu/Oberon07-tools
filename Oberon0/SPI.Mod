MODULE SPI; (*Phu 22.9.26 / generic SPI slave*)

  IMPORT Texts, Oberon, SYSTEM, Sys := System, Kernel;

  CONST
    Idle = 0; Input = 1; Output = 2; (*controller state*)
    Undef* = 0FFX;
    Word = 4; Fast = 3; SPI1* = 1; SPI0* = 0; (*ctrl*)
    BitDelayFast = 3; BitDelaySlow = 29;
    Ready = 0; (*status*)

  TYPE
    INTEGER* = Sys.INT32;
    LONGINT* = Sys.INT32;
    BYTE* = CHAR;

    Slave* = POINTER TO SlaveDesc;
    IOHandler* = PROCEDURE(slave: Slave; b: BYTE);
    SlaveDesc* = RECORD
      buf-: POINTER TO ARRAY OF BYTE;
      pos, len-: INTEGER;
      state: INTEGER; (*controller state: Idle, Input, Output*)

      response: BYTE;
      CmdFinish*: IOHandler;
      CmdStart*: IOHandler;

      status-: SET;
      ctrl-: SET;
      delayRx-: LONGINT;
      delayTx-: LONGINT;
      dataRx, dataTx: LONGINT;

      debug*: BOOLEAN;
    END ;

  VAR
    W: Texts.Writer;

  (*logging*)
  PROCEDURE (s: Slave) Warning*(msg: ARRAY OF CHAR; x: LONGINT);
  BEGIN
    IF s.debug THEN
      Texts.WriteLn(W);
      Texts.WriteString(W, "-W-SPI: ");
      Texts.WriteString(W, msg);
      Texts.Write(W, " ");
      Texts.WriteInt(W, x, 0);
      Texts.Append(Oberon.Log, W.buf)
    END
  END Warning;

  PROCEDURE (s: Slave) Log*(msg: ARRAY OF CHAR; x: LONGINT);
  BEGIN
    IF s.debug THEN
      Texts.WriteLn(W);
      Texts.WriteString(W, "-I-SPI: ");
      Texts.WriteString(W, msg);
      IF 0 <= x THEN
        Texts.Write(W, " ");
        Texts.WriteInt(W, x, 0)
      END ;
      Texts.Append(Oberon.Log, W.buf)
    END
  END Log;

  PROCEDURE (s: Slave) IsBufferEmpty*(): BOOLEAN;
  BEGIN RETURN s.pos = s.len
  END IsBufferEmpty;

  PROCEDURE (s: Slave) ResetBuffer*;
  BEGIN
    s.Log("ResetBuffer", s.len);
    ASSERT(s.IsBufferEmpty(), 10);
    s.pos := 0; s.len := 0; s.state := Idle
  END ResetBuffer;

  (*command handling*)

  PROCEDURE (s: Slave) SetCmdStart*(h: IOHandler; arg: INTEGER);
  BEGIN
    ASSERT(h # NIL, 10);
    s.Log("SetDetector", arg);
    s.CmdStart := h
  END SetCmdStart;

  PROCEDURE (s: Slave) Recv*(n: INTEGER; b: BYTE);
    VAR i: INTEGER;
  BEGIN (*prepare buf for RX*)
    ASSERT((s.state = Idle) OR (s.state = Input), 10);
    s.state := Input;
    FOR i := 0 TO n - 1 DO s.buf[s.len] := b; INC(s.len) END
  END Recv;

  PROCEDURE (s: Slave) Send*(b: BYTE);
  BEGIN (*prepare buf for TX*)
    ASSERT((s.state = Idle) OR (s.state = Output), 10);
    s.state := Output;
    s.buf[s.len] := b; INC(s.len)
  END Send;

  PROCEDURE DoNothing*(s: Slave; b: BYTE);
  BEGIN s.Log("DoNothing", -1);
    s.state := Idle;
  END DoNothing;

  PROCEDURE DoRespond*(s: Slave; b: BYTE);
  BEGIN
    s.Log("DoRespond", ORD(s.response));
    s.ResetBuffer; s.CmdFinish := DoNothing;
    s.Send(s.response)
  END DoRespond;

  PROCEDURE (s: Slave) RespondWith*(b: BYTE; h: IOHandler);
  BEGIN
    s.CmdFinish := h;
    s.response := b
  END RespondWith;

  PROCEDURE (s: Slave) Respond*(b: BYTE);
  BEGIN s.RespondWith(b, DoRespond)
  END Respond;

  PROCEDURE (s: Slave) Peek*(): BYTE;
  BEGIN
    ASSERT(s.pos < s.len, 10);
    RETURN s.buf[s.pos]
  END Peek;

  PROCEDURE (s: Slave) Append*(b: BYTE);
  BEGIN
    ASSERT((0 <= s.pos) & (s.pos < s.len), 10);
    s.buf[s.pos] := b; INC(s.pos)
  END Append;

  PROCEDURE (s: Slave) Get*(): BYTE;
    VAR ret: BYTE;
  BEGIN
    ASSERT((0 <= s.pos) & (s.pos < s.len), 10);
    ret := s.buf[s.pos]; INC(s.pos);
    RETURN ret
  END Get;

  PROCEDURE (s: Slave) Get4*(): LONGINT;
    VAR ret: LONGINT;
        i: INTEGER;
  BEGIN
    ASSERT((0 <= s.pos) & (s.pos + 3 < s.len), 10);
    i := s.pos;
    ret := ORD(s.buf[i + 3]);
    ret := ret * 100H + ORD(s.buf[i + 2]);
    ret := ret * 100H + ORD(s.buf[i + 1]);
    ret := ret * 100H + ORD(s.buf[i]);
    INC(s.pos, 4);
    RETURN ret
  END Get4;

  PROCEDURE (s: Slave) GetCommandArg*(i: INTEGER): LONGINT;
    VAR ret: LONGINT;
  BEGIN
    ASSERT((0 <= i) & (i + 3 < s.len), 10);
    ret := ORD(s.buf[i]);
    ret := ret * 100H + ORD(s.buf[i + 1]);
    ret := ret * 100H + ORD(s.buf[i + 2]);
    ret := ret * 100H + ORD(s.buf[i + 3]);
    RETURN ret
  END GetCommandArg;

  PROCEDURE (s: Slave) CalcDelay*(numBits: INTEGER): LONGINT;
    VAR scale: LONGINT;
  BEGIN
    IF Fast IN s.ctrl THEN
      scale := BitDelayFast
    ELSE
      scale := BitDelaySlow
    END ;
    RETURN numBits * scale
  END CalcDelay;

  (*examples*)
  PROCEDURE HandleCommand(s: Slave; b: BYTE);
  BEGIN
  END HandleCommand;

  PROCEDURE HandleStart(s: Slave; b: BYTE);
  BEGIN
    IF b # Undef THEN (*lock CMD*)
      s.Log("Lock CMD", ORD(b));
      s.ResetBuffer;
      s.Recv(6, Undef);
      s.CmdFinish := HandleCommand
    END
  END HandleStart;

  PROCEDURE (s: Slave) Cycle*;
    VAR ret: BYTE;
        ret4: LONGINT;
        inp, b: BYTE;
        noBits: INTEGER;
  BEGIN
    ASSERT(s.CmdStart # NIL, 10);
    (*ASSERT((delayRx = 0) OR (delayTx = 0), 10);*)
    (*s.Log("Cycle", bufState);*)
    IF ~(Ready IN s.status) THEN
      (*s.Log("delayRx", delayRx);
      s.Log("delayTx", delayTx);*)
      IF s.delayRx # 0 THEN DEC(s.delayRx) END ;
      IF s.delayTx # 0 THEN DEC(s.delayTx) END ;
      ret := Undef;
      noBits := 8;
      CASE s.state OF
        Idle, Input:
          IF s.delayRx = 0 THEN
            INCL(s.status, Ready);
            inp := CHR(s.dataRx MOD 100H);
            IF s.state = Idle THEN
              s.CmdStart(s, inp)
            END ;
            s.Log("Recv", ORD(inp));
            s.Log("state", s.state);
            s.Log("RecvPos", s.pos);
            s.Log("RecvLen", s.len);
            IF s.pos < s.len THEN
              b := s.Peek();
              IF (b # Undef) & (b # inp) THEN
                s.Warning("input mismatch ", s.pos);
                Kernel.Exit(1)
              END ;
              s.Append(inp)
            END ;
            IF s.IsBufferEmpty() THEN
              s.Log("Input handle BEGIN", -1);
              s.CmdFinish(s, Undef);
              s.Log("Input handle END", -1);
            END
          END
        | Output:
          IF s.delayTx = 0 THEN
            INCL(s.status, Ready);
            s.Log("Send", -1);
            s.Log("state", s.state);
            IF s.pos < s.len THEN
              s.Log("Send!", ORD(s.Peek()));
              s.Log("SendPos", s.pos);
              s.Log("SendLen", s.len);
              IF Word IN s.ctrl THEN
                ret4 := s.Get4(); noBits := 32
              ELSE
                ret := s.Get()
              END
            END ;
            IF s.IsBufferEmpty() THEN
              s.Log("Output handle BEGIN", -1);
              s.CmdFinish(s, Undef);
              s.Log("Output handle END", -1)
            END
          END ;
      END ; (*CASE*)
      IF s.delayTx = 0 THEN
        IF noBits = 32 THEN
          s.Log("DataTx32", ret4);
          s.dataTx := ret4;
        ELSE
          s.Log("DataTx8", ORD(ret));
          s.dataTx := ORD(ret)
        END ;
        s.delayTx := s.CalcDelay(noBits);
      END (*CASE*)
    END (*Ready*)
  END Cycle;

  PROCEDURE (s: Slave) AfterControlSet;
  BEGIN
  END AfterControlSet;

  PROCEDURE (s: Slave) WriteControl*(x: SET);
    VAR y: LONGINT;
  BEGIN
    y := SYSTEM.VAL(LONGINT, x);
    (*s.Log("WriteControl", y);*)
    s.ctrl := x;
    s.AfterControlSet
  END WriteControl;

  PROCEDURE (s: Slave) WriteData*(x: LONGINT);
  BEGIN
    ASSERT(Ready IN s.status);
    s.Log("WriteData", x);
    s.dataRx := x;
    s.delayRx := s.CalcDelay(8);
    (*s.Log("delayRx", delayRx);*)
    EXCL(s.status, Ready)
  END WriteData;

  PROCEDURE (s: Slave) ReadData*(): LONGINT;
  BEGIN
    ASSERT(Ready IN s.status);
    (*s.Log("ReadData", dataTx);
    s.Log("delayTx", delayTx);*)
    RETURN s.dataTx
  END ReadData;

  PROCEDURE (s: Slave) Reset*;
  BEGIN s.status := {Ready}; s.ctrl := {};
    s.pos := 0; s.len := 0;
    s.ResetBuffer;
    s.CmdFinish := DoNothing; s.state := Idle;
    s.CmdStart := DoNothing
  END Reset;

  PROCEDURE (s: Slave) InitBuffer*(n: INTEGER);
  BEGIN NEW(s.buf, n); s.debug := FALSE
  END InitBuffer;

  PROCEDURE (s: Slave) Debug*;
  BEGIN s.debug := TRUE
  END Debug;

  PROCEDURE BusTerminator*(): Slave;
    VAR s: Slave;
  BEGIN NEW(s); s.InitBuffer(0); RETURN s
  END BusTerminator;

BEGIN Texts.OpenWriter(W)
END SPI.
(* vim:set ts=2 sw=2 et: *)
