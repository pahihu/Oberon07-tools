MODULE Alias;
	(* (2.6) module name can be used for aliasing: OK *)
	IMPORT Alias := X;
	VAR i: Alias.INTEGER;
END Alias.
