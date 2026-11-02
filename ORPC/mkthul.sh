#!/bin/bash
opsys=$(uname -o)
unset LDFLAGS
unset CPPFLAGS
###
i=1
CC=1
while [ $i -le $# ];
do
    eval "value=\$$i"
    case "$value" in
    -nocc)
        CPPFLAGS="-DOCG_CORTEX_M_CC=0"
        CC=0
        shift
        ;;
    esac
    i=$(expr $i + 1)
done
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
###
SYSTICK=$(grep -q Timers *.Mod && echo 1 || echo 0)
MAINDBG=$(grep -q MainDebug *.Mod && echo 1 || echo 0)
###
echo "----------------"
echo "MAIN   =$MAIN"
echo "TGT    =$TGT"
echo "ARGS   =$*"
echo "CC     =$CC"
echo "SYSTICK=$SYSTICK"
echo "MAINDBG=$MAINDBG"
echo "----------------"
###
RTDIR=${OCG_RUNTIME_DIR}/cortexm
CPPRTDIR=$RTDIR
if [ "$opsys" = "Msys" ];
then
  CPPRTDIR=$(echo $RTDIR | cut -c 3-)
fi
###
rm -f $RTDIR/vectors.o
###
CPPFLAGS="-fno-delete-null-pointer-checks $CPPFLAGS"
if [ $MAINDBG -eq 1 ];
then
  CPPFLAGS="-include $CPPRTDIR/ocg_trap_decl.h $CPPFLAGS"
else
  CPPFLAGS="$CPPFLAGS"
fi
###
if [ -z "$ARGS" ];
then
  make -f $MAIN.mk \
	  LDSCRIPT=$RTDIR/memmap.gnu \
	  EXTRA_OBJS=$RTDIR/coro.o \
	  STARTUP_OBJS=$RTDIR/vectors.o \
	  ASFLAGS="-Wa,--defsym,HAVE_OCG_IRQ_15_Handler=$SYSTICK" \
	  CPPFLAGS="$CPPFLAGS"
else
  make -f $MAIN.mk \
	  LDSCRIPT=$RTDIR/memmap.gnu \
	  EXTRA_OBJS=$RTDIR/coro.o \
	  STARTUP_OBJS=$RTDIR/vectors.o \
	  ASFLAGS="-Wa,--defsym,HAVE_OCG_IRQ_15_Handler=$SYSTICK" \
	  CPPFLAGS="$CPPFLAGS" \
	  "$ARGS"
fi
###
if [ -s "$MAIN" ] && [ ! -s "$MAIN.bin" -o "$MAIN.bin" -ot "$MAIN" ];
then
  elf2bin.sh $MAIN
fi
if [ "$TGT" = "clobber" ];
then
  rm -f *.o *.map *.list *.sym *.bin Oberon.Log
fi
