#ifndef _A_GAME_MODULES_REQUEST_QUEUE_H_
#define _A_GAME_MODULES_REQUEST_QUEUE_H_

#include "player.h"

DECLARE_PLAYER_MODULE(request_queue);

typedef struct tagREQUEST_ITEM{
	struct tagREQUEST_ITEM* prev;
	struct tagREQUEST_ITEM* next;
	void*   context;
	int     busy;
	int64_t create_time;
	unsigned long long playerid;
	int64_t rpc_id;
	struct network* net;
	uint32_t channel_id;
	uint32_t cmd;
	uint32_t flag;
	uint32_t length;
	char data[1];
}REQUEST_ITEM, *PREQUEST_ITEM;

void request_queue_push(unsigned long long pid, struct network* net, uint32_t cmd, uint32_t flag, const char* data, uint32_t length);
void request_queue_pop(unsigned long long pid);
PREQUEST_ITEM request_queue_front(unsigned long long pid);

#endif
