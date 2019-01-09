#ifndef _A_GAME_WORLD_DISPATCH_H_
#define _A_GAME_WORLD_DISPATCH_H_

#include "network.h"
#include "player.h"


int start_dispatch(resid_t conn);
void kickPlayer(unsigned long long playerid, unsigned int reason);
// 返回值:0 => 有更多待处理请求, 1 => 正在忙, 2 => 无更多待处理请求, -1 => 出错
enum {
	PNR_ERROR  = -1,
	PNR_MORE   =  0,
	PNR_BUSY   =  1,
	PNR_EMPTY  =  2,
};
int process_next_request(unsigned long long pid);
resid_t get_gateway_conn();
void reset_gateway_conn();
void broadcast_to_client(const uint32_t cmd, const uint32_t flag, const char* msg, const int32_t msg_len, const int32_t count, const unsigned long long* pids);
void broadcast_hot_update_to_client(const int32_t id);

enum{
	HOT_UPDATE_EXCHANGE_GIFT           =1001,
	HOT_UPDATE_ACCUMULATE_CONSUME_GOLD =1002,
	HOT_UPDATE_FESTIVAL                =1003,
	HOT_UPDATE_ACCUMULATE_EXCHANGE     =1004,
};

#endif
