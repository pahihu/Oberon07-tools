.SUFFIXES:
.SUFFIXES: .Mod

O2C=o2c
O2EF=o2ef
O2CFLAGS=-M

MODS=ORP.Mod ORTool.Mod ORX.Mod ORL.Mod O7Depends.Mod POSystem.Mod
BINS=$(MODS:.Mod=$(EXE))

%$(EXE): %.Mod
	$(O2C) $(DYNEXPORT) $(O2CFLAGS) $(basename $@) | $(O2EF)

all:
	@-echo "select compiler: make org (NW) or make numcase (AP)"

compiler:
	make $(BINS)

org: setup-org compiler
numcase: setup-numcase compiler

setup-org: clean
	ln -s ORG.NW.Mod ORG.Mod
	ln -s ORP.NW.Mod ORP.Mod

setup-numcase: clean
	ln -s ORG.AP.Mod ORG.Mod
	ln -s ORP.AP.Mod ORP.Mod

clean:
	$(RM) sym/* obj/*
	$(RM) $(BINS) ORL32$(EXE)
	$(RM) Oberon.Log
	$(RM) ORG.Mod ORP.Mod

O7Depends$(EXE): Depends.Mod

# vim:set ts=4 sw=4 noet:
