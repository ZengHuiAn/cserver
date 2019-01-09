#ifndef H_PBC_INT64_H__
#define H_PBC_INT64_H__

#ifdef __cplusplus
extern "C" {
#endif

#include "pbc.h"

#ifdef __cplusplus
}
#endif



void pbc_wmessage_int64(struct pbc_wmessage * msg, const char * key, int64_t value);
int64_t pbc_rmessage_int64(struct pbc_rmessage * msg, const char * key, int idx);

#endif
