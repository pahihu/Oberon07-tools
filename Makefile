.SUFFIXES:
.SUFFIXES: .Mod .OSym
VPATH=lib

O2C=o2c
O2EF=o2ef

MODS=System.Mod DynLoad.Mod Kernal.Mod Kernel.Mod Args.Mod Modules.Mod Complex.Mod ComplexL.Mod ComplexConv.Mod InOut.Mod Logger.Mod RandomNumbers.Mod Timer.Mod Texts.Mod Oberon.Mod Files07.Mod
SYMS=$(MODS:.Mod=.OSym)

%.OSym: %.Mod
	$(O2C) $< | $(O2EF)

all: help

l32: force
	make O2CARCH=32 DYNEXPORT="--ldflags -Wl,--export-dynamic" build

l64: force
	make O2CARCH=64 DYNEXPORT="--ldflags -Wl,--export-dynamic" build

m64: force
	make O2CARCH=64 DYNEXPORT="" build

w32: force
	make O2CARCH=32 DYNEXPORT="--ldflags -Wl,--export-all-symbols" EXE=".exe" build

w64: force
	make O2CARCH=64 DYNEXPORT="--ldflags -Wl,--export-all-symbols" EXE=".exe" build

help:
	@-echo "usage: m64|l32|l64|w32|w64"

build: System.Mod $(SYMS)
	@-echo "execute: source .env"

System.Mod: dot.env lib/System32.Mod lib/System64.Mod
	cp lib/System$(O2CARCH).Mod lib/System.Mod

dot.env:
	echo "export O2CARCH=$(O2CARCH)" > .env
	echo "export DYNEXPORT=\"$(DYNEXPORT)\"" >> .env
	echo "export EXE=\"$(EXE)\"" >> .env

force:
	$(RM) -f .env

clean:
	$(RM) .env
	$(RM) obj/* sym/*
	$(RM) lib/System.Mod
	$(RM) Oberon.Log

###
# macOS
# DYNEXPORT=""
# Linux
# DYNEXPORT="--ldflags -Wl,--export-dynamic"
# MinGW
# DYNEXPORT="--ldflags -Wl,--export-all-symbols"

# vim:set ts=4 sw=4 noet:
