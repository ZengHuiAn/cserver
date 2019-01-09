#include <stdlib.h>
#include <string.h>

#include "event_manager.h"
#include "buffer.h"

struct watcher {
	struct watcher * prev;
	struct watcher * next;

	void (*cb)(unsigned int id, const void * param, size_t len, const void * ctx);
	const void * ctx;
};

struct WatcherList {
	struct watcher * head;
	struct watcher * tail;
};

struct watcher * free_watcher = 0;

struct watcher * alloc_watcher()
{
	if (free_watcher == 0) {
		return (struct watcher*)malloc(sizeof(struct watcher));
	} else {
		struct watcher * w = free_watcher;
		free_watcher->next = w->next;
		return w;
	}
}

void release_watcher(struct watcher * w)
{
	w->next = free_watcher;
	free_watcher = w;
}

void cleanup_wather(struct watcher * list)
{
	while(list) {
		struct watcher * w = list;
		list = w->next;
		free(w);
	}
}


#define MAX_EVENT_ID	1024

struct EventManager {
	struct WatcherList events[MAX_EVENT_ID];
} eventManager = {
	{ {0,0}, },
};

static struct buffer * eventBuffer = 0;

int module_event_manager_load(int argc, char * argv[])
{
	memset(&eventManager, 0, sizeof(eventManager));
	return 0;
}

int module_event_manager_reload()
{
	return 0;
}

void module_event_manager_update(time_t now)
{
	agEvent_schedule();
}

void module_event_manager_unload()
{

	int i;
	for(i = 0; i < MAX_EVENT_ID; i++) {
		struct WatcherList * list = eventManager.events + i;
		if (list->head) {
			cleanup_wather(list->head);
			list->head = list->tail = 0;
		}
	}

	if (eventBuffer) _agB_free(eventBuffer);

	cleanup_wather(free_watcher);
	free_watcher = 0;
}

int agEvent_dispatch(unsigned int id, const void * param, size_t len)
{
	if (id >= MAX_EVENT_ID) {
		return -1;
	}

	if (eventBuffer == 0) {
		eventBuffer = _agB_new(4096);
	}

	_agB_write(eventBuffer, &id, sizeof(id));
	_agB_write(eventBuffer, &len, sizeof(len));
	_agB_write(eventBuffer, param, len);

	return 0;
}

int  agEvent_watch(unsigned int id, void (*cb)(unsigned int id, const void * param, size_t len, const void * ctx), const void * ctx)
{
	if (id >= MAX_EVENT_ID) {
		return -1;
	}

	struct watcher * w = alloc_watcher();
	w->cb = cb;
	w->ctx = ctx;
	w->next = 0;

	struct WatcherList * list = eventManager.events + id;
	if (list->head == 0) {
		list->head = w;
	}

	if (list->tail) {
		list->tail->next = w;
	}
	list->tail = w;
	return 0;
}

int agEvent_schedule()
{
	if (eventBuffer == 0) {
		return 0;
	}

	while(_agB_size(eventBuffer) > 0) {
		unsigned int id = *((int*)_agB_read(eventBuffer, sizeof(int)));
		size_t len = *((int*)_agB_read(eventBuffer, sizeof(len)));
		void * param = _agB_read(eventBuffer, len);

		struct WatcherList * list = eventManager.events + id;

		struct watcher * ite;
		for(ite = list->head; ite; ite = ite->next) {
			ite->cb(id, param, len, ite->ctx);
		}
	}
	return 0;
}
