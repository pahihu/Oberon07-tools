MODULE RedirFiles;
  IMPORT Redir, Files, Out;
  
  TYPE Path = ARRAY 256 OF CHAR;
  VAR pat: Redir.Pattern;
      debug*: BOOLEAN;
  
  PROCEDURE FindOld*(VAR name: ARRAY OF CHAR): BOOLEAN;
    VAR path: Path;
        found: BOOLEAN;
  BEGIN
    IF pat # NIL THEN
      IF debug THEN Out.String(" RedirFiles.Old("); Out.String(name); Out.String(") => "); END;
      path[0] := 0X;
      found := Redir.FindPath(pat, name, path);
      IF found THEN COPY(path, name); IF debug THEN Out.String(name) END;
      ELSE IF debug THEN Out.String(" not found ") END
      END;
      IF debug THEN Out.Ln END
    END;
    RETURN found
  END FindOld;

  PROCEDURE Old*(name: ARRAY OF CHAR): Files.File;
    VAR found: BOOLEAN;
  BEGIN found := FindOld(name); RETURN Files.Old(name)
  END Old;
  
  PROCEDURE New*(name: ARRAY OF CHAR): Files.File;
    VAR path: Path;
  BEGIN
    IF pat # NIL THEN
      IF debug THEN Out.String(" RedirFiles.New("); Out.String(name); Out.String(") => ") END;
      path[0] := 0X;
      Redir.GeneratePath(pat, name, path);
      COPY(path, name);
      IF debug THEN Out.String(name); Out.Ln END
    END;
    RETURN Files.New(name)
  END New;
  
  PROCEDURE Init*(name: ARRAY OF CHAR);
  BEGIN pat := Redir.Read(name)
  END Init;
  
BEGIN pat := NIL; debug := FALSE;
END RedirFiles.
