MODULE Timer;
  IMPORT Unix;

  TYPE
    Timer* = Unix.timeval;

  PROCEDURE Start* (VAR t: Timer);
    VAR ret: LONGINT;
  BEGIN ret := Unix.gettimeofday (t, 0)
  END Start;

  PROCEDURE Reset*(VAR t: Timer);
  BEGIN Start(t)
  END Reset;

  PROCEDURE Elapsed* (VAR t: Timer): LONGINT;
    VAR now: Unix.timeval; ret: LONGINT;
  BEGIN ret := Unix.gettimeofday (now, 0);
    ret := (now.tv_sec - t.tv_sec) * 1000
           + (now.tv_usec - t.tv_usec) DIV 1000;
    ASSERT(ret >= 0,99);
    RETURN ret
  END Elapsed;

END Timer.

(* vim:set ts=2 sw=2 et: *)
