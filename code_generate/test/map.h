#ifndef _MAP_H_
#define _MAP_H_

#include <stdint.h>

#include "memory.h"

struct map;

struct map * _agMap_new(struct heap * heap);
void         _agMap_delete(struct map * map);
size_t       _agMap_size(struct map * map);

void *       _agMap_alloc(struct map * map, size_t s);

void *       _agMap_ip_get(struct map * map, uint64_t key);
void *       _agMap_ip_set(struct map * map, uint64_t key, void * p);

void *       _agMap_sp_get(struct map * map, const char * key);
void *       _agMap_sp_set(struct map * map, const char * key, void * p);
void *       _agMap_sp_next(struct map * map, const char ** key);
void         _agMap_sp_foreach(struct map *map, void (*func)(const char * key, void *p, void * ctx), void * ctx);

#endif
