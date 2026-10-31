#ifndef OCG_TRAP_DECL_H
#define OCG_TRAP_DECL_H

#include <stdint.h>

void O_MainDebug_ReportError(int32_t O_MainDebug_2_why, int32_t O_MainDebug_2_module, int32_t O_MainDebug_2_position);

#define OCG_TRAP_AT(why,module,position) \
	O_MainDebug_ReportError((int32_t)why,(int32_t)module,position)
#endif
