(* basic template file for Oberon-07 *)

MODULE HelloWorld;
  IMPORT Main, Out;

  PROCEDURE Run;
  BEGIN
    Out.Ln; Out.String("hello world")
  END Run;
  
BEGIN Run
END HelloWorld.
