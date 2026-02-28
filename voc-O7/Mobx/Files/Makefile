.SUFFIXES:
.SUFFIXES: .Mod .smb .a6m .a7m
VPATH=$(O7DIR)/Micro/Files


MOD=Mod
SYM=smb
# ARMv6
# OBJ=a6m
# OXP=O7ARMv6MP
# OXL=O7ARMv6MLinker
# ARMv7[E]
OBJ=a7m
OXP=O7ARMv7MP
OXL=O7ARMv7MLinker
OXTOOL=O7ARMv7MTool

# MCU=LPC1114FBD48302
# SRCS=MobxLPC1114FBD48302Echo0.Mod
MCU=LPC1343
SRCS=MobxLPC1343Blink.Mod
OBJS=$(SRCS:.Mod=.$(OBJ))
BINS=$(SRCS:.Mod=.bin)
HEXS=$(SRCS:.Mod=.hex)
DBINS=$(SRCS:.Mod=.decbin)
DHEXS=$(SRCS:.Mod=.dechex)

%.smb %.$(OBJ): %.Mod
	$(OXP) Compile $(notdir $<)

%.bin: %.$(OBJ)
	$(OXL) Link $(MCU) $(basename $@)

%.dechex: %.hex
	$(OXTOOL) DecHex $< > $@

%.decbin: %.bin
	$(OXTOOL) DecBin $< > $@


all: $(DBINS)

clean:
	$(RM) $(DHEXS) $(DBINS) $(HEXS) $(BINS) $(OBJS)
	$(RM) sym/* obj/*
	$(RM) Oberon.Log

$(DBINS): $(BINS)
###
# include Echo0.dep
include Blink.dep

# vim:set ts=4 sw=4 noet:
