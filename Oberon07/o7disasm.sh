#!/bin/sh
if [ $# -eq 0 ] || [ $# -gt 2 ];
then
  echo "usage: o7disasm.sh <module> [<map>]"
  exit 1
fi
MOD=$1
MAP=$(ls *.map)
if [ ! -z "$2" ];
then
  MAP=$2
fi

opsys=$(uname -o)
AWK=awk
if [ "$opsys" = "Darwin" ];
then
  AWK=gawk
fi

omake $MOD.lst
c0de=$(grep $MOD $MAP | head -1 | $AWK '{print $4;}')

### DecObj file
cat $MOD.lst >match.inp

### position to pc mapping
echo "###" >>match.inp
cat $MOD.pos >>match.inp

### optional modules profile
echo "###" >>match.inp

if [ -s modules.prof ];
then
  cat modules.prof >>match.inp
fi

### source with line numbers
MODNAME=$MOD.Mod
if [ ! -s $MODNAME ];
then
  MODNAME=$MOD.Mod.txt
fi

echo "###" >>match.inp

$AWK -f $O7DIR/Oberon07/lineno.awk $MODNAME >$MOD.lno
cat $MOD.lno >>match.inp

### process
$AWK -f $O7DIR/Oberon07/o7disasm.awk -v MOD=$MOD -v C0DE=$c0de match.inp

rm -f match.inp
rm -f $MOD.lno

