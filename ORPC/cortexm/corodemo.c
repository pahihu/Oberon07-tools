#include "coro.h"

static coroutine_t main_coro;
static coroutine_t *worker_coro;
static uint8_t worker_stack[1024];

static volatile unsigned counter;

static void worker(void)
{
    for (;;) {
        ++counter;
        coro_transfer(worker_coro, &main_coro);
    }
}

int main(void)
{
    if (coro_new(worker, worker_stack, sizeof worker_stack,
                 &worker_coro) != 0) {
        for (;;) {}
    }

    /* main_coro needs no initialization: its stack pointer is captured on its first transfer. */
    for (;;) {
        coro_transfer(&main_coro, worker_coro);
        /* worker has incremented counter and yielded here. */
    }
}
