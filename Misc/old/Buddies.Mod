MODULE Buddies;
  IMPORT Objects, Out;

  TYPE
    Buddy* = POINTER TO BuddyDesc;
    BuddyDesc* = RECORD (Objects.ObjectDesc)
      i: LONGINT;
    END;

  PROCEDURE (this: Buddy) Copy*(): Objects.Object; (** copy Buddy *)
    VAR other: Buddy;
  BEGIN NEW(other); other.i := this.i; RETURN other
  END Copy;

  PROCEDURE (this: Buddy) Equals*(other: Objects.Object): BOOLEAN; (** test Buddy FOR equality *)
    VAR ret: BOOLEAN;
  BEGIN ret := FALSE;
    WITH other:Buddy DO
      ret := this.i = other.i
    END;
    RETURN ret
  END Equals;

  PROCEDURE (this: Buddy) Print*;
  BEGIN Out.String('aBuddy [i='); Out.Int(this.i, 0); Out.String(']')
  END Print;

  PROCEDURE New*(i: LONGINT): Buddy; (** make new Buddy *)
    VAR obj: Buddy;
  BEGIN NEW(obj); obj.i := i; RETURN obj
  END New;

END Buddies.
