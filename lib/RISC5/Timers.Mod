MODULE Timers; (*Phu 8.11.26*)
  IMPORT Timer;

  VAR
    T: Timer.Timer;

  PROCEDURE Time*(): LONGINT;
  BEGIN RETURN Timer.Elapsed(T)
  END Time;

BEGIN Timer.Start(T)
END Timers.
(* vim:set ts=2 sw=2 et:*)
