#include <stdio.h>
#include <stdlib.h>
#include <sys/time.h>
#include "ocg_runtime.h"

int emb_putchar(uint8_t ch)
{
  return putchar(ch);
}

struct timeval T0;

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

/* vim:set ts=2 sw=2 et:*/
