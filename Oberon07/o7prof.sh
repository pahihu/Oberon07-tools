#!/bin/sh

if [ $# -ne 1 ];
then
  echo "usage: o7prof <module>"
  exit 1
fi
MOD=$1

omake $MOD.map
omake profile.out

cat $MOD.map >prof.inp

echo "###" >>prof.inp
cat profile.out >>prof.inp

awk -f $O7DIR/Oberon07/o7prof.awk prof.inp | tee modules.prof

rm -f prof.inp
