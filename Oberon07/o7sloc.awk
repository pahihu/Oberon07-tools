BEGIN \
{
}

/^[\t\r\n ]*$/ \
{
    next;
}

/\(\*/ \
{
    nest++;
}

/\*\)/ \
{
    nest--;
}

{
    sub("[ ]*\\(\\*[^*()]*\\*\\)[ ]*", "");
    if (nest) next;
    if (match($0, /\*\)/)) next;
    # gsub(";[ ]", ";\n");
    print $0;
}
