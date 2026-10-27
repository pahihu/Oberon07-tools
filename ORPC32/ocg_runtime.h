#ifndef OCG_RUNTIME_H
#define OCG_RUNTIME_H
#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <math.h>
#include <limits.h>
#include <float.h>
/* C11 ABI: 32-bit INTEGER/SET and IEEE binary32 REAL; native C pointers.
   Applications may override allocation, e.g. with a tracing collector. */
#ifndef OCG_ALLOC
#define OCG_ALLOC(n) calloc(1, (n))
#endif
#ifndef OCG_FREE
#define OCG_FREE(p) free(p)
#endif
_Static_assert(FLT_RADIX==2 && FLT_MANT_DIG==24 && FLT_MAX_EXP==128, "OCG requires IEEE binary32");
_Static_assert(sizeof(float)==4 && sizeof(int32_t)==4, "OCG scalar ABI");
typedef struct ocg_type { const struct ocg_type *base; } ocg_type;
static inline _Noreturn void ocg_fail(const char *why) { fprintf(stderr,"Oberon trap: %s\n",why); abort(); }
static inline void ocg_assert(bool b) { if(!b) ocg_fail("ASSERT/type guard"); }
static inline void *ocg_nonnull(void *p) { if(!p) ocg_fail("NIL"); return p; }
static inline void *ocg_alloc(size_t n) { return ocg_nonnull(OCG_ALLOC(n)); }
/* memcpy avoids strict-aliasing violations in unrelated record types. */
static inline void ocg_settag(void *p,const ocg_type *t) { memcpy(p,&t,sizeof t); }
static inline bool ocg_is(const void *p,const ocg_type *want) {
  const ocg_type *t; if(!p) return true; memcpy(&t,p,sizeof t);
  while(t && t!=want) t=t->base;
  return t==want;
}
static inline void ocg_recordcopy(void *dst,const void *src,size_t n) {
  if(n<sizeof(void *)) ocg_fail("record size");
  memmove((unsigned char *)dst+sizeof(void *),(const unsigned char *)src+sizeof(void *),n-sizeof(void *));
}
static inline void ocg_recordassign(void *dst,const void *src,size_t n,const ocg_type *want) {
  const ocg_type *actual;
  memcpy(&actual,dst,sizeof actual);
  if(actual!=want) ocg_fail("VAR record assignment type");
  ocg_recordcopy(dst,src,n);
}
static inline void ocg_arraycopy(void *dst,int32_t nd,const void *src,int32_t ns,size_t element_size) {
  if(nd<0 || ns<0 || ns>nd || (ns && element_size>SIZE_MAX/(size_t)ns))
    ocg_fail("array length");
  if(ns) memmove(dst,src,(size_t)ns*element_size);
}
static inline int32_t ocg_add(int32_t a,int32_t b) { return (int32_t)((uint32_t)a+(uint32_t)b); }
static inline int32_t ocg_sub(int32_t a,int32_t b) { return (int32_t)((uint32_t)a-(uint32_t)b); }
static inline int32_t ocg_mul(int32_t a,int32_t b) { return (int32_t)((uint32_t)a*(uint32_t)b); }
static inline int32_t ocg_checked(int64_t x) {
  if(x<INT32_MIN || x>INT32_MAX) ocg_fail("INTEGER overflow");
  return (int32_t)x;
}
static inline int32_t ocg_addv(int32_t a,int32_t b) { return ocg_checked((int64_t)a+b); }
static inline int32_t ocg_subv(int32_t a,int32_t b) { return ocg_checked((int64_t)a-b); }
static inline int32_t ocg_mulv(int32_t a,int32_t b) { return ocg_checked((int64_t)a*b); }
static inline int32_t ocg_address(const void *p) {
  uintptr_t a=(uintptr_t)p;
  if(a>UINT32_MAX) ocg_fail("ADR exceeds 32-bit SYSTEM address range");
  return (int32_t)(uint32_t)a;
}
static inline int32_t ocg_div(int32_t a,int32_t b) {
  if(b<=0) ocg_fail("DIV divisor must be positive");
  return a/b - (a%b<0);
}
static inline int32_t ocg_mod(int32_t a,int32_t b) {
  if(b<=0) ocg_fail("MOD divisor must be positive");
  int32_t r=a%b; return r<0?r+b:r;
}
static inline int32_t ocg_index(int32_t i,int32_t n) { if(i<0 || i>=n) ocg_fail("index"); return i; }
static inline uint32_t ocg_single(int32_t i) { if((uint32_t)i>=32) ocg_fail("set element"); return UINT32_C(1)<<i; }
static inline uint32_t ocg_range(int32_t a,int32_t b) {
  if((uint32_t)a>=32 || (uint32_t)b>=32) ocg_fail("set range");
  if(a>b) return 0;
  return (UINT32_MAX<<a) & (UINT32_MAX>>(31-b));
}
static inline bool ocg_in(int32_t i,uint32_t set) { return (uint32_t)i<32 && ((set>>i)&1u); }
static inline int32_t ocg_lsl(uint32_t x,int32_t n) { return (int32_t)(x<<((uint32_t)n&31)); }
static inline int32_t ocg_lsr(uint32_t x,int32_t n) { return (int32_t)(x>>((uint32_t)n&31)); }
static inline int32_t ocg_asr(uint32_t x,int32_t n) {
  unsigned k=(uint32_t)n&31; uint32_t v=x>>k;
  if(k && (x&UINT32_C(0x80000000))) v|=UINT32_MAX<<(32-k);
  return (int32_t)v;
}
static inline int32_t ocg_ror(uint32_t x,int32_t n) { unsigned k=(uint32_t)n&31; return (int32_t)((x>>k)|(x<<((32-k)&31))); }
static inline int32_t ocg_abs(int32_t x) { if(x==INT32_MIN) ocg_fail("ABS overflow"); return x<0?-x:x; }
static inline float ocg_real(int32_t x) { float f; memcpy(&f,&x,4); return f; }
static inline int32_t ocg_bits(float f) { int32_t x; memcpy(&x,&f,4); return x; }
static inline int32_t ocg_floor(float f) {
  double d=floor((double)f); if(!(d>=INT32_MIN && d<=INT32_MAX)) ocg_fail("FLOOR range"); return (int32_t)d;
}
static inline float ocg_unpk(float f,int32_t *exponent) {
  int e; if(f==0) { *exponent=0; return f; }
  float m=frexpf(f,&e); *exponent=e-1; return m*2;
}
static inline int ocg_strcmp(const uint8_t *a,int32_t na,const uint8_t *b,int32_t nb) {
  int32_t i=0;
  for (;;) {
    unsigned ca=i<na?a[i]:0, cb=i<nb?b[i]:0;
    if(ca!=cb) return ca<cb?-1:1;
    if(ca==0) return 0;
    ++i;
  }
}
static inline void ocg_string(uint8_t *dst,int32_t n,const uint8_t *src,int32_t ns) {
  /* Literal lengths include a quoted string's terminator. Hex strings have
     no implicit terminator and may contain zero bytes anywhere. */
  ocg_arraycopy(dst,n,src,ns,sizeof *src);
}
static inline size_t ocg_bytes(int32_t words) {
  if(words<0 || (uint64_t)(uint32_t)words*4>SIZE_MAX) ocg_fail("COPY size");
  return (size_t)(uint32_t)words*4;
}
static inline bool ocg_bit(int32_t address,int32_t bit) {
  if((uint32_t)bit>=32) ocg_fail("BIT index");
  return ((*(volatile const uint32_t *)(uintptr_t)(uint32_t)address)>>bit)&1u;
}
#endif
