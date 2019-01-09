#include <string.h>

#include "stringCache.h"
#include "map.h"



static struct map * _m = 0;

const char * agSC_get(const char * str, size_t len)
{
	if (_m == 0) {
		_m = _agMap_new(0);
	}

	char * ptr = (char*)_agMap_sp_get(_m, str);

	if (ptr == 0) {
		ptr = (char*)malloc(len + 1);

		if (len == 0) len = strlen(str);
		memcpy(ptr, str, len);
		ptr[len] = 0;

		_agMap_sp_set(_m, ptr, ptr);
	}
	return ptr;
}
