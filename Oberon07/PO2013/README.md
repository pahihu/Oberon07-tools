# How to build a PO2013 image?

There files:

* `Makefile` builds the inner core (Modules.bin)
* `mkrsc.sh` without parameters it checks which modules has no corresponding .rsc files
  `mkrsc.sh build` compiles the .Mod.txt files without .rsc files
* `buildimg.sh` calls `make` `mk.sh build` then copies the base RISC5 image and deletes its contents.
  Then copies exactly the smae files from the recompiled sources and installs Modules.bin in the
  boot area.
- `smallimg.sh` removes the FAT partition from the SD card image RISC.img


# NOTES

Differences found during the compilation:
* prom.mem does NOT match the prom.mem in RISC5Verilog.zip@projectoberon.net
* Printer is commented out, needs Depends fix
    MacroTool	Printer Graphics
* V24 is missing
    ORC		V24
