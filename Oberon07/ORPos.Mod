MODULE ORPos;
  IMPORT ORS, ORB, ORG, Files, Texts, Oberon;

  VAR
    isOpen: BOOLEAN;
    T: Texts.Text;
    W: Texts.Writer;

  PROCEDURE Open*(modid: ORS.Ident);
    VAR fname: ORS.Ident;
        res: INTEGER;
        F: Files.File;
  BEGIN
    ORB.MakeFileName(fname, modid, ".pos");

    Files.Delete(fname, res);
    F := Files.New(fname); Files.Register(F); Files.Close(F);

    NEW(T); Texts.Open(T, fname);
    Texts.OpenFileWriter(W, T.base);
    isOpen := TRUE
  END Open;

  PROCEDURE Close*;
  BEGIN
    IF isOpen THEN
      Texts.Append(T, W.buf); Texts.Close(T)
    END
  END Close;

  PROCEDURE EmitPosition*;
  BEGIN
    IF isOpen THEN
      Texts.WriteLn(W); Texts.WriteInt(W, ORS.lineNo, 0); Texts.WriteString(W, " "); Texts.WriteInt(W, ORG.pc, 0);
      Texts.Append(T, W.buf)
    END
  END EmitPosition;

BEGIN isOpen := FALSE
END ORPos.
(* vim:set ts=2 sw=2 et: *)
