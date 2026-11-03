#!/bin/bash
if [ $# -ne 1 ];
then
  echo "usage: thulrun.sh <module>"
  exit 1
fi
###
MOD=$1
FREQ=12000000
###
if [ -s "$MOD.sym" ];
then
  SYM="-m $MOD.sym"
fi
###
${OCG_RUNTIME_DIR}/thumbulator.exe -f $FREQ $SYM $MOD.bin

# vim:set ts=2 sw=2 et:
