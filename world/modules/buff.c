#include <assert.h>
#include <string.h>
#include "dlist.h"
#include "buff.h"
#include "mtime.h"
#include "database.h"
#include "log.h"
#include "notify.h"
#include "map.h"
#include <stdint.h>
#include "config/buff.h"
#include "logic/aL.h"

#include "calc/calc.h"


typedef struct BuffSet {
	struct map * m;
	Buff * list;
} BuffSet;

BuffSet * gBuffSet = 0;   //全局buff

void buff_init()
{

}

static void insert_into_sort_dlist(Buff ** list, Buff * cur)
{
	//WRITE_DEBUG_LOG("buff_id%d >>>>>>>>>>>>>", cur->buff_id);
	if (agT_current() > cur->end_time) {
		return;
	}
	
	if (*list == 0) {
		dlist_init(cur);
		//WRITE_DEBUG_LOG("insert tail >>>>>>>>");
		dlist_insert_tail(*list, cur);
	} else {
		Buff * it = 0;
		Buff * next = 0;
		while(dlist_next(*list, it)) {
			it = dlist_next(*list, it);
			if (cur->end_time > it->end_time) {
				dlist_init(cur);
				//WRITE_DEBUG_LOG("insert before buff %d >>>>>>>", it->buff_id);
				dlist_insert_before(it, cur);

				if (it == *list) {
					*list = cur;
				}
				break;
			} 

			next = dlist_next(*list, it);
			if ((cur->end_time <= it->end_time) && (next == 0 || cur->end_time >= next->end_time)) {
				dlist_init(cur);
				//WRITE_DEBUG_LOG("insert after buff %d >>>>>>>>", it->buff_id);
				dlist_insert_after(it, cur);
				break;
			}
		}
	}
}

static int load_global_buff()
{
	if (!gBuffSet) {
		Buff * list = 0;

		extern struct DBHandler * role_db;
		database_update(role_db, "delete from `buff` where  now() > `end_time` and pid = 0");

		if (DATA_Buff_load_by_pid(&list, 0) != 0) {
			return 0;
		}

		gBuffSet = (BuffSet*)malloc(sizeof(BuffSet));
		gBuffSet->list = 0;
		gBuffSet->m = _agMap_new(0);

		while(list) {
			Buff * cur = list;
			list = cur->next;

			insert_into_sort_dlist(&(gBuffSet->list), cur);
			_agMap_ip_set(gBuffSet->m, cur->buff_id, cur);

		}
	
	}

	return 1;
}

static int add_notify(Buff * buff)
{
	if(!buff) return -1;

	// notify
	amf_value * res = amf_new_array(3);
	amf_set(res, 0, amf_new_integer(buff->buff_id));
	amf_set(res, 1, amf_new_integer(buff->value));
	amf_set(res, 2, amf_new_integer(buff->end_time));

	return notification_set(buff->pid, NOTIFY_BUFF, buff->buff_id, res);
}


static int add_global_notify(Buff * buff)
{
	return add_notify(buff);
}

Buff * get_global_buff()
{
	if (!load_global_buff()) {
		return 0;
	}

	return gBuffSet->list;
}

static Buff * add_global_buff(unsigned int buff_id, unsigned int buff_value, time_t buff_end_time)
{
	if (!load_global_buff()) {
		return 0;
	}

	Buff * pNew = (Buff*)_agMap_ip_get(gBuffSet->m, buff_id);
	if (pNew) {
/*
		if (pNew->end_time >= agT_current()) {
			WRITE_ERROR_LOG("%s: fail to add global buff, buff:%d already exist", __FUNCTION__, buff_id);
			return 0;
		}
*/
		if (pNew->end_time > buff_end_time && buff_value <= 0) {
			return pNew;
		}

		if (pNew->end_time < agT_current()) {
			DATA_Buff_update_value(pNew, buff_value);
		} else {
			DATA_Buff_update_value(pNew, pNew->value + buff_value);
		}

		DATA_Buff_update_end_time(pNew, buff_end_time);
		//sort again
		dlist_remove(gBuffSet->list, pNew);
		insert_into_sort_dlist(&(gBuffSet->list), pNew);

		add_global_notify(pNew);
		
		return pNew;
	} else {
		Buff * pNew = (Buff*)malloc(sizeof(Buff));
		memset(pNew, 0, sizeof(Buff));
		pNew->pid = 0;
		pNew->buff_id = buff_id;
		pNew->end_time = buff_end_time;
		if (DATA_Buff_new(pNew) != 0) {
			free(pNew);
			return 0;
		}

		insert_into_sort_dlist(&(gBuffSet->list), pNew);
		_agMap_ip_set(gBuffSet->m, pNew->buff_id, pNew);

		add_global_notify(pNew);

		return pNew;
	}
}

static int remove_global_buff(unsigned int buff_id, unsigned int buff_value) 
{
	Buff * buff = (Buff*)_agMap_ip_get(gBuffSet->m, buff_id);
	if (!buff) {
		WRITE_DEBUG_LOG("global_buff remove fail , donnt has buff %u", buff_id)
		return -1;
	}

	if (buff->value > buff_value) {
		DATA_Buff_update_value(buff, buff->value - buff_value);

		add_global_notify(buff);
	} else {
		buff->end_time = agT_current();

		add_global_notify(buff);

		if (DATA_Buff_delete(buff) != 0) {
			return -1;
		}

		_agMap_ip_set(gBuffSet->m, buff_id, (void*)0);
		dlist_remove(gBuffSet->list, buff);
	}

	return 0;
}

void * buff_new(Player * player)
{
	BuffSet * set = (BuffSet*)malloc(sizeof(BuffSet));
	set->list = 0;
	set->m = _agMap_new(0);

	return set;
}

