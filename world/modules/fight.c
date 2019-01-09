#include <assert.h>
#include <string.h>
#include "property.h"
#include "hero.h"
#include "data/Hero.h"
#include "database.h"
#include "log.h"
#include "package.h"
#include "notify.h"
#include "mtime.h"
#include "map.h"
#include "stringCache.h"
#include "event_manager.h"
#include "backend.h"
#include "protocol.h"
#include <stdint.h>
#include "dlist.h"
#include "map.h"
#include "fight.h"
#include "aifightdata.h"

#include "config/fight.h"


typedef struct FightSet
{
	//chapter->battle->fb
	int sum_star;//总星数
	int cur_fight_id;//0: 没有进入fb, 其他: 副本id
	struct map * m;
	struct Fight * list;
} FightSet;

void fight_init()
{

}

void * fight_new(Player * player)
{
	if (player == NULL)
	{
		return NULL;
	}

	FightSet * set = (FightSet *)malloc(sizeof(FightSet));
	memset(set, 0, sizeof(FightSet));

	set->m = _agMap_new(0);

	return set;
}

static int calc_star_count(int star)
{
	int count = 0;
	for (int i = 0; i < 15; i++) {
		if ((star & (1<<(i*2))) != 0) {
			count ++;
		}
	}

	return count ;
}

void * fight_load(Player * player)
{
	if (player == NULL)
	{
		return NULL;
	}

	unsigned long long pid = player_get_id(player);

	struct Fight * list = NULL;
	if (DATA_Fight_load_by_pid(&list, pid) != 0)
	{
		return NULL;
	}

	FightSet * set = (FightSet *)malloc(sizeof(FightSet));
	memset(set, 0, sizeof(FightSet));

	set->m = _agMap_new(0);

	int total_star = 0;
	while (list)
	{
		struct Fight * cur = list;
		list = cur->next;

		dlist_init(cur);
		dlist_insert_tail(set->list, cur);

		_agMap_ip_set(set->m, cur->gid, cur);
		
		struct PVE_FightConfig * pCfg = get_pve_fight_config(cur->gid);
		if (pCfg && pCfg->rank == FIGHT_TYPE_STAR) {
			total_star += calc_star_count(cur->star);
		}
	}
	property_change_total_star(player, total_star);

	if (player_get_id(player) <= AI_MAX_ID) {
		BalanceAIStar(player_get_id(player));
	}

	return set;
}

int fight_update(Player * player, void * data, time_t now)
{
	return 0;
}

int fight_save(Player * player, void * data, const char * sql, ...)
{
	return 0;
}

int fight_release(Player * player, void * data)
{
	if (player == NULL || data == NULL)
	{
		return -1;
	}

	FightSet * set = (FightSet *)data;

	while (set->list)
	{
		struct Fight * cur = set->list;

		dlist_remove(set->list, cur);
		DATA_Fight_release(cur);
	}

	_agMap_delete(set->m);
	free(set);

	return 0;
}

int fight_add_notify(struct Fight * fight)
{
	if (fight == NULL)
	{
		return -1;
	}

	amf_value * v = amf_new_array(5);
	amf_set(v, 0, amf_new_integer(fight->gid));
	amf_set(v, 1, amf_new_integer(fight->flag));
	amf_set(v, 2, amf_new_integer(fight->today_count));
	amf_set(v, 3, amf_new_integer(fight->update_time));
	amf_set(v, 4, amf_new_integer(fight->star));

	return notification_set(fight->pid, NOTIFY_FIGHT, fight->gid, v);
}

int fight_add(Player * player, unsigned int gid, int flag, int star, int count, int fight_time)
{
	if (player == NULL)
	{
		return RET_ERROR;
	}

	struct PVE_FightConfig * pCfg = get_pve_fight_config(gid);
	if (pCfg == NULL)
	{
		WRITE_DEBUG_LOG("%s player %llu not found config %d", __FUNCTION__, player_get_id(player), gid);
		return RET_NOT_EXIST;
	}

	FightSet * set = (FightSet *)player_get_module(player, PLAYER_MODULE_FIGHT);
	if (set == NULL)
	{
		WRITE_ERROR_LOG("%s player %llu get fight modeule fail", __FUNCTION__, player_get_id(player));
		return RET_ERROR;
	}

	if (_agMap_ip_get(set->m, gid) != NULL)
	{
		return RET_EXIST;
	}

	struct Fight * pNew = (struct Fight *)malloc(sizeof(struct Fight));
	memset(pNew, 0, sizeof(struct Fight));

	pNew->pid = player_get_id(player);
	pNew->gid = gid;
	pNew->flag = flag;
	pNew->star = star;
	pNew->today_count = count;
	pNew->update_time = agT_current();

	DATA_Fight_new(pNew);

	dlist_insert_tail(set->list, pNew);
	_agMap_ip_set(set->m, pNew->gid, pNew);

	return 0;
}

