MODULE Surfaces;

  IMPORT Points,RayUtils;

  TYPE  Surface*     = POINTER TO SurfaceDesc; (* Surfaces *)
	  SurfaceDesc* = RECORD
          color*: LONGREAL;
        END;

  PROCEDURE (s:Surface) Intersect*(VAR pt:Points.Point; VAR out:Points.Point; VAR r:RayUtils.Vector): BOOLEAN;
  BEGIN RETURN FALSE
  END Intersect;

  PROCEDURE (s:Surface) Normal*(VAR pt:Points.Point; VAR out:RayUtils.Vector);
  BEGIN
  END Normal;

END Surfaces.
