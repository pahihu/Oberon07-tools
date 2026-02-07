Astrobe:
- .rsc object files without number compression
- .smb symbol files with number compression, size aligned to 4byte boundaries

ORL
- at least on 32bit platforms it works, but only with "--nogc"
- GC confuses when sees the Module RECORD casts

The ORX port has an interesting pattern, how to process command line
arguments. Rewrite ORP.Compile and ORTool.DecSym, DecObj similarly. DONE


Quick start with Oberon building tools
======================================
ORP Compile Kernel.Mod.txt FileDir.Mod.txt Files.Mod.txt Modules.Mod.txt
ORL Link Modules
