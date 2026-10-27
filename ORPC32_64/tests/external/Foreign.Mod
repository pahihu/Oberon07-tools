MODULE Foreign;
TYPE Transform* = PROCEDURE (x: INTEGER): INTEGER;
PROCEDURE SetValue* ["MyLib_SetValue"] (x: INTEGER);
PROCEDURE GetValue* ["MyLib_GetValue"] (): INTEGER;
PROCEDURE Add* ["MyLib_Add"] (a, b: INTEGER): INTEGER;
PROCEDURE Twice* ["MyLib_Twice"] (x: INTEGER): INTEGER;
PROCEDURE Adjust* ["MyLib_Adjust"] (VAR x: INTEGER; amount: INTEGER);
PROCEDURE Sum* ["MyLib_Sum"] (values: ARRAY OF INTEGER): INTEGER;
PROCEDURE Scale* ["MyLib_Scale"] (x: REAL): REAL;
PROCEDURE CApply* ["MyLib_Apply"] (f: Transform; x: INTEGER): INTEGER;
PROCEDURE GetCallback* ["MyLib_GetCallback"] (): Transform;
PROCEDURE Touch* ["MyLib_Touch"];
PROCEDURE Local ["MyLib_Local"] (x: INTEGER): INTEGER;
PROCEDURE Apply*(f: Transform; x: INTEGER): INTEGER;
RETURN f(x)
END Apply;
PROCEDURE CheckLocal*;
BEGIN ASSERT(Local(3)=12)
END CheckLocal;
BEGIN SetValue(5); Touch
END Foreign.
