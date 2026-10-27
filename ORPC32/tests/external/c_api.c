#include "Foreign.h"
#include <assert.h>
int main(void) {
  O_Foreign__init();
  O_Foreign_SetValue(17);
  assert(O_Foreign_GetValue()==17);
  assert(O_Foreign_Add(2,9)==11);
  O_Foreign_Transform f=O_Foreign_Twice;
  assert(f(5)==10);
  return 0;
}
