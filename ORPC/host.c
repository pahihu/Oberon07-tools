#ifdef __WINNT
#ifndef _WIN32_WINNT
#define _WIN32_WINNT 0x0600
#endif
#define WIN32_LEAN_AND_MEAN 1
#include <windows.h>
#endif

#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/time.h>

#include "ocg_runtime.h"

int host_putchar(uint8_t ch)
{
  return putchar(ch);
}

uint8_t host_getchar()
{
  return getchar();
}

static struct timeval T0;

ocg_int host_time(void)
{
  static int init = 0;
  struct timeval T1;

  if (!init) {
    gettimeofday(&T0, NULL);
    init = 1;
  }
  gettimeofday(&T1, NULL);
  return 1000 * (T1.tv_sec - T0.tv_sec) + (T1.tv_usec - T0.tv_usec) / 1000;
}

ocg_int host_utime(void)
{
  static int init = 0;
  struct timeval T1;

  if (!init) {
    gettimeofday(&T0, NULL);
    init = 1;
  }
  gettimeofday(&T1, NULL);
  return 1000000 * (T1.tv_sec - T0.tv_sec) + (T1.tv_usec - T0.tv_usec);
}

#ifdef __APPLE__
#define _XOPEN_SOURCE 1
#include <ucontext.h>
#include <setjmp.h>
#include <errno.h>

ucontext_t main_ctx;

ocg_int host_coro_current(ocg_int *coro)
{
  static int init = 0;
  int err;

  if (!init) {
    init = 1;
    if (getcontext(&main_ctx) < 0) {
      err = errno;
      fprintf(stderr, "getcontext(): failed %s\n", strerror(err));
      *coro = 0;
      return err;
    }
  }
  *coro = (ocg_int) &main_ctx;
  return 0;
}

ocg_int host_coro_new(void (*proc)(void), uint8_t *stk, ocg_int stksize, ocg_int *coro)
{
  const char *where;
  ucontext_t *ctx;
  int err;

  /*fprintf(stderr, "MINSIGSTKSZ=%d", MINSIGSTKSZ);*/
  /*fprintf(stderr, "proc=%p, stk=%p, stksize=%ld, coro=%p\n", proc, stk, stksize, coro);*/

  ctx = (ucontext_t *) malloc(sizeof(ucontext_t));
  if (!ctx) {
    err = errno; where = "malloc";
    goto ErrOut;
  }

  if (getcontext(ctx) < 0) {
    err = errno; where = "getcontext";
    free(ctx);
    goto ErrOut;
  }
  ctx->uc_stack.ss_sp = stk;
  ctx->uc_stack.ss_size = stksize;

  makecontext(ctx, proc, 0);

  *coro = (ocg_int) ctx;
  return 0;
ErrOut:
  fprintf(stderr, "host_coro_new: %s failed %s\n", where, strerror(err));
  *coro = 0;
  return err;
}

void host_coro_transfer(ocg_int *p_from, ocg_int p_to)
{
  ucontext_t *from = (ucontext_t *)(*p_from);
  const ucontext_t *to = (const ucontext_t *)(p_to);

  assert(from != NULL && to != NULL);
  assert(from != to);

  swapcontext(from, to);
}
#endif

#ifdef __WINNT

typedef void (*coroutine_fn)(void);

typedef struct coroutine {
    void *fiber;
    void *caller;
    coroutine_fn fn;
    int done;
} coroutine;

static coroutine main_co;

void coro_finish(void)
{
  ConvertFiberToThread();
}

ocg_int host_coro_current(ocg_int *coro)
{
  static int init = 0;

  if (!init) {
    main_co.fiber = ConvertThreadToFiberEx(NULL, FIBER_FLAG_FLOAT_SWITCH);
    if (!main_co.fiber) {
        ocg_int err = GetLastError();
        fprintf(stderr, "ConvertThreadToFiberEx failed: %lu\n",
                (ocg_uint)err);
        *coro = 0;
        return err;
    }
    init = 0;
    atexit(coro_finish);
  }
  *coro = (ocg_int)&main_co;
  return 0;
}

void host_coro_transfer(ocg_int *p_from, ocg_int p_to)
{
  coroutine *from = (coroutine *)(*p_from);
  coroutine *to = (coroutine *)(p_to);

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

/* Returns zero on success; GetLastError() on failure. */
ocg_int host_coro_new(void (*proc)(void), uint8_t *stk, ocg_int stksize, ocg_int *coro)
{
  const char *where;
  coroutine *self;
  ocg_int err;

  self = (coroutine *) malloc(sizeof(coroutine));
  if (!self) {
    err = errno; where = "malloc";
    goto ErrOut;
  }
  *self = (coroutine){0};
  self->fn = proc;

  self->fiber = CreateFiberEx(
    0, 0, FIBER_FLAG_FLOAT_SWITCH,
    coroutine_entry, self
  );
  if (!self->fiber) {
    err = GetLastError(); where = "CreateFiberEx";
    free(self);
    goto ErrOut;
  }
  *coro = (ocg_int) self;
  return 0;

ErrOut:
  fprintf(stderr, "host_coro_new: %s failed %lu\n", (ocg_uint)err);
  *coro = 0;
  return err;
}

/* Never destroy the currently executing coroutine. */
void host_coro_destroy(ocg_int *coro)
{
  coroutine *self = (coroutine *)(*coro);
  assert(self->fiber != GetCurrentFiber());

  if (self->fiber) {
    DeleteFiber(self->fiber);
    self->fiber = NULL;
  }

  self->done = 1;
}

#endif
/* vim:set ts=2 sw=2 et:*/