int fight_update_player_data(Player * player, struct Fight * fight, int flag, int star, int count)
{
	if (player == NULL || fight == NULL)
	{
		return RET_ERROR;
	}

	int ostar = calc_star_count(fight->star);
	DATA_Fight_update_flag(fight, flag);
	DATA_Fight_update_star(fight, star | fight->star);
	DATA_Fight_update_today_count(fight, count);
	DATA_Fight_update_update_time(fight, agT_current());

	fight_add_notify(fight);

	int nstar = calc_star_count(fight->star);
	WRITE_DEBUG_LOG("ostar  %d,   nstar %d", ostar, nstar);
	if (nstar > ostar) {
		Property * property = player_get_property(player);
		struct PVE_FightConfig * pCfg = get_pve_fight_config(fight->gid);
		if (property && pCfg && pCfg->rank == FIGHT_TYPE_STAR) {
			int new_total_star = property->total_star + (nstar - ostar);
			property_change_total_star(player, new_total_star);

			if (player_get_id(player) <= AI_MAX_ID) {
				BalanceAIStar(player_get_id(player));
			}
		}
	}

	return 0;
}

#define PVE_FIGHT_RESET_TIME 1262275200 //2010.1.1.0.0

#define DAY(t) (((t) - PVE_FIGHT_RESET_TIME) / (24 * 60 * 60))

struct Fight * fight_get(Player * player, int gid)
{
	FightSet * set = (FightSet *)player_get_module(player, PLAYER_MODULE_FIGHT);
	if (set == NULL)
	{
		WRITE_ERROR_LOG("%s player %llu get fight module fail", __FUNCTION__, player_get_id(player));
		return NULL;
	}

	struct Fight * fight = (struct Fight *)_agMap_ip_get(set->m, gid);

	if (fight) {
		if (DAY(agT_current()) != DAY(fight->update_time)) {
			fight->today_count = 0;
		}
	}

	return fight;
}

struct Fight * fight_next(Player * player, struct Fight * ite)
{
	FightSet * set = (FightSet *)player_get_module(player, PLAYER_MODULE_FIGHT);
	struct Fight * fight = dlist_next(set->list, ite);
	if (fight) {
		if (DAY(agT_current()) != DAY(fight->update_time)) {
			fight->today_count = 0;
		}
	}
	return fight;
}

int fight_current_id(Player * player)
{
	if (player == NULL)
	{
		return 0;
	}

	FightSet * set = (FightSet *)player_get_module(player, PLAYER_MODULE_FIGHT);
	if (set == NULL)
	{
		WRITE_ERROR_LOG("%s player %llu get fight module fail", __FUNCTION__, player_get_id(player));
		return 0;
	}

	return set->cur_fight_id;
}

int fight_prepare(Player * player, int gid, int limit, int yjdq)
{
	FightSet * set = (FightSet *)player_get_module(player, PLAYER_MODULE_FIGHT);
	if (set == NULL) {
		WRITE_ERROR_LOG("%s player %llu get module fight fail", __FUNCTION__, player_get_id(player));
		return RET_ERROR;
	}

	struct Fight * fight = (struct Fight *)_agMap_ip_get(set->m, gid);
	if (fight == NULL) {
		if (yjdq > 0) {
			return RET_FIGHT_CHECK_YJDQ_FAIL;//没通关过, 不可以扫荡
		}

		int r = fight_add(player, gid, 0, 0, 0, time(NULL));
		if (r != RET_SUCCESS) {
			WRITE_ERROR_LOG("add fight failed");
			return r;
		}
		set->cur_fight_id = gid;
	} else {
		if (yjdq > 0 && fight->star <= 0) {
			return RET_FIGHT_CHECK_YJDQ_FAIL;//没通关过, 不可以扫荡
		}

		if (fight->today_count >= limit) {
			WRITE_ERROR_LOG(" daily count limit");
			return RET_FIGHT_CHECK_COUNT_FAIL;
		}

		// fight_update_player_data(player, fight, 0, fight->star, fight->today_count + 1);
		set->cur_fight_id = gid;
	}

	return RET_SUCCESS;
}

int fight_check(Player * player, int gid, int star)
{
	FightSet * set = (FightSet *)player_get_module(player, PLAYER_MODULE_FIGHT);
	if (set == NULL)
	{
		WRITE_ERROR_LOG("%s player %llu get module fight fail", __FUNCTION__, player_get_id(player));
		return RET_ERROR;
	}

	if (set->cur_fight_id != gid)
	{
		return RET_NOT_EXIST;
	}

	struct Fight * fight = (struct Fight *)_agMap_ip_get(set->m, gid);
	if (fight == NULL)
	{
		return RET_NOT_EXIST;
	}

	set->cur_fight_id = 0;

	return RET_SUCCESS;
}

int fight_result(Player * player, int gid)
{
	struct Fight * fight = fight_get(player, gid);
	return (fight && fight->flag) ? PVE_FIGHT_SUCCESS : PVE_FIGHT_FAIL;
}

void fight_set_daily_count(struct Fight * fight, int count)
{
	if (count != fight->today_count) {
		DATA_Fight_update_today_count(fight, count);
		DATA_Fight_update_update_time(fight, agT_current());
	}

	fight_add_notify(fight);
}
