/* coro.h */
#ifndef CORO_H
#define CORO_H

#include "ocg_runtime.h"

typedef struct {
    uint32_t *sp;
    ocg_stack_range stack;
} coroutine_t;

int coro_current(coroutine_t **coro);
int coro_new(void (*proc)(void),
             uint8_t *stk, long stksize,
             coroutine_t **coro);

void coro_transfer(coroutine_t *from, coroutine_t *to);

#endif
