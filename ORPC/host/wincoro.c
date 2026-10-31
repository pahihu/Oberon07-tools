#ifndef _WIN32_WINNT
#define _WIN32_WINNT 0x0600
#endif

#include <windows.h>
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>

typedef void (*coroutine_fn)(void);

typedef struct coroutine {
    void *fiber;
    void *caller;
    coroutine_fn fn;
    int done;
} coroutine;

static void coroutine_transfer(coroutine *from, coroutine *to)
{
    assert(from != NULL && to != NULL);
    assert(from != to);
    assert(from->fiber == GetCurrentFiber());
    assert(to->fiber != NULL && !to->done);

    to->caller = from->fiber;
    SwitchToFiber(to->fiber);

    /* Execution continues here when 'from' is resumed. */
}

static VOID WINAPI coroutine_entry(LPVOID arg)
{
    coroutine *self = (coroutine *)arg;

    self->fn();
    self->done = 1;

    /* Return control to the most recent transferring coroutine. */
    SwitchToFiber(self->caller);

    /* A completed coroutine must never be resumed. */
    abort();
}

/* Returns nonzero on success; GetLastError() on failure. */
static int coroutine_init(coroutine *self, coroutine_fn fn)
{
    *self = (coroutine){0};
    self->fn = fn;

    self->fiber = CreateFiberEx(
        0, 0, FIBER_FLAG_FLOAT_SWITCH,
        coroutine_entry, self
    );

    return self->fiber != NULL;
}

/* Never destroy the currently executing coroutine. */
static void coroutine_destroy(coroutine *self)
{
    if (self->fiber) {
        DeleteFiber(self->fiber);
        self->fiber = NULL;
    }

    self->done = 1;
}

/* Example */

static coroutine main_co;
static coroutine worker_co;

static void worker(void)
{
    for (int i = 1; i <= 3; ++i) {
        printf("worker: %d\n", i);

        coroutine_transfer(&worker_co, &main_co);

        puts("worker: transfer returned");
    }
}

int main(void)
{
    main_co.fiber =
        ConvertThreadToFiberEx(NULL, FIBER_FLAG_FLOAT_SWITCH);

    if (!main_co.fiber) {
        fprintf(stderr, "ConvertThreadToFiberEx failed: %lu\n",
                (unsigned long)GetLastError());
        return EXIT_FAILURE;
    }

    if (!coroutine_init(&worker_co, worker)) {
        fprintf(stderr, "CreateFiberEx failed: %lu\n",
                (unsigned long)GetLastError());
        ConvertFiberToThread();
        return EXIT_FAILURE;
    }

    while (!worker_co.done) {
        coroutine_transfer(&main_co, &worker_co);
        puts("main: transfer returned");
    }

    coroutine_destroy(&worker_co);
    return ConvertFiberToThread() ? EXIT_SUCCESS : EXIT_FAILURE;
}
