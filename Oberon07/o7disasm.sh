#!/bin/sh
if [ $# -ne 1 ];
then
  echo "usage: o7disasm.sh <module>"
  exit 1
fi
MOD=$1

omake $MOD.lst

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

awk -f $O7DIR/Oberon07/lineno.awk $MODNAME >$MOD.lno
cat $MOD.lno >>match.inp

### process
awk -f $O7DIR/Oberon07/o7disasm.awk -v MOD=$MOD match.inp

rm -f match.inp
rm -f $MOD.lno

