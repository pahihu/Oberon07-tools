MODULE Records;
TYPE Base* = RECORD x*: INTEGER END;
  Derived* = RECORD (Base) y*: INTEGER END;
  P* = POINTER TO Base;
  Q* = POINTER TO Derived;
  Callback* = PROCEDURE (x: INTEGER): INTEGER;
  Text* = ARRAY 16 OF CHAR;
VAR p*: P; q*: Q; b*: Base; d*: Derived; result*: INTEGER;
  text*: Text; cb*: Callback;
PROCEDURE Apply*(f: Callback; x: INTEGER): INTEGER;
RETURN f(x)
END Apply;
PROCEDURE Inc*(x: INTEGER): INTEGER;
RETURN x+1
END Inc;
PROCEDURE SetBase*(VAR r: Base);
BEGIN r.x := 7
END SetBase;
PROCEDURE Test*;
VAR local: Derived; a, z: ARRAY 2 OF Derived;
BEGIN NEW(q); q.x := 5; q.y := 9; p := q;
  result := 0;
  IF p IS Q THEN result := p(Q).y END;
  SetBase(q^); result := result + q.x;
  CASE p OF Q: result := result + p.y | P: result := -100 END;
  cb := Inc; result := result + Apply(cb, 2);
  d.x := 3; d.y := 4; b := d;
  local := d; a[0] := local; z := a;
  result := result + b.x + z[0].y;
  text := "abc";
  IF text = "abc" THEN INC(result) END
END Test;
END Records.
