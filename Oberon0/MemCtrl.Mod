MODULE MemCtrl;
  IMPORT Sys := System, Texts, Oberon;

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
    (* 8K Lines = 512; (* 9bit *) Tags = 16; (* 4bit *) *)
    Lines = 256; Tags = 32;
    (* 2K Lines = 128; Tags = 64; *)
    (* 1K Lines =  64; Tags = 128; *)
    (* 512B Lines = 32; Tags = 256; *)
    MaxMem* = 32768; (*128KB*)
    WriteBackClks = 2 + 6 +  WordsPerLine * 8 + 1; FillClks = WriteBackClks + 6;
    (* 24MHz WriteBackClks = 21; FillClks = 23; *)
    (* 36MHz WriteBackClks = 14; FillClks = 16; *)
    Debug = FALSE;
    Valid = 0; Dirty = 1; Code = 2;

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

  VAR instrCache, dataCache: CacheMem;
      instrTags, dataTags: TagMem;
      M*: ARRAY MaxMem OF LONGINT;
      cntMiss-, cntHit-: LONGINT; (*number of cache miss/hit count*)
      cntFetch-, cntMemRd-, cntMemWr-: LONGINT; (*number of memory fetch/read/write*)
      elapsedClks-: LONGINT; (*elapsed CLKs for the last operation*)
      enabled-: BOOLEAN;
      W: Texts.Writer;

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
      instrTags[i].flags := {}
    END ;
    FOR i := 0 TO LEN(TagMem) - 1 DO
      dataTags[i].flags := {}
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

  PROCEDURE InvalidateInstr(tag, idx: INTEGER);
  BEGIN
    IF (Valid IN instrTags[idx].flags) & (instrTags[idx].tag = tag) THEN
      EXCL(instrTags[idx].flags, Valid);
      DebugInt(TRUE," INVALIDATE",1);
    END
  END InvalidateInstr;

  PROCEDURE Read*(adr: Address): Word;
    VAR ret: Word;
        tag, idx, wsel: INTEGER;
  BEGIN
    DebugInt(TRUE, "READ", adr);
    elapsedClks := 0;
    IF enabled THEN
      SplitAdr(adr, tag, idx, wsel);
      IF ~(Valid IN dataTags[idx].flags) OR (dataTags[idx].tag # tag) THEN
        INC(cntMiss);
        IF Dirty IN dataTags[idx].flags THEN WriteBackLine(dataTags, dataCache, idx) END ;
        FillLine(dataTags, dataCache, tag, idx, adr);
      ELSE INC(cntHit)
      END ;
      ret := dataCache[idx][wsel];
    ELSE
      ret := M[adr]
    END ;
    INC(cntMemRd);
    RETURN ret
  END Read;

  PROCEDURE Write*(adr: Address; data: Word);
    VAR tag, idx, wsel: INTEGER;
  BEGIN
    DebugInt(TRUE, "WRITE", adr);
    elapsedClks := 0;
    IF enabled THEN
      SplitAdr(adr, tag, idx, wsel);
      IF ~(Valid IN dataTags[idx].flags) OR (dataTags[idx].tag # tag) THEN
        INC(cntMiss);
        IF Dirty IN dataTags[idx].flags THEN WriteBackLine(dataTags, dataCache, idx) END ;
        FillLine(dataTags, dataCache, tag, idx, adr);
      ELSE INC(cntHit)
      END ;
      dataCache[idx][wsel] := data;
      INCL(dataTags[idx].flags, Dirty);
      InvalidateInstr(tag, idx);
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
    FOR i := 0 TO LEN(dataTags) - 1 DO
      IF {Valid, Dirty} = dataTags[i].flags THEN
        WriteBackLine(dataTags, dataCache, i)
      END
    END
  END Flush;

  PROCEDURE Fetch*(adr: Address): Word;
    VAR ret: Word;
        tag, idx, wsel: INTEGER;
  BEGIN
    DebugInt(TRUE, "FETCH", adr);
    elapsedClks := 0;
    IF enabled THEN
      SplitAdr(adr, tag, idx, wsel);
      IF ~(Valid IN instrTags[idx].flags) OR (instrTags[idx].tag # tag) THEN
        INC(cntMiss);
        FillLine(instrTags, instrCache, tag, idx, adr);
      ELSE INC(cntHit)
      END ;
      ret := instrCache[idx][wsel]
    ELSE
      ret := M[adr]
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

BEGIN Init; Texts.OpenWriter(W);
END MemCtrl.
(* vim:set ts=2 sw=2 et: *)
