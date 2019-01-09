#ifndef _WELLRNG523_H_
#define _WELLRNG523_H_

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

struct WELLRNG512aGenerator
{
	uint32_t state[16];
	uint32_t index;
	uint32_t count;
};

void     WELLRNG512a_seed  (struct WELLRNG512aGenerator * generator, uint32_t value);
void     WELLRNG512a_seed16(struct WELLRNG512aGenerator * generator, uint32_t values[16]);
uint32_t WELLRNG512a        (struct WELLRNG512aGenerator * generator);

#ifdef __cplusplus
}
#endif

#endif
