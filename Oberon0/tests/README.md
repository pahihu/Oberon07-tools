# ORTool0 maximum-memory mode

Apply `ORTool0-max-memory.patch` at the root of Oberon07-tools
(tested at `00ffda58db63fd5fd70a0c4acca2a21902e6f462`) and rebuild ORTool0.

```sh
git apply /path/to/simulator/ORTool0-max-memory.patch
make -B -C Oberon0 ORTool0
ORTool0 Execute ComsTime.bin/im
```

The RAM limit is 112 KiB in both modes. For a linked binary, `/m` starts
RISC5 SP at `1C000H` and writes the same address to the boot header at byte
offset 24. Without `/m`, ORTool0 starts SP and writes the header at the 96 KiB
boundary for compatibility with programs using the 16 KiB heap. Byte offset
12 reports `1C000H` in both modes. Flags combine, for example `/ims` enables
interrupts, maximum memory, and SD card emulation.

To verify the boot header and SP, compile `MaxMemoryTest.Mod/as` with the
package's module symbols, then link it with `ORL Link MaxMemoryTest/i`.
Run `ORTool0 Execute MaxMemoryTest.bin` for the default and
`ORTool0 Execute MaxMemoryTest.bin/mw 1` for maximum memory.

On the board, configure the boot loader to start SP at `1C000H` and publish
that value at byte offsets 12 and 24 for a heap-free image. Leave space for the
startup and interrupt frames above the linked image.
