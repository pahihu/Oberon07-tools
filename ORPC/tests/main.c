#include "Client.h"
#include "Bytes.h"
#include "AliasUser.h"
#include "Expressions.h"
#include "Deep.h"
#include "DeepClient.h"
#include <assert.h>
int main(void) {
 O_Client__init(); O_Expressions__init(); assert(O_Client_answer==100);
 O_Client_Run(); assert(O_Records_result==36); assert(O_Client_answer==71);
 O_Expressions_Run(); assert(O_Expressions_ticks==0); assert(O_Expressions_result==49);
 O_Deep__init(); O_DeepClient__init(); O_Deep_Run();
 assert(O_DeepClient_size==sizeof(O_Deep_T)); assert(O_Deep_answer==145+sizeof(O_Deep_T));
 assert(ocg_is(&O_Records_b, &O_Records_Base_tag));
 assert(!ocg_is(&O_Records_b, &O_Records_Derived_tag));
 O_Bytes__init(); O_Bytes_init(); assert(O_Bytes_result==OCG_INT_MIN); O_AliasUser__init(); assert(O_AliasUser_r.f_n==3);
 assert(O_AliasClient_p->f_n==42); assert(O_AliasClient_size==sizeof(void *));
 free(O_AliasClient_p); free(O_Aliases_child); free(O_Records_q); return 0;
}
