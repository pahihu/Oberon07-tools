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
        Fast = 4; Word = 3; SPI1 = 1; SPI0 = 0; (*ctrl*)
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
      ioHandle: Handler;

      status-: SET;
      ctrl-: SET;
      delayRx-: LONGINT;
      delayTx-: LONGINT;
      dataRx-, dataTx-: LONGINT;

      BlockNo: LONGINT;

  (*logging*)
  PROCEDURE Warning(s: ARRAY OF CHAR; x: LONGINT);
  BEGIN
    Texts.WriteLn(W);
    Texts.WriteString(W, "-W-SPI: ");
    Texts.WriteString(W, s);
    Texts.WriteInt(W, x, 0)
  END Warning;

  PROCEDURE Log(s: ARRAY OF CHAR; x: LONGINT);
  BEGIN
    Texts.WriteLn(W);
    Texts.WriteString(W, "-I-SPI: ");
    Texts.WriteString(W, s);
    Texts.WriteInt(W, x, 0)
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
    response := Undef;
    bufState := Idle;
    delayRx := 0;
    delayTx := 0
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
  BEGIN response := b
  END Respond;

  PROCEDURE Get4(i: INTEGER): LONGINT;
    VAR ret: LONGINT;
  BEGIN
    ASSERT((0 <= i) & (i + 4 <= bufLen), 10);
    ret := (((ORD(buf[i+3]) * 100H) + ORD(buf[i+2])) * 100H + ORD(buf[i+1])) * 100H + ORD(buf[i]);
    RETURN ret
  END Get4;

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
    cmd := GetCommand(buf[0]); arg := Get4(1); crc := buf[5];
    ret := Undef;
    ResetBuffer;
    CASE cmd OF
      CMDGoIdleState:
        bufState := Idle;
        ret := InIdleState; delayTx := CalcDelay(8) |
      CMDSendIfCond:
        ASSERT(arg = 01AAH, 10);
        Recv(3, Undef);
        Respond(NoError);
        ioHandle := DoNothing |
      CMDAppCmd:
        ASSERT(arg = 0, 10);
        ret := NoError; delayTx := CalcDelay(8) |
      CMDSendOpCond:
        ASSERT(arg = 40000000H);
        Recv(1000, Undef);
        Respond(NoError);
        ioHandle := DoNothing |
      CMDWriteSingleBlock:
        BlockNo := arg |
      CMDWriteStartData:
        Recv(256, Undef); Recv(2, Undef);
        Respond(CHR(20H + 05H));
        ioHandle := DoWrite |
      CMDReadSingleBlock:
        BlockNo := arg;
        ReadBlock(BlockNo, tmp);
        Send(CHR(0FEH));
        FOR i := 0 TO 255 DO Send(tmp[i]) END ;
        Send(CHR(098H)); Send(CHR(040H)); (*dummy 'CRC'*)
    END ;
    dataTx := ORD(ret); delayTx := CalcDelay(8)
  END DoCommand;

  PROCEDURE Cycle*;
    VAR ret: BYTE;
        ret4: LONGINT;
        inp: BYTE;
        done: BOOLEAN;
  BEGIN (*either send or recv*)
    ASSERT((delayRx = 0) OR (delayTx = 0), 10);
    IF Ready IN status THEN
    ELSE
      IF delayRx # 0 THEN DEC(delayRx) END ;
      IF delayTx # 0 THEN DEC(delayTx) END ;
      inp := CHR(dataRx MOD 100H);
      ret := Undef;
      CASE bufState OF
        Idle, Input:
          IF delayRx = 0 THEN
            INCL(status, Ready);
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
            ELSE
              done := TRUE
            END
          END |
        Output:
          IF delayTx = 0 THEN
            INCL(status, Ready);
            IF pos < bufLen THEN
              IF Word IN ctrl THEN
                ret4 := Get4(pos); INC(pos, 4); delayTx := CalcDelay(32)
              ELSE
                ret := buf[pos]; INC(pos); delayTx := CalcDelay(8)
              END
            ELSE
              done := TRUE
            END
          END
      END ; (*CASE bufState*)
      IF done THEN
        ioHandle;
        ResetBuffer;
        ret := response; delayTx := CalcDelay(8)
      END ;
      IF Word IN ctrl THEN dataTx := ret4 ELSE dataTx := ORD(ret) END
    END (*Ready*)
  END Cycle;

  PROCEDURE WriteControl*(s: SET);
  BEGIN ctrl := s
  END WriteControl;

  PROCEDURE WriteData*(x: INTEGER);
  BEGIN
    ASSERT(Ready IN status);
    dataRx := x;
    delayRx := CalcDelay(8);
    EXCL(status, Ready)
  END WriteData;

  PROCEDURE ReadData*(): LONGINT;
  BEGIN
    ASSERT(Ready IN status);
    RETURN dataTx
  END ReadData;

  PROCEDURE Reset*;
  BEGIN status := {Ready}; ctrl := {}; ResetBuffer;
  END Reset;

  PROCEDURE Open*(fname: ARRAY OF CHAR);
  BEGIN
    F := Files.Old("risk.img");
    maxSize := Files.Length(F);
    ASSERT(maxSize MOD BlockSize = 0, 30);
    numBlocks := maxSize DIV BlockSize;
    Files.Set(R, F, 0)
  END Open;

BEGIN Texts.OpenWriter(W); Reset
END SPICtrl.
(* vim:set ts=2 sw=2 et: *)

