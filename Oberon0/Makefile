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
	./OSP Compile $<

%.dump: %.rsc
	./ORTool0 DecObj $< > $@


all: $(BINS) TestOberon0.dump

clean:
	$(RM) sym/* obj/*
	$(RM) $(BINS)
	$(RM) *.rsc *.dump
	$(RM) Oberon.Log

###
TestOberon0.rsc: OSP$(EXE) TestOberon0.Mod.txt
TestOberon0.dump: ORTool0$(EXE) TestOberon0.rsc

