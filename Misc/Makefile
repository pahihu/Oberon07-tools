.SUFFIXES:
.SUFFIXES: .Mod

O2C=o2c
O2EF=o2ef
O2CFLAGS=-M

MODS=Hello.Mod Fib.Mod Sizes.Mod TestENTIER.Mod TestInt.Mod TestInt1.Mod
BINS=$(MODS:.Mod=$(EXE))

%$(EXE): %.Mod
	$(O2C) $(DYNEXPORT) $(O2CFLAGS) $(basename $@) | $(O2EF)

all: $(BINS)

clean:
	$(RM) sym/* obj/*
	$(RM) $(BINS)
	$(RM) Oberon.Log
