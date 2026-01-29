# Oberon-07 compiler tools

This repo contains the Oberon-2 sources of [ORP, ORTool](https://people.inf.ethz.ch/wirth/ProjectOberon/index.html) from N.Wirth.
and [ORL, ORX](https://github.com/andreaspirklbauer/Oberon-building-tools/tree/master/Sources/FPGAOberon2013) from A.Pirklbauer.

You can compile the sources with [O2C](https://github.com/pahihu/o2c/tree/feature-64bit-port), at least on macOS ARM64, Rocky Linux 8 i686/x86_64 or MinGW32.

***

Oberon0/ contains the source code from [Compiler Construction](https://people.inf.ethz.ch/wirth/CompilerConstruction/index.html).
Oberon07/ contains ORP, ORTool, ORL, ORX.
EO/ contains the inner core of Embedded Oberon.

Example:

    ./m 64
    cd Oberon07
    ./m
    cd ../EO
    ./m

***

*NOTE*: Don't forget the excellent [Astrobe for RISC5](https://web.archive.org/web/20250212125608/https://www.astrobe.com/RISC5/), otherwise here is the code. Good luck!
