MODULE Platform;
    IMPORT Unix;

    PROCEDURE Exit*(status: INTEGER);
    BEGIN Unix.exit(status)
    END Exit;

END Platform.
