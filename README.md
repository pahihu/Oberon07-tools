# Oberon-07 compiler tools

This repo contains the Oberon-2 port of [ORP, ORTool](https://people.inf.ethz.ch/wirth/ProjectOberon/index.html) from N.Wirth
and [ORL, ORX](https://github.com/andreaspirklbauer/Oberon-building-tools/tree/master/Sources/FPGAOberon2013) from A.Pirklbauer.

You can compile the sources with [O2C](https://github.com/pahihu/o2c/tree/feature-64bit-port), at least on macOS ARM64, Rocky Linux 8 i686/x86_64 or MinGW32.

The original sources depend on the assumption, that `SIZE(INTEGER) = 4`. Hence I've replaced every reference to
`INTEGER` and `LONGINT` with `Sys.Integer` defined in `lib/System.Mod`. It is declared as `LONGINT` on 32bit systems and `INTEGER` on 64bit systems in O2C.

***

The directories:
- `Oberon0/` contains the source code from [Compiler Construction](https://people.inf.ethz.ch/wirth/CompilerConstruction/index.html).
- `Oberon07/` contains ORP, ORTool, ORL, ORX, Depends.
- `Oberon07/EO/` contains the inner core of Embedded Oberon.
- `Oberon07/PO2013/` contains the sources of Project Oberon 2013.
- `Oberon07/riscw/` contains the Windows 64bit binary of Peter De Wachter's [oberon-risc-emu](https://github.com/pdewacht/oberon-risc-emu).
- `Lola2/EO/` contains the Lola-2 compiler.
- `Lola2/risc5/` Lola-2 sources of RISC5.
- `Misc/` contains classic Hello World, Fibonacci series, Oberon-2 type sizes programs.
- `Misc/Benchmark/` contains the Pow! benchmark program.
- `Misc/RayTest/` contains [Paul Graham's Common Lisp ray-tracer](https://paulgraham.com/acl.html) ported to Oberon-2.
- `cedt/` contains Oberon-2 and Lola-2 syntax definitions for Crimson Editor.

You can rebuild the Project Oberon 2013 sources and install it in an SD card image with these tools.
See `Oberon07/PO2013/buildimg.sh`.

Setup O2C and include the `lib/` `obj/` and `sym/` directories into `~/.o2c.red`.

Example run:

    make m64
    source .env
    cd Oberon07
    make
    cd PO2013
    make
    ./mk.sh build

***

**NOTE**: Don't forget the excellent [Astrobe for RISC5](https://web.archive.org/web/20250212125608/https://www.astrobe.com/RISC5/), otherwise here is the code. Good luck!
