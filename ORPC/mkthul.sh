#!/bin/bash
unset LDFLAGS
unset CPPFLAGS
###
MAIN=$1
shift
if [ -s $MAIN.mk ];
then
  TGT=$1
else
  TGT=$MAIN
  MK=$(ls *.mk | head -1)
  MAIN=$(basename $MK .mk)
fi
echo "MAIN=$MAIN"
echo " TGT=$TGT"
###
make -f $MAIN.mk LDSCRIPT=$OCG_RUNTIME_DIR/cortexm/memmap.gnu STARTUP_OBJS=$OCG_RUNTIME_DIR/cortexm/vectors.o $TGT
if [ "X$TGT" = "X" ];
then
  elf2bin.sh $MAIN
fi
if [ "$TGT" = "clobber" ];
then
  rm -f *.o *.map *.list *.sym *.bin Oberon.Log
fi
