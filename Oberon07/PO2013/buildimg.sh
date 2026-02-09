FILES="Blink.Mod \
Blink.rsc \
Curves.rsc \
Display.rsc \
Display.smb \
Draw.rsc \
Edit.rsc \
Files.smb \
Fonts.rsc \
Fonts.smb \
GraphTool.rsc \
GraphicFrames.rsc \
Graphics.rsc \
Hilbert.Mod \
Hilbert.rsc \
Input.rsc \
Input.smb \
Kernel.smb \
MenuViewers.rsc \
MenuViewers.smb \
Modules.smb \
Net.rsc \
ORB.rsc \
ORG.rsc \
ORP.rsc \
ORS.rsc \
ORTool.rsc \
Oberon.rsc \
Oberon.smb \
PCLink1.rsc \
RS232.rsc \
RS232.smb \
Rectangles.rsc \
SCC.rsc \
Sierpinski.Mod \
SmallPrograms.Mod \
Stars.Mod \
Stars.rsc \
System.rsc \
TextFrames.rsc \
TextFrames.smb \
Texts.rsc \
Texts.smb \
Tools.Mod \
Viewers.rsc \
Viewers.smb"

make
./mk.sh build

echo "copying RISC.img..."
cp ../riscw/RISC-11.12.2018.img.gz RISC.img.gz
gunzip RISC.img.gz

echo "checking files..."
for f in RISC.img Modules.bin $FILES 
do
  src=$f
  nm=$(basename $f .Mod)
  if [ "$nm.Mod" = "$f" ];
  then
    src=$nm.Mod.txt
  fi
  if [ ! -s $src ];
  then
    echo "$f not found"
    exit 1
  fi
done

echo "deleting old files from image..."
for f in $FILES
do
  ../POSystem DeleteFiles "$f"
done

echo "copying new files to image..."
for f in $FILES
do
  nm=$(basename $f .Mod)
  src=$f
  dst=$f
  ismod=0
  if [ "$nm.Mod" = "$f" ];
  then
    awk 'sub("$", "\r")' $nm.Mod.txt > $f
    src=$f
    ismod=1
  fi
  if [ ! -s $src ];
  then
    echo "$f not found"
    exit 1
  fi
  ../POSystem CopyTo "$src => $dst"
  if [ $ismod -eq 1 ];
  then
    rm $src
  fi
done

echo "writing inner core (Modules.bin)..."
../ORL Load Modules.bin RISC.img

# vim:set ts=2 sw=2 et:
