#include <stdint.h>
static int32_t value;
void MyLib_SetValue(int32_t x) { value=x; }
int32_t MyLib_GetValue(void) { return value; }
int32_t MyLib_Add(int32_t a,int32_t b) { return a+b; }
int32_t MyLib_Twice(int32_t x) { return x*2; }
void MyLib_Adjust(int32_t *x,int32_t amount) { *x+=amount; }
int32_t MyLib_Sum(const int32_t *values,int32_t length) {
  int32_t result=0;
  for(int32_t i=0;i<length;++i) result+=values[i];
  return result;
}
float MyLib_Scale(float x) { return x*2.5f; }
void MyLib_Touch(void) { ++value; }
int32_t MyLib_Local(int32_t x) { return x*4; }

typedef int32_t (*Transform)(int32_t);
int32_t MyLib_Apply(Transform f,int32_t x) { return f(x); }
Transform MyLib_GetCallback(void) { return MyLib_Twice; }
