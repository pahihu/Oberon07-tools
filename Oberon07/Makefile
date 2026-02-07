.SUFFIXES:
.SUFFIXES: .Mod

O2C=o2c
O2EF=o2ef
O2CFLAGS=-M

MODS=ORP.Mod ORTool.Mod ORX.Mod ORL.Mod Depends.Mod POSystem.Mod
BINS=$(MODS:.Mod=$(EXE))

%$(EXE): %.Mod
	$(O2C) $(DYNEXPORT) $(O2CFLAGS) $(basename $@) | $(O2EF)

all: $(BINS)

clean:
	$(RM) sym/* obj/*
	$(RM) $(BINS) ORL32$(EXE)
	$(RM) Oberon.Log

# vim:set ts=4 sw=4 noet:
