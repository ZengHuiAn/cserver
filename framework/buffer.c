#include <assert.h>
#include <string.h>
#include <stdio.h>

#include "buffer.h"
#include "memory.h"

struct buffer {
	size_t size;
	size_t rpos;
	size_t wpos;
	char * data;
};

static unsigned int _g_malloc = 0;
static unsigned int _g_free = 0;
static unsigned int _g_resize = 0;
static size_t _g_max_size = 0;

#define ALIGN(s) (((s) + 3 ) & ~3)

struct buffer * _agB_new(size_t size)
{
	if (size == 0) {
		size = 64;
	}

	size = ALIGN(size);

	struct buffer * buf = (struct buffer*)MALLOC(sizeof(struct buffer));
	if (buf) {
		buf->size = size;
		buf->rpos = 0;
		buf->wpos = 0;
		buf->data = (char*)MALLOC(size);

		++_g_malloc;
		if (size > _g_max_size) {
			_g_max_size = size;
		}
	}
	return buf;
}

void _agB_free(struct buffer * buf)
{
	if (buf) {
		++_g_free;
		FREE(buf->data);
		FREE(buf);
	}
}

/*
struct buffer * _agB_new2(const void * ptr, size_t len)
{
	struct buffer * buf = (struct buffer*)_agM_malloc(sizeof(struct buffer));
	if (buf) {
		buf->size = len;
		buf->rpos = 0;
		buf->wpos = 0;
		buf->data = (char*)ptr;

		++_g_malloc;
	}
	return buf;
}
*/

#define CHECK(buf) assert(buf->wpos <= buf->size && buf->rpos <= buf->size && buf->wpos >= buf->rpos)

size_t _agB_size(struct buffer * buf)
{
	CHECK(buf);
	return buf->wpos - buf->rpos;
}

static void _agB_align(struct buffer * buf)
{
	if (buf->rpos > 0 && buf->wpos > buf->rpos) {
		size_t s = buf->wpos - buf->rpos;
		memmove(buf->data, buf->data + buf->rpos, s);
		buf->rpos = 0;
		buf->wpos = s;
	}
}

static int _agB_resize(struct buffer * buf, size_t size)
{
	// out of range
	if (size < buf->wpos - buf->rpos) {
		return -1;
	}

	// wpos out of range
	if (buf->wpos > size) {
		_agB_align(buf);
	}

	assert(buf->wpos <= size);

	char * data = (char*)REALLOC(buf->data, size);
	if (data == 0) {
		return -1;
	}
	buf->data = data;
	buf->size = size;

	++ _g_resize;
	if (size > _g_max_size) {
		_g_max_size = size;
	}
	return 0;
}

void * _agB_peek(struct buffer * buf, size_t len)
{
	CHECK(buf);
	if (buf->wpos - buf->rpos < len) {
		return 0;
	} else {
		return buf->data + buf->rpos;
	}
}

void * _agB_read(struct buffer * buf, size_t len)
{
	CHECK(buf);
	if (buf->wpos - buf->rpos < len) {
		return 0;
	} else {
		char * ptr = buf->data + buf->rpos;
		buf->rpos += len;

		/*
		// shrink ?
		if (buf->size > 4096 && buf->wpos - buf->rpos <= 4096) {
			_agB_resize(buf, 4096);
		}
		*/
		return ptr;
	}
}

void * _agB_buffer(struct buffer * buf, size_t len)
{
	CHECK(buf);

	// calc new size
	size_t ns = buf->size;
	size_t nr = buf->wpos - buf->rpos + len;
	while(ns < nr) {
		ns *= 2;
	}

	// expend
	if (ns != buf->size) {
		if (_agB_resize(buf, ns) != 0) {
			return 0;
		}
	}

	// align
	if (buf->rpos == buf->wpos) {
		buf->rpos = buf->wpos = 0;
	}

	size_t tail = buf->size - buf->wpos;
	if (tail < len) {
		_agB_align(buf);
	}

	assert(buf->size - buf->wpos >= len);

	char * ptr = buf->data + buf->wpos;
	buf->wpos += len;
	return ptr;
}

int _agB_write(struct buffer * buf, const void * data, size_t len)
{
	void * ptr = _agB_buffer(buf, len);
	if (ptr == 0) {
		return -1;
	}
	memcpy(ptr, data, len);
	return 0;
}

char   _agB_getc(struct buffer * buf)
{
	char * ptr = (char*)_agB_read(buf, 1);
	return ptr ? ptr[0] : 0;
}

int    _agB_putc(struct buffer * buf, char c)
{
	return _agB_write(buf, &c, 1);
}

void _agB_statistic()
{
	printf("STATISTIC [agB] malloc %u, free %u, realloc %u, max %lu\n", _g_malloc, _g_free, _g_resize, _g_max_size);
}
