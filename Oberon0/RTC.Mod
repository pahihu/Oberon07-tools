MODULE RTC; (*Phu 22.9.26 / DS3234*)
  IMPORT SPI, Kernel, Sys := System;

  CONST
    BufLen = 14H; ReadAdrEnd = 13X; WriteAdrStart = 80X; WriteAdrEnd = 93X;
    TimeAdr = 0X; DateAdr = 04X;

  TYPE
    INTEGER* = SPI.INTEGER;
    LONGINT* = SPI.LONGINT;
    BYTE* = SPI.BYTE;
    RTC* = POINTER TO RTCDesc;
    RTCDesc* = RECORD (SPI.SlaveDesc) END;

  VAR
    RecvInc: SPI.IOHandler;


  PROCEDURE IntToBCD(i: LONGINT): BYTE;
  BEGIN RETURN CHR(i DIV 10 * 16 + i MOD 10)
  END IntToBCD;

  PROCEDURE RecvAndIncrement(r: SPI.Slave; b: BYTE);
  BEGIN (*dummy*)
    WITH r: RTC DO
      r.ResetBuffer;
      r.Recv(1, SPI.Undef);
      r.CmdFinish := RecvInc
    END
  END RecvAndIncrement;

  PROCEDURE SendAndIncrement(r: SPI.Slave; b: BYTE);
    VAR lt, ld: Sys.Address;
        t, d: LONGINT;
        hh, mm, ss, dy, mo, yr: LONGINT;
        adr: BYTE;
  BEGIN
    WITH r: RTC DO
      adr := r.buf[0];
      Kernel.GetClock(lt, ld); t := Sys.Short(lt); d := Sys.Short(ld);
      hh := t DIV 4096; mm := t DIV 64 MOD 64; ss := t MOD 64;
      yr := (d DIV 512) MOD 100; mo := d DIV 32 MOD 16; dy := d MOD 32;
      r.Log("ss", ss);
      r.Log("mm", mm);
      r.Log("hh", hh);
      r.Log("dy", dy);
      r.Log("mo", mo);
      r.Log("yr", yr);
      r.ResetBuffer;
      IF adr = TimeAdr THEN
        r.Send(IntToBCD(ss));
        r.Send(IntToBCD(mm));
        r.Send(IntToBCD(hh));
        r.Send(1X)
      END ;
      IF (adr = TimeAdr) OR (adr = DateAdr) THEN
        r.Send(IntToBCD(dy));
        r.Send(IntToBCD(mo));
        r.Send(IntToBCD(yr))
      END ;
      r.CmdFinish := SPI.DoNothing
    END
  END SendAndIncrement;

  PROCEDURE HandleCmdStart(r: SPI.Slave; b: BYTE);
  BEGIN
    WITH r: RTC DO
      IF (0X <= b) & (b <= ReadAdrEnd) THEN
        r.Log("HandleCmdStart READ", ORD(b));
        r.Recv(1, SPI.Undef);
        r.CmdFinish := SendAndIncrement
      ELSIF (WriteAdrStart <= b) & (b <= WriteAdrEnd) THEN
        r.Log("HandleCmdStart WRITE", ORD(b));
        r.Recv(1, SPI.Undef);
        r.CmdFinish := RecvAndIncrement
      END
    END
  END HandleCmdStart;

  PROCEDURE (r: RTC) Reset*;
  BEGIN
    r.Reset^;
    r.SetCmdStart(HandleCmdStart, 0)
  END Reset;

  PROCEDURE (r: RTC) AfterControlSet;
  BEGIN IF SPI.SPI1 IN r.ctrl THEN r.Reset END
  END AfterControlSet;

  PROCEDURE New*(): RTC;
    VAR r: RTC;
  BEGIN NEW(r); r.InitBuffer(BufLen); RETURN r
  END New;

BEGIN RecvInc := RecvAndIncrement
END RTC.
(* vim:set ts=2 sw=2 et: *)
