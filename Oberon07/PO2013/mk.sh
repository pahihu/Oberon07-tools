BUILD=$1
MODS=$(ls *.Mod.txt)
for m in $MODS
do
  nm=$(basename $m .Mod.txt)
  rsc="$nm.rsc"
  if [ ! -s $rsc ];
  then
    echo "$rsc not found"
    if [ "X$BUILD" != "X" ];
    then
      make $rsc
    fi
  fi
done
