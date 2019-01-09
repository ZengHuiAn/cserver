#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#include "memory.h"

struct key {
	size_t hash;
	union {
		uint64_t i;
		const char * s;
	};
};

struct slot {
	struct slot * head;
	struct slot * next;

	struct key   key;
	void *       value;
};

struct map
{
	struct heap * heap;

	size_t count;
	size_t size;

	struct slot * free;
	struct slot * slots;
};

static void * _alloc(struct heap * heap, size_t s)
{
	return heap ? _agMH_alloc(heap, s) : MALLOC(s);
}

static void _free(struct heap * heap, void * p)
{
	if (heap == 0) FREE(p);
}

struct map * _agMap_new(struct heap * heap)
{
	struct map * m = _alloc(heap, sizeof(struct map));
	memset(m, 0, sizeof(struct map));
	m->heap = heap;
	return m;
}

void _agMap_delete(struct map * map) 
{
	if (map) {
		_free(map->heap, map->slots);
		_free(map->heap, map);
	}
}

static size_t _s_calc_hash(const char * name)
{
	size_t len = strlen(name);
	size_t h = len;
	size_t step = (len>>5)+1;
	size_t i;
	for (i=len; i>=step; i-=step)
		h = h ^ ((h<<5)+(h>>2)+(size_t)name[i-1]);
	return h;
}

typedef size_t (*_func_hash)(struct key * key);
typedef int (*_func_cmp)(struct key * key1, struct key * key2);

static size_t _s_hash(struct key * key) 
{
	return _s_calc_hash(key->s);
}

static int _s_cmp(struct key * key1, struct key * key2) 
{
	return strcmp(key1->s, key2->s);
}

static size_t _i_hash(struct key * key)
{
	return key->i;
}

static int _i_cmp(struct key * key1, struct key * key2) 
{
	return key1->i - key2->i;
}

struct map_func {
	_func_hash hash;
	_func_cmp  cmp;
};

static struct map_func map_ip_func = { _i_hash, _i_cmp };
static struct map_func map_sp_func = { _s_hash, _s_cmp };

size_t _agMap_size(struct map * map)
{
	return map->count;
}

static struct slot * _find(struct map * map, struct key * key, struct map_func * func)
{
	return 0;
}

static struct slot * _find_free(struct map * map)
{
	size_t i;
	for(i = 0; i < map->size; i++) {
		if (map->slots[i].value == 0) {
			return map->slots + i;
		}
	}
	return 0;
}

static void _resize(struct map * map, size_t s)
{
	return ;
}

/*
static void _insert(struct map * map, struct key * key, union value * value, struct map_func * func)
{
	assert(map->size > 0);
}
*/

static void * _set_or_insert(struct map * map, struct key * key, union value * value, struct map_func * func)
{
	((void)_resize);
	return 0;
}

static void _remove(struct map * map, struct slot * slot)
{

}

void * _agMap_sp_get(struct map * map, const char * key)
{
	((void)_resize);
	struct key  skey;
	skey.s    = key;
	skey.hash = _s_hash(&skey);
	struct slot * s = _find(map, &skey, &map_sp_func); 
	return s ? s->value.ptr : 0;
}


void * _agMap_sp_set(struct map * map, const char * key, void * value)
{
	struct key skey;
	skey.s = key;
	skey.hash = _s_hash(&skey);

	union value svalue;
	svalue.ptr = value;

	return _set_or_insert(map, &skey, &svalue, &map_sp_func);
}

void * _agMap_ip_get(struct map * map, const char * key)
{
	((void)_resize);
	struct key  skey;
	skey.s    = key;
	skey.hash = _s_hash(&skey);
	struct slot * s = _find(map, &skey, &map_ip_func); 
	return s ? s->value.ptr : 0;
}


void * _agMap_ip_set(struct map * map, const char * key, void * value)
{
	struct key skey;
	skey.s = key;
	skey.hash = _s_hash(&skey);

	union value svalue;
	svalue.ptr = value;

	return _set_or_insert(map, &skey, &svalue, &map_ip_func);
}
