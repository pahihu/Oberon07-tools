MODULE BuildMain;
IMPORT L := BuildLeft, R := BuildRight, B := BuildBase, S := SYSTEM;
BEGIN B.Advance(3); ASSERT(B.order=4)
END BuildMain.
