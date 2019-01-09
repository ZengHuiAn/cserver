#include <string.h>

#include "array.h"
#include "memory.h"

struct array
{
	size_t s;
	size_t c;
	void * p[1];
};

struct array * array_new(size_t s)
{
	struct array * a = (struct array*)MALLOC(sizeof(struct array) + sizeof(void*) * (s - 1));
	a->c = 0;
	a->s = s;
	memset(a->p, 0, sizeof(void*) * s);
	return a;
}

void array_free(struct array *a )
{
	FREE(a);
}

void * array_get(struct array * a, size_t i)
{
	return (i < a->s) ? a->p[i] : 0;
}

void * array_set(struct array * a, size_t i, void * p)
{
	if (i >= a->s) {
		return 0;
	}

	void * r = a->p[i];
	if (r == p ) {
		return 0;
	}

	if (r) a->c--;
	if (p) a->c++;
	a->p[i] = p;
	return r;
}

size_t array_push(struct array * a, void * p)
{
	if (p == 0) return -1;

	size_t i;
	for(i = 0; i < a->s; i++) {
		if (a->p[i] == 0) {
			a->p[i] = p;
			a->c++;
			return i;
		}
	}
	return -1;
}

size_t array_size(struct array * a)
{
	return a->s;
}

size_t array_count(struct array * a)
{
	return a->c;
}

int array_full(struct array * a)
{
	return a->c >= a->s;
}

int array_empty(struct array * a)
{
	return a->c == 0;
}
