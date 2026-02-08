.SUFFIXES:
.SUFFIXES: .Mod .Mod.txt .a6m .a7m

O2C=o2c
O2EF=o2ef
O2CFLAGS=-M

# O7ARMv6MP Compile
# O7ARMv6MLinker Link
#
# O7ARMv7MP Compile
# O7ARMv7MTool DecObj DecSym DecBin DecHex
# O7ARMv7MLinker Link

MODS=O7ARMv6MP.Mod \
    O7ARMv7MP.Mod \
    O7ARMv7MTool.Mod \
    O7ARMv6MLinker.Mod \
    O7ARMv7MLinker.Mod
BINS=$(MODS:.Mod=$(EXE))

%$(EXE): %.Mod
	$(O2C) $(DYNEXPORT) $(O2CFLAGS) $(basename $@) | $(O2EF)

%.a7m: %.Mod.txt
	./O7ARMv7MP Compile $<

%.a6m: %.Mod.txt
	./O7ARMv6MP Compile $<

%.bin: %.a7m
	./O7ARMv7MLinker LPC1311 $(basename $<)

all: $(BINS) HelloWord.a7m MicroIEEE754.a6m

check: HelloWord.bin
	./O7ARMv7MTool DecBin $<

clean:
	$(RM) sym/* obj/*
	$(RM) *.smb *.a6m *.a7m *.bin *.hex
	$(RM) $(BINS)
	$(RM) Oberon.Log

# vim:set ts=4 sw=4 noet:

