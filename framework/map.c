#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#include "memory.h"
#include "map.h"

struct map_element {
	struct map_element * next;

	size_t hash;
	union {
		uint64_t     i;
		const char * s;
	} key;
	void * value;
} map_element;

struct map
{
	struct heap * heap;

	size_t item_count;
	size_t buckets_size;

	struct map_element ** buckets;
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
	struct map * m = (struct map*)_alloc(heap, sizeof(struct map));
	memset(m, 0, sizeof(struct map));
	m->heap = heap;
	return m;
}

void _agMap_delete(struct map * map) {
	if (map) {
		size_t i;
		for(i = 0; i < map->buckets_size; i++) {
			struct map_element * head = map->buckets[i];
			while(head) {
				struct map_element * cur = head;
				head = cur->next;
				_free(map->heap, cur);
			}
		}
		_free(map->heap, map->buckets);
		_free(map->heap, map);
	}
}

void  _agMap_empty(struct map * map, void (*cb_free)(void * p))
{
	if (map) {
		size_t i;
		for(i = 0; i < map->buckets_size; i++) {
			struct map_element * head = map->buckets[i];
			map->buckets[i] = 0;
			while(head) {
				struct map_element * cur = head;
				head = cur->next;

				if (cb_free) cb_free(cur->value);
				_free(map->heap, cur);
			}
		}
	}
}


/*
static void * _agMap_alloc(struct map * map, size_t s)
{
	return _alloc(map->heap, s);
}

static void _agMap_free(struct map * map, void * p)
{
	return _free(map->heap, p);
}
*/

size_t _agMap_size(struct map * map)
{
	return map->item_count;
}

static struct map_element * _new_element(struct map * map)
{
	return (struct map_element*)_alloc(map->heap, sizeof(struct map_element));
}

static void _free_element(struct map * map, struct map_element * element)
{
	_free(map->heap, element);
	map->item_count --;
}

static void _insert_element(struct map * map, struct map_element * element)
{
	assert(map->buckets_size > 0);

	size_t pos = element->hash % map->buckets_size;

	struct map_element * head = map->buckets[pos];
	element->next = head;
	map->buckets[pos] = element;

	map->item_count ++;
}

static void _resize(struct map * map, size_t s)
{
	if (map->buckets_size >= s) return;

	size_t os = map->buckets_size;
	size_t ns = map->buckets_size;
	if (ns == 0)  ns = 32;
	while(ns < s) ns *= 2;

	struct map_element ** old_buckets = map->buckets;

	map->buckets = (struct map_element**)_alloc(map->heap, sizeof(struct map_element*) * ns);
	memset(map->buckets, 0, sizeof(struct map_element*) * ns);
	map->item_count = 0;
	map->buckets_size = ns;

	size_t i;
	for(i = 0; i < os; i++) {
		struct map_element * ite = old_buckets[i];
		while(ite) {
			struct map_element * cur = ite;
			ite = ite->next;

			cur->next = 0;
			_insert_element(map, cur);
		}
	}

	if(old_buckets) _free(map->heap, old_buckets);
}

static struct map_element * _ip_find(struct map * map, uint64_t key, struct map_element ** pparent)
{
	if (map == 0 
			|| map->buckets == 0 
			|| map->item_count == 0 
			|| map->buckets_size == 0) {
		return 0;
	}

	size_t hash = key;

	struct map_element * parent = 0;
	size_t pos = hash % map->buckets_size;
	struct map_element * ite = map->buckets[pos];
	while(ite && (ite->hash != hash || ite->key.i != key)) {
		parent = ite;
		ite = ite->next;
	}
	if (ite == 0) parent = 0;
	if (pparent) *pparent = parent;

	return ite;
}

void * _agMap_ip_get(struct map * map, uint64_t key)
{
	struct map_element * cur = _ip_find(map, key, 0);
	return cur ? cur->value : 0;
}

