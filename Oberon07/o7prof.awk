BEGIN \
{
    readmap = 1;
    doread = 0;
    # mod[name] = beg;
}

/###/ \
{
    readmap = 0;
    for (nm in mods) revmods[mods[nm]] = nm;
    next;
}

(NF > 0) \
{
    if (readmap) {
        if ($1 == "linking") {
            doread = 1;
        } else if (index(",initializing,total", "," $1)) {
            doread = 0;
        } else {
            mods[$1] = 0 + ("0x" $4);
        }
        next;
    }
    cnt = $1; where = $2; pos = 0 + ("0x" $2);
    # printf "processing %s\n", $0;
    base = 0;
    for (nm in mods) {
        if (pos >= mods[nm]) {
            if (mods[nm] > base) base = mods[nm];
        }
    }
    printf "%10d  %s ; %s %d\n", cnt, where, revmods[base], (pos - base) / 4;
}

END \
{
    if (debug) {
        for (nm in mods) {
            printf "%s %d\n", nm, mods[nm];
        }
    }
}
