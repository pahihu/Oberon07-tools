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
/* C11 native ABI: INTEGER/REAL/address widths follow pointers; SET is 32-bit.
   Applications may override allocation, e.g. with a tracing collector. */
#ifndef OCG_ALLOC
#define OCG_ALLOC(n) calloc(1, (n))
#endif
#ifndef OCG_FREE
#define OCG_FREE(p) free(p)
#endif
#if UINTPTR_MAX == UINT64_MAX
typedef int64_t ocg_int;
typedef uint64_t ocg_uint;
typedef double ocg_real_t;
#define OCG_INT_MIN INT64_MIN
#define OCG_INT_MAX INT64_MAX
#define OCG_FLOOR floor
#define OCG_FABS fabs
#define OCG_FREXP frexp
#define OCG_LDEXP ldexp
_Static_assert(FLT_RADIX==2 && DBL_MANT_DIG==53 && DBL_MAX_EXP==1024, "OCG requires IEEE binary64");
#elif UINTPTR_MAX == UINT32_MAX
typedef int32_t ocg_int;
typedef uint32_t ocg_uint;
typedef float ocg_real_t;
#define OCG_INT_MIN INT32_MIN
#define OCG_INT_MAX INT32_MAX
#define OCG_FLOOR floorf
#define OCG_FABS fabsf
#define OCG_FREXP frexpf
#define OCG_LDEXP ldexpf
_Static_assert(FLT_RADIX==2 && FLT_MANT_DIG==24 && FLT_MAX_EXP==128, "OCG requires IEEE binary32");
#else
#error OCG requires 32-bit or 64-bit pointers
#endif
#define OCG_WORD_BITS ((unsigned)(sizeof(ocg_int)*CHAR_BIT))
_Static_assert(sizeof(ocg_real_t)==sizeof(void *) && sizeof(ocg_int)==sizeof(void *), "OCG native scalar ABI");
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
static inline void ocg_arraycopy(void *dst,ocg_int nd,const void *src,ocg_int ns,size_t element_size) {
  if(nd<0 || ns<0 || ns>nd || (ns && element_size>SIZE_MAX/(size_t)ns))
    ocg_fail("array length");
  if(ns) memmove(dst,src,(size_t)ns*element_size);
}
static inline ocg_int ocg_add(ocg_int a,ocg_int b) { return (ocg_int)((ocg_uint)a+(ocg_uint)b); }
static inline ocg_int ocg_sub(ocg_int a,ocg_int b) { return (ocg_int)((ocg_uint)a-(ocg_uint)b); }
static inline ocg_int ocg_mul(ocg_int a,ocg_int b) { return (ocg_int)((ocg_uint)a*(ocg_uint)b); }
static inline ocg_int ocg_addv(ocg_int a,ocg_int b) {
  if((b>0 && a>OCG_INT_MAX-b) || (b<0 && a<OCG_INT_MIN-b)) ocg_fail("INTEGER overflow");
  return a+b;
}
static inline ocg_int ocg_subv(ocg_int a,ocg_int b) {
  if((b>0 && a<OCG_INT_MIN+b) || (b<0 && a>OCG_INT_MAX+b)) ocg_fail("INTEGER overflow");
  return a-b;
}
static inline ocg_int ocg_mulv(ocg_int a,ocg_int b) {
  if(a>0 ? (b>0 ? a>OCG_INT_MAX/b : b<OCG_INT_MIN/a)
         : (a<0 && (b>0 ? a<OCG_INT_MIN/b : (b<0 && a<OCG_INT_MAX/b))))
    ocg_fail("INTEGER overflow");
  return a*b;
}
static inline ocg_int ocg_address(const void *p) { return (ocg_int)(uintptr_t)p; }
static inline ocg_int ocg_div(ocg_int a,ocg_int b) {
  if(b<=0) ocg_fail("DIV divisor must be positive");
  return a/b - (a%b<0);
}
static inline ocg_int ocg_mod(ocg_int a,ocg_int b) {
  if(b<=0) ocg_fail("MOD divisor must be positive");
  ocg_int r=a%b; return r<0?r+b:r;
}
static inline ocg_int ocg_index(ocg_int i,ocg_int n) { if(i<0 || i>=n) ocg_fail("index"); return i; }
static inline uint32_t ocg_single(ocg_int i) { if((ocg_uint)i>=32) ocg_fail("set element"); return UINT32_C(1)<<i; }
static inline uint32_t ocg_range(ocg_int a,ocg_int b) {
  if((ocg_uint)a>=32 || (ocg_uint)b>=32) ocg_fail("set range");
  if(a>b) return 0;
  return (UINT32_MAX<<a) & (UINT32_MAX>>(31-b));
}
static inline bool ocg_in(ocg_int i,uint32_t set) { return (ocg_uint)i<32 && ((set>>i)&1u); }
static inline uint32_t ocg_set_lsl(uint32_t x,ocg_int n) { return x<<((ocg_uint)n&31); }
static inline uint32_t ocg_set_lsr(uint32_t x,ocg_int n) { return x>>((ocg_uint)n&31); }
static inline uint32_t ocg_set_asr(uint32_t x,ocg_int n) {
  unsigned k=(ocg_uint)n&31; uint32_t v=x>>k;
  if(k && (x&UINT32_C(0x80000000))) v|=UINT32_MAX<<(32-k);
  return v;
}
static inline uint32_t ocg_set_ror(uint32_t x,ocg_int n) {
  unsigned k=(ocg_uint)n&31; return (x>>k)|(x<<((32-k)&31));
}
static inline ocg_int ocg_lsl(ocg_uint x,ocg_int n) { return (ocg_int)(x<<((ocg_uint)n&(OCG_WORD_BITS-1))); }
static inline ocg_int ocg_lsr(ocg_uint x,ocg_int n) { return (ocg_int)(x>>((ocg_uint)n&(OCG_WORD_BITS-1))); }
static inline ocg_int ocg_asr(ocg_uint x,ocg_int n) {
  unsigned k=(ocg_uint)n&(OCG_WORD_BITS-1); ocg_uint v=x>>k;
  if(k && (x&((ocg_uint)1<<(OCG_WORD_BITS-1)))) v|=~(ocg_uint)0<<(OCG_WORD_BITS-k);
  return (ocg_int)v;
}
static inline ocg_int ocg_ror(ocg_uint x,ocg_int n) {
  unsigned k=(ocg_uint)n&(OCG_WORD_BITS-1);
  return (ocg_int)((x>>k)|(x<<((OCG_WORD_BITS-k)&(OCG_WORD_BITS-1))));
}
static inline ocg_int ocg_abs(ocg_int x) { if(x==OCG_INT_MIN) ocg_fail("ABS overflow"); return x<0?-x:x; }
static inline ocg_real_t ocg_real(ocg_int x) { ocg_real_t f; memcpy(&f,&x,sizeof f); return f; }
static inline ocg_int ocg_bits(ocg_real_t f) { ocg_int x; memcpy(&x,&f,sizeof x); return x; }
static inline ocg_int ocg_floor(ocg_real_t f) {
  ocg_real_t d=OCG_FLOOR(f);
  /* The positive bound is exclusive: MAX rounds to 2^(bits-1) in REAL. */
  if(!(d>=(ocg_real_t)OCG_INT_MIN && d<-(ocg_real_t)OCG_INT_MIN)) ocg_fail("FLOOR range");
  return (ocg_int)d;
}
static inline ocg_real_t ocg_fabs(ocg_real_t f) { return OCG_FABS(f); }
static inline ocg_real_t ocg_ldexp(ocg_real_t f,ocg_int e) {
  if(e>INT_MAX) e=INT_MAX;
  if(e<INT_MIN) e=INT_MIN;
  return OCG_LDEXP(f,(int)e);
}
static inline ocg_real_t ocg_unpk(ocg_real_t f,ocg_int *exponent) {
  int e; if(f==0) { *exponent=0; return f; }
  ocg_real_t m=OCG_FREXP(f,&e); *exponent=e-1; return m*2;
}
static inline int ocg_strcmp(const uint8_t *a,ocg_int na,const uint8_t *b,ocg_int nb) {
  ocg_int i=0;
  for (;;) {
    unsigned ca=i<na?a[i]:0, cb=i<nb?b[i]:0;
    if(ca!=cb) return ca<cb?-1:1;
    if(ca==0) return 0;
    ++i;
  }
}
static inline void ocg_string(uint8_t *dst,ocg_int n,const uint8_t *src,ocg_int ns) {
  /* Literal lengths include a quoted string's terminator. Hex strings have
     no implicit terminator and may contain zero bytes anywhere. */
  ocg_arraycopy(dst,n,src,ns,sizeof *src);
}
static inline size_t ocg_bytes(ocg_int words) {
  if(words<0 || (ocg_uint)words>SIZE_MAX/sizeof(ocg_int)) ocg_fail("COPY size");
  return (size_t)words*sizeof(ocg_int);
}
static inline bool ocg_bit(ocg_int address,ocg_int bit) {
  if((ocg_uint)bit>=OCG_WORD_BITS) ocg_fail("BIT index");
  return ((*(volatile const ocg_uint *)(uintptr_t)(ocg_uint)address)>>bit)&1u;
}
#endif
