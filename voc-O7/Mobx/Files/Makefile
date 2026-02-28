.SUFFIXES:
.SUFFIXES: .Mod .smb .a6m
VPATH=$(O7DIR)/Micro/Files

MCU=LPC1114FBD48302

MOD=Mod
SYM=smb
OBJ=a6m

SRCS=MobxLPC1114FBD48302Echo0.Mod
OBJS=$(SRCS:.Mod=.a6m)
BINS=$(SRCS:.Mod=.bin)
HEXS=$(SRCS:.Mod=.hex)
DBINS=$(SRCS:.Mod=.decbin)
DHEXS=$(SRCS:.Mod=.dechex)

%.smb %.a6m: %.Mod
	O7ARMv6MP Compile $(notdir $<)

%.bin: %.a6m
	O7ARMv6MLinker Link $(MCU) $(basename $@)

%.dechex: %.hex
	O7ARMv7MTool DecHex $< > $@

%.decbin: %.bin
	O7ARMv7MTool DecBin $< > $@


all: $(DBINS)

clean:
	$(RM) $(DHEXS) $(DBINS) $(HEXS) $(BINS) $(OBJS)
	$(RM) sym/* obj/*
	$(RM) Oberon.Log

$(DBINS): $(BINS)
###
include Makefile.dep

# vim:set ts=4 sw=4 noet:
