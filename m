rm -f obj/* sym/* lib/System.Mod
rm -f .env

if [ $# -eq 0 ];
then
  echo "clean"
  exit 0
fi
###
SYSMOD="lib/System$1.Mod"
if [ ! -s $SYSMOD ];
then
  echo "cannot read $SYSMOD"
  exit 1
fi
echo "O2CARCH=$1" > .env
cp $SYSMOD lib/System.Mod
###
MODULES="System.Mod \
    Args.Mod \
    Texts.Mod \
    Oberon.Mod \
    Files07.Mod"
#
for m in $MODULES
do
    o2c $m | o2ef
done

