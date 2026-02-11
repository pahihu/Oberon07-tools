.SUFFIXES:
.SUFFIXES: .Lola.txt .v

SRC=Divider.Lola.txt FPAdder.Lola.txt FPDivider.Lola.txt FPMultiplier.Lola.txt \
  LeftShifter.Lola.txt MouseP.Lola.txt Multiplier.Lola.txt PS2.Lola.txt \
  RISC5.Lola.txt RISC5Top.Lola.txt RS232R.Lola.txt RS232T.Lola.txt \
  RightShifter.Lola.txt SPI.Lola.txt VID.Lola.txt
VLOG=$(SRC:.Lola.txt=.v)

%.v: %.Lola.txt
	LSC Compile $</v $@

all: RISC5Top.v

clean:
	$(RM) $(VLOG)
	$(RM) Oberon.Log

###
# RISC5Top.v: PROM.v
RISC5Top.v: RISC5.v RS232R.v RS232T.v SPI.v VID.v MouseP.v PS2.v
VID.v: DCMX3.v
# RISC5.v: Registers.v
RISC5.v: Multiplier.v Divider.v LeftShifter.v RightShifter.v FPAdder.v FPMultiplier.v FPDivider.v
