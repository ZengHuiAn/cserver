#include <time.h>

#include "map.h"
#include "local.h"
#include "dlist.h"
#include "memory.h"
#include "aiLevel.h"
#include "database.h"
#include "modules/hero.h"
#include "log.h"
#include "mtime.h"
#include "array.h"
#include "rankreward.h"
#include "timeline.h"
#include "config/rankreward.h"
#include "logic/aL.h"

#define ATOI(x,def) ( (x) ? atoll((const char*)x):(def))

struct RankValue{
	unsigned long long pid;
	int value;
};

struct RankList {
	int type;
	int n;
	struct RankValue top[RANK_COUNT];
};

static struct RankList rank_exp  = {RANK_TYPE_EXP,  0, {{0,0}}};
static struct RankList rank_star = {RANK_TYPE_STAR, 0, {{0,0}}};
static struct RankList rank_tower = {RANK_TYPE_TOWER, 0, {{0,0}}};


static int32_t open_flag = 0;  //  0未開放 1 开放
static uint32_t first_begin_time = 0;
static uint32_t rank_reward_begin = 0;
static uint32_t rank_reward_end = 0; 

static void rank_insert(struct RankList * list, unsigned long long pid, int value);
static void check_reward(time_t now);
static void init_rank_reward_end();
static int first_begin_rank_reward = 1;

static int on_query(struct slice *fields,void *ctx)
{
	struct RankList * rank = (struct RankList*)ctx;
	unsigned long long pid = ATOI(fields[0].ptr, 0);
	unsigned int value = ATOI(fields[1].ptr, 0);
	rank_insert(rank, pid, value);

	return 0;
}

static int on_query_flag(struct slice *fields,void *ctx)
{
	first_begin_rank_reward = 0;
	first_begin_time = ATOI(fields[0].ptr, 0);
	rank_reward_begin = ATOI(fields[1].ptr, 0);
	open_flag = ATOI(fields[2].ptr, 0);
	time_t begin = rank_reward_begin;
	init_rank_reward_end();
	time_t end = rank_reward_end;
	WRITE_DEBUG_LOG("rank_reward_begin = %s",ctime(&begin));
	WRITE_DEBUG_LOG("rank_reward_end = %s",ctime(&end));

	return 0;
}

static void init_first_rankreward_time()
{
	time_t now = agT_current();
	if ((now - GET_DAY_BEGIN_TIME(now)) < BEGIN_HOUR) {
		first_begin_time = GET_DAY_BEGIN_TIME(now) + BEGIN_HOUR - RANK_PERIOD;
	} else {
		first_begin_time = GET_DAY_BEGIN_TIME(now) + BEGIN_HOUR;
	}

	rank_reward_begin = first_begin_time;
	init_rank_reward_end();
	open_flag = 1;

	database_update(role_db,"insert into rank_flag (id, open_flag, first_begin_time, begin_time) values(1, 1, from_unixtime_s(%d), from_unixtime_s(%d))",first_begin_time, rank_reward_begin);
}

int module_rankreward_load(int argc,char **argv)
{
	if(database_query(role_db, on_query_flag, 0, "select unix_timestamp(`first_begin_time`) as first_begin_time, unix_timestamp(`begin_time`) as begin_time, open_flag from `rank_flag` where `id`=1") != 0){
		WRITE_ERROR_LOG("load rank_flag failed!");
		return -1;
	}

	if (first_begin_rank_reward) {
		WRITE_DEBUG_LOG("first begin rankreward activity");
		init_first_rankreward_time();
	}

	if(database_query(role_db, on_query, &rank_exp, "select pid, exp from hero where gid = %d order by exp desc, exp_change_time limit %d", LEADING_ROLE, RANK_COUNT) != 0){
		WRITE_ERROR_LOG("load failed , rank_exp");
		return -1;
	}

	if(database_query(role_db, on_query, &rank_star, "select pid, total_star from property order by total_star desc, total_star_change_time limit %d", RANK_COUNT)!=0){
		WRITE_ERROR_LOG("load failed rank_star");
		return -1;
	}

	if(database_query(role_db, on_query, &rank_tower, "select pid, max_floor from property order by max_floor desc, max_floor_change_time limit %d", RANK_COUNT)!=0){
		WRITE_ERROR_LOG("load failed rank_tower");
		return -1;
	}

	return 0;
}

int module_rankreward_reload()
{
	return 0;
}

void module_rankreward_update(time_t now)
{
	//WRITE_DEBUG_LOG("module rankreward update >>>>>>>>");
	check_reward(now);
}

void module_rankreward_unload()
{
}

static unsigned long long rank_get(struct RankList * list, unsigned int index, unsigned int * value)
{
	struct RankValue * rank = list->top;

	if (index < 1 || index > RANK_COUNT) {
		return 0;
	}

	if(value) *value=rank[index-1].value;
	return rank[index-1].pid;
}

unsigned long long rank_exp_get(unsigned int index, unsigned int * value)
{
	return rank_get(&rank_exp, index, value);
}

unsigned long long rank_star_get(unsigned int index, unsigned int * value)
{
	return rank_get(&rank_star, index, value);
}

unsigned long long rank_tower_get(unsigned int index, unsigned int * value)
{
	return rank_get(&rank_tower, index, value);
}


unsigned int rank_exp_set(unsigned long long pid, unsigned int exp)
{
	rank_insert(&rank_exp, pid, exp);
	return 0;
}

