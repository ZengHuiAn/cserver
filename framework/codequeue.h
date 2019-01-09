#ifndef _A_GAME_NETWORK_CODEQUEUE_H_
#define _A_GAME_NETWORK_CODEQUEUE_H_

#include <stdlib.h>
#include <stdarg.h>

struct codequeue;

struct codequeue * agCQ_open  (void * ptr, size_t size);
struct codequeue * agCQ_attach(void * ptr);

size_t agCQ_push(struct codequeue * queue, const void * data, size_t len);
size_t agCQ_pop (struct codequeue * queue,       void * data, size_t len);

size_t agCQ_pushf(struct codequeue * queue, ...);
size_t agCQ_pushv(struct codequeue * queue, va_list args);

#endif
