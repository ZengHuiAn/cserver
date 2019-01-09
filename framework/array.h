#ifndef _A_GAME_ARRAY_H_
#define _A_GAME_ARRAY_H_

#include <string.h>

#include "array.h"
#include "memory.h"

struct array;

struct array * array_new(size_t s);
void array_free(struct array * a);
void * array_get(struct array * a, size_t i);
void * array_set(struct array * a, size_t i, void * p);
size_t array_push(struct array * a, void * p);
size_t array_size(struct array * a);
size_t array_count(struct array * a);
int array_full(struct array * a);
int array_empty(struct array * a);

#endif
