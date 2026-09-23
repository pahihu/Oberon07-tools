MODULE MemCtrl; (*Phu 18.9.26*)
  IMPORT Sys := System, Texts, Oberon, Files;

  (*
    Cache controller
    We have a small amount of BRAM and a lot of QPI PSRAM
    QPI protocol:
      8bit command(2 clk)
      24bit address(6 clk)
      if read then 6 clk wait-state
      <stream of bytes>
      stop 1 clk

    Assume a 16byte cache line (4 words), direct-mapped separate I/D cache of 8KB each, 23bit address lines:
      TTTTTTTTTTxxxxxxxxxwwbb 23bit (8MB)
            TTTTxxxxxxxxxwwbb 17bit (128KB)

      10bit tag
       9bit index
       2bit word select
       2bit byte select

    Read 16bytes on QPI:

      2 + 6 + 6 + 32 + 1 = 47 clk

    Write 16bytes on QPI:

      2 + 6     + 32 + 1 = 41 clk
   *)

  CONST
    WordsPerLine = 4; (* 2bit *)
    (* TestReals
       =========
        BRAM     58K
        512BS   286K
        1KS     224K
        2KS     167K
        4KS     122K
        8KS     101K
        8KS24    79K
        8KS36    73K
    *)
    Lines = 512; (* 9bit *) Tags = 16; (* 4bit *)
    (* 4K Lines = 256; Tags = 32; *)
    (* 2K Lines = 128; Tags = 64; *)
    (* 1K Lines =  64; Tags = 128; *)
    (* 512B Lines = 32; Tags = 256; *)
    (* 128KB MaxMem* = 32768; *)
    MaxMem* = 112 * 1024 DIV 4;
    WriteBackClks = 2 + 6 +  WordsPerLine * 8 + 1; FillClks = WriteBackClks + 6;
    (* 24MHz WriteBackClks = 21; FillClks = 23; *)
    (* 36MHz WriteBackClks = 14; FillClks = 16; *)
    Debug = FALSE;
    Valid = 0; Dirty = 1;
    PromSize = 512; PromStart* = 3FF800H; (*in words*)
    LF = 0AX;

  TYPE
    INTEGER = Sys.INT32;
    LONGINT = Sys.INT32;

    Address = LONGINT;
    Word = LONGINT;
    CacheMem = ARRAY Lines, WordsPerLine OF Word;
    TagDesc = RECORD
        tag: INTEGER;
        flags: SET;
    END ;
    TagMem = ARRAY Lines OF TagDesc;

  VAR cache: CacheMem;
      tags: TagMem;
      M*: ARRAY MaxMem OF LONGINT;
      cntMiss-, cntHit-: LONGINT; (*number of cache miss/hit count*)
      cntFetch-, cntMemRd-, cntMemWr-: LONGINT; (*number of memory fetch/read/write*)
      elapsedClks-: LONGINT; (*elapsed CLKs for the last operation*)
      enabled-: BOOLEAN;
      W: Texts.Writer;
      PROM: ARRAY PromSize OF LONGINT;

  PROCEDURE Where(s: ARRAY OF CHAR);
  BEGIN Texts.WriteLn(W); Texts.WriteString(W, s);
    Texts.Append(Oberon.Log, W.buf)
  END Where;

  PROCEDURE DebugInt(nl: BOOLEAN; s: ARRAY OF CHAR; x: LONGINT);
  BEGIN
    IF Debug THEN
      IF nl THEN Texts.WriteLn(W)
      ELSE Texts.Write(W, ' ') END ;
      Texts.WriteString(W, s);
      Texts.Write(W, '=');
      Texts.WriteInt(W, x, 0);
      Texts.Append(Oberon.Log, W.buf);
    END
  END DebugInt;

  PROCEDURE Init;
    VAR i: INTEGER;
  BEGIN
    enabled := FALSE;
    FOR i := 0 TO LEN(TagMem) - 1 DO
      tags[i].flags := {}
    END ;
  END Init;

  PROCEDURE FillLine(VAR tags: TagMem; VAR lines: CacheMem; tag, idx: INTEGER; adr: Address);
    VAR i: INTEGER;
  BEGIN
    ASSERT((0 <= tag) & (tag < Tags), 10);
    adr := (adr DIV WordsPerLine) * WordsPerLine;
    FOR i := 0 TO WordsPerLine - 1 DO
      DebugInt(i = 0, " fill", adr);
      lines[idx][i] := M[adr]; INC(adr); INC(cntMemRd);
    END ;
    tags[idx].tag := tag;
    INCL(tags[idx].flags, Valid);
    EXCL(tags[idx].flags, Dirty);

    INC(elapsedClks, FillClks - 1); (*RISC will count 1 for each instr*)
  END FillLine;

  PROCEDURE WriteBackLine(VAR tags: TagMem; VAR lines: CacheMem; idx: INTEGER);
    VAR adr: Address;
        i: INTEGER;
  BEGIN
    adr := (tags[idx].tag * Lines + idx) * WordsPerLine;

    FOR i := 0 TO WordsPerLine - 1 DO
      DebugInt(i = 0, " wb", adr);
      M[adr] := lines[idx][i]; INC(adr); INC(cntMemWr);
    END ;
    EXCL(tags[idx].flags, Dirty);

    INC(elapsedClks, WriteBackClks - 1); (*RISC will count 1 for each instr*)
  END WriteBackLine;

  PROCEDURE SplitAdr(adr: Address; VAR tag, idx, wsel: INTEGER);
  BEGIN
    wsel := adr MOD WordsPerLine; adr := adr DIV WordsPerLine;
    idx := adr MOD Lines; adr := adr DIV Lines;
    tag := adr MOD Tags;
    DebugInt(TRUE, " tag", tag);
    DebugInt(FALSE, "idx", idx);
    DebugInt(FALSE, "wsel", wsel);
  END SplitAdr;

  PROCEDURE ReadInt(msg: ARRAY OF CHAR; adr: Address): Word;
    VAR ret: Word;
        tag, idx, wsel: INTEGER;
  BEGIN
    DebugInt(TRUE, msg, adr);
    elapsedClks := 0;
    IF enabled THEN
      SplitAdr(adr, tag, idx, wsel);
      IF ~(Valid IN tags[idx].flags) OR (tags[idx].tag # tag) THEN
        INC(cntMiss);
        IF Dirty IN tags[idx].flags THEN WriteBackLine(tags, cache, idx) END ;
        FillLine(tags, cache, tag, idx, adr);
      ELSE INC(cntHit)
      END ;
      ret := cache[idx][wsel];
    ELSE
      ret := M[adr]
    END ;
    RETURN ret
  END ReadInt;

  PROCEDURE Read*(adr: Address): Word;
    VAR ret: Word;
  BEGIN
    ASSERT((0 <= adr) & (adr < MaxMem), 10);
    ret := ReadInt("READ", adr); INC(cntMemRd);
    RETURN ret
  END Read;

  PROCEDURE Write*(adr: Address; data: Word);
    VAR tag, idx, wsel: INTEGER;
  BEGIN
    ASSERT((0 <= adr) & (adr < MaxMem), 10);
    DebugInt(TRUE, "WRITE", adr);
    elapsedClks := 0;
    IF enabled THEN
      SplitAdr(adr, tag, idx, wsel);
      IF ~(Valid IN tags[idx].flags) OR (tags[idx].tag # tag) THEN
        INC(cntMiss);
        IF Dirty IN tags[idx].flags THEN WriteBackLine(tags, cache, idx) END ;
        FillLine(tags, cache, tag, idx, adr);
      ELSE INC(cntHit)
      END ;
      cache[idx][wsel] := data;
      INCL(tags[idx].flags, Dirty)
    ELSE
      M[adr] := data
    END ;
    INC(cntMemWr)
  END Write;

  PROCEDURE Flush*;
    VAR i: INTEGER;
  BEGIN
    DebugInt(TRUE,"FLUSH",0);
    elapsedClks := 0;
    FOR i := 0 TO LEN(tags) - 1 DO
      IF {Valid, Dirty} = tags[i].flags THEN
        WriteBackLine(tags, cache, i)
      END
    END
  END Flush;

  PROCEDURE IsRamAdr(adr: Address): BOOLEAN;
  BEGIN RETURN (0 <= adr) & (adr < MaxMem)
  END IsRamAdr;

  PROCEDURE IsPromAdr(adr: Address): BOOLEAN;
  BEGIN RETURN (PromStart <= adr) & (adr < PromStart + PromSize)
  END IsPromAdr;

  PROCEDURE Fetch*(adr: Address): Word;
    VAR ret: Word;
  BEGIN
    IF IsRamAdr(adr) THEN
      ret := ReadInt("FETCH", adr)
    ELSIF IsPromAdr(adr) THEN
      ret := PROM[adr - PromStart]
    ELSE
      Texts.WriteLn(W);
      Texts.WriteString(W, "Fetch: invalid address ");
      Texts.WriteHex(W, adr * 4);
      HALT(1)
    END ;
    INC(cntFetch);
    RETURN ret
  END Fetch;

  PROCEDURE Enable*;
  BEGIN
    DebugInt(TRUE, "Enable", 0);
    ASSERT(~enabled, 10);
    Init; enabled := TRUE;
    cntMemRd := 0; cntMemWr := 0; elapsedClks := 0;
    cntHit := 0; cntMiss := 0;
    DebugInt(FALSE, "Enable", 1);
  END Enable;

  PROCEDURE Disable*;
  BEGIN
    ASSERT(enabled, 10);
    Flush;
    enabled := FALSE
  END Disable;

  PROCEDURE Efficiency*(): LONGREAL;
    VAR x: LONGREAL;
  BEGIN
    IF enabled THEN
      x := (0.0 + cntHit) / (0.0 + cntHit + cntMiss)
    ELSE
      x := 0.0
    END ;
    RETURN x;
  END Efficiency;

  (*PROM reader*)
  PROCEDURE HexToInt(s: ARRAY OF CHAR): LONGINT;
    VAR i, digit: INTEGER;
        ret: LONGINT;
        ch: CHAR;
  BEGIN ret := 0; i := 0;
    ch := s[i];
    WHILE ch # 0X DO
      IF ch > "9" THEN
        digit := ORD(ch) - ORD("A") + 10
      ELSE
        digit := ORD(ch) - ORD("0")
      END ;
      ret := ret * 16 + digit;
      INC(i); ch := s[i]
    END ;
    RETURN ret
  END HexToInt;

  PROCEDURE ReadLine(VAR R: Files.Rider; VAR s: ARRAY OF CHAR);
    VAR i: INTEGER;
        ch: CHAR;
  BEGIN i := 0;
    Files.Read(R, ch);
    WHILE ~R.eof & (ch # LF) & (i < LEN(s) - 1) DO
      s[i] := ch; INC(i);
      Files.Read(R, ch)
    END ;
    s[i] := 0X;
    (*Where(s)*)
  END ReadLine;

  PROCEDURE ReadProm*(fname: ARRAY OF CHAR);
    VAR F: Files.File;
        R: Files.Rider;
        s: ARRAY 16 OF CHAR;
        i: INTEGER;
  BEGIN
    F := Files.Old(fname);
    IF F # NIL THEN
      Files.Set(R, F, 0);
      i := 0;
      WHILE ~R.eof & (i < PromSize) DO
        ReadLine(R, s);
        IF s[0] # 0X THEN
          PROM[i] := HexToInt(s); INC(i)
        END
      END ;
      Files.Close(F);
    ELSE
      Texts.WriteLn(W);
      Texts.WriteString(W, "PROM file not found");
      Texts.Append(Oberon.Log, W.buf);
      HALT(1)
    END ;
    Texts.Append(Oberon.Log, W.buf);
  END ReadProm;

BEGIN Init; Texts.OpenWriter(W);
END MemCtrl.
(* vim:set ts=2 sw=2 et: *)
