#!/bin/bash
unset LDFLAGS
unset CPPFLAGS
###
MAIN=$1
if [ -s "$MAIN.mk" ];
then
  shift
  TGT=$1
else
  TGT=$MAIN
  MK=$(ls *.mk | head -1)
  MAIN=$(basename $MK .mk)
fi
ARGS=$*
echo "MAIN=$MAIN"
echo " TGT=$TGT"
echo "ARGS=$*"
###
RTDIR=${OCG_RUNTIME_DIR}/cortexm
if [ -z "$ARGS" ];
then
  make -f $MAIN.mk LDSCRIPT=$RTDIR/memmap.gnu EXTRA_OBJS=$RTDIR/coro.o STARTUP_OBJS=$RTDIR/vectors.o
else
  make -f $MAIN.mk LDSCRIPT=$RTDIR/memmap.gnu EXTRA_OBJS=$RTDIR/coro.o STARTUP_OBJS=$RTDIR/vectors.o "$ARGS"
fi
if [ "X$TGT" = "X" ];
then
  elf2bin.sh $MAIN
fi
if [ "$TGT" = "clobber" ];
then
  rm -f *.o *.map *.list *.sym *.bin Oberon.Log
fi
