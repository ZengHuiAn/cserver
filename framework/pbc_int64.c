#include "pbc_int64.h"

void pbc_wmessage_int64(struct pbc_wmessage * msg, const char * key, int64_t value)
{
	uint32_t low = 0, hi = 0;
    uint64_t u = (value>0) ? value : -value;
    hi = u >> 32;
    if (value < 0) {
        hi |= 0x80000000;
    }
    low = u & 0xffffffff;
    pbc_wmessage_integer(msg, key, low, hi);
}
int64_t pbc_rmessage_int64(struct pbc_rmessage * msg, const char * key, int idx)
{
	uint32_t low, hi;
	int64_t value;
    low = pbc_rmessage_integer(msg, key, idx, &hi);
 
    value = (((uint64_t)hi&0x7fffffff)<<32)|low;
    if (hi&0x80000000) {
        value = -value;
    }
    return value;
}
