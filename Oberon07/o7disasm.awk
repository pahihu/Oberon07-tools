BEGIN \
{
    # MOD is the module name
    # C0DE is the beginning of the module code in hex
    C0DE = hex2int(C0DE);

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

func hex2int(s ,i,ret)
{
    ret = 0;
    s = toupper(s);
    for (i = 1; i <= length(s); i++) {
        ret = 16 * ret + index("0123456789ABCDEF", substr(s,i,1)) - 1;
    }
    return ret;
}

func printasm(pc ,i,asmline,cnt,instr,pre)
{
    for (i = last; i < pc; i++) {
        asmline = lst[i];
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
        printf "%s  %05X   %s\n", pre, C0DE + i * 4, asmline;
    }
    last = pc;
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
            printasm(pc);
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
        line = substr($0, index($0, lno) + length(lno));
        sub("[\t ]*","",line);
        lst[lno] = line;
	    # 261011AP track last pc
        if (lastAdr < lno) lastAdr = lno;
        if (debug) printf "# EMIT %d %s\n", lno, line;
        next;
    }
}

END \
{
    printasm(lastAdr + 1);
}
# vim:set ts=4 sw=4 et:
