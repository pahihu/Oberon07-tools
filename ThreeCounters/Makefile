.SUFFIXES:
.SUFFIXES: .Lola.txt .Mod.txt .v

SRC=Counter0.Lola.txt
VLOG=$(SRC:.Lola.txt=.v)

%.v: %.Lola.txt
	LSC Compile $</v $@

%.rsc: %.Mod.txt
	ORP Compile $<

%.dump: %.rsc
	ORTool DecObj $< > $@

all: Counter0.v Counter1.dump prom.mem

prom.mem: Counter1.rsc
	ORX WriteFile Counter1.rsc prom.mem

clean:
	$(RM) $(VLOG)
	$(RM) *.rsc *.smb *.dump prom.mem
	$(RM) Oberon.Log

# vim:set ts=4 sw=4 noet:
