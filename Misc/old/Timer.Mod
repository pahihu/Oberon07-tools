MODULE Timer;
  IMPORT Time;

  TYPE
    Timer* = Time.Time;

  PROCEDURE Start*(VAR t: Timer);
  BEGIN Time.GetSysTime(t)
  END Start;

  PROCEDURE Reset*(VAR t: Timer);
  BEGIN Start(t)
  END Reset;

  PROCEDURE Elapsed*(VAR t: Timer): LONGINT;
    VAR milliseconds: LONGINT;
      now: Time.Time;
  BEGIN Time.Since(t, now);
    RETURN now.tv_sec * 1000 + now.tv_usec DIV 1000
  END Elapsed;

END Timer.
