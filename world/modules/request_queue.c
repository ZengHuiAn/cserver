#include <assert.h>

#include <assert.h>
#include <string.h>

#include "dlist.h"
#include "request_queue.h"
#include "database.h"
#include "log.h"
#include "package.h"
#include "hash.h"
#include "notify.h"
#include "map.h"
#include "database.h"
#include "event_manager.h"
#include "mtime.h"
#include <stdint.h>

typedef struct tagREQUEST_QUEUE{
	unsigned long long pid;
	PREQUEST_ITEM head;
	PREQUEST_ITEM tail;
}REQUEST_QUEUE, *PREQUEST_QUEUE;

////////////////////////////////////////////////////////////////////////////////
// struct, alloc and free
void request_queue_init()
{

}

void * request_queue_new(Player * player)
{
	PREQUEST_QUEUE queue= (PREQUEST_QUEUE)malloc(sizeof(REQUEST_QUEUE));
	memset(queue, 0, sizeof(REQUEST_QUEUE));
	queue->pid = player_get_id(player);
	return queue;
}

void * request_queue_load(Player * player)
{
	PREQUEST_QUEUE queue= (PREQUEST_QUEUE)malloc(sizeof(REQUEST_QUEUE));
	memset(queue, 0, sizeof(REQUEST_QUEUE));
	queue->pid = player_get_id(player);
	return queue;
}

int request_queue_update(Player * player, void * data, time_t now)
{
	return 0;
}

int request_queue_save(Player * player, void * data, const char * sql, ... )
{
	return 0;
}

int request_queue_release(Player * player, void * data)
{
	PREQUEST_QUEUE queue =(PREQUEST_QUEUE)data;
	if(queue){
		PREQUEST_ITEM item =queue->head;
		while(item){
			PREQUEST_ITEM next =item->next;
			free(item);
			item =next;
		}
		free(queue);
	}
	return 0;
}

// ctrl //
void request_queue_push(unsigned long long pid, struct network* net, uint32_t cmd, uint32_t flag, const char* data, uint32_t length){
	Player* player =player_get(pid);
	if(!player){
		WRITE_WARNING_LOG("fail to %s, player(%llu) not online", __FUNCTION__, pid);
		return;
	}

	PREQUEST_QUEUE queue =(PREQUEST_QUEUE)player_get_module(player, PLAYER_MODULE_REQUEST_QUEUE);
	assert(data && length);
	PREQUEST_ITEM item =(PREQUEST_ITEM)malloc(sizeof(REQUEST_ITEM) + length - 1);
	memset(item, 0, sizeof(REQUEST_ITEM) + length - 1);
	item->create_time =agT_current();	
	item->playerid    =pid;
	item->net         =net;
	item->cmd         =cmd;
	item->flag        =flag;
	item->length      =length;
	memcpy(item->data, data, length);

	if(queue->head == 0){
		queue->head =queue->tail =item;
	}
	else{
		queue->tail->next =item;
		item->prev =queue->tail;
		queue->tail =item;
	}
}
void request_queue_pop(unsigned long long pid){
	Player* player =player_get(pid);
	if(!player){
		WRITE_INFO_LOG("call %s, player(%llu) not online, perhaps logout", __FUNCTION__, pid);
		return;
	}

	PREQUEST_QUEUE queue =(PREQUEST_QUEUE)player_get_module(player, PLAYER_MODULE_REQUEST_QUEUE);
	if(queue->head == 0){
		return;
	}
	else if(queue->head == queue->tail){
		PREQUEST_ITEM item =queue->head;
		queue->head =queue->tail =0;
		free(item->context);
		free(item);
		return;
	}
	else{
		PREQUEST_ITEM item =queue->head;
		queue->head =queue->head->next;
		queue->head->prev =0;
		free(item->context);
		free(item);
		return;
	}
}

PREQUEST_ITEM request_queue_front(unsigned long long pid){
	Player* player =player_get(pid);
	if(!player){
		WRITE_WARNING_LOG("fail to %s, player(%llu) not online", __FUNCTION__, pid);
		return 0;
	}

	PREQUEST_QUEUE queue =(PREQUEST_QUEUE)player_get_module(player, PLAYER_MODULE_REQUEST_QUEUE);
	return queue->head;
}
