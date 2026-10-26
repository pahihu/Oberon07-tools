#!/bin/bash
opsys=$(uname -o)
PYTHONEXE=python3
if [ "$opsys" = "Msys" ];
then
  PYTHONEXE=python
fi
${PYTHONEXE} $O7DIR/Oberon07/oberon07_sloc.py $*
