#define MODULE_Kernal

#include "_OGCC.h"

static ModuleId moduleId;

Module get_module_list(void)
{
  return module_list;
}

void _init_Kernal (void) {
  moduleId = add_module ("Kernal");
}
