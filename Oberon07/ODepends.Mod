MODULE ODepends;
  IMPORT Depends, RedirFiles, Oberon;

  PROCEDURE Scan*;
  BEGIN Depends.Scan
  END Scan;

  PROCEDURE Help*;
  BEGIN Depends.Help
  END Help;

BEGIN Oberon.Run
END ODepends.

(* vim:set ts=2 sw=2 et: *)
