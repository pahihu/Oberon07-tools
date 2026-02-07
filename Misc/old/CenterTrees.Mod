MODULE CenterTrees;
IMPORT Trees, Out;

TYPE
    CenterTree* = POINTER TO CenterNode;
    CenterNode* = RECORD (Trees.Node)
        width: INTEGER;
        subnode: Trees.Tree
    END;
    
PROCEDURE (t: CenterTree) Insert (node: Trees.Tree);  (*redefinition*)
BEGIN
    Out.Int (node(CenterTree).width, 0);
    t.Insert^ (node)
END Insert;

END CenterTrees.