void * _agMap_ip_set(struct map * map, uint64_t key, void * p)
{
	struct map_element * parent = 0;
	struct map_element * cur = _ip_find(map, key, &parent);

	void * o = 0;
	if (cur) {
		assert(map->buckets_size > 0);

		o = cur->value;
		if (p == 0) { // delete
			if (parent) {
				parent->next = cur->next;
			} else {
				map->buckets[key % map->buckets_size] = cur->next;
			}
			_free_element(map, cur);
		} else {
			cur->value = p;
		}
	} else if (p) {
		_resize(map, map->item_count + 1);
		struct map_element * element = _new_element(map);
		element->next     = 0;
		element->hash     = key;
		element->key.i    = key;
		element->value    = p;

		_insert_element(map, element);
	}
	return o;
}

void _agMap_ip_foreach(struct map * map, void (*func)(uint64_t key, void *p, void * ctx), void * ctx)
{
	size_t i;
	for(i = 0; i < map->buckets_size; i++) {
		struct map_element * ite = map->buckets[i];
		for(;ite;ite = ite->next) {
			func(ite->key.i, ite->value, ctx);
		}
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

static struct map_element * _sp_find(struct map * map, size_t hash, const char * key, struct map_element ** pparent)
{
	if (map == 0 
			|| map->buckets == 0 
			|| map->item_count == 0 
			|| map->buckets_size == 0) {
		return 0;
	}

	struct map_element * parent = 0;

	size_t pos = hash % map->buckets_size;
	struct map_element * ite = map->buckets[pos];
	while(ite && (ite->hash != hash || strcmp(ite->key.s, key) != 0)) {
		parent = ite;
		ite = ite->next;
	}
	if (ite == 0) parent = 0;
	if (pparent) *pparent = parent;

	return ite;
}

void * _agMap_sp_get(struct map * map, const char * key)
{
	size_t hash = _s_calc_hash(key);
	struct map_element * cur = _sp_find(map, hash, key, 0);
	return cur ? cur->value : 0;
}

void * _agMap_sp_set(struct map * map, const char * key, void * p)
{
	size_t hash = _s_calc_hash(key);

	struct map_element * parent = 0;
	struct map_element * cur = _sp_find(map, hash, key, &parent);

	void * o = 0;
	if (cur) {
		assert(map->buckets_size > 0);

		o = cur->value;
		if (p == 0) { // delete
			if (parent) {
				parent->next = cur->next;
			} else {
				map->buckets[hash % map->buckets_size] = cur->next;
			}
			_free_element(map, cur);
		} else {
			cur->value = p;
		}
	} else if (p) {
		_resize(map, map->item_count + 1);
		struct map_element * element = _new_element(map);
		element->next     = 0;
		element->hash     = hash;
		element->key.s    = key;
		element->value    = p;

		_insert_element(map, element);
	}
	return o;
}

static struct map_element * _find_first(struct map * map, size_t from)
{
	size_t i;
	for (i = from; i < map->buckets_size; i++) {
		if (map->buckets[i]) {
			return map->buckets[i];;
		}
	}
	return 0;
}

void * _agMap_sp_next(struct map * map, const char ** key)
{
	if (map == 0) {
		*key = 0;
		return 0;
	}

	if (*key == NULL) {
		return _find_first(map, 0);
	} 

	size_t hash = _s_calc_hash(*key);
	struct map_element * cur = _sp_find(map, hash, *key, 0);
	if (cur->next) {
		return cur->next;
	} else {
		return _find_first(map, (hash % map->buckets_size) + 1);
	}
}

void _agMap_sp_foreach(struct map *map, void (*func)(const char * key, void *p, void * ctx), void * ctx)
{
	size_t i;
	for(i = 0; i < map->buckets_size; i++) {
		struct map_element * ite = map->buckets[i];
		for(;ite;ite = ite->next) {
			func(ite->key.s, ite->value, ctx);
		}
	}
	return;
}

struct map_element * _agMap_next(struct map * map, struct map_element * ite)
{
	if (ite == 0) {
		return _find_first(map, 0);
	}

	if (ite->next) {
		return ite->next;
	} else {
		return _find_first(map, ite->hash % map->buckets_size + 1);
	}
}