unsigned int rank_star_set(unsigned long long pid,unsigned int total_count)
{
	rank_insert(&rank_star, pid, total_count);
	return 0;
}

unsigned int rank_tower_set(unsigned long long pid,unsigned int floor)
{
	rank_insert(&rank_tower, pid, floor);
	return 0;
}

static void rank_insert(struct RankList * list, unsigned long long pid, int value)
{
	int nTop = list->n;
	struct RankValue * top = list->top;

	/*
	if (!find) {
		if (nTop < RANK_COUNT) {
			top[nTop].pid = pid;
			top[nTop].value = value;
			nTop ++;
		}
		return;
	}
	*/

	if (nTop >= RANK_COUNT && value <= top[RANK_COUNT-1].value) {
		return;
	}

	// 寻找
	int i;
	for (i = 0; i < nTop; i++) {
		if (top[i].pid == pid) {
			assert(value >= top[i].value);
			top[i].value = value;
			break;
		};
	}

	if (i >= nTop) {
		// 没找到
		if (nTop < RANK_COUNT) {
			// 还有空位
			top[nTop].pid = pid;
            top[nTop].value = value;
            nTop ++;
		} else {
			// 没空位
			top[RANK_COUNT-1].pid = pid;
			top[RANK_COUNT-1].value = value;
			i = RANK_COUNT-1;
		}
	}

	// 前移
	for (; i > 0; i--) {
		if (top[i-1].value < top[i].value) {
			unsigned long long pid = top[i].pid;
			int value = top[i].value;

			top[i].pid = top[i-1].pid;		
			top[i].value = top[i-1].value;		

			top[i-1].pid = pid;
			top[i-1].value = value;
		}
	}
	list->n = nTop;
}

int32_t get_flag_of_rank()
{
	return open_flag;
}

uint32_t get_first_begin_time()
{
	return first_begin_time;
}

/*static void update_rank_flag()
{
	if(g_flag == 0) {
		database_update(role_db,"update `rank_flag` set `rank_flag` = 1 where `id` = 1");
		g_flag = 1;
	}
}*/

static void resetTimeRange()
{
	rank_reward_begin = rank_reward_end;
	rank_reward_end = rank_reward_begin + RANK_PERIOD;
	database_update(role_db, "update rank_flag set begin_time = from_unixtime_s(%d) where `id`= 1", rank_reward_begin);
}

static int is_weekly()
{
	if (((rank_reward_end - first_begin_time) / RANK_PERIOD) % 7 == 0) {
		return 1;
	} else {
		return 0;
	}
}

static int is_first_week()
{
	if ((rank_reward_end - first_begin_time) / RANK_PERIOD <= 7) {
		return 1;
	} else {
		return 0;
	}
}

static void send_reward_of_rank_list(struct RankList * rank, int reason, const char * message)
{
	if (!open_flag) {
		return;
	}

	int j;
	for(j= 1;j<= RANK_COUNT;j++) {
		unsigned int value = 0;
		unsigned long long pid = 0;
		pid = rank_get(rank,j,&value);

		WRITE_INFO_LOG("send reward of rank_type %d: pid %llu, value %d, rank %d", rank->type, pid, value, j);

		if (pid == 0) {
			continue;
		}

		Player * player=player_get(pid);
		if(player == 0){
			continue;
		}

		struct RewardContent content;
		int first_week = is_first_week();
		int weekly = is_weekly();
		//WRITE_INFO_LOG("send reward first_week %d weekly %d", first_week, weekly);
		struct RankRewardConfig * cfg = get_rank_reward_config(rank->type, j, first_week, weekly);
		if (!cfg) continue;
		WRITE_INFO_LOG("rank reward type %d, id %d, value %d  first_week %d weekly %d", content.type,content.id,content.value, first_week, weekly);

		char msg[128] = {0};
    	sprintf(msg, message, j);
		if (sendReward(player, 0, msg, 1, 0, reason, 1, cfg->type, cfg->id, cfg->value) != 0) {
			WRITE_ERROR_LOG("    failed");
		}
	}
}

static void check_reward(time_t now)
{
	time_t end_time = get_rank_reward_end();
	if(now  < end_time ) {
		return;
	}

	send_reward_of_rank_list(&rank_exp,  REASON_EXP_RANK_REWARD, "等级排行榜第%d名奖励");
	send_reward_of_rank_list(&rank_star, REASON_STAR_RANK_REWARD, "副本星星排行榜第%d名奖励");
	send_reward_of_rank_list(&rank_tower, REASON_TOWER_RANK_REWARD, "试练塔排行榜第%d名奖励");

	//update_rank_flag();
	resetTimeRange();
}

unsigned int get_rank_reward_begin(){
	return rank_reward_begin;
}

static void init_rank_reward_end()
{
	/*struct tm tm1;
	time_t timeep = (time_t)rank_reward_begin;
	localtime_r(&timeep, &tm1);
	tm1.tm_hour = 0;
	tm1.tm_min = 0;
	tm1.tm_sec = 0;
	time_t tmp = mktime(&tm1);
	rank_reward_end = tmp + RANK_PERIOD;*/
	rank_reward_end = rank_reward_begin + RANK_PERIOD;
}

unsigned int get_rank_reward_end()
{
	return rank_reward_end;
}
