#include "pipe.h"
#include "buffer.h"
#include "memory.h"

struct pipe {
	struct buffer * buf;
};

struct pipe * agP_open(size_t size)
{
	struct pipe * p = (struct pipe*)MALLOC(sizeof(struct pipe));
	p->buf = _agB_new(size);

	return p;
}

void agP_close(struct pipe * p)
{
	if (p) {
		if (p->buf) {
			FREE(p->buf);
		}
		FREE(p);
	}
}

size_t agP_size(struct pipe * p)
{
	return _agB_size(p->buf);
}

int agP_write(struct pipe * p, const void * data, size_t len)
{
	return _agB_write(p->buf, data, len);
}

void * agP_buffer(struct pipe * p, size_t len)
{
	return _agB_buffer(p->buf, len);
}

const void * agP_peek(struct pipe * p, size_t len)
{
	return _agB_peek(p->buf, len);
}

const void * agP_read(struct pipe * p, size_t len)
{
	return _agB_read(p->buf, len);
}
