.SUFFIXES:
.SUFFIXES: .bin .smb .rsc .Mod.txt .dump .xxd

ORP=../ORP
ORTool=../ORTool
ORL=../ORL
ORL32=../ORL32
ORX=../ORX

INNER_MOD=Modules.Mod.txt Kernel.Mod.txt Files.Mod.txt FileDir.Mod.txt
INNER_RSC=$(INNER_MOD:.Mod.txt=.rsc)
INNER_SMB=$(INNER_MOD:.Mod.txt=.smb)
INNER_DUMP=$(INNER_RSC:.rsc=.dump)

%.rsc %.smb: %.Mod.txt
	$(ORP) Compile $<

%.xxd: %.bin
	xxd $< > $@

%.dump: %.rsc
	$(ORTool) DecObj $< > $@

all: Modules.xxd prom.mem $(INNER_DUMP)

Modules.bin: $(INNER_RSC)
	$(ORL) Link Modules

prom.mem: BootLoad.rsc
	$(ORX) WriteFile $< $@

Modules32.bin: $(INNER_RSC)
	$(ORL32) Link Modules
	mv Modules.bin Modules32.bin

check: Modules.xxd Modules32.xxd
	diff Modules32.xxd Modules.xxd

clean:
	$(RM) $(INNER_RSC) $(INNER_SMB)
	$(RM) *.rsc *.smb
	$(RM) Modules.bin *.xxd *.dump
	$(RM) prom.mem
	$(RM) Oberon.Log

###
include Makefile.dep
