/* coro.c -- Arm GNU Toolchain, Thumb mode */
#include "coro.h"
#include "ocg_runtime.h"
#include <stddef.h>

/*
 * Preserve floating-point callee-saved registers when the compiler
 * is allowed to generate hardware floating-point instructions.
 */
#if defined(__ARM_FP) && (__ARM_FP != 0)
#define CORO_FP_WORDS 16
#define CORO_FP_SAVE    "vpush {s16-s31}\n"
#define CORO_FP_RESTORE "vpop  {s16-s31}\n"
#else
#define CORO_FP_WORDS 0
#define CORO_FP_SAVE    ""
#define CORO_FP_RESTORE ""
#endif

static coroutine_t main_co;

/*
 * r4 initially contains proc.
 * If proc returns, this coroutine stops here permanently.
 */
__attribute__((naked, noreturn, used))
static void coro_entry(void)
{
    __asm__(
        "blx r4\n"
        "1: b 1b\n"
    );
}

int coro_current(coroutine_t **coro)
{
    *coro = &main_co;
    return 0;
}

__attribute__((naked, noinline))
void coro_transfer(coroutine_t *from, coroutine_t *to)
{
    __asm__(
        CORO_FP_SAVE

        /* Save the original low registers before using them. */
        "push {r4-r7, lr}\n"
        "mov r4, r8\n"
        "mov r5, r9\n"
        "mov r6, r10\n"
        "mov r7, r11\n"
        "push {r4-r7}\n"

        /* from->sp = sp; sp = to->sp; */
        "mov r2, sp\n"
        "str r2, [r0]\n"
        "ldr r2, [r1]\n"
        "mov sp, r2\n"

        /* Restore high registers, then original low registers. */
        "pop {r4-r7}\n"
        "mov r8, r4\n"
        "mov r9, r5\n"
        "mov r10, r6\n"
        "mov r11, r7\n"
        "pop {r4-r7}\n"
        "pop {r2}\n"       /* Saved LR / initial entry address. */

        CORO_FP_RESTORE

        "bx r2\n"
    );
}

int coro_new(void (*proc)(void),
             uint8_t *stk, long stksize,
             coroutine_t **coro)
{
    enum { FRAME_WORDS = 9 + CORO_FP_WORDS };

    if (!proc || !stk || !coro || stksize <= 0)
        return -1;

    uintptr_t begin = (uintptr_t)stk;
    uintptr_t size = (uintptr_t)stksize;

    if (size > UINTPTR_MAX - begin)
        return -1;

    uintptr_t end = (begin + size) & ~(uintptr_t)7;

    /* Allow alignment of the descriptor at the buffer's bottom. */
    if (size < 7)
        return -1;

    uintptr_t bottom = (begin + 7) & ~(uintptr_t)7;

    if (end < bottom ||
        end - bottom < sizeof(coroutine_t) +
                       FRAME_WORDS * sizeof(uint32_t))
        return -1;

    coroutine_t *c = (coroutine_t *)bottom;
    uint32_t *frame = (uint32_t *)end - FRAME_WORDS;

    for (unsigned i = 0; i < FRAME_WORDS; ++i)
        frame[i] = 0;

    /*
     * Saved frame, in increasing address order:
     * r8-r11, r4-r7, LR, optional s16-s31.
     */
    frame[4] = (uint32_t)(uintptr_t)proc;
    frame[8] = (uint32_t)(uintptr_t)coro_entry;

    c->sp = frame;
    *coro = c;
    return 0;
}
