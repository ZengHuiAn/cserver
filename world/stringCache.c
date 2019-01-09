#include <string.h>
#include <stdio.h>

#include "stringCache.h"
#include "map.h"
#include "memory.h"

static struct map * _m = 0;
static struct heap * _h = 0;

const char * agSC_get(const char * str, size_t len)
{
	if (_m == 0) {
		_h = _agMH_new(4096);
		_m = _agMap_new(_h);
	}

	char * ptr = (char*)_agMap_sp_get(_m, str);
	printf("agSC_get %s %p\n", str, ptr);

	if (ptr == 0) {
		if (len == 0) len = strlen(str);

		ptr = (char*)_agMH_alloc(_h, len + 1);

		if (len == 0) len = strlen(str);
		memcpy(ptr, str, len);
		ptr[len] = 0;

		_agMap_sp_set(_m, ptr, ptr);
	}
	return ptr;
}

void agSC_release()
{
	if (_m) _agMap_delete(_m);
	if (_h) _agMH_delete(_h);
	_h = 0;
	_m = 0;
}
