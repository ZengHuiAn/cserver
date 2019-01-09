#include <time.h>

#include "dlist.h"
#include "memory.h"
#include "timer.h"
#include "mtime.h"

#define MAX_TIMER	(3600 * 1)

struct TimerManger {
	time_t next;
	struct Timer * timer_list[MAX_TIMER];
};

struct Timer {
	struct Timer * prev;
	struct Timer * next;

	time_t at;
	TimerCallBack cb;
	void * data;
};

static struct TimerManger manager;

int module_timer_load(int argc, char * argv[]) 
{
	int i;
	for(i = 0; i < MAX_TIMER; i++) {
		manager.timer_list[i] = 0;
		manager.next = agT_current();
	}
	return 0;
}

int module_timer_reload()
{
	return 0;
}

void module_timer_update(time_t now)
{
	for (; manager.next <= now; manager.next++) {
		int pos = manager.next % MAX_TIMER;
		struct Timer * list = manager.timer_list[pos];
		manager.timer_list[pos] = 0;

		while(list) {
			struct Timer * timer = list;
			dlist_remove(list, timer);

			timer->cb(timer->at, timer->data);

			FREE(timer);
		}
	}
}

void module_timer_unload()
{
	int i;
	for (i = 0; i < MAX_TIMER; i++) {
		struct Timer * list = manager.timer_list[i];
		while(list) {
			struct Timer * timer = list;
			dlist_remove(list, timer);
			FREE(timer);
		}
	}
}


int timer_max_sec()
{
	return MAX_TIMER - 1;
}

struct Timer * timer_add(time_t at, TimerCallBack cb, void * data)
{
	if (at < manager.next || at >= manager.next + MAX_TIMER) {
		return 0;
	}

	struct Timer * timer = MALLOC_N(struct Timer, 1);
	if (timer == 0) return 0;

	dlist_init(timer);
	timer->next = 0;
	timer->at   = at;
	timer->cb   = cb;
	timer->data = data;

	int pos = at % MAX_TIMER;
	dlist_insert_tail(manager.timer_list[pos], timer);
	
#if 0

	if (manager.timer_list == 0 || timer->at < manager.timer_list->at) {
		dlist_insert_head(manager.timer_list, timer);
	} else if (timer->at >= manager.timer_list->prev->at) {
		dlist_insert_tail(manager.timer_list, timer);
	} else {
		struct Timer * ite = 0;
		// find position from tail
		while((ite = dlist_prev(manager.timer_list, ite)) != 0) {
			if (ite->at <= timer->at) {
				break;
			}
		}

		assert(ite);
		dlist_insert_after(ite, timer);
	}
#endif
	return timer;
}

void timer_remove(struct Timer * timer)
{
	int pos = timer->at % MAX_TIMER;

	assert(timer && timer->next && timer->prev);
	dlist_remove(manager.timer_list[pos], timer);
	FREE(timer);
}
