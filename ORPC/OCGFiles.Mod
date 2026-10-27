MODULE OCGFiles;
(* Publish generated text without changing timestamps when bytes are equal. *)
IMPORT Files := Files07;
PROCEDURE Publish*(name: ARRAY OF CHAR; VAR file: Files.File);
  VAR old: Files.File; a, b: Files.Rider; x, y: CHAR; equal: BOOLEAN;
BEGIN
  (* Set flushes the writer before comparing its temporary file. *)
  Files.Set(b, file, 0); old := Files.Old(name); equal := FALSE;
  IF old # NIL THEN
    Files.Set(a, old, 0); equal := Files.Length(old) = Files.Length(file);
    WHILE equal & ~b.eof DO
      Files.Read(a, x); Files.Read(b, y);
      equal := (a.eof = b.eof) & (a.eof OR (x = y))
    END;
    Files.Close(old)
  END;
  IF ~equal THEN Files.Register(file) END;
  Files.Close(file)
END Publish;
END OCGFiles.