void * buff_load(Player * player)
{
	unsigned long long playerid = player_get_id(player);

	Buff * list = 0;

	//TODO; 从数据库删除过期buff
	extern struct DBHandler * role_db;
	database_update(role_db, "delete from `buff` where  now() > `end_time` and pid = %llu", playerid);

	if (DATA_Buff_load_by_pid(&list, playerid) != 0) {
		return 0;
	}

	BuffSet * set = (BuffSet*)malloc(sizeof(BuffSet));
	set->list = 0;
	set->m = _agMap_new(0);

	while(list) {
		struct Buff * cur = list;
		list = cur->next;

		insert_into_sort_dlist(&(set->list), cur);
		_agMap_ip_set(set->m, cur->buff_id, cur);

	}
	return set; 
}


int buff_update(Player * player, void * data, time_t now)
{
	return 0;
}

int buff_save(Player * player, void * data, const char * sql, ... )
{
	return 0;
}

int buff_release(Player * player, void * data)
{
	BuffSet * set = (BuffSet*)data;

	while(set->list) {
		Buff * buff = set->list;

		dlist_remove(set->list, buff);
		DATA_Buff_release(buff);
	}
	_agMap_delete(set->m);
	free(set);
	return 0;
}

////////////////////////////////////////////////////////////////////////////////
//
#define player_get_buff(player) \
	(BuffSet*)player_get_module(player, PLAYER_MODULE_BUFF)
Buff * buff_get(Player * player, unsigned long long buff_id)
{
	BuffSet * set = player_get_buff(player);
	
	if (set == NULL) {
		WRITE_ERROR_LOG("%s player %llu get module buff fail", __FUNCTION__, player_get_id(player));
		return NULL;
	}

	return (Buff*)_agMap_ip_get(set->m, buff_id);
}

static Buff * global_buff_next(Buff * buff) 
{
	Buff * list = get_global_buff();

	Buff * it = buff;
	it = dlist_next(list, it);

	if (!it || agT_current() > it->end_time) {
		return 0;
	} else {
		return dlist_next(list, buff);
	} 
}

Buff * buff_next(Player * player, Buff * buff) 
{
	if (buff && buff->pid == 0) {
		return global_buff_next(buff);	
	} 

	BuffSet * set = (BuffSet*)player_get_buff(player);
	
	if (set == NULL) {
		WRITE_ERROR_LOG("%s player %llu get module buff fail", __FUNCTION__, player_get_id(player));
		return 0;
	}

	Buff * it = buff;
	it = dlist_next(set->list, it);

	if (!it || agT_current() > it->end_time || it == 0) {
		return global_buff_next(0);
	} else {
		return dlist_next(set->list, buff);
	} 
}

Buff * buff_add(unsigned long long playerid, unsigned int buff_id, int buff_value, time_t buff_end_time)
{
	WRITE_DEBUG_LOG("player %llu add buff %u, value %d", playerid, buff_id, buff_value);

	if (playerid != 0) { 
		Player * player = player_get(playerid);
		if (!player) {
			return 0;
		}

		BuffSet * set = (BuffSet*)player_get_buff(player);
		if (set == NULL) {
			WRITE_ERROR_LOG("%s player %llu get module buff fail", __FUNCTION__, player_get_id(player));
			return 0;
		}

		Buff * pNew = (Buff*)_agMap_ip_get(set->m, buff_id);
		if (pNew) {
			if (buff_value <= 0 && buff_end_time <= pNew->end_time) {
				return pNew;
			}

			if (pNew->end_time < agT_current()) {
				DATA_Buff_update_value(pNew, buff_value);
			} else {
				DATA_Buff_update_value(pNew, pNew->value + buff_value);
			}

			DATA_Buff_update_end_time(pNew, buff_end_time);

			//sort again
			dlist_remove(set->list, pNew);
			insert_into_sort_dlist(&(set->list), pNew);

			add_notify(pNew);

			return pNew;
		} else {
			pNew = (Buff*)malloc(sizeof(Buff));
			memset(pNew, 0, sizeof(Buff));
			pNew->pid = playerid;
			pNew->buff_id = buff_id;
			pNew->value = buff_value;
			pNew->end_time = buff_end_time;
			if (DATA_Buff_new(pNew) != 0) {
				free(pNew);
				return 0;
			}

			insert_into_sort_dlist(&(set->list), pNew);
			_agMap_ip_set(set->m, pNew->buff_id, pNew);

			add_notify(pNew);

			return pNew;
		}
	} else {
		return add_global_buff(buff_id, buff_value, buff_end_time);
	}
}

int buff_remove(unsigned long long playerid, unsigned int buff_id, int buff_value)
{
	if (playerid != 0) {
		Player * player = player_get(playerid);
		if (!player) {
			return -1;
		}

		BuffSet * set = (BuffSet*)player_get_buff(player);
		if (set == NULL) {
			return -1;
		}

		Buff * buff = (Buff*)_agMap_ip_get(set->m, buff_id);
		if (!buff) {
			WRITE_DEBUG_LOG("buff remove fail , player %llu donnt has buff %u", playerid, buff_id)
			return -1;
		} 

		if ((int)buff->value > buff_value) {
			DATA_Buff_update_value(buff, buff->value - buff_value);
			add_notify(buff);
		} else {
			buff->end_time = agT_current();
			add_notify(buff);

			if (DATA_Buff_delete(buff) != 0) {
				return -1;
			}

			_agMap_ip_set(set->m, buff_id, (void*)0);
			dlist_remove(set->list, buff);	
		}

		return 0;
	} else {
		return remove_global_buff(buff_id, buff_value);
	}
}
