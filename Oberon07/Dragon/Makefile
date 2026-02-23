.SUFFIXES:
.SUFFIXES: .Mod.txt .rsc .dump


MODS=OSP.Mod ORTool0.Mod
BINS=$(MODS:.Mod=$(EXE))

%.rsc: %.Mod.txt
	ORP Compile $<

%.dump: %.rsc
	ORTool0 DecObj $< > $@


all: IO.dump Fib.dump

run: IO.rsc Fib.rsc
	ORTool0 Execute IO.rsc Fib.rsc

clean:
	$(RM) *.smb *.rsc *.dump
	$(RM) Oberon.Log

###
IO.rsc: IO.Mod.txt
Fib.rsc: Fib.Mod.txt

# vim:set ts=4 sw=4 noet:
