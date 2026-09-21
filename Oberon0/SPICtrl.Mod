MODULE SPICtrl;

  IMPORT Files, Texts, Oberon, SYSTEM, Sys := System, Kernel;

  CONST FSoffset = 10000000H; (*256MBytes*)
        BlockSize = 512;
        Idle = 0; Input = 1; Output = 2; (*controller state*)
        CMDoffset = 40H;
        CMDGoIdleState = 0X; CMDSendIfCond = 8X; CMDAppCmd = 37X; CMDSendOpCond = 29X; (*SPI commands*)
        CMDWriteSingleBlock = 18X; WriteStartData = 0FEX; CMDReadSingleBlock = 11X;
        NoError = 0X; InIdleState = 01X; Error = 80H; (*SPI response*)
        Undef = 0FFX;
        Word = 4; Fast = 3; SPI1 = 1; SPI0 = 0; (*ctrl*)
        BitDelayFast = 3; BitDelaySlow = 29; (*TODO check*)
        Ready = 0; (*status*)

  TYPE
      INTEGER = Sys.INT32;
      LONGINT = Sys.INT32;
      BYTE = CHAR;
      Handler = PROCEDURE;
      Block = ARRAY BlockSize OF BYTE;
      Buffer = RECORD
        pos, len: INTEGER;
        data: ARRAY 2 * BlockSize OF BYTE;
      END ;

  VAR R: Files.Rider;
      F: Files.File;
      maxSize: LONGINT;
      numBlocks: LONGINT;
      W: Texts.Writer;

      sendBuf: Buffer;
      recvBuf: Buffer;
      state: INTEGER; (*controller state: Idle, Input, Output*)

      response: BYTE;
      ioHandle: Handler;

      status-: SET;
      ctrl: SET;
      delayRx-: LONGINT;
      delayTx-: LONGINT;
      dataRx, dataTx: LONGINT;

      BlockNo: LONGINT;

  (*logging*)
  PROCEDURE Warning(s: ARRAY OF CHAR; x: LONGINT);
  BEGIN
    Texts.WriteLn(W);
    Texts.WriteString(W, "-W-SPI: ");
    Texts.WriteString(W, s);
    Texts.Write(W, " ");
    Texts.WriteInt(W, x, 0);
    Texts.Append(Oberon.Log, W.buf)
  END Warning;

  PROCEDURE Log(s: ARRAY OF CHAR; x: LONGINT);
  BEGIN
    Texts.WriteLn(W);
    Texts.WriteString(W, "-I-SPI: ");
    Texts.WriteString(W, s);
    Texts.Write(W, " ");
    Texts.WriteInt(W, x, 0);
    Texts.Append(Oberon.Log, W.buf)
  END Log;

  (*raw block IO*)

  PROCEDURE ReadBlock(blkNo: LONGINT; VAR buf: Block);
  BEGIN
    ASSERT((0 <= blkNo) & (blkNo < numBlocks), 10);
    Log("ReadBlock: blkNo=", blkNo);
    Files.Set(R, F, FSoffset + blkNo * BlockSize);
    Files.ReadBytes(R, buf, BlockSize)
  END ReadBlock;

  PROCEDURE WriteBlock(blkNo: LONGINT; VAR buf: Block);
  BEGIN
    ASSERT(blkNo < numBlocks, 10);
    Log("WriteBlock: blkNo=", blkNo);
    Files.Set(R, F, FSoffset + blkNo * BlockSize);
    Files.WriteBytes(R, buf, BlockSize)
  END WriteBlock;

  (*command handling*)

  PROCEDURE Recv(n: INTEGER; b: BYTE);
    VAR i: INTEGER;
  BEGIN (*prepare buf for RX*)
    ASSERT((state = Idle) OR (state = Input), 10);
    state := Input;
    FOR i := 0 TO n - 1 DO recvBuf.data[recvBuf.len] := b; INC(recvBuf.len) END
  END Recv;

  PROCEDURE Send(b: BYTE);
  BEGIN (*prepare buf for TX*)
    ASSERT((state = Idle) OR (state = Output), 10);
    state := Output;
    sendBuf.data[sendBuf.len] := b; INC(sendBuf.len);
  END Send;

  PROCEDURE DoNothing;
  BEGIN Log("DoNothing", 0);
    (*state := Idle;*)
  END DoNothing;

  PROCEDURE ResetBuffer(VAR buf: Buffer);
  BEGIN
    Log("ResetBuffer", buf.len);
    buf.pos := 0; buf.len := 0
  END ResetBuffer;

  PROCEDURE ResetSendBuffer;
  BEGIN
    Log("ResetSendBuffer", sendBuf.len);
    ResetBuffer(sendBuf)
  END ResetSendBuffer;

  PROCEDURE ResetRecvBuffer;
  BEGIN
    Log("ResetRecvBuffer", recvBuf.len);
    ResetBuffer(recvBuf)
  END ResetRecvBuffer;

  PROCEDURE ResetSendThenIdle;
  BEGIN
    Log("ResetSendThenIdle", 0);
    ResetSendBuffer;
    state := Idle
  END ResetSendThenIdle;

  PROCEDURE DoRespond;
  BEGIN
    Log("DoRespond", ORD(response));
    ResetSendBuffer; ioHandle := ResetSendThenIdle;
    Send(response); EXCL(status, Ready)
  END DoRespond;

  PROCEDURE DoWrite;
    VAR tmp: Block;
        i: INTEGER;
  BEGIN
    Log("DoWrite", BlockNo);
    FOR i := 0 TO BlockSize - 1 DO tmp[i] := recvBuf.data[i] END ;
    WriteBlock(BlockNo, tmp);
    (*this triggers to send the response*)
    DoRespond
  END DoWrite;

  PROCEDURE Respond(b: BYTE);
  BEGIN
    ioHandle := DoRespond;
    response := b
  END Respond;

  PROCEDURE Get4(i: INTEGER): LONGINT;
    VAR ret: LONGINT;
  BEGIN
    ASSERT((0 <= i) & (i + 4 <= recvBuf.len), 10);
    ret := (((ORD(recvBuf.data[i+3]) * 100H) + ORD(recvBuf.data[i+2])) * 100H + ORD(recvBuf.data[i+1])) * 100H + ORD(recvBuf.data[i]);
    RETURN ret
  END Get4;

  PROCEDURE GetCommandArg(i: INTEGER): LONGINT;
    VAR ret: LONGINT;
  BEGIN
    ASSERT((0 <= i) & (i + 4 <= recvBuf.len), 10);
    ret := (((ORD(recvBuf.data[i]) * 100H) + ORD(recvBuf.data[i+1])) * 100H + ORD(recvBuf.data[i+2])) * 100H + ORD(recvBuf.data[i+3]);
    RETURN ret
  END GetCommandArg;

  PROCEDURE CalcDelay(numBits: INTEGER): LONGINT;
    VAR ret: LONGINT;
  BEGIN
    IF Fast IN ctrl THEN
      ret := numBits * BitDelayFast
    ELSE
      ret := numBits * BitDelaySlow
    END ;
    RETURN ret
  END CalcDelay;

  PROCEDURE GetCommand(b: BYTE): BYTE;
  BEGIN RETURN CHR(ORD(b) - CMDoffset)
  END GetCommand;

  PROCEDURE DoCommand;
    VAR tmp: Block;
        cmd, crc: BYTE;
        arg: LONGINT;
        ret: BYTE;
        i: INTEGER;
  BEGIN
    cmd := GetCommand(recvBuf.data[0]); arg := GetCommandArg(1); crc := recvBuf.data[5];
    Log("cmd=",ORD(cmd)); Log("arg=",arg);
    ret := Undef;
    ResetRecvBuffer;
    CASE cmd OF
      CMDGoIdleState:
        Log("CMDGoIdleState", 0);
        Respond(InIdleState) |
      CMDSendIfCond:
        ASSERT(arg = 01AAH, 10);
        Log("CMDSendIfCond", 0);
        Recv(3, Undef);
        Respond(NoError) |
      CMDAppCmd:
        ASSERT(arg = 0, 10);
        Log("CMDAppCmd", 0);
        Respond(NoError) |
      CMDSendOpCond:
        ASSERT(arg = 40000000H);
        Log("CMDSendOpCond", 0);
        Recv(1000, Undef);
        Respond(NoError) |
      CMDWriteSingleBlock:
        Log("CMDWriteSingleBlock", arg);
        BlockNo := arg;
        Recv(1, WriteStartData);
        Recv(256, Undef); Recv(2, Undef);
        response := CHR(20H + 05H);
        ioHandle := DoWrite |
      CMDReadSingleBlock:
        Log("CMDReadSingleBlock", arg);
        BlockNo := arg;
        ReadBlock(BlockNo, tmp);
        Send(CHR(0FEH));
        FOR i := 0 TO 255 DO Send(tmp[i]) END ;
        Send(CHR(098H)); Send(CHR(040H)); (*dummy 'CRC'*)
    END
  END DoCommand;

  PROCEDURE Cycle*;
    VAR ret: BYTE;
        ret4: LONGINT;
        inp: BYTE;
        noBits: INTEGER;
  BEGIN
    (*ASSERT((delayRx = 0) OR (delayTx = 0), 10);*)
    (*Log("Cycle", bufState);*)
    IF Ready IN status THEN
    ELSE
      (*Log("delayRx", delayRx);
      Log("delayTx", delayTx);*)
      IF delayRx # 0 THEN DEC(delayRx) END ;
      IF delayTx # 0 THEN DEC(delayTx) END ;
      inp := CHR(dataRx MOD 100H);
      ret := Undef;
      noBits := 8;
    CASE state OF
    Idle, Input:
      IF state = Idle THEN
        IF delayRx = 0 THEN
          IF inp # Undef THEN (*lock CMD*)
            Log("Lock CMD", ORD(inp));
            ASSERT(recvBuf.pos = 0, 30);
            Recv(6, Undef);
            ioHandle := DoCommand
          END
        END
      END ;
      IF delayRx = 0 THEN
        INCL(status, Ready);
        Log("Recv", ORD(inp));
        Log("state", state);
        (*Log("RecvPos", recvBuf.pos);
        Log("RecvLen", recvBuf.len);*)
        IF recvBuf.pos < recvBuf.len THEN
          IF recvBuf.data[recvBuf.pos] # Undef THEN
            IF recvBuf.data[recvBuf.pos] # inp THEN Warning("input mismatch ", recvBuf.pos); Kernel.Exit(1) END
          END ;
          recvBuf.data[recvBuf.pos] := inp; INC(recvBuf.pos)
        ELSE
          Log("IO handle BEGIN", 0);
          ioHandle;
          Log("IO handle END", 0);
        END
      END
    | Output:
      IF delayTx = 0 THEN
        INCL(status, Ready);
        Log("Send", ORD(sendBuf.data[sendBuf.pos]));
        Log("state", state);
        IF sendBuf.pos < sendBuf.len THEN
          IF Word IN ctrl THEN
            ret4 := Get4(sendBuf.pos); INC(sendBuf.pos, 4); noBits := 32;
          ELSE
            ret := sendBuf.data[sendBuf.pos]; INC(sendBuf.pos);
          END
        ELSE
          Log("IO handle BEGIN", 0);
          ioHandle;
          Log("IO handle END", 0);
        END
      END ;
    END ; (*CASE*)
    IF delayTx = 0 THEN
      IF noBits = 32 THEN
        Log("DataTx32", ret4);
        dataTx := ret4;
      ELSE
        Log("DataTx8", ORD(ret));
        dataTx := ORD(ret)
      END ;
      delayTx := CalcDelay(noBits);
    END
    END (*Ready*)
  END Cycle;

  PROCEDURE WriteControl*(s: SET);
    VAR x: LONGINT;
  BEGIN
    x := SYSTEM.VAL(LONGINT, s);
    (*Log("WriteControl", x);*)
    ctrl := s
  END WriteControl;

  PROCEDURE WriteData*(x: LONGINT);
  BEGIN
    ASSERT(Ready IN status);
    Log("WriteData", x);
    dataRx := x;
    delayRx := CalcDelay(8);
    Log("delayRx", delayRx);
    EXCL(status, Ready)
  END WriteData;

  PROCEDURE ReadData*(): LONGINT;
  BEGIN
    ASSERT(Ready IN status);
    (*Log("ReadData", dataTx);
    Log("delayTx", delayTx);*)
    RETURN dataTx
  END ReadData;

  PROCEDURE Reset*;
  BEGIN status := {Ready}; ctrl := {};
    ResetSendBuffer;
    ResetRecvBuffer;
    ioHandle := DoNothing; state := Idle
  END Reset;

  PROCEDURE Open*(fname: ARRAY OF CHAR);
  BEGIN
    Log("Open", 0);
    F := Files.Old(fname);
    maxSize := Sys.Short(Files.Length(F));
    Log("maxSize", maxSize);
    ASSERT(maxSize MOD BlockSize = 0, 30);
    numBlocks := maxSize DIV BlockSize;
    Log("numBlocks", numBlocks);
    Files.Set(R, F, 0)
  END Open;

  PROCEDURE Close*;
  BEGIN IF F # NIL THEN Files.Close(F) END
  END Close;

BEGIN Texts.OpenWriter(W); Reset; F := NIL
END SPICtrl.
(* vim:set ts=2 sw=2 et: *)
