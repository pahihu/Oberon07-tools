MODULE RTC; (*Phu 22.9.26 / DS3234*)
  IMPORT SPI, Kernel, Sys := System;

  CONST
    BufLen = 7; ReadAdr = 13X; WriteAdrStart = 80X; WriteAdrEnd = 93X;


  TYPE
    INTEGER* = SPI.INTEGER;
    LONGINT* = SPI.LONGINT;
    BYTE* = SPI.BYTE;
    RTC* = POINTER TO RTCDesc;
    RTCDesc* = RECORD (SPI.SlaveDesc) END;


  PROCEDURE IntToBCD(i: LONGINT): BYTE;
  BEGIN RETURN CHR(i DIV 10 * 16 + i MOD 10)
  END IntToBCD;

  PROCEDURE RecvAndIncrement(r: SPI.Slave; b: BYTE);
  BEGIN (*dummy*)
  END RecvAndIncrement;

  PROCEDURE HandleCmdStart(r: SPI.Slave; b: BYTE);
    VAR t, d: LONGINT;
        hh, mm, ss, dy, mo, yr: LONGINT;
  BEGIN
    WITH r: RTC DO
      IF (0X <= b) & (b <= ReadAdr) THEN
        Kernel.GetClock(t, d);
        hh := t DIV 4096; mm := t DIV 64 MOD 64; ss := t MOD 64;
        yr := (d DIV 512) MOD 100; mo := d DIV 32 MOD 16; dy := d MOD 32;
        r.ResetBuffer;
        r.Send(IntToBCD(ss));
        r.Send(IntToBCD(mm));
        r.Send(IntToBCD(hh));
        r.Send(1X);
        r.Send(IntToBCD(dy));
        r.Send(IntToBCD(mo));
        r.Send(IntToBCD(yr));
        r.CmdFinish := SPI.DoNothing
      ELSIF (WriteAdrStart <= b) & (b <= WriteAdrEnd) THEN
        r.ResetBuffer;
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
  BEGIN IF SPI.DEV1 IN r.ctrl THEN r.Reset END
  END AfterControlSet;

  PROCEDURE New*(): RTC;
    VAR r: RTC;
  BEGIN NEW(r); r.InitBuffer(BufLen); RETURN r
  END New;

END RTC.
(* vim:set ts=2 sw=2 et: *)
