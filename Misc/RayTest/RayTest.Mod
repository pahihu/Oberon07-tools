MODULE RayTest;
  IMPORT Tracer, Timer, Out, Args;
  
  VAR T: Timer.Timer;
      elapsed: LONGINT;
      worldSize: LONGINT;

  PROCEDURE Init(res: LONGINT);
    VAR x, z: INTEGER;
  BEGIN
    Tracer.SetEye(0.0D0, 0.0D0, 200.0D0);
    Tracer.DefSphere(  0.0D0, -300.0D0, -1200.0D0, 200.0D0, 0.8D0);
    Tracer.DefSphere(-80.0D0, -150.0D0, -1200.0D0, 200.0D0, 0.7D0);
    Tracer.DefSphere( 70.0D0, -100.0D0, -1200.0D0, 200.0D0, 0.9D0);
    FOR x := -2 TO 2 DO
      FOR z := 2 TO 7 DO
        Tracer.DefSphere(200.0D0 * x, 300.0D0, -400.0D0 * z, 40.0D0, 0.75D0)
      END
    END;
    Tracer.Trace("sphere.pgm", res)
  END Init;

BEGIN worldSize := 4;
  IF Args.argc > 0 THEN worldSize := Args.GetInt(1) END;
  Out.String("World size="); Out.Int(worldSize, 0); Out.Ln;
  Timer.Start(T); Init(worldSize); elapsed := Timer.Elapsed(T);
  Out.String("Elapsed time "); Out.Int(elapsed, 0); Out.Ln
END RayTest.
