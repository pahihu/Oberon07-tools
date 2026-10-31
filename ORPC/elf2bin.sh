#!/bin/bash
if [ $# -eq 0 ];
then
  echo "usage: elf2bin.sh <elf>"
  exit 1
fi

TGT=$1
BIN=$TGT.bin

ARMGNU=arm-none-eabi

${ARMGNU}-objdump -D $TGT > $TGT.list
${ARMGNU}-objdump -t $TGT > $TGT.map
awk -f ${O7DIR}/ORPC/cortexm/map2sym.awk $TGT.map > $TGT.sym
${ARMGNU}-objcopy $TGT $BIN -O binary
ls -l $BIN
