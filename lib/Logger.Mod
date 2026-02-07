MODULE Logger;
  IMPORT Unix;
  
  PROCEDURE Log* (s: ARRAY OF CHAR);
    VAR rc: LONGINT;
  BEGIN rc := Unix.fputs (s, Unix.stderr);
    rc := Unix.fputc (13, Unix.stderr);
    rc := Unix.fputc (10, Unix.stderr);
  END Log;
  
END Logger.