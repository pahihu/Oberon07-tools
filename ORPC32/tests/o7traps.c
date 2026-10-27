#include "Traps.h"
int main(int argc, char **argv) {
  if(argc!=2) return 2;
  O_Traps__init();
  switch(argv[1][0]) {
    case '0': O_Traps_Bounds(); break;
    case '1': O_Traps_Nil(); break;
    case '2': O_Traps_DivZero(); break;
    case '3': { O_Traps_T r={0}; O_Traps_T_init(&r); O_Traps_Guard(&r); break; }
    case '4': O_Traps_Assertion(); break;
    case '5': O_Traps_Overflow(); break;
    case '6': O_Traps_NilCall(); break;
    default: return 2;
  }
  return 0;
}
