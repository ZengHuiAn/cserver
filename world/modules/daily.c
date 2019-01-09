#include <assert.h>

#include <assert.h>
#include <string.h>

#include "dlist.h"
#include "timeline.h"
#include "daily.h"
#include "database.h"
#include "log.h"
#include "package.h"
#include "hash.h"
#include "notify.h"
#include "mtime.h"
#include "modules/property.h"

#include "map.h"

////////////////////////////////////////////////////////////////////////////////
// struct, alloc and free

typedef struct DailySet {
	struct map * m;
	DailyData * list;
} DailySet;

//事件角色数据接口
void daily_init()
{
}

void * daily_new(Player * player)
{
	DailySet * data = (DailySet*)malloc(sizeof(DailySet));
	data->list = 0;
	//data->check = 0;
	data->m = _agMap_new(0);

	return data;
}

void * daily_load(Player * player)
{
	unsigned long long playerid = player_get_id(player);
	WRITE_DEBUG_LOG("player %llu load daily", playerid);

	struct DailyData * ds = 0;
	if (DATA_DailyData_load_by_pid(&ds, playerid) != 0) {
		return 0;
	}

	DailySet * data = (DailySet*)malloc(sizeof(DailySet));
	data->list = 0;
	data->m = _agMap_new(0);

	while(ds) {
		struct DailyData * cur = ds;
		ds = cur->next;

		dlist_init(cur);
		dlist_insert_tail(data->list, cur);

		_agMap_ip_set(data->m, cur->id, cur);
	}
	return data; 
}

int daily_update(Player * player, void * data, time_t now)
{
	return 0;
}

int daily_save(Player * player, void * data, const char * sql, ... )
{
	unsigned long long pid = player_get_id(player);
	database_update(role_db, "delete from dailydata where pid = %llu", pid);
	return 0;
}

int    daily_release(Player * player, void * data)
{

	// 写入在线时间， 这个数值写入间隔较久
	daily_update_online_time(player, agT_current(), 1);

	DailySet * set = (DailySet*)data;
	while(set->list) {
		DailyData * daily = set->list;
		dlist_remove(set->list, daily);

		DATA_DailyData_release(daily);
	}
	_agMap_delete(set->m);
	free(set);
	return 0;
}

////////////////////////////////////////////////////////////////////////////////
// operation
static int add_notify(DailyData * daily)
{
	return 0;
}

#define player_get_daily(player) (DailySet*)player_get_module(player, PLAYER_MODULE_DAILY);

#define DAY(x) timeline_get_day((x) - 5 * 3600)

DailyData * daily_next(Player * player, DailyData * daily)
{
	DailySet * data = player_get_daily(player);
	daily = dlist_next(data->list, daily);

	if (daily && daily->id == DAILY_ITEM_ONLINE) {
		if (daily && (timeline_get_day(agT_current()) != timeline_get_day(daily->update_time))) {
			daily->update_time = agT_current();
			daily->value = 0;
		}
		return daily;
	}

	if (daily && DAY(agT_current()) != DAY(daily->update_time)) {
		daily->update_time = agT_current();
		daily->value = 0;
		add_notify(daily);
	}
	return daily;
}

DailyData * daily_add(Player * player, unsigned int id)
{
	unsigned long long  playerid = player_get_id(player);

	WRITE_DEBUG_LOG("player %llu add daily %u", playerid, id);

	DailySet * data = player_get_daily(player);
	DailyData * daily = (DailyData*)_agMap_ip_get(data->m, id);
	if (daily) {
		return daily;
	}
	
	daily = (DailyData*)malloc(sizeof(DailyData));
	memset(daily, 0, sizeof(DailyData));
	daily->pid = playerid;
	daily->id = id;
	daily->update_time = agT_current();
	daily->value = 0;

	if (DATA_DailyData_new(daily) != 0) {
		free(daily);
		return 0;
	}

	_agMap_ip_set(data->m, daily->id, daily);
	dlist_insert_tail(data->list, daily);

	add_notify(daily);

	return daily;
}

int  daily_remove(Player * player, unsigned int type)
{
	unsigned long long playerid = player_get_id(player);

	WRITE_DEBUG_LOG("player %llu remove daily %u", playerid, type);

	DailySet * data = player_get_daily(player);
	DailyData * daily = (DailyData*)_agMap_ip_get(data->m, type);
	if (daily == 0) {
		return 0;
	}

	if (DATA_DailyData_delete(daily) != 0) {
		return -1;
	}

	_agMap_ip_set(data->m, daily->id, (void*)0);
	dlist_remove(data->list, daily);

	//通知
	daily->update_time = 0;
	daily->value = 0;
	add_notify(daily);

	return 0;
}


