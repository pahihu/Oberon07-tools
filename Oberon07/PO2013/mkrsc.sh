BUILD=$1
MODS=$(ls *.Mod.txt)
for mod in $MODS
do
  compile=0
  nm=$(basename $mod .Mod.txt)
  rsc="$nm.rsc"
  smb="$nm.smb"
  echo "-I-MKRSC: checking $mod"
  if [ ! -s $rsc ];
  then
    echo "-W-MKRSC: $rsc not found"
    compile=1
  elif [ $mod -nt $smb ];
  then
    echo "-W-MKRSC: $mod is newer than $smb"
  elif [ $rsc -nt $smb -o $smb -nt $rsc ];
  then
    echo "-W-MKRSC: $rsc and $smb are out of sync"
  fi
  if [ "X$BUILD" != "X" -a $compile -ne 0 ]; 
  then
    echo "-I-MKRSC: compiling $mod"
    make $rsc
  fi
done
