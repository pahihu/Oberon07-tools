MODULE O7Depends;
  IMPORT Depends, RedirFiles, Oberon;

  PROCEDURE Scan*;
  BEGIN Depends.Scan
  END Scan;

  PROCEDURE Build*;
  BEGIN Depends.Build
  END Build;

  PROCEDURE Rebuild*;
  BEGIN Depends.Rebuild
  END Rebuild;

  PROCEDURE Clean*;
  BEGIN Depends.Clean
  END Clean;

  PROCEDURE Help*;
  BEGIN Depends.Help
  END Help;

BEGIN RedirFiles.Init("~/.o7.red"); Oberon.Run
END O7Depends.

(* vim:set ts=2 sw=2 et: *)
