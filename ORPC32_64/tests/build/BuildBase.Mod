MODULE BuildBase;
VAR order*: INTEGER;
PROCEDURE Advance*(expected: INTEGER);
BEGIN ASSERT(order=expected); INC(order)
END Advance;
BEGIN order := 1
END BuildBase.
