/* coro.h */
#ifndef CORO_H
#define CORO_H

#include <stdint.h>

typedef struct {
    uint32_t *sp;
} coroutine_t;

int coro_new(void (*proc)(void),
             uint8_t *stk, long stksize,
             coroutine_t **coro);

void coro_transfer(coroutine_t *from, coroutine_t *to);

#endif
