BEGIN \
{
    # MOD is the module name

    # parser states
    PARSECODE = 1;  # search for "code"
    EMIT = 2;       # store LST
    COMMANDS = 3;   # skip
    # ###
    POS = 4;
    # ###
    PROF = 5;       # optional modules.prof
    # ###
    SRC = 6;
    
    state = PARSECODE;
    last = 0;
    debug = 0;

    adjust["MUL"] = 33;
    adjust["DIV"] = 33;
    adjust["FAD"] = 3;
    adjust["FSB"] = 3;
    adjust["FML"] = 25;
    adjust["FDV"] = 26;
}

/###/ \
{
    state++;
    next;
}

{
    if (debug) printf "# state=%d\n", state;
    if (state == PROF) {
        # cnt adr ; module pc
        if ($4 == MOD) {
            if (debug) printf "# PROF %d %d\n", $5, $1;
            prof[$5] = $1;
        }
        next;
    }
    if (state == SRC) {
        # lno line
        lno = $1;
        line = substr($0, index($0, " "));
        print;
        if (lno in lno2pc) {
            pc = lno2pc[lno];
            for (i = last; i < pc; i++) {
                asmline = lst[i]
                if (i in prof) {
                    cnt = prof[i];
                    for (instr in adjust) {
                        if (index(asmline, instr))
                            cnt = cnt * adjust[instr];
                    }
                    pre = sprintf("%10d", cnt);
                } else {
                    pre = "          ";
                }
                printf "%s  %s\n", pre, asmline;
            }
            last = pc;
        }
        next;
    }
    if (state == POS) {
        # lno pc
        lno = $1; pc = $2;
        if ((pc >= 0) && (!(pc in pc2lno))) {
        # if (pc >= 0) {
            pc2lno[pc] = lno;
            lno2pc[lno] = pc;
            if (debug) printf "# POS %d %d\n", lno, pc;
        }
        next;
    }
    if (state == PARSECODE) {
        if ($1 == "code") {
            if (debug) printf "# CODE\n";
            state++;
        }
        next;
    }
    if (state == EMIT) {
        if ($1 == "commands:") {
            if (debug) printf "# COMMANDS\n";
            state++;
            next;
        }
        # lno line
        lno = $1;
        line = substr($0, index($0, " "));
        lst[lno] = line;
        if (debug) printf "# EMIT %d %s\n", lno, line;
        next;
    }
}
