MODULE Tracer;
  IMPORT Files, Points, Surfaces, Spheres, RayUtils,
         IntStr, RealStr, ConvTypes;

  TYPE
    List = POINTER TO ListDesc;
	  ListDesc = RECORD 
      obj: Surfaces.Surface;
      next: List;
    END;

  VAR world: List;
	    eye: Points.Point;

  PROCEDURE FirstHit(VAR pt: Points.Point; VAR r: RayUtils.Vector;
                     VAR surface: Surfaces.Surface; VAR hit: Points.Point);
    VAR s: Surfaces.Surface;
	      h: Points.Point;
	      d, dist: LONGREAL;
	      p: List;
  BEGIN surface := NIL; p := world; dist := MAX(LONGREAL);
    WHILE p # NIL DO
      s := p.obj;
	    IF s.Intersect(pt, h, r) THEN
	      d := h.QuasiDistance(pt);
	      IF d < dist THEN
	        surface :=  s; hit := h; dist := d;
	      END
	    END;
	    p := p.next
    END
  END FirstHit;

  PROCEDURE Max(a, b: LONGREAL): LONGREAL;
    VAR ret: LONGREAL;
  BEGIN ret := a; IF b > a THEN ret := b END;
    RETURN ret
  END Max;

  PROCEDURE Lambert(s: Surfaces.Surface; int: Points.Point;
						   VAR r: RayUtils.Vector): LONGREAL;
    VAR n: RayUtils.Vector;
  BEGIN s.Normal(int, n);
    RETURN Max(0, r.x * n.x + r.y * n.y + r.z * n.y)
  END Lambert;


  PROCEDURE SendRay(VAR pt: Points.Point; VAR r: RayUtils.Vector): LONGREAL;
    VAR s: Surfaces.Surface;
	  int: Points.Point;
	  ret: LONGREAL;
  BEGIN ret := 0.0;
    FirstHit(pt, r, s, int);
    IF s # NIL THEN
      ret := Lambert(s, int, r) * s.color
    END;
    RETURN ret
  END SendRay;

  PROCEDURE Round(a: LONGREAL): LONGREAL;
  BEGIN RETURN ENTIER(a + 0.5D0) + 0.0D0
  END Round;

  PROCEDURE ColorAt(x, y: LONGREAL):INTEGER;
    VAR r: RayUtils.Vector;
  BEGIN RayUtils.UnitVector(x - eye.x, y - eye.y, 0.0 - eye.z, r);
    (* NB. instead of passing 3 floats around, we can use the r vector *)
    RETURN SHORT(ENTIER(Round(SendRay(eye, r) * 255.0)))
  END ColorAt;

  PROCEDURE WriteChar(VAR r: Files.Rider; ch: CHAR);
  BEGIN Files.Write(r, ch)
  END WriteChar;

  PROCEDURE WriteString(VAR r: Files.Rider; txt: ARRAY OF CHAR);
    VAR i: LONGINT;
  BEGIN i := 0; WHILE txt[i] # 0X DO WriteChar(r, txt[i]); INC(i) END
  END WriteString;

  PROCEDURE WriteLReal(VAR r: Files.Rider; x: LONGREAL);
    VAR txt: ARRAY 64 OF CHAR;
  BEGIN RealStr.GiveFloat(txt, x, 3, 0, ConvTypes.right); WriteString(r, txt)
  END WriteLReal;

  PROCEDURE WriteReal(VAR r: Files.Rider; x: REAL);
  BEGIN WriteLReal(r, LONG(x))
  END WriteReal;

  PROCEDURE WriteLInt(VAR r: Files.Rider; i: LONGINT);
    VAR txt: ARRAY 30 OF CHAR;
  BEGIN IntStr.Give(txt, i, 0, ConvTypes.right); WriteString(r, txt)
  END WriteLInt;

  PROCEDURE WriteInt(VAR r: Files.Rider; i: INTEGER);
  BEGIN WriteLInt(r, LONG(i))
  END WriteInt;

  PROCEDURE Ln(VAR r: Files.Rider);
  BEGIN
    WriteChar(r, CHR(13)); WriteChar(r, CHR(10));
  END Ln;

  PROCEDURE WriteHeader(VAR r:Files.Rider; res:LONGINT);
  BEGIN
    WriteString(r, "P2 ");
    WriteLInt(r, 100 * res);
    WriteChar(r, " ");
    WriteLInt(r, 100 * res);
    WriteString(r, " 255");
    Ln(r);
  END WriteHeader;


  PROCEDURE WriteColor(VAR r: Files.Rider; c: INTEGER);
  BEGIN WriteInt(r, c); Ln(r)
  END WriteColor;

  PROCEDURE Trace*(path: ARRAY OF CHAR; res: LONGINT);
    VAR f: Files.File; r: Files.Rider;
	  inc: LONGREAL;
	  x,y: LONGREAL;
	  c: INTEGER;
  BEGIN f := Files.New(path); Files.Set(r, f, 0);
    WriteHeader(r, res);
    inc := 1.0D0 / (res + 0.0D0);
    y := -50.0D0;
    WHILE (50.0D0 - y) >= inc DO
      x := -50.0D0;
	WHILE (50.0D0 - x) >= inc DO
	  c := ColorAt(x, y);
	  WriteColor(r, c);
	  x := x + inc
	END;
	y := y + inc
    END;
    Files.Register(f)
  END Trace;


  PROCEDURE DefSphere*(x, y, z, r, c: LONGREAL);
    VAR s: Spheres.Sphere;
	  node: List;
  BEGIN s := Spheres.Make(x, y, z, r, c);
    NEW(node);
    node.obj := s;
    node.next := world;
    world := node
  END DefSphere;


  PROCEDURE SetEye*(x, y, z: LONGREAL);
  BEGIN eye.Init(x, y, z)
  END SetEye;


BEGIN world := NIL
END Tracer.
