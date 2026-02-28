.SUFFIXES:
.SUFFIXES: .Mod .smb .a6m
VPATH=$(HOME)/Projects/Oberon/voc-O7/Micro/Files

MCU=LPC1114FBD48302

MOD=Mod
SYM=smb
OBJ=a6m

SRCS=MobxLPC1114FBD48302Echo0.Mod
OBJS=$(SRCS:.Mod=.a6m)
DBINS=$(SRCS:.Mod=.decbin)

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
	$(RM) $(DBINS) $(OBJS)
	$(RM) sym/* obj/*
	$(RM) Oberon.Log

include Makefile.dep
