/* memmap */
MEMORY
{
    rom(RX)   : ORIGIN = 0x00000000, LENGTH = 1024K
    ram(WAIL) : ORIGIN = 0x40000000, LENGTH = 1024K
}

SECTIONS
{
    .text : {
         KEEP(*(.vectors))
         *(.text)
         *(.text*)
         KEEP(*(.text))
    } > rom

    .rodata : { 
         . = ALIGN(2);
         *(.rodata)
         *(.rodata*)
         . = ALIGN(2);
         KEEP(*(.rodata))
    } > rom

    .bss : {
         __bss_start__ = .; PROVIDE(_bss_start = .);
         *(.bss*)
         __bss_end__ = . ; PROVIDE(_bss_end = .);
         KEEP(*(.bss))
    } > ram AT > rom
    PROVIDE(_bss_size = SIZEOF(.bss));

    .data : {
         __data_start__ = .; PROVIDE(_data_start = .);
         *(.data*)
         __data_end__ = .; PROVIDE(_data_end = .);
         KEEP(*(.data))
    } > ram AT > rom
    PROVIDE(_data_size = SIZEOF(.data));
    PROVIDE(_data_load_start = LOADADDR(.data));

    PROVIDE(end = .);
    PROVIDE(__ocg_stack_top = ORIGIN(ram) + 512K);
    PROVIDE(__ocg_stack_bottom = __ocg_stack_top - 64K);
    ASSERT(end <= __ocg_stack_bottom, "static data overlaps the startup stack")
}

