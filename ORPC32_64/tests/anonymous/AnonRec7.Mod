MODULE AnonRec7;
  TYPE
    AnonList* = POINTER TO RECORD
      key*: INTEGER;
      next*: AnonList
    END ;
    List* = POINTER TO ListDesc;
    ListDesc* = RECORD
      key*: INTEGER;
      next*: List
    END ;
END AnonRec7.
(* vim:set ts=2 sw=2 et:*)
