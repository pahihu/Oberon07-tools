MODULE RedirFiles;
  IMPORT Redir, Files, Out;
  
  VAR
    pat: Redir.Pattern;
  
  PROCEDURE Old*(name: ARRAY OF CHAR): Files.File;
    VAR path: ARRAY 256 OF CHAR;
        found: BOOLEAN;
  BEGIN
    IF pat # NIL THEN
      (*Out.String(" RedirFiles.Old("); Out.String(name); Out.String(") => ");*)
      path[0] := 0X;
      found := Redir.FindPath(pat, name, path);
      IF found THEN COPY(path, name); (*Out.String(name);*)
      (*ELSE Out.String(" not found ")*)
      END;
      (*Out.Ln*)
    END;
    RETURN Files.Old(name)
  END Old;
  
  PROCEDURE New*(name: ARRAY OF CHAR): Files.File;
    VAR path: ARRAY 256 OF CHAR;
  BEGIN
    IF pat # NIL THEN
      (*Out.String(" RedirFiles.New("); Out.String(name); Out.String(") => ");*)
      path[0] := 0X;
      Redir.GeneratePath(pat, name, path);
      COPY(path, name);
      (*Out.String(name); Out.Ln*)
    END;
    RETURN Files.New(name)
  END New;
  
  PROCEDURE Init*(name: ARRAY OF CHAR);
  BEGIN pat := Redir.Read(name)
  END Init;
  
BEGIN pat := NIL
END RedirFiles.