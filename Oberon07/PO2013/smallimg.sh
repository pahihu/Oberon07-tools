#
# strip FAT partition from RISC.img
# skip 80002H blocks
#
if [ ! -s RISC.img ];
then
  echo "RISC.img not found"
  exit 1
fi
dd if=RISC.img of=SMALL.img bs=512 skip=524290

