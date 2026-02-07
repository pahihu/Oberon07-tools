MODULE X; 
	(* (2.6) recursive import: OK *)
	(* IMPORT X; *)

  (* (2.8) redeclaration of predeclared identifiers: OK *)
	TYPE
		INTEGER* = LONGINT;

END X.
