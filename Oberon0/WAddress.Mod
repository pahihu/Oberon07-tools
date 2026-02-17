MODULE WAddress;
  IMPORT Sys := System;

  TYPE
    LONGINT = Sys.INT32;
    INTEGER = Sys.INT32;

    ADDR* = RECORD
      a-: LONGINT;
    END;

  PROCEDURE (VAR w: ADDR) ToBytes*(): LONGINT;
  BEGIN RETURN w.a * 4
  END ToBytes;

  PROCEDURE (VAR w: ADDR) FromWords*(n: LONGINT);
  BEGIN w.a := n
  END FromWords;

  PROCEDURE (VAR w: ADDR) FromBytes*(a: LONGINT);
  BEGIN w.FromWords(a DIV 4)
  END FromBytes;

  PROCEDURE (VAR w: ADDR) Aligned*(a: LONGINT);
  BEGIN w.FromBytes(a + 3)
  END Aligned;

  PROCEDURE (VAR w: ADDR) Inc*(n: ADDR);
  BEGIN INC(w.a, n.a)
  END Inc;

  PROCEDURE (VAR w: ADDR) IncBy*(i: LONGINT);
  BEGIN INC(w.a, i)
  END IncBy;

  PROCEDURE (VAR w: ADDR) Dec*(n: ADDR);
  BEGIN DEC(w.a, n.a)
  END Dec;

  PROCEDURE (VAR w: ADDR) DecBy*(i: LONGINT);
  BEGIN DEC(w.a, i)
  END DecBy;

  PROCEDURE (VAR w: ADDR) Next*;
  BEGIN INC(w.a, 1)
  END Next;

  PROCEDURE (VAR w: ADDR) Prev*;
  BEGIN DEC(w.a, 1)
  END Prev;

END WAddress.

(* vim:set ts=2 sw=2 et: *)

