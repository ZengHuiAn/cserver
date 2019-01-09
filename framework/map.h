#ifndef _AGAME_MAP_H_
#define _AGAME_MAP_H_

#include <stdint.h>

#include "memory.h"

struct map;

#if 0
struct map_element {
	struct map_element * next;

	size_t hash;
	union {
		uint64_t     i;
		const char * s;
	} key;
	void * value;
} map_element;
#endif

struct map * _agMap_new(struct heap * heap);
void         _agMap_delete(struct map * map);
size_t       _agMap_size(struct map * map);

void         _agMap_empty(struct map * map, void (*cb_free)(void * p));

void *       _agMap_alloc(struct map * map, size_t s);

void *       _agMap_ip_get(struct map * map, uint64_t key);
void *       _agMap_ip_set(struct map * map, uint64_t key, void * p);
void         _agMap_ip_foreach(struct map * map, void (*func)(uint64_t key, void *p, void * ctx), void * ctx);

void *       _agMap_sp_get(struct map * map, const char * key);
void *       _agMap_sp_set(struct map * map, const char * key, void * p);
void *       _agMap_sp_next(struct map * map, const char ** key);
void         _agMap_sp_foreach(struct map *map, void (*func)(const char * key, void *p, void * ctx), void * ctx);

// struct map_element * _agMap_next(struct map * map, struct map_element * ite);

#endif
