#include <stdint.h>
#include <stddef.h>
static volatile int32_t led;
void ocg_cortex_led(int32_t value) { led=value; }
int32_t board_led_value(void) { return led; }
static int semihost(unsigned operation,const void *argument) {
  register unsigned r0 __asm__("r0")=operation;
  register const void *r1 __asm__("r1")=argument;
  __asm__ volatile("bkpt 0xab" : "+r"(r0) : "r"(r1) : "memory");
  return (int)r0;
}
_Noreturn void board_exit(unsigned code) {
  uint32_t block[2]={0x20026,code};
  semihost(0x20,block);
  for(;;) {}
}
_Noreturn void board_trap(const char *why) {
  semihost(4,why); board_exit(1);
}
void *memcpy(void *dst,const void *src,size_t n) {
  unsigned char *a=dst; const unsigned char *b=src;
  for(size_t i=0;i<n;i++) a[i]=b[i];
  return dst;
}
void *memset(void *dst,int value,size_t n) {
  unsigned char *a=dst;
  for(size_t i=0;i<n;i++) a[i]=(unsigned char)value;
  return dst;
}
void *memmove(void *dst,const void *src,size_t n) {
  unsigned char *a=dst; const unsigned char *b=src;
  if(a<b) for(size_t i=0;i<n;i++) a[i]=b[i];
  else for(size_t i=n;i>0;i--) a[i-1]=b[i-1];
  return dst;
}
