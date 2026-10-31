#!/bin/bash
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
RTDIR=${OCG_RUNTIME_DIR}/host
make -f $MAIN.mk EXTRA_OBJS=$RTDIR/host.o $TGT
if [ "$TGT" = "clobber" ];
then
  rm -f *.log Oberon.Log
fi
