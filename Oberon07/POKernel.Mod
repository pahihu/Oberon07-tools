MODULE POKernel;
  IMPORT SYSTEM, Files := Files07, Sys := System, Kernel, Out;

  CONST SectorLength* = 1024;
        BlkLength = 512;
        FSoffset = 80000H; (*256MB in 512-byte blocks*)
        mapsize = 10000H; (*1K sectors, 64MB*)
        imageNotFound* = 1;
        done* = 0;
  TYPE
    INTEGER = Sys.INT32;
    Sector* = ARRAY SectorLength OF SYSTEM.BYTE;

  VAR SD: Files.File; SDR: Files.Rider;
      res-: INTEGER;
  VAR allocated*, NofSectors*: INTEGER;
      sectorMap: ARRAY mapsize DIV 32 OF SET;

  (*--------------- Misc -----------------*)

  PROCEDURE Clock*(): INTEGER;
    VAR t, d: LONGINT;
        yr, mo, dy, hh, mm, ss: INTEGER;
        pod: INTEGER;
  BEGIN Kernel.GetClock(t, d);
    hh := Sys.Short(t DIV 4096); mm := Sys.Short(t DIV 64 MOD 64); ss := Sys.Short(t MOD 64);
    yr := Sys.Short((d DIV 512) MOD 100); mo := Sys.Short(d DIV 32 MOD 16); dy := Sys.Short(d MOD 32);
    pod := ss + (mm * 40H) + (hh * 1000H) + 20000H * dy + 400000H * mo + 4000000H * yr;
    RETURN pod
  END Clock;

  (*--------------- Blocks ---------------*)

  PROCEDURE WriteSD(VAR src: ARRAY OF SYSTEM.BYTE; offs: INTEGER);
    VAR blk: ARRAY BlkLength OF SYSTEM.BYTE;
        i: INTEGER;
  BEGIN IF offs = 0 THEN Files.WriteBytes(SDR, src, BlkLength)
    ELSE FOR i := 0 TO BlkLength-1 DO blk[i] := src[offs+i] END;
      Files.WriteBytes(SDR, blk, BlkLength)
    END
  END WriteSD;
  
  PROCEDURE ReadSD(VAR dst: ARRAY OF SYSTEM.BYTE; offs: INTEGER);
    VAR blk: ARRAY BlkLength OF SYSTEM.BYTE;
        i: INTEGER;
  BEGIN IF offs = 0 THEN Files.ReadBytes(SDR, dst, BlkLength)
    ELSE Files.ReadBytes(SDR, blk, BlkLength);
      FOR i := 0 TO BlkLength-1 DO dst[offs+i] := blk[i] END
    END
  END ReadSD;

  (*--------------- Sectors ------------------*)

  PROCEDURE InitSecMap*;
    VAR i: INTEGER;
  BEGIN NofSectors := 0; sectorMap[0] := {0 .. 31}; sectorMap[1] := {0 .. 31};
    FOR i := 2 TO mapsize DIV 32 - 1 DO sectorMap[i] := {} END
  END InitSecMap;

  PROCEDURE MarkSector*(sec: INTEGER);
  BEGIN sec := sec DIV 29;
    INCL(sectorMap[sec DIV 32], sec MOD 32); INC(NofSectors)
  END MarkSector;

  PROCEDURE FreeSector*(sec: INTEGER);
  BEGIN sec := sec DIV 29;
    EXCL(sectorMap[sec DIV 32], sec MOD 32); DEC(NofSectors)
  END FreeSector;

  PROCEDURE AllocSector*(hint: INTEGER; VAR sec: INTEGER);
    VAR s: INTEGER;
  BEGIN (*find free sector, starting after hint*)
    hint := hint DIV 29; s := hint;
    REPEAT INC(s);
      IF s = mapsize THEN s := 1 END ;
    UNTIL ~(s MOD 32 IN sectorMap[s DIV 32]);
    INCL(sectorMap[s DIV 32], s MOD 32); INC(NofSectors); sec := s * 29
  END AllocSector;
  
  PROCEDURE GetSector*(src: INTEGER; VAR dst: ARRAY OF SYSTEM.BYTE);
  BEGIN src := src DIV 29;
    src := src * 2 + FSoffset;
    Files.Set(SDR, SD, src * BlkLength);
    ReadSD(dst, 0); ReadSD(dst, BlkLength)
  END GetSector;

  PROCEDURE PutSector*(dst: INTEGER; VAR src: ARRAY OF SYSTEM.BYTE);
  BEGIN dst := dst DIV 29;
    dst := dst * 2 + FSoffset;
    Files.Set(SDR, SD, dst * BlkLength);
    WriteSD(src, 0); WriteSD(src, BlkLength)
  END PutSector;
  
  (*---------------- Image ------------------*)

  PROCEDURE OpenImage*(name: ARRAY OF CHAR);
  BEGIN res := imageNotFound; SD := Files.Old(name);
    IF SD # NIL THEN res := done; Files.Set(SDR, SD, 0) END
  END OpenImage;

  PROCEDURE CloseImage*;
  BEGIN Files.Close(SD)
  END CloseImage;
  
  PROCEDURE Init*;
  BEGIN InitSecMap
  END Init;

END POKernel.
(* vim:set ts=2 sw=2 et: *)
