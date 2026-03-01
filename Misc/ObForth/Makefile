.SUFFIXES:
.SUFFIXES: .Mod

O2C=o2c
O2EF=o2ef
# O2CFLAGS=-MOsR
O2CFLAGS=-MOs

MODS=ObForth.Mod
BINS=$(MODS:.Mod=$(EXE))

%$(EXE): %.Mod
	$(O2C) $(DYNEXPORT) $(O2CFLAGS) $(basename $@) | $(O2EF)

all: SerIO.Mod $(BINS)

test: ObForth$(EXE) test.fo
	./ObForth < test.fo

SerIO.Mod: UnixIO.Mod
	cp $< $@

clean:
	$(RM) sym/* obj/*
	$(RM) SerIO.Mod $(BINS)
	$(RM) Oberon.Log

###
ObForth$(EXE): ObForth.Mod UnixIO.Mod VFC.Mod Logic.Mod

# vim:set ts=2 sw=2 noet:
