#include <stdio.h>
#include <stdlib.h>
#include <sys/time.h>

#include "ocg_runtime.h"

int emb_putchar(uint8_t ch)
{
  return putchar(ch);
}

static struct timeval T0;

long emb_time(void)
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

long emb_utime(void)
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

void emb_coro_current(long *coro)
{
  ucontext_t *ctx;

  ctx = (ucontext_t *) malloc(sizeof(ucontext_t));
  getcontext(ctx);
  *coro = (long) ctx;
}

void emb_coro_new(void (*proc)(void), uint8_t *stk, long stksize, long *coro)
{
  ucontext_t *ctx;
  int err;

  /*fprintf(stderr, "MINSIGSTKSZ=%d", MINSIGSTKSZ);*/
  /*fprintf(stderr, "proc=%p, stk=%p, stksize=%ld, coro=%p\n", proc, stk, stksize, coro);*/

  ctx = (ucontext_t *) malloc(sizeof(ucontext_t));

  if (getcontext(ctx) < 0) {
    *coro = -errno;
    return;
  }
  ctx->uc_stack.ss_sp = stk;
  ctx->uc_stack.ss_size = stksize;

  makecontext(ctx, proc, 0);

  *coro = (long) ctx;
}

void emb_coro_transfer(long *from, long to)
{
  swapcontext((ucontext_t*)*from, (const ucontext_t*)to);
}
#endif
/* vim:set ts=2 sw=2 et:*/
