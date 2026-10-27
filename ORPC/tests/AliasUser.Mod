MODULE AliasUser;
IMPORT A := AliasClient;
VAR r*: A.Reexport;
BEGIN r.n := 3
END AliasUser.
