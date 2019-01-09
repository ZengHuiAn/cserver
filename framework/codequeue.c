//#include "win_linux.h"
//#include "shm.h"
//#include "codequeue.h"

#include <string.h>
#include <stdint.h>
#include <stdarg.h>

#include "codequeue.h"
#include "log.h"
#include "memory.h"

#define AG_CODEQUEEU_RESERVE	4

struct codequeue {
	size_t begin;
	size_t end;
	size_t size;
};

typedef struct codequeue CQ;

struct codequeue * agCQ_open(void * ptr, size_t size)
{
	if (size < sizeof(CQ) + AG_CODEQUEEU_RESERVE) {
		return 0;
	}

	CQ * queue = agCQ_attach(ptr);

	if (queue) {
		queue->size  = size - sizeof(CQ);
		queue->begin = queue->end = 0;
	}
	return queue;
}

struct codequeue * agCQ_attach(void * ptr)
{
	CQ * queue = (CQ*)ptr;
	if (((long)&queue->begin) % sizeof(size_t) != 0 || ((long)&queue->end) % sizeof(size_t) != 0) {
		return 0;
	}
	return queue;
}

static void GetCriticalData(CQ * queue, size_t * begin, size_t * end)
{
	if (begin) {
		*begin = queue->begin;
	}

	if (end) {
		*end = queue->end;
	}
}

static void SetCriticalData(CQ * queue, size_t begin, size_t end)
{
	if (begin != (size_t)-1 && begin < queue->size) {
		queue->begin = begin;
	}

	if (end != (size_t)-1 && end < queue->size) {
		queue->end = end;
	}
}

#define CQSize(queue)  ((((CQ*)(queue))->size >= AG_CODEQUEEU_RESERVE) ? (((CQ*)(queue))->size - AG_CODEQUEEU_RESERVE) : 0)
#define CQLength(queue, begin, end)  (((end) >= (begin)) ?  ((end) - (begin)) : (((CQ*)(queue))->size + (end) - (begin)))

static size_t CQRead(CQ * queue, size_t begin, void * data, size_t len)
{
	const char * ptr = (const char*)(queue + 1);
	if (queue->size - begin > len) {
		memmove(data, ptr + begin, len);
	} else {
		size_t l1 = queue->size - begin;
		memcpy(data, ptr + begin, l1);
		memcpy(((char*)data) + l1, ptr, len - l1);
	}
	return (begin + len) % queue->size;
}

static size_t CQWrite(CQ * queue, size_t end, const void * data, size_t len)
{
	char * ptr = (char*)(queue + 1);
	if (queue->size - end > len) {
		memmove(ptr + end, data, len);
	} else {
		size_t l1 = queue->size - end;
		memmove(ptr + end, data, l1);
		memmove(ptr, ((char*)data) + l1, len - l1);
	}
	return (end + len) % queue->size;
}

size_t agCQ_pop(struct codequeue * _queue, void * data, size_t len)
{
	CQ * queue = (CQ *)_queue;

	size_t begin, end;
	GetCriticalData(queue, &begin, &end);
	
	if (begin == end) { return 0; }

	size_t length = CQLength(queue, begin, end);

	uint32_t rlen = 0;

	// read head
	if (length < sizeof(rlen)) {
		SetCriticalData(queue, end, -1);
		return 0;
	}

	begin = CQRead(queue, begin, &rlen, sizeof(uint32_t));

	// buffer is small
	if (len == 0 || rlen > len) {
		return rlen;
	}

	// skip head
	length -= sizeof(rlen);

	if (rlen > 0) {
		// read body
		if (length < rlen) {
			WRITE_ERROR_LOG("codequeue error data length");
			SetCriticalData(queue, end, -1);
			return 0;
		}
		begin = CQRead(queue, begin, data, rlen);
	}
	SetCriticalData(queue, begin, -1);
	return rlen;
}

size_t agCQ_push(struct codequeue * _queue, const void * data, size_t len)
{
	CQ * queue = (CQ *)_queue;

	size_t begin, end;
	GetCriticalData(queue, &begin, &end);

	size_t size = CQSize(queue);
	size_t length = CQLength(queue, begin, end);

	uint32_t wlen = (uint32_t)len;

	if ((length + len + sizeof(wlen)) > size) {
		return 0;
	}

	end = CQWrite(queue, end, &wlen, sizeof(wlen));
	if (len > 0) {
		end = CQWrite(queue, end, data, len);
	}
	SetCriticalData(queue, -1, end);
	return len;
}

size_t agCQ_pushv(struct codequeue * _queue, va_list args)
{
	CQ * queue = (CQ *)_queue;

	size_t begin, end;
	GetCriticalData(queue, &begin, &end);
	size_t s_end = 0;

	size_t size = CQSize(queue);
	size_t tlen = 0;

	end = (end + sizeof(uint32_t)) % queue->size;

	while(1) {
		const void * data = va_arg(args, const void*);
		if (data == 0) { break; }
		size_t len = va_arg(args, size_t);

		size_t length = CQLength(queue, begin, end);
		if ((length + len) > size) {
			return 0;
		}

		end = CQWrite(queue, end, data, len);

		tlen += len;
	}

	uint32_t wlen = tlen;
	CQWrite(queue, s_end, &wlen, sizeof(wlen));

	SetCriticalData(queue, -1, end);

	return tlen;
}

size_t agCQ_pushf(struct codequeue * queue, ...)
{
	va_list args;
	va_start(args, queue);
	size_t ret = agCQ_pushv(queue, args);
	va_end(args);
	return ret;
}
