MODULE Objects;
  IMPORT Out;

  TYPE
    Object* = POINTER TO ObjectDesc;
    ObjectDesc* = RECORD
    END;

  PROCEDURE (this: Object) Copy*(): Object;
    VAR other: Object;
  BEGIN NEW(other); RETURN other
  END Copy;

  PROCEDURE (this: Object) Equals*(other: Object): BOOLEAN;
  BEGIN RETURN this = other
  END Equals;

  PROCEDURE (this: Object) Print*;
  BEGIN Out.String('anObject')
  END Print;

END Objects.
