MODULE AnonRec2;
  TYPE
    Node* = POINTER TO RECORD
      value*: INTEGER;
      (*ERROR undef recursive named-pointer case?*)
      next*: Node
    END ;

    Node1* = POINTER TO Node1Desc;
    Node1Desc* = RECORD
      value*: INTEGER;
      next*: Node1
    END ;
    
    Container = RECORD
      p: POINTER TO RECORD
        next: POINTER TO RECORD
        x: INTEGER
        END
      END
    END ;
    P0* = POINTER TO RECORD
      i*: INTEGER;
      j: INTEGER
    END ;
    R1 = RECORD
      i*, j: INTEGER
    END ;
    P1* = POINTER TO R1;
    Base = RECORD END ;
    Q* = POINTER TO RECORD (Base)
      x: INTEGER
    END ;

  VAR
    p*, q*: POINTER TO RECORD
      i*: INTEGER
    END ;

BEGIN NEW(p); q := p
END AnonRec2.
(* vim:set ts=2 sw=2 et: *)
