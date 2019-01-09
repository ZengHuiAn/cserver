#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>

#include "memory.h"

static unsigned int _g_malloc  = 0;
static unsigned int _g_free    = 0;
static unsigned int _g_realloc = 0;

static pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;

static void lock()
{
	pthread_mutex_lock(&mutex);
}

static void unlock()
{
	pthread_mutex_unlock(&mutex);
}

static void malloc_record() {
	((void)lock);
	((void)unlock);

	// lock();
	++ _g_malloc;
	// unlock();
}

static void free_record()
{
	// lock();
	++ _g_free;
	// unlock();
}

void * _agM_malloc(size_t sz, const char * file, int line)
{
	void * p = malloc(sz);

	if (p) malloc_record();

	return p;
}

void _agM_free(void * p, const char * file, int line)
{
	if (p) {
		free_record();
		free(p);
	}
}

void * _agM_realloc(void *p, size_t sz, const char * file, int line)
{
	++ _g_realloc;
	return realloc(p,sz);
}

void   _agM_statistic()
{
	printf("STATISTIC [agM] malloc %u, free %u, realloc %u\n", _g_malloc, _g_free, _g_realloc);
}

void  _agM_dump()
{
}


struct heap_page {
	struct heap_page * next;
};

struct heap {
	struct heap_page *current;
	int size;
	int used;
};

struct heap * _agMH_new(int pagesize) {
	int cap = 1024;
	while(cap < pagesize) {
		cap *= 2;
	}
	struct heap * h = (struct heap*)MALLOC(sizeof(struct heap));
	h->current = (struct heap_page*)MALLOC(sizeof(struct heap_page) + cap);
	h->size = cap;
	h->used = 0;
	h->current->next = NULL;
	return h;
}

void _agMH_delete(struct heap *h) {
	struct heap_page * p = h->current;
	struct heap_page * next = p->next;
	for(;;) {
		FREE(p);
		if (next == NULL)
			break;
		p = next;
		next = p->next;
	}
	FREE(h);
}

void* _agMH_alloc(struct heap *h, int size) {
	size = (size + 3) & ~3;
	if (h->size - h->used < size) {
		struct heap_page * p;
		if (size < h->size) {
			p = (struct heap_page*)MALLOC(sizeof(struct heap_page) + h->size);
		} else {
			p = (struct heap_page*)MALLOC(sizeof(struct heap_page) + size);
		}
		p->next = h->current;
		h->current = p;
		h->used = size;
		return (p+1);
	} else {
		char * buffer = (char *)(h->current + 1);
		buffer += h->used;
		h->used += size;
		return buffer;
	}
}
