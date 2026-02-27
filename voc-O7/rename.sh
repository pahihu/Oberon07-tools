for mod in *.Mod.txt
do
  nm=$(basename $mod .Mod.txt)
  mv $mod $nm.Mod
done
