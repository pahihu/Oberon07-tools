.SUFFIXES:
.SUFFIXES: .Mod .Mod.txt .rsc .dump

O2C=o2c
O2EF=o2ef
O2CFLAGS=-M

MODS=OSP.Mod ORTool0.Mod
BINS=$(MODS:.Mod=$(EXE))

%$(EXE): %.Mod
	$(O2C) $(DYNEXPORT) $(O2CFLAGS) $(basename $@) | $(O2EF)

%.rsc: %.Mod.txt
	./OSP Compile $</x

%.dump: %.rsc
	./ORTool0 DecObj $< > $@


all: $(BINS) IO.dump TestOberon0.dump Permutation.dump Fib.dump

run: ORTool0$(EXE) IO.rsc TestOberon0.rsc
	./ORTool0 Execute IO.rsc TestOberon0.rsc

clean:
	$(RM) sym/* obj/*
	$(RM) $(BINS)
	$(RM) *.rsc *.dump
	$(RM) Oberon.Log

###
IO.rsc: OSP$(EXE) IO.Mod.txt
TestOberon0.rsc: OSP$(EXE) TestOberon0.Mod.txt
TestOberon0.dump: ORTool0$(EXE) TestOberon0.rsc
Permutation.rsc: OSP$(EXE) Permutation.Mod.txt
Fib.rsc: OSP$(EXE) Fib.Mod.txt
include Makefile.dep

# vim:set ts=4 sw=4 noet:
