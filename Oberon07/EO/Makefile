.SUFFIXES:
.SUFFIXES: .bin .smb .rsc .Mod.txt

ORP=../ORP
ORL=../ORL
ORL32=../ORL32
ORTool=../ORTool

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

all: Modules.xxd $(INNER_DUMP)

Modules.bin: $(INNER_RSC)
	$(ORL) Link Modules

Modules32.bin: $(INNER_RSC)
	$(ORL32) Link Modules
	mv Modules.bin Modules32.bin

clean:
	$(RM) $(INNER_RSC) $(INNER_SMB) $(INNER_DUMP)
	$(RM) Modules.bin Modules.xxd
	$(RM) Modules32.bin Modules32.xxd
	$(RM) Oberon.Log

###
Modules.rsc Modules.smb: Modules.Mod.txt Files.smb
Kernel.rsc Kernel.smb: Kernel.Mod.txt
Files.rsc Files.smb: Files.Mod.txt Kernel.smb FileDir.smb
FileDir.rsc FileDir.smb: FileDir.Mod.txt Kernel.smb

