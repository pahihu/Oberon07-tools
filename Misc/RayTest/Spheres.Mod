MODULE Spheres;

  IMPORT RayUtils,Points,Surfaces;

  TYPE
    Sphere*    = POINTER TO SphereDesc;
    SphereDesc = RECORD (Surfaces.SurfaceDesc)
      radius*: LONGREAL;
      center*: Points.Point;
    END;

  PROCEDURE Make*(x, y, z, r, c:LONGREAL): Sphere;
    VAR s: Sphere;
  BEGIN NEW(s);
    s.radius := r;
    s.center.Init(x, y, z);
    s.color := c;
    RETURN s
  END Make;


  PROCEDURE (s:Sphere) Intersect*(VAR pt: Points.Point; VAR out: Points.Point; VAR r: RayUtils.Vector): BOOLEAN;
    VAR xdist, ydist, zdist: LONGREAL;
	  n: LONGREAL;
        ret: BOOLEAN;
  BEGIN ret := FALSE;
    xdist := pt.x - s.center.x;
    ydist := pt.y - s.center.y;
    zdist := pt.z - s.center.z;
    n := RayUtils.MinRoot(RayUtils.Square(r.x) + RayUtils.Square(r.y) + RayUtils.Square(r.z),
			   2.0 * (r.x * xdist + r.y * ydist + r.z * zdist),
			   RayUtils.Square(xdist) + RayUtils.Square(ydist) + RayUtils.Square(zdist)
					             - RayUtils.Square(s.radius));
    IF n >= 0.0 THEN
      out.Init(pt.x + n * r.x, pt.y + n * r.y, pt.z + n * r.z);
      ret := TRUE
    END;
    RETURN ret
  END Intersect;


  PROCEDURE (s:Sphere) Normal*(VAR pt:Points.Point; VAR out:RayUtils.Vector);
  BEGIN RayUtils.UnitVector(s.center.x - pt.x, s.center.y - pt.y, s.center.z - pt.z, out)
  END Normal;


END Spheres.
