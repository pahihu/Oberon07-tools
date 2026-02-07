MODULE Points;
  IMPORT RayUtils;

  TYPE Point* = RECORD
	   x*, y*, z*: LONGREAL
	 END;

  PROCEDURE (VAR pt: Point) Init*(x, y, z: LONGREAL);
  BEGIN pt.x := x; pt.y := y; pt.z := z;
  END Init;

  PROCEDURE (VAR pt1: Point) Distance*(VAR pt2:Point):LONGREAL;
  BEGIN RETURN RayUtils.Magnitude(pt1.x - pt2.x,
					 pt1.y - pt2.y,
					 pt1.z - pt2.z)
  END Distance;
  
  PROCEDURE (VAR pt1: Point) QuasiDistance*(VAR pt2:Point):LONGREAL;
  BEGIN RETURN  ABS(pt1.x - pt2.x) +
					      ABS(pt1.y - pt2.y) +
					      ABS(pt1.z - pt2.z)
  END QuasiDistance;

END Points.

