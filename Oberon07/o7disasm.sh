#!/bin/sh
if [ $# -eq 0 ] || [ $# -gt 2 ];
then
  echo "usage: o7disasm.sh <module> [<map>]"
  exit 1
fi
###
opsys=$(uname -o)
AWK=awk
if [ "$opsys" = "Darwin" ];
then
  AWK=gawk
fi
###
MOD=$1
if [ ! -z "$2" ];
then
  MAP=$2
else
  MAP=$(ls *.map 2>/dev/null)
fi
### 261128AP remove the need for Makefile
if [ ! -s $MOD.rsc ];
then
  echo "$MOD.rsc not found"
  exit 1
fi
###
if [ ! -s $MOD.lst ] || [$MOD.rsc -nt $MOD.lst ];
then
  ORTool DecObj $MOD.rsc > $MOD.lst
fi
###
if [ -z "$MAP" ];
then
  c0de=0FFE000
  echo "warning: no .map file, assume PROM" 1>&2
else
  c0de=$(grep $MOD $MAP | head -1 | $AWK '{print $4;}')
fi

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

# vim:set ts=2 sw=2 et:
