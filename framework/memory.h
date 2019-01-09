#ifndef _A_GAME_COMM_MEMORY_H_
#define _A_GAME_COMM_MEMORY_H_

#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif

void * _agM_malloc(size_t sz, const char * file, int len);
void   _agM_free(void * p, const char * file, int len);
void * _agM_realloc(void *p, size_t sz, const char * file, int len);
void   _agM_statistic();

struct heap;

struct heap * _agMH_new(int pagesize);
void          _agMH_delete(struct heap *);
void        * _agMH_alloc(struct heap *, int size);


#define MALLOC(size)      _agM_malloc((size), __FILE__, __LINE__)
#define FREE(p)           _agM_free((p), __FILE__, __LINE__)
#define REALLOC(p, size)  _agM_realloc((p), (size), __FILE__, __LINE__)


#define MALLOC_N(type, n)     (type*)_agM_malloc(sizeof(type) * (n), __FILE__, __LINE__)

#ifdef __cplusplus
}
#endif

#endif
