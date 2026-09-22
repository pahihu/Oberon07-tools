MODULE SDCardNew;

  IMPORT SPI, Files, Sys := System;

  CONST
    FSoffset = 0 (*10000000H*); (*256MBytes*)
    BlockSize = 512; SectorSize = 1024;
    CMDoffset = 40H;
    CMDGoIdleState = 0X; CMDSendIfCond = 8X; CMDAppCmd = 37X; CMDSendOpCond = 29X; (*SPI commands*)
    CMDWriteSingleBlock = 18X; WriteStartData = 0FEX; CMDReadSingleBlock = 11X;
    NoError = 0X; InIdleState = 01X; Error = 80H; (*SPI response*)
    detCommand = 0; detWriteStart = 1; (*detectors*)

  TYPE
    INTEGER = SPI.INTEGER;
    LONGINT = SPI.LONGINT;
    BYTE = SPI.BYTE;
    Block = ARRAY BlockSize OF BYTE;
    SDCard* = POINTER TO SDCardDesc;
    SDCardDesc* = RECORD (SPI.SlaveDesc)
      R: Files.Rider;
      F: Files.File;
      maxSize: LONGINT;
      numBlocks: LONGINT;
      blkNo: LONGINT;
    END ;

  VAR
    detectors: ARRAY 2 OF SPI.IOHandler;

  (*raw block IO*)

  PROCEDURE (s: SDCard) ReadBlock(VAR buf: Block);
  BEGIN
    SPI.Log("ReadBlock: blkNo=", s.blkNo);
    ASSERT((0 <= s.blkNo) & (s.blkNo < s.numBlocks), 10);
    Files.Set(s.R, s.F, FSoffset + s.blkNo * BlockSize);
    Files.ReadBytes(s.R, buf, BlockSize)
  END ReadBlock;

  PROCEDURE (s: SDCard) WriteBlock(VAR buf: Block);
  BEGIN
    SPI.Log("WriteBlock: blkNo=", s.blkNo);
    (*Texts.WriteLn(W); Texts.WriteString(W, "WriteBlock@"); Texts.WriteInt(W, blkNo, 0); Texts.Append(Oberon.Log, W.buf);*)
    ASSERT((0 <= s.blkNo) & (s.blkNo < s.numBlocks), 10);
    Files.Set(s.R, s.F, FSoffset + s.blkNo * BlockSize);
    Files.WriteBytes(s.R, buf, BlockSize)
  END WriteBlock;

  (*command handling*)

  PROCEDURE (s: SDCard) SetDetector(x: INTEGER);
  BEGIN
    ASSERT((x = detCommand) OR (x = detWriteStart), 10);
    SPI.Log("SetDetector", x);
    s.SetCmdStart(detectors[x], x)
  END SetDetector;

  PROCEDURE DoWrite(s: SPI.Slave; b: BYTE);
    VAR tmp: Block;
        i: INTEGER;
  BEGIN
    WITH s: SDCard DO
      SPI.Log("DoWrite", s.blkNo);
      ASSERT(s.IsBufferEmpty(), 10);
      ASSERT(s.len = BlockSize + 3, 10); (*WriteStartData + 512xB + 2xCRC*)
      FOR i := 0 TO BlockSize - 1 DO tmp[i] := s.buf[i + 1] END ;
      s.WriteBlock(tmp);
      s.SetDetector(detCommand);
      SPI.DoRespond(s, SPI.Undef)
    END
  END DoWrite;

  PROCEDURE GetCommand(b: BYTE): BYTE;
  BEGIN RETURN CHR(ORD(b) - CMDoffset)
  END GetCommand;

  PROCEDURE DoCommand(s: SPI.Slave; b: BYTE);
    VAR tmp: Block;
        cmd, crc: BYTE;
        arg: LONGINT;
        ret: BYTE;
        i: INTEGER;
  BEGIN
    WITH s: SDCard DO
      ASSERT(s.len = 6, 10);
      cmd := GetCommand(s.buf[0]); arg := s.GetCommandArg(1); crc := s.buf[5];
      SPI.Log("cmd=",ORD(cmd)); SPI.Log("arg=",arg);
      ret := SPI.Undef;
      s.ResetBuffer;
      s.SetDetector(detCommand);
      CASE cmd OF
        CMDGoIdleState:
            SPI.Log("CMDGoIdleState", -1);
            s.Respond(InIdleState)
        | CMDSendIfCond:
            ASSERT(arg = 01AAH, 10);
            SPI.Log("CMDSendIfCond", -1);
            s.Recv(3, SPI.Undef);
            s.Respond(NoError)
        | CMDAppCmd:
            ASSERT(arg = 0, 10);
            SPI.Log("CMDAppCmd", -1);
            s.Respond(NoError)
        | CMDSendOpCond:
            ASSERT(arg = 40000000H);
            SPI.Log("CMDSendOpCond", -1);
            (*Recv(1000, Undef);*)
            s.Respond(NoError)
        | CMDWriteSingleBlock:
            SPI.Log("CMDWriteSingleBlock", arg);
            s.blkNo := arg;
            s.Respond(NoError);
            s.SetDetector(detWriteStart)
        | CMDReadSingleBlock:
            SPI.Log("CMDReadSingleBlock", arg);
            s.blkNo := arg;
            s.ReadBlock(tmp);
            s.Send(NoError);
            s.Send(CHR(0FEH));
            FOR i := 0 TO BlockSize - 1 DO s.Send(tmp[i]) END ;
            s.Send(CHR(098H)); (*dummy 'CRC'*)
            s.Respond(040X)
      END
    END
  END DoCommand;

  PROCEDURE HandleCmdStart(s: SPI.Slave; b: BYTE);
  BEGIN
    WITH s: SDCard DO
      IF b # SPI.Undef THEN (*lock CMD*)
        SPI.Log("Lock CMD", ORD(b));
        s.ResetBuffer;
        s.Recv(6, SPI.Undef);
        s.CmdFinish := DoCommand
      END
    END
  END HandleCmdStart;

  PROCEDURE HandleWriteStart(s: SPI.Slave; b: BYTE);
  BEGIN
    WITH s: SDCard DO
      IF b = WriteStartData THEN
        s.ResetBuffer;
        s.Recv(1, WriteStartData); s.Recv(BlockSize, SPI.Undef); s.Recv(2, SPI.Undef);
        s.RespondWith(CHR(20H + 05H), DoWrite)
      END ;
    END
  END HandleWriteStart;

  PROCEDURE (s: SDCard) Reset*;
  BEGIN s.Reset^;
    s.SetDetector(detCommand)
  END Reset;

  PROCEDURE (s: SDCard) Open*(fname: ARRAY OF CHAR);
  BEGIN
    SPI.Log("Open", -1);
    s.F := Files.Old(fname);
    s.maxSize := Sys.Short(Files.Length(s.F));
    SPI.Log("maxSize", s.maxSize);
    ASSERT(s.maxSize MOD BlockSize = 0, 30);
    s.numBlocks := s.maxSize DIV BlockSize;
    SPI.Log("numBlocks", s.numBlocks);
    Files.Set(s.R, s.F, 0)
  END Open;

  PROCEDURE (s: SDCard) Close*;
  BEGIN IF s.F # NIL THEN Files.Close(s.F) END
  END Close;

  PROCEDURE New*(): SDCard;
    VAR s: SDCard;
  BEGIN NEW(s); s.InitBuffer(SectorSize); s.F := NIL; RETURN s
  END New;

BEGIN
  detectors[detCommand] := HandleCmdStart;
  detectors[detWriteStart] := HandleWriteStart
END SDCardNew.
(* vim:set ts=2 sw=2 et: *)