DailyData * daily_get(Player * player, unsigned int id)
{
	DailySet * data = player_get_daily(player);
	DailyData * daily = (DailyData*)_agMap_ip_get(data->m, id);

	if (id == DAILY_ITEM_ONLINE) {
		if (daily && (timeline_get_day(agT_current()) != timeline_get_day(daily->update_time))) {
			DATA_DailyData_update_value(daily, 0);
			DATA_DailyData_update_update_time(daily, agT_current());
		}
		return daily;
	}

	if (daily && DAY(agT_current()) != DAY(daily->update_time)) {
		DATA_DailyData_update_value(daily, 0);
		DATA_DailyData_update_update_time(daily, agT_current());
		add_notify(daily);
	}
	return daily;
}

DailyData * daily_get_raw(Player * player, unsigned int id)
{
	DailySet * data = player_get_daily(player);
	return (DailyData*)_agMap_ip_get(data->m, id);
}

DailyData * daily_next_raw(Player * player, DailyData * daily)
{
	DailySet * data = player_get_daily(player);
	return dlist_next(data->list, daily);
}


int daily_set(DailyData * daily, unsigned int value)
{
	if (value == daily->value) {
		return 0;
	}

	DATA_DailyData_update_value(daily, value);
	DATA_DailyData_update_update_time(daily, agT_current());

	//DATA_FLUSH_ALL();

	add_notify(daily);

	return 0;
}

unsigned int daily_get_online_time(Player * player)
{
	DailyData * daily = daily_get(player, DAILY_ITEM_ONLINE);
	if (daily == 0) {
		return 0;
	}

	if (player_get_conn(player_get_id(player)) == INVALID_ID) {
		return daily->value;
	}

	struct CheckData * check = player_get_check_data(player);

	time_t now = agT_current();

	// 5分钟没心跳了
	if (check->daily_online_record_time == 0 || now > check->tick_time + 5 * 60) {
		check->daily_online_record_time = now;
	}

	if (now > check->daily_online_record_time) {
		time_t today_sec = timeline_get_sec(now) % (3600 * 24);
		if (now - check->daily_online_record_time > today_sec) {
			return today_sec;
		} else {
			return daily->value + now - check->daily_online_record_time;
		}
	} else {
		return daily->value;
	} 
}

void daily_update_online_time(Player * player, time_t now, int force)
{
	DailyData * daily = daily_get(player, DAILY_ITEM_ONLINE);
	if (daily == 0) {
		daily = daily_add(player, DAILY_ITEM_ONLINE);
	}

	// 每5分钟记录在线时长
	struct CheckData * check = player_get_check_data(player);

	// 5分钟没心跳了
	if (check->daily_online_record_time == 0 || now > check->tick_time + 5 * 60) {
		check->daily_online_record_time = now;
	}

	if (now > check->daily_online_record_time) {
		if (force || (now >= check->daily_online_record_time + 60 * 5)) {
			time_t today_sec = timeline_get_sec(now) % (3600 * 24);
			if (now - check->daily_online_record_time > today_sec) {
				// 跨天了
				daily_set(daily, today_sec);
			} else {
				daily_set(daily, daily->value + now - check->daily_online_record_time);
			}
			check->daily_online_record_time = now;
		}
	}
}


int daily_get_value(Player * player, unsigned int id)
{
	DailyData * daily = daily_get(player, id);	
	return daily ? daily->value : 0;
}

void daily_set_value(Player * player, unsigned int id, int value)
{
	DailyData * daily = daily_get(player, id);
	if (daily == 0) {
		daily = daily_add(player, id);
	}
	DATA_DailyData_update_value(daily, value);
	DATA_DailyData_update_update_time(daily, agT_current());
}


void daily_add_value(Player * player, unsigned int id, int value)
{

	DailyData * daily = daily_get(player, id);
	if (daily == 0) {
		daily = daily_add(player, id);
	}
	DATA_DailyData_update_value(daily, daily->value + value);
	DATA_DailyData_update_update_time(daily, agT_current());

	add_notify(daily);
}
