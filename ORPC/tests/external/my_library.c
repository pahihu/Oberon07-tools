#include "ocg_runtime.h"
static ocg_int value;
void MyLib_SetValue(ocg_int x) { value=x; }
ocg_int MyLib_GetValue(void) { return value; }
ocg_int MyLib_Add(ocg_int a,ocg_int b) { return a+b; }
ocg_int MyLib_Twice(ocg_int x) { return x*2; }
void MyLib_Adjust(ocg_int *x,ocg_int amount) { *x+=amount; }
ocg_int MyLib_Sum(const ocg_int *values,ocg_int length) {
  ocg_int result=0;
  for(ocg_int i=0;i<length;++i) result+=values[i];
  return result;
}
ocg_real_t MyLib_Scale(ocg_real_t x) { return x*2.5f; }
void MyLib_Touch(void) { ++value; }
ocg_int MyLib_Local(ocg_int x) { return x*4; }

typedef ocg_int (*Transform)(ocg_int);
ocg_int MyLib_Apply(Transform f,ocg_int x) { return f(x); }
Transform MyLib_GetCallback(void) { return MyLib_Twice; }
