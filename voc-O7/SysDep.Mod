MODULE SysDep;
    IMPORT IntStr, ConvTypes, Sys := System;

    PROCEDURE IntToStr*(x: Sys.Integer; VAR s0: ARRAY OF CHAR);
    BEGIN IntStr.Give(s0, x, 0, ConvTypes.left)
    END IntToStr;

END SysDep.
