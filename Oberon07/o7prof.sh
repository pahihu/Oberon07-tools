#!/bin/sh

if [ $# -ne 1 ];
then
  echo "usage: o7prof <module>"
  exit 1
fi
MOD=$1

opsys=$(uname -o)
AWK=awk
if [ "$opsys" = "Darwin" ];
then
  AWK=gawk
fi

omake $MOD.map
omake profile.out

cat $MOD.map >prof.inp

echo "###" >>prof.inp
cat profile.out >>prof.inp

$AWK -f $O7DIR/Oberon07/o7prof.awk prof.inp | tee modules.prof

rm -f prof.inp
