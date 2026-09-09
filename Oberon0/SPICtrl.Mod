MODULE SPICtrl;

  IMPORT Files, Texts, Oberon;

  CONST FSoffset = 10000000H; (*256MBytes*)
        BlockSize = 512;
        Undef = 0; Input = 1; Output = 2; (*buffer state*)
        GoIdleState = 0; SendIfCond = 8; AppCmd = 55; SendOpCond = 41; (*SPI commands*)
        WriteSingleBlock = 24; WriteStartDate = 254; ReadSingleBlock = 17;
        NoError = 0; InIdleState = 1; Error = 80H; (*SPI response*)
        Idle = 0FFH;
        Fast = 16; Word = 8; (*ctrl*)
        BitDelayFast = 3; BitDelaySlow = 29; (*TODO check*)
        RxRdy = 1; TxRdy = 0;

  TYPE
      Block = ARRAY BlockSize OF BYTE;
      Proc = PROCEDURE;

  VAR R: Files.Rider;
      F: Files.File;
      maxSize: LONGINT;
      numBlocks: LONGINT;

      bufState: INTEGER;
      buf: ARRAY 2 * BlockSize OF CHAR;
      bufLen: INTEGER;
      pos: INTEGER;
      reponse: LONGINT;
      DoIO: Proc;

      status*: SET;
      ctrl*: SET;
      data*: LONGINT;
      delayRx*: LONGINT;
      delayTx: LONGINT;

      BlockNo: LONGINT;

  (*logging*)
  PROCEDURE Warning(s: ARRAY OF CHAR; x: INTEGER);
  BEGIN
    Texts.WriteLn(W);
    Texts.WriteString(W, "-W-SPI: ");
    Texts.WriteString(W, s);
    Texts.WriteString(W, x, 0)
  END Warning;

  PROCEDURE Log(s: ARRAY OF CHAR; x: INTEGER);
  BEGIN
    Texts.WriteLn(W);
    Texts.WriteString(W, "-I-SPI: ");
    Texts.WriteString(W, s);
    Texts.WriteString(W, x, 0)
  END Log;

  (*raw block IO*)

  PROCEDURE ReadBlock(blkNo: LONGINT; VAR buf: Block);
  BEGIN
    ASSERT(blkNo < numBlocks, 10);
    Files.Set(R, F, blkNo * BlockSize);
    Files.ReadBytes(R, buf, BlockSize)
  END ReadBlock;

  PROCEDURE WriteBlock(blkNo: LONGINT; VAR buf: Block);
  BEGIN
    ASSERT(blkNo < numBlocks, 10);
    Files.Set(R, F, blkNo * BlockSize);
    Files.WriteBytes(R, buf, BlockSize)
  END WriteBlock;

  PROCEDURE DoWrite;
    VAR tmp: Block;
  BEGIN
    FOR i := 0 TO BlockSize - 1 DO tmp[i] := buf[i] END ;
    WriteBlock(BlockNo, tmp);
  END DoWrite;

  PROCEDURE DoNothing;
  BEGIN
  END DoNothing;

  PROCEDURE ResetIO*;
  BEGIN
    pos := 0; bufLen := 0;
    response := Idle;
    bufState := Undef
  END ResetIO;

  PROCEDURE Recv(n: INTEGER; b: BYTE);
  BEGIN
    ASSERT((bufState = Idle) OR (bufState = Input));
    bufState := Input;
    FOR i := 0 TO n - 1 DO buf[bufLen] := b; INC(bufLen) END
  END Recv;

  PROCEDURE Send(b: BYTE);
  BEGIN
    ASSERT((bufState = Idle) OR (bufState = Output), 10);
    bufState := Output;
    buf[bufLen] := b; INC(bufLen);
  END Send;

  PROCEDURE Respond(b: BYTE);
  BEGIN response := b
  END Repond;

  PROCECURE Get4(i: INTEGER): LONGINT;
    VAR ret: LONGINT;
  BEGIN
    ASSERT((0 <= i) & (i + 4 <= bufLen));
    ret := buf[i+3] * 100H) + buf[i+2]) * 100H + buf[i+1]) * 100H + buf[i];
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

  PROCEDURE DoCommand;
    VAR tmp: Block;
  BEGIN
    cmd := buf[0]; arg := Get4(1); crc := buf[5];
    resp := Idle;
    ResetIO;
    CASE cmd OF
      GoIdleState:
        resp := InIdleState |
      SendIfCmd:
        ASSERT(arg = 01AAH, 10);
        Recv(3, 0FFH);
        Respond(NoError);
        DoIO := DoNothing |
      AppCmd:
        ASSERT(arg = 0, 10);
        resp := NoError |
      SendOpCmd:
        ASSERT(arg = 40000000H);
        Recv(1000, 0FFH);
        Respond(NoError);
        DoIO := DoNothing |
      WriteSingleBlock:
        BlockNo := arg |
      WriteStartData:
        Recv(256, Idle); Recv(2, Idle);
        Respond(20H + 05H);
        DoIO := DoWrite;
      ReadSingleBlock:
        BlockNo := arg;
        ReadBlock(BlockNo, tmp);
        Send(0FEH);
        FOR i := 0 TO 255 DO Send(tmp[i]) END ;
        Send(098H); Send(040H); (*dummy 'CRC'*)
    END
  END Command;

  PROCEDURE Do*(inp: BYTE): LONGINT;
    VAR ret: LONGINT;
  BEGIN
    CASE bufState OF
      Undef:
        ret := Idle |
      Input:
        IF delayRx = 0 THEN
          IF pos < bufLen THEN (*TODO check input*)
            IF buf[pos] # Any THEN
              IF buf[pos] # inp THEN Warning("input mismatch ", pos) END
            END ;
            buf[pos] := inp; INC(pos)
          ELSE
            DoIO;
            bufState := Idle;
            ret := response
          END
        ELSE
          DEC(delayRx)
        END |
      Output:
        IF delayTx = 0 THEN
          IF pos < bufLen THEN
            IF Word IN ctrl THEN
              ret := Get4(pos); INC(pos, 4); delayTx := CalcDelay(32)
            ELSE
              ret := buf[pos]; INC(pos); delayTx := CalcDelay(8)
            END ;
          ELSE
            DoIO;
            bufState := Idle;
            ret := response; delayTx := CalcDelay(8)
          END
        ELSE
          DEC(delayTx)
        END
    END ;
    RETURN ret
  END Do;

BEGIN
  F := Files.Old("risk.img")
  maxSize := Files.Length(F)
  ASSERT(maxSize MOD BlockSize = 0, 30);
  numBlocks := maxSize DIV BlockSize;
  Files.Set(R, F, 0);

  status := {rxRdy, txRdy}; ctrl := {}; ResetIO;
END SPICtrl.
(* vim:set ts=2 sw=2 et: *)

