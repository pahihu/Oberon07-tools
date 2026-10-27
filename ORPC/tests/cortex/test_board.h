#ifndef __ASSEMBLER__
_Noreturn void board_trap(const char *why);
#define OCG_TRAP(why) board_trap(why)
#endif
