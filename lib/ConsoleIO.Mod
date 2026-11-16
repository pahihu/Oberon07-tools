MODULE ConsoleIO ["C"] EXTERNAL ["ConsoleIO.c"];
  IMPORT C := CType;

  CONST
    RxReady* = 1; TxReady* = 2;
    NoData* = -1; EndOfInput* = -2; Error* = -3;

  (* Open returns 1 on success, 0 on error. Calls are idempotent.
     Close restores terminal settings; neither call discards buffered RX. *)
  PROCEDURE Open* ["ConsoleIO_Open"] (): C.int;
  PROCEDURE Close* ["ConsoleIO_Close"];
  (* Status returns RxReady + TxReady as a bit mask. It may buffer one byte. *)
  PROCEDURE Status* ["ConsoleIO_Status"] (): C.int;
  (* Read returns 0..255, NoData, EndOfInput, or Error. *)
  PROCEDURE Read* ["ConsoleIO_Read"] (): C.int;
  (* Write returns 1 if accepted, 0 if busy, Error on failure.
     Retry the SAME byte when busy. No heap allocation or output queue. *)
  PROCEDURE Write* ["ConsoleIO_Write"] (ch: C.int): C.int;
END ConsoleIO.
