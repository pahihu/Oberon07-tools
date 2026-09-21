MODULE SPICtrl;

  IMPORT Files, Texts, Oberon, SYSTEM, Sys := System, Kernel;

  CONST FSoffset = 0 (*10000000H*); (*256MBytes*)
        BlockSize = 512; SectorSize = 1024;
        Idle = 0; Input = 1; Output = 2; (*controller state*)
        CMDoffset = 40H;
        CMDGoIdleState = 0X; CMDSendIfCond = 8X; CMDAppCmd = 37X; CMDSendOpCond = 29X; (*SPI commands*)
        CMDWriteSingleBlock = 18X; WriteStartData = 0FEX; CMDReadSingleBlock = 11X;
        NoError = 0X; InIdleState = 01X; Error = 80H; (*SPI response*)
        Undef = 0FFX;
        Word = 4; Fast = 3; SPI1 = 1; SPI0 = 0; (*ctrl*)
        BitDelayFast = 3; BitDelaySlow = 29; (*TODO check*)
        Ready = 0; (*status*)
        detCommand = 0; detWriteStart = 1; (*detectors*)
        debug = FALSE;

  TYPE
      INTEGER = Sys.INT32;
      LONGINT = Sys.INT32;
      BYTE = CHAR;
      Handler = PROCEDURE;
      Detector = PROCEDURE (b: BYTE);
      Block = ARRAY BlockSize OF BYTE;

  VAR R: Files.Rider;
      F: Files.File;
      maxSize: LONGINT;
      numBlocks: LONGINT;
      W: Texts.Writer;

      buf: ARRAY SectorSize OF BYTE;
      pos, len: INTEGER;
      state: INTEGER; (*controller state: Idle, Input, Output*)

      response: BYTE;
      ioHandle: Handler;
      detector: Detector; (*DetectCommand, DetectWriteStart*)
      detectors: ARRAY 2 OF Detector;

      status-: SET;
      ctrl: SET;
      delayRx-: LONGINT;
      delayTx-: LONGINT;
      dataRx, dataTx: LONGINT;

      BlockNo: LONGINT;

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

  (*raw block IO*)

  PROCEDURE ReadBlock(blkNo: LONGINT; VAR buf: Block);
  BEGIN
    Log("ReadBlock: blkNo=", blkNo);
    ASSERT((0 <= blkNo) & (blkNo < numBlocks), 10);
    Files.Set(R, F, FSoffset + blkNo * BlockSize);
    Files.ReadBytes(R, buf, BlockSize)
  END ReadBlock;

  PROCEDURE WriteBlock(blkNo: LONGINT; VAR buf: Block);
  BEGIN
    Log("WriteBlock: blkNo=", blkNo);
    (*Texts.WriteLn(W); Texts.WriteString(W, "WriteBlock@"); Texts.WriteInt(W, blkNo, 0); Texts.Append(Oberon.Log, W.buf);*)
    ASSERT((0 <= blkNo) & (blkNo < numBlocks), 10);
    Files.Set(R, F, FSoffset + blkNo * BlockSize);
    Files.WriteBytes(R, buf, BlockSize)
  END WriteBlock;

  PROCEDURE ResetBuffer;
  BEGIN
    Log("ResetBuffer", len);
    ASSERT(pos = len, 10); (*empty*)
    pos := 0; len := 0; state := Idle
  END ResetBuffer;

  (*command handling*)

  PROCEDURE SetDetector(x: INTEGER);
  BEGIN
    ASSERT((x = detCommand) OR (x = detWriteStart), 10);
    Log("SetDetector", x);
    detector := detectors[x]
  END SetDetector;

  PROCEDURE Recv(n: INTEGER; b: BYTE);
    VAR i: INTEGER;
  BEGIN (*prepare buf for RX*)
    ASSERT((state = Idle) OR (state = Input), 10);
    state := Input;
    FOR i := 0 TO n - 1 DO buf[len] := b; INC(len) END
  END Recv;

  PROCEDURE Send(b: BYTE);
  BEGIN (*prepare buf for TX*)
    ASSERT((state = Idle) OR (state = Output), 10);
    state := Output;
    buf[len] := b; INC(len);
  END Send;

  PROCEDURE DoNothing;
  BEGIN Log("DoNothing", -1);
    state := Idle;
  END DoNothing;

  PROCEDURE DoRespond;
  BEGIN
    Log("DoRespond", ORD(response));
    ResetBuffer; ioHandle := DoNothing;
    Send(response); (*EXCL(status, Ready)*)
  END DoRespond;

  PROCEDURE DoWrite;
    VAR tmp: Block;
        i: INTEGER;
  BEGIN
    Log("DoWrite", BlockNo);
    ASSERT(pos = len, 10);
    ASSERT(len = BlockSize + 3, 10); (*WriteStartData + 512xB + 2xCRC*)
    FOR i := 0 TO BlockSize - 1 DO tmp[i] := buf[i + 1] END ;
    WriteBlock(BlockNo, tmp);
    SetDetector(detCommand);
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
    ASSERT((0 <= i) & (i + 4 <= len), 10);
    ret := ((ORD(buf[i+3]) * 100H + ORD(buf[i+2])) * 100H + ORD(buf[i+1])) * 100H + ORD(buf[i]);
    RETURN ret
  END Get4;

  PROCEDURE GetCommandArg(i: INTEGER): LONGINT;
    VAR ret: LONGINT;
  BEGIN
    ASSERT((0 <= i) & (i + 4 <= len), 10);
    ret := ((ORD(buf[i]) * 100H + ORD(buf[i+1])) * 100H + ORD(buf[i+2])) * 100H + ORD(buf[i+3]);
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
    ASSERT(len = 6, 10);
    cmd := GetCommand(buf[0]); arg := GetCommandArg(1); crc := buf[5];
    Log("cmd=",ORD(cmd)); Log("arg=",arg);
    ret := Undef;
    ResetBuffer;
    detector := detectors[detCommand];
    CASE cmd OF
      CMDGoIdleState:
          Log("CMDGoIdleState", -1);
          Respond(InIdleState)
      | CMDSendIfCond:
          ASSERT(arg = 01AAH, 10);
          Log("CMDSendIfCond", -1);
          Recv(3, Undef);
          Respond(NoError)
      | CMDAppCmd:
          ASSERT(arg = 0, 10);
          Log("CMDAppCmd", -1);
          Respond(NoError)
      | CMDSendOpCond:
          ASSERT(arg = 40000000H);
          Log("CMDSendOpCond", -1);
          (*Recv(1000, Undef);*)
          Respond(NoError)
      | CMDWriteSingleBlock:
          Log("CMDWriteSingleBlock", arg);
          BlockNo := arg;
          Respond(NoError);
          SetDetector(detWriteStart)
      | CMDReadSingleBlock:
          Log("CMDReadSingleBlock", arg);
          BlockNo := arg;
          ReadBlock(BlockNo, tmp);
          Send(NoError);
          Send(CHR(0FEH));
          FOR i := 0 TO BlockSize - 1 DO Send(tmp[i]) END ;
          Send(CHR(098H)); (*dummy 'CRC'*)
          Respond(040X)
    END
  END DoCommand;

  PROCEDURE DetectCommand(b: BYTE);
  BEGIN
    IF b # Undef THEN (*lock CMD*)
      Log("Lock CMD", ORD(b));
      ResetBuffer;
      Recv(6, Undef);
      ioHandle := DoCommand
    END
  END DetectCommand;

  PROCEDURE DetectWriteStart(b: BYTE);
  BEGIN
    IF b = WriteStartData THEN
      ResetBuffer;
      Recv(1, WriteStartData); Recv(BlockSize, Undef); Recv(2, Undef);
      response := CHR(20H + 05H);
      ioHandle := DoWrite
    END ;
  END DetectWriteStart;

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
          IF (state = Idle) & (delayRx = 0) THEN
            detector(inp)
          END ;
          IF delayRx = 0 THEN
            INCL(status, Ready);
            Log("Recv", ORD(inp));
            Log("state", state);
            Log("RecvPos", pos);
            Log("RecvLen", len);
            IF pos < len THEN
              IF buf[pos] # Undef THEN
                IF buf[pos] # inp THEN Warning("input mismatch ", pos); Kernel.Exit(1) END
              END ;
              buf[pos] := inp; INC(pos)
            END ;
            IF pos = len THEN
              Log("Input handle BEGIN", -1);
              ioHandle;
              Log("Input handle END", -1);
            END
          END
        | Output:
          IF delayTx = 0 THEN
            INCL(status, Ready);
            Log("Send", -1);
            Log("state", state);
            IF pos < len THEN
              Log("Send!", ORD(buf[pos]));
              Log("SendPos", pos);
              Log("SendLen", len);
              IF Word IN ctrl THEN
                ret4 := Get4(pos); INC(pos, 4); noBits := 32;
              ELSE
                ret := buf[pos]; INC(pos)
              END
            END ;
            IF pos = len THEN
              Log("Output handle BEGIN", -1);
              ioHandle;
              Log("Output handle END", -1);
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
      END (*CASE*)
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
  BEGIN status := {Ready}; ctrl := {};
    ResetBuffer;
    ioHandle := DoNothing; state := Idle;
    SetDetector(detCommand)
  END Reset;

  PROCEDURE Open*(fname: ARRAY OF CHAR);
  BEGIN
    Log("Open", -1);
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

BEGIN Texts.OpenWriter(W);
  F := NIL;
  detectors[detCommand] := DetectCommand;
  detectors[detWriteStart] := DetectWriteStart;
  Reset
END SPICtrl.
(* vim:set ts=2 sw=2 et: *)
