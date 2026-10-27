#ifndef OCG_CORTEX_H
#define OCG_CORTEX_H
/* Included by ocg_runtime.h after the native scalar types. Arm GNU Toolchain. */
#if !defined(__GNUC__) || !defined(__arm__) || !defined(__thumb__)
#error Cortex-M output requires the Arm GNU Toolchain in Thumb mode
#endif
#if OCG_CORTEX_M == 1
#if !defined(__ARM_ARCH_6M__)
#error Compile Cortex-M0 output with -mcpu=cortex-m0
#endif
#elif OCG_CORTEX_M == 3
#if !defined(__ARM_ARCH_7M__)
#error Compile Cortex-M3 output with -mcpu=cortex-m3
#endif
#elif OCG_CORTEX_M == 4 || OCG_CORTEX_M == 7
#if !defined(__ARM_ARCH_7EM__)
#error Compile Cortex-M4/M7 output with the matching -mcpu option
#endif
#endif
_Static_assert(sizeof(void *)==4 && sizeof(ocg_int)==4, "Cortex-M scalar ABI");
#define OCG_INTERRUPT __attribute__((interrupt("IRQ"),used,externally_visible))
typedef struct { uint32_t apsr, high; } ocg_arm_state;
/* Identical weak definitions coalesce into one shared GNU ELF symbol. */
volatile ocg_arm_state ocg_arm_cpu __attribute__((weak)) = {0,0};
#define OCG_ARM_N UINT32_C(0x80000000)
#define OCG_ARM_Z UINT32_C(0x40000000)
#define OCG_ARM_C UINT32_C(0x20000000)
#define OCG_ARM_V UINT32_C(0x10000000)
static inline uint32_t ocg_arm_nz(uint32_t r) {
  return (r&OCG_ARM_N) | (r==0 ? OCG_ARM_Z : 0);
}
static inline ocg_int ocg_arm_add(ocg_int a,ocg_int b,unsigned carry) {
  uint64_t wide=(uint64_t)(uint32_t)a+(uint32_t)b+carry;
  int64_t signed_wide=(int64_t)a+b+carry;
  uint32_t r=(uint32_t)wide;
  ocg_arm_cpu.apsr=ocg_arm_nz(r) | (wide>>32 ? OCG_ARM_C : 0) |
    (signed_wide<INT32_MIN || signed_wide>INT32_MAX ? OCG_ARM_V : 0);
  return (ocg_int)r;
}
static inline ocg_int ocg_arm_sub(ocg_int a,ocg_int b,unsigned carry) {
  uint64_t sub=(uint64_t)(uint32_t)b+(1-carry);
  uint32_t r=(uint32_t)a-(uint32_t)sub;
  int64_t signed_wide=(int64_t)a-b-(1-carry);
  ocg_arm_cpu.apsr=ocg_arm_nz(r) | ((uint64_t)(uint32_t)a>=sub ? OCG_ARM_C : 0) |
    (signed_wide<INT32_MIN || signed_wide>INT32_MAX ? OCG_ARM_V : 0);
  return (ocg_int)r;
}
static inline ocg_int ocg_arm_adc(ocg_int a,ocg_int b) {
  return ocg_arm_add(a,b,(ocg_arm_cpu.apsr&OCG_ARM_C)!=0);
}
static inline ocg_int ocg_arm_sbc(ocg_int a,ocg_int b) {
  return ocg_arm_sub(a,b,(ocg_arm_cpu.apsr&OCG_ARM_C)!=0);
}
static inline ocg_int ocg_arm_mul(ocg_int a,ocg_int b) {
  uint32_t r=(uint32_t)a*(uint32_t)b;
  ocg_arm_cpu.apsr=(ocg_arm_cpu.apsr&(OCG_ARM_C|OCG_ARM_V)) | ocg_arm_nz(r);
  return (ocg_int)r;
}
static inline ocg_int ocg_arm_uml(ocg_int a,ocg_int b) {
  uint64_t r=(uint64_t)(uint32_t)a*(uint32_t)b;
  ocg_arm_cpu.high=(uint32_t)(r>>32);
  return (ocg_int)(uint32_t)r;
}
static inline ocg_int ocg_arm_shift(uint32_t x,ocg_int n,unsigned operation) {
  unsigned k=(uint32_t)n&31, carry=(ocg_arm_cpu.apsr&OCG_ARM_C)!=0;
  uint32_t r=x;
  if(k) {
    if(operation==0) { carry=(x>>(32-k))&1; r=x<<k; }
    else {
      carry=(x>>(k-1))&1; r=x>>k;
      if(operation==1 && (x&OCG_ARM_N)) r|=UINT32_MAX<<(32-k);
      if(operation==2) r|=x<<(32-k);
    }
  }
  ocg_arm_cpu.apsr=(ocg_arm_cpu.apsr&OCG_ARM_V) | ocg_arm_nz(r) | (carry ? OCG_ARM_C : 0);
  return (ocg_int)r;
}
static inline bool ocg_arm_condition(unsigned condition) {
  uint32_t f=ocg_arm_cpu.apsr;
  bool n=(f&OCG_ARM_N)!=0, z=(f&OCG_ARM_Z)!=0;
  bool c=(f&OCG_ARM_C)!=0, v=(f&OCG_ARM_V)!=0;
  switch(condition) {
  case 0: return z; case 1: return !z; case 2: return c; case 3: return !c;
  case 4: return n; case 5: return !n; case 6: return v; case 7: return !v;
  case 8: return c&&!z; case 9: return !c||z;
  case 10: return n==v; case 11: return n!=v;
  case 12: return !z&&(n==v); case 13: return z||(n!=v);
  case 14: return true; default: return false;
  }
}
static inline void ocg_arm_interrupts(unsigned enable) {
  if(enable) __asm__ volatile("cpsie i" ::: "memory");
  else __asm__ volatile("cpsid i" ::: "memory");
}
/* Board support supplies this only if the Oberon program uses LED(). */
void ocg_cortex_led(ocg_int value);
#endif
