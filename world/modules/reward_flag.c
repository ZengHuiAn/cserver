#include <assert.h>
#include <string.h>
#include "dlist.h"
#include "reward_flag.h"
#include "mtime.h"
#include "bag.h"
#include "database.h"
#include "log.h"
#include "notify.h"
#include "map.h"
#include <stdint.h>

typedef struct RewardFlagSet {
	struct map * m;
	RewardFlag * list;
} RewardFlagSet;


//事件角色数据接口
void reward_flag_init()
{
}

void * reward_flag_new(Player * player)
{
	RewardFlagSet * set = (RewardFlagSet*)malloc(sizeof(RewardFlagSet));
	set->list = 0;
	set->m = _agMap_new(0);

	return set;
}

#define HERO_IS_INUSE(hero)  (!!(hero->stat & HERO_STAT_INUSE))

void * reward_flag_load(Player * player)
{
	unsigned long long playerid = player_get_id(player);

	struct RewardFlag * list = 0;

	if (DATA_RewardFlag_load_by_pid(&list, playerid) != 0) {
		return 0;
	}

	RewardFlagSet * set = (RewardFlagSet*)malloc(sizeof(RewardFlagSet));
	set->list = 0;
	set->m = _agMap_new(0);

	while(list) {
		struct RewardFlag * cur = list;
		list = cur->next;

		dlist_init(cur);
		dlist_insert_tail(set->list, cur);

		_agMap_ip_set(set->m, cur->id, cur);

	}
	return set; 
}

int reward_flag_update(Player * player, void * data, time_t now)
{
	return 0;
}

int reward_flag_save(Player * player, void * data, const char * sql, ... )
{
	unsigned long long pid = player_get_id(player);
	database_update(role_db, "delete from rewardflag where pid = %llu", pid);
	return 0;
}

int reward_flag_release(Player * player, void * data)
{
	RewardFlagSet * set = (RewardFlagSet*)data;

	while(set->list) {
		RewardFlag * reward_flag = set->list;

		dlist_remove(set->list, reward_flag);
		DATA_RewardFlag_release(reward_flag);
	}
	_agMap_delete(set->m);
	free(set);
	return 0;
}

////////////////////////////////////////////////////////////////////////////////
static int add_notify(RewardFlag * reward_flag)
{
	if(!reward_flag) return -1;

	amf_value * res = amf_new_array(3);
	amf_set(res, 0, amf_new_integer(reward_flag->id));
	if (reward_flag->value >= AMF_INTEGER_MAX) {
		amf_set(res, 1, amf_new_double(reward_flag->value));
	} else {
		amf_set(res, 1, amf_new_integer(reward_flag->value));
	}

	return notification_set(reward_flag->pid, NOTIFY_REWARDFLAG, reward_flag->id, res);
}

#define player_get_reward_flag(player) \
	(RewardFlagSet*)player_get_module(player, PLAYER_MODULE_REWARDFLAG)

int reward_flag_get(Player * player, unsigned int id)
{
	unsigned int rid = id / 50;
	unsigned int pos = id % 50;

	unsigned long long mask = (((unsigned long long)1) << pos);

	RewardFlagSet * set = player_get_reward_flag(player);

	RewardFlag * reward_flag = (RewardFlag*)_agMap_ip_get(set->m, rid);

	return (reward_flag && (reward_flag->value & mask) > 0) ? 1 : 0;
}

RewardFlag * reward_flag_next(Player * player, RewardFlag * reward_flag)
{
	RewardFlagSet * set = (RewardFlagSet*)player_get_reward_flag(player);
	return dlist_next(set->list, reward_flag);
}

int reward_flag_set(Player * player, unsigned int id)
{
	unsigned int rid = id / 50;
	unsigned int pos = id % 50;

	WRITE_DEBUG_LOG(" !!!!!!!! %d, %d, %d", id, rid, pos);

	unsigned long long mask = (((unsigned long long)1) << pos);

	RewardFlagSet * set = player_get_reward_flag(player);
	RewardFlag * reward_flag = (RewardFlag*)_agMap_ip_get(set->m, rid);

	if (reward_flag == 0) {
		reward_flag = (RewardFlag*)malloc(sizeof(RewardFlag));
		memset(reward_flag, 0, sizeof(RewardFlag));
		reward_flag->pid   = player_get_id(player);
		reward_flag->id    = rid;
		reward_flag->value = mask;

		if (DATA_RewardFlag_new(reward_flag) != 0) {
			free(reward_flag);
			return -1;
		}

		_agMap_ip_set(set->m, reward_flag->id, reward_flag);
		dlist_insert_tail(set->list, reward_flag);
	} else {
		if ( (reward_flag->value & mask) != 0) {
			return 0;
		}

		DATA_RewardFlag_update_value(reward_flag, reward_flag->value | mask);
	}

	add_notify(reward_flag);

	return 0;
}
