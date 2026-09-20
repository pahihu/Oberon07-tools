MODULE SPICtrl;

  IMPORT Files, Texts, Oberon, SYSTEM;

  CONST FSoffset = 10000000H; (*256MBytes*)
        BlockSize = 512;
        Idle = 0; Input = 1; Output = 2; (*buffer state*)
        CMDoffset = 40H;
        CMDGoIdleState = 0X; CMDSendIfCond = 8X; CMDAppCmd = 37X; CMDSendOpCond = 29X; (*SPI commands*)
        CMDWriteSingleBlock = 18X; CMDWriteStartData = 0FEX; CMDReadSingleBlock = 11X;
        NoError = 0X; InIdleState = 01X; Error = 80H; (*SPI response*)
        Undef = 0FFX;
        Word = 4; Fast = 3; SPI1 = 1; SPI0 = 0; (*ctrl*)
        BitDelayFast = 3; BitDelaySlow = 29; (*TODO check*)
        Ready = 0; (*status*)

  TYPE
      Handler = PROCEDURE;
      BYTE = CHAR;
      Block = ARRAY BlockSize OF BYTE;

  VAR R: Files.Rider;
      F: Files.File;
      maxSize: LONGINT;
      numBlocks: LONGINT;
      W: Texts.Writer;

      bufState: INTEGER;
      buf: ARRAY 2 * BlockSize OF BYTE;
      bufLen: INTEGER;
      pos: INTEGER;
      response: BYTE;
      hasResponse: BOOLEAN;
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

  PROCEDURE DoWrite;
    VAR tmp: Block;
        i: INTEGER;
  BEGIN
    FOR i := 0 TO BlockSize - 1 DO tmp[i] := buf[i] END ;
    WriteBlock(BlockNo, tmp);
  END DoWrite;

  PROCEDURE DoNothing;
  BEGIN
  END DoNothing;

  PROCEDURE ResetBuffer*;
  BEGIN
    pos := 0; bufLen := 0;
    response := Undef; hasResponse := FALSE;
    bufState := Idle;
    (*delayRx := 0;
    delayTx := 0*)
  END ResetBuffer;

  PROCEDURE Recv(n: INTEGER; b: BYTE);
    VAR i: INTEGER;
  BEGIN (*prepare buf for RX*)
    ASSERT((bufState = Idle) OR (bufState = Input));
    bufState := Input;
    FOR i := 0 TO n - 1 DO buf[bufLen] := b; INC(bufLen) END
  END Recv;

  PROCEDURE Send(b: BYTE);
  BEGIN (*prepare buf for TX*)
    ASSERT((bufState = Idle) OR (bufState = Output), 10);
    bufState := Output;
    buf[bufLen] := b; INC(bufLen);
  END Send;

  PROCEDURE Respond(b: BYTE);
  BEGIN response := b; hasResponse := TRUE
  END Respond;

  PROCEDURE Get4(i: INTEGER): LONGINT;
    VAR ret: LONGINT;
  BEGIN
    ASSERT((0 <= i) & (i + 4 <= bufLen), 10);
    ret := (((ORD(buf[i+3]) * 100H) + ORD(buf[i+2])) * 100H + ORD(buf[i+1])) * 100H + ORD(buf[i]);
    RETURN ret
  END Get4;

  PROCEDURE GetCommandArg(i: INTEGER): LONGINT;
    VAR ret: LONGINT;
  BEGIN
    ASSERT((0 <= i) & (i + 4 <= bufLen), 10);
    ret := (((ORD(buf[i]) * 100H) + ORD(buf[i+1])) * 100H + ORD(buf[i+2])) * 100H + ORD(buf[i+3]);
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
    cmd := GetCommand(buf[0]); arg := GetCommandArg(1); crc := buf[5];
    Log("cmd=",ORD(cmd)); Log("arg=",arg);
    ret := Undef;
    ResetBuffer;
    CASE cmd OF
      CMDGoIdleState:
        Log("CMDGoIdleState", 0);
        bufState := Idle;
        Respond(InIdleState) |
      CMDSendIfCond:
        ASSERT(arg = 01AAH, 10);
        Log("CMDSendIfCond", 0);
        Recv(3, Undef);
        Respond(NoError);
        ioHandle := DoNothing |
      CMDAppCmd:
        ASSERT(arg = 0, 10);
        Log("CMDAppCmd", 0);
        Respond(NoError) |
      CMDSendOpCond:
        ASSERT(arg = 40000000H);
        Log("CMDSendOpCond", 0);
        Recv(1000, Undef);
        Respond(NoError);
        ioHandle := DoNothing |
      CMDWriteSingleBlock:
        Log("CMDWriteSingleBlock", arg);
        BlockNo := arg |
      CMDWriteStartData:
        Log("CMDWriteStartData", 0);
        Recv(256, Undef); Recv(2, Undef);
        Respond(CHR(20H + 05H));
        ioHandle := DoWrite |
      CMDReadSingleBlock:
        Log("CMDReadSingleBlock", arg);
        BlockNo := arg;
        ReadBlock(BlockNo, tmp);
        Send(CHR(0FEH));
        FOR i := 0 TO 255 DO Send(tmp[i]) END ;
        Send(CHR(098H)); Send(CHR(040H)); (*dummy 'CRC'*)
    END ;
    (*dataTx := ORD(ret); delayTx := CalcDelay(8)*)
  END DoCommand;

  PROCEDURE Cycle*;
    VAR ret: BYTE;
        ret4: LONGINT;
        inp: BYTE;
        done: BOOLEAN;
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
      CASE bufState OF
        Idle, Input:
          IF delayRx = 0 THEN
            INCL(status, Ready);
            (*Log("Recv", ORD(inp));
            Log("bufState", bufState);*)
            IF bufState = Idle THEN
              IF inp # Undef THEN (*lock CMD*)
                Recv(6, Undef);
                ioHandle := DoCommand;
                bufState := Input
              END
            END ;
            IF pos < bufLen THEN
              IF buf[pos] # Undef THEN
                IF buf[pos] # inp THEN Warning("input mismatch ", pos) END
              END ;
              buf[pos] := inp; INC(pos)
            ELSIF bufLen # 0 THEN
              done := TRUE
            END
          END |
        Output:
          IF delayTx = 0 THEN
            INCL(status, Ready);
            (*Log("bufState", bufState);*)
            IF pos < bufLen THEN
              IF Word IN ctrl THEN
                ret4 := Get4(pos); INC(pos, 4); delayTx := CalcDelay(32)
              ELSE
                ret := buf[pos]; INC(pos); delayTx := CalcDelay(8)
              END
            ELSIF bufLen # 0 THEN
              done := TRUE
            END
          END
      END ; (*CASE bufState*)
      IF done THEN
        ioHandle;
        IF hasResponse THEN ret := response END ;
        ResetBuffer;
        Log("IO done, response", ORD(ret))
      END ;
      IF delayTx = 0 THEN
        IF Word IN ctrl THEN
          (*Log("DataTx32", ret4);*)
          dataTx := ret4
        ELSE
          (*Log("DataTx8", ORD(ret));*)
          dataTx := ORD(ret)
        END
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
    (*Log("WriteData", x);*)
    dataRx := x;
    delayRx := CalcDelay(8);
    (*Log("delayRx", delayRx);*)
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
  BEGIN status := {Ready}; ctrl := {}; ResetBuffer;
  END Reset;

  PROCEDURE Open*(fname: ARRAY OF CHAR);
  BEGIN
    Log("Open", 0);
    F := Files.Old(fname);
    maxSize := Files.Length(F);
    Log("maxSize", maxSize);
    ASSERT(maxSize MOD BlockSize = 0, 30);
    numBlocks := maxSize DIV BlockSize;
    Log("numBlocks", numBlocks);
    Files.Set(R, F, 0)
  END Open;

BEGIN Texts.OpenWriter(W); Reset
END SPICtrl.
(* vim:set ts=2 sw=2 et: *)
