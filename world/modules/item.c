#include <assert.h>
#include <string.h>
#include "dlist.h"
#include "item.h"
#include "mtime.h"
#include "bag.h"
#include "database.h"
#include "log.h"
#include "notify.h"
#include "map.h"
#include <stdint.h>
#include "config/quest.h"
#include "logic/aL.h"
#include "config/compensate.h"
#include "config/item.h"
#include "dispatch.h"

#include "calc/calc.h"

typedef struct ItemSet {
	int check;
	struct map * m;
	Item * list;
	
	struct map * m2;
	struct map * m3; //这个map用来记录某个sub_type的道具数量和
	Compensate *list2;
	
} ItemSet;


static void compensate_load(Player * player, ItemSet * set);
static void compensate_release(ItemSet *set);
static void compensate_set(Player *player, Compensate *c);
static Compensate * compensate_get(Player *player, unsigned int id, time_t time);
static int compensate_item(Player *player, int id, int over_flow, time_t update_time);
static void increase_item_total_by_sub_type(unsigned long long pid, unsigned int sub_type, unsigned int value);
static void decrease_item_total_by_sub_type(unsigned long long pid, unsigned int sub_type, unsigned int value);

#define COMPEN_TIME(t, ref, period) \
	((ref) + (((t) - (ref)) / (period) + 1) * (period) - 1)

//事件角色数据接口
void item_init()
{
}

void * item_new(Player * player)
{
	ItemSet * set = (ItemSet*)malloc(sizeof(ItemSet));
	set->check = 0;
	set->list = 0;
	set->m = _agMap_new(0);
	
	set->list2 = 0;
	set->m2 = _agMap_new(0);
	set->m3 = _agMap_new(0);

	return set;
}

#define HERO_IS_INUSE(hero)  (!!(hero->stat & HERO_STAT_INUSE))


void * item_load(Player * player)
{
	unsigned long long playerid = player_get_id(player);

	struct Item * list = 0;

	if (DATA_Item_load_by_pid(&list, playerid) != 0) {
		return 0;
	}

	ItemSet * set = (ItemSet*)malloc(sizeof(ItemSet));
	set->check = 0;
	set->list = 0;
	set->list2 = 0;
	set->m = _agMap_new(0);
	set->m2 = 0;
	set->m3 = _agMap_new(0);

	while(list) {
		struct Item * cur = list;
		list = cur->next;

		dlist_init(cur);
		dlist_insert_tail(set->list, cur);

		_agMap_ip_set(set->m, cur->id, cur);
	
		struct ItemConfig * item_cfg = get_item_base_config(cur->id);
		if (item_cfg && item_cfg->type != 0) {
			long count = (long)_agMap_ip_get(set->m3, item_cfg->type);
			count = count + cur->limit;
			_agMap_ip_set(set->m3, item_cfg->type, (void *)count);
		}
	}

	compensate_load(player, set);

	return set; 
}

static void compensate_load(Player * player, ItemSet * set)
{
	unsigned long long pid;
 	struct Compensate *list, *p;
 	struct map *tmap;

 	if (NULL == set) {
 		return;
 	}

	pid = player_get_id(player);
	
	set->m2 = _agMap_new(0);
	set->list2 = NULL;

	if (DATA_Compensate_load_by_pid(&list, pid) != 0) {
 		return;
 	}

	while (list) {
		p = list;
 		list = list->next;
 		dlist_init(p);
		dlist_insert_tail(set->list2, p);

		tmap = (struct map *) _agMap_ip_get(set->m2, p->drop_id); 
		if (NULL == tmap) {
			tmap = _agMap_new(0);
 			_agMap_ip_set(set->m2, p->drop_id, tmap);
		}	
 
		_agMap_ip_set(tmap, p->time, p);
 	}
}
 


int item_update(Player * player, void * data, time_t now)
{
	ItemSet * set = (ItemSet*)data;
	((void)set);
	return 0;
}

int item_save(Player * player, void * data, const char * sql, ... )
{
	unsigned long long pid = player_get_id(player);
	//unsigned int pid32 = 0;
	//TRANSFORM_PLAYERID(pid, 0, pid32);
	database_update(role_db, "delete from item where pid = %llu", pid);
	return 0;
}

int item_release(Player * player, void * data)
{
	ItemSet * set = (ItemSet*)data;

	while(set->list) {
		Item * item = set->list;

		dlist_remove(set->list, item);
		DATA_Item_release(item);
	}
	_agMap_delete(set->m);

	compensate_release(set);

	free(set);

	return 0;
}

static void compensate_release(ItemSet *set)
{
	Compensate *p;
 	struct map *tmap;
 
 	if (NULL == set) {
 		return;
 	}

	while (set->list2) {
		p = set->list2;
		dlist_remove(set->list2, p);
 		tmap = (struct map *) _agMap_ip_get(set->m2, p->drop_id);
		if (tmap) {
			_agMap_delete(tmap);
			_agMap_ip_set(set->m2, p->drop_id, NULL);
		}
		DATA_Compensate_release(p);
	}

	if (set->m2) {
		_agMap_delete(set->m2);
	}
}

////////////////////////////////////////////////////////////////////////////////
//
enum{
	ET_ITEM_NEW 			=1 << 0,
	ET_ITEM_DEL 			=1 << 1,
	ET_ITEM_CHANGE_POS 		=1 << 2,
	ET_ITEM_CHANGE_COUNT 	=1 << 3,
};
static int add_log(Item * item, long long evt_type, long long change, int reason){
	const long long now      =agT_current();

	if (item->id == 100000) {
		return 0;
	}
	
	if (item->pid > AI_MAX_ID) {
		agL_write_user_logger(ITEM_LOGGER, LOG_FLAT, "%d,%lld,%u,%u,%d,%lld", (int)now, item->pid, item->id, item->limit, reason, change);
	}
	return 0;
}
static int add_notify(Item * item, int32_t evt_type, int32_t param, int reason)
{
	if(!item) return -1;

	/* log
	struct ItemLog log;
	memset(&log, 0, sizeof(log));
	log.pid 			=item->pid;
	log.id 				=item->id;
	log.count 			=item->limit;
	log.evt_type 		=evt_type;
	log.time			=agT_current();
	if(evt_type==ET_ITEM_NEW || evt_type==ET_ITEM_DEL || evt_type==ET_ITEM_CHANGE_COUNT){
		log.change =param;
	}
	DATA_ItemLog_new(&log);
	*/


	long long change =0;
	if(evt_type==ET_ITEM_NEW || evt_type==ET_ITEM_DEL || evt_type==ET_ITEM_CHANGE_COUNT){
		change =param;
	}
	add_log(item, evt_type, change, reason);
	struct ItemConfig * item_cfg = get_item_base_config(item->id);
	if (item_cfg && item_cfg->type != 0) {
		if (change > 0) {
			increase_item_total_by_sub_type(item->pid, item_cfg->type, change);
		} else {
			decrease_item_total_by_sub_type(item->pid, item_cfg->type, -change);
		}
	}

	// notify
	amf_value * res = amf_new_array(3);
	amf_set(res, 0, amf_new_integer(item->id));
	amf_set(res, 1, amf_new_integer(item->limit));
	return notification_set(item->pid, NOTIFY_ITEM_COUNT, item->id, res);
}

#define player_get_item(player) \
	(ItemSet*)player_get_module(player, PLAYER_MODULE_ITEM)

static void increase_item_total_by_sub_type(unsigned long long pid, unsigned int sub_type, unsigned int value)
{
	Player * player = player_get(pid);
	if (!player) {
		return;
	}

	ItemSet * set = player_get_item(player);
	if (!set) {
		return;
	}

	long count = (long)_agMap_ip_get(set->m3, sub_type);
	count = count + value;
	_agMap_ip_set(set->m3, sub_type, (void *)count);
}

static void decrease_item_total_by_sub_type(unsigned long long pid, unsigned int sub_type, unsigned int value)
{
	Player * player = player_get(pid);
	if (!player) {
		return;
	}

	ItemSet * set = player_get_item(player);
	if (!set) {
		return;
	}

	long count = (long)_agMap_ip_get(set->m3, sub_type);
	count = (count - value) > 0 ? (count - value) : 0;
	_agMap_ip_set(set->m3, sub_type, (void *)count);
}

Item * item_get(Player * player, unsigned int id)
{
	ItemSet * set = player_get_item(player);
	Item * item = (Item*)_agMap_ip_get(set->m, id);

	if (item) {	
		int modified = 0;
		int over_flow = 0;
		int count = calc_item_grow_count(player, id, item->limit, item->update_time, &modified, &over_flow);

		if (modified) {		
			if (over_flow) {
				compensate_item(player, id, over_flow, item->update_time);
			}

			if (item->id != 100000) {
				item_add(player, 100000, 1, REASON_ITEM_AUTO_GROW);
			}
			item_set_limit(item, count, REASON_ITEM_AUTO_GROW);
			DATA_Item_update_update_time(item, agT_current());
		}
	} else {
		int count = calc_item_grow_count(player, id, 0, 0, 0, 0);	
		if (count > 0) {
			item = (Item*)malloc(sizeof(Item));
			memset(item, 0, sizeof(Item));
			item->pid   = player_get_id(player);
			item->id    = id;
			item->limit = count;
			item->update_time = agT_current();

			if (DATA_Item_new(item) != 0) {
				free(item);
				return 0;
			}

			_agMap_ip_set(set->m, item->id, item);
			dlist_insert_tail(set->list, item);

			Bag * bag = player_get_bag(player);
			bag_push(bag, BAG_ITEM_ITEM, item);
		}
	}

	return item;
}

Item * item_next(Player * player, Item * item)
{
	ItemSet * set = (ItemSet*)player_get_item(player);

	item = dlist_next(set->list, item);

	if (item) {
		int modified = 0;
		int over_flow = 0;
		int count = calc_item_grow_count(player, item->id, item->limit, item->update_time, &modified, &over_flow);	
		if (modified) {	
			if (over_flow) {
				compensate_item(player, item->id, over_flow, item->update_time);
			}	

			item_set_limit(item, count, REASON_ITEM_AUTO_GROW);
			DATA_Item_update_update_time(item, agT_current());
		}	
	}
	return item;
}


static void on_item_change(unsigned long long pid, unsigned int id, int change_count, int reason)
{
	if (change_count < 0 && 13016 != reason) {
		if (id == 410010) {
			notification_record_count(pid, 5, -change_count);
		} else if (id == 410007) {
			notification_record_count(pid, 6, -change_count);
		} else if (id == 410012) {
			notification_record_count(pid, 7, -change_count);
		} else if (id == 410009) {
			notification_record_count(pid, 8, -change_count);
		}
	}
}

int    item_set(Player * player, unsigned int id, unsigned int limit,int reason)
{
	Item * item = item_get(player, id);
	if (item) {
		if (0 && limit == 0) {
			return item_remove(item, item->limit, reason);
		} else {
			WRITE_DEBUG_LOG("player %llu item %u limit %u -> %u",
				item->pid, item->id, item->limit, limit);
			const int32_t change_count =limit - item->limit;
			DATA_Item_update_limit(item, limit);
			// DATA_FLUSH_ALL();
	
			/* 判断好感度道具是否达到最大 */
			struct ItemNpcFavorConfig * cfg = get_favor_item_config(id);
			if (cfg && (unsigned) cfg->degree[6] < limit) {	
				amf_value * v = amf_new_array(3);
				amf_push(v, amf_new_integer(7));
				amf_push(v, amf_new_string(player_get_name(player), 0));
				amf_push(v, amf_new_integer(cfg->npc_id));
				
				char msg[1024] = { 0 };
				int32_t size = 0;
				size = amf_encode(msg, sizeof(msg), v);
				/* 增加全服公告 */	
				broadcast_to_client(C_PLAYER_DATA_CHANGE, 1, msg, size, 0, NULL);
				amf_free(v);	
			}

			add_notify(item, ET_ITEM_CHANGE_COUNT, change_count, reason);
			on_item_change(item->pid, item->id, change_count, reason);

			//quest
			if (change_count < 0) {
				aL_quest_on_event(player_get(item->pid), QuestEventType_ITEM_CONSUME, item->id, -change_count);
				
				if (item->id >= 55001 && item->id <= 55999) {
					aL_quest_on_event(player_get(item->pid), QuestEventType_LINGHUN, 1, -change_count);
				}
			}

		}
		return 0;
	} else if (limit > 0) {
		Item * item = item_add(player, id, limit, reason);
		return item ? 0 : -1;
	} else {
		return 0;
	}

}

Item * item_add(Player * player, unsigned int id, unsigned int limit, int reason)
{
	unsigned long long playerid = player_get_id(player);
	Item * item = item_get(player, id);

	WRITE_DEBUG_LOG("player %llu add item %u count %u + %u",
				playerid, id, item ? item->limit : 0, limit);

	if (item == 0) {
		ItemSet * set = player_get_item(player);

		item = (Item*)malloc(sizeof(Item));
		memset(item, 0, sizeof(Item));
		item->pid = playerid;
		item->id   = id;
		item->limit = limit + calc_item_grow_count(player, id, 0, 0, 0, 0);
		item->update_time = agT_current();
	
		if (DATA_Item_new(item) != 0) {
			free(item);
			return 0;
		}

		/* 判断好感度道具是否达到最大 */
		struct ItemNpcFavorConfig * cfg = get_favor_item_config(id);
		if (cfg && (unsigned) cfg->degree[6] < limit) {	
			amf_value * v = amf_new_array(3);
			amf_push(v, amf_new_integer(7));
			amf_push(v, amf_new_string(player_get_name(player), 0));
			amf_push(v, amf_new_integer(cfg->npc_id));
				
			char msg[1024] = { 0 };
			int32_t size = 0;
			size = amf_encode(msg, sizeof(msg), v);
			/* 增加全服公告 */	
			broadcast_to_client(C_PLAYER_DATA_CHANGE, 1, msg, size, 0, NULL);
			amf_free(v);	
		}

		/* 是否获得一个称号道具 */
		struct ItemConfig * item_cfg = get_item_base_config(id);
		if (item_cfg && item_cfg->type == 110) {	
			amf_value * v = amf_new_array(3);
			amf_push(v, amf_new_integer(6));
			amf_push(v, amf_new_string(player_get_name(player), 0));
			amf_push(v, amf_new_integer(id));
				
			char msg[1024] = { 0 };
			int32_t size = 0;
			size = amf_encode(msg, sizeof(msg), v);
			/* 增加全服公告 */	
			broadcast_to_client(C_PLAYER_DATA_CHANGE, 1, msg, size, 0, NULL);
			amf_free(v);	
		}

		_agMap_ip_set(set->m, item->id, item);
		dlist_insert_tail(set->list, item);

		Bag * bag = player_get_bag(player);
		bag_push(bag, BAG_ITEM_ITEM, item);

		const int32_t change_count =limit;
		add_notify(item, ET_ITEM_NEW, change_count, reason);
		on_item_change(item->pid, item->id, limit, reason);

	} else {
		if (limit > 0) {
			DATA_Item_update_limit(item, item->limit + limit);
	
			/* 判断好感度道具是否达到最大 */
			struct ItemNpcFavorConfig * cfg = get_favor_item_config(id);
			if (cfg && (unsigned) cfg->degree[6] < item->limit + limit) {
				amf_value * v = amf_new_array(3);
				amf_push(v, amf_new_integer(7));
				amf_push(v, amf_new_string(player_get_name(player), 0));
				amf_push(v, amf_new_integer(cfg->npc_id));
				
				char msg[1024] = { 0 };
				int32_t size = 0;
				size = amf_encode(msg, sizeof(msg), v);
				/* 增加全服公告 */	
				broadcast_to_client(C_PLAYER_DATA_CHANGE, 1, msg, size, 0, NULL);
				amf_free(v);	
			}

			//DATA_FLUSH_ALL();
			const int32_t change_count =limit;
			add_notify(item, ET_ITEM_CHANGE_COUNT, change_count, reason);
			on_item_change(item->pid, item->id, change_count, reason);
		}
	}
	return item;
}

int    item_set_limit(Item * item, unsigned int limit, int reason)
{
	if (item->limit == limit) {
		return 0;
	}

	WRITE_DEBUG_LOG("player %llu item %u limit %u -> %u",
			item->pid, item->id, item->limit, limit);

	if (1 || limit > 0) {
		const int32_t change_count =limit - item->limit;
		DATA_Item_update_limit(item, limit);

		add_notify(item, ET_ITEM_CHANGE_COUNT, change_count, reason);
		on_item_change(item->pid, item->id, change_count, reason);

		//quest
		if (change_count < 0) {
			aL_quest_on_event(player_get(item->pid), QuestEventType_ITEM_CONSUME, item->id, -change_count);

			if (item->id >= 55001 && item->id <= 55999) {
				aL_quest_on_event(player_get(item->pid), QuestEventType_LINGHUN, 1, -change_count);
			}
		}
	} else  {
		item_remove(item, item->limit, reason);
	}
	return 0;
}

int item_remove(Item * item, unsigned int limit, int reason)
{
	if (limit == 0) {
		return 0;
	}

	if (item->limit < limit) {
		return -1;
	}

	if (0 && item->limit == limit) {

		if (DATA_Item_delete(item) != 0) {
			return -1;
		}

		Player * player = player_get(item->pid);
		ItemSet * set = player_get_item(player);

		Bag * bag = player_get_bag(player);	
		struct BagItem * bi = bag_get(bag, item->pos);
		if (bi && bi->ptr == item) {
			bag_remove(bag, item->pos);
		}

		const int32_t change_count = -item->limit;
		item->limit = 0;
		add_notify(item, ET_ITEM_DEL, change_count, reason);
		on_item_change(item->pid, item->id, change_count, reason);

		_agMap_ip_set(set->m, item->id, (void*)0);
		dlist_remove(set->list, item);

		return 0;
	} else {
		item_set_limit(item, item->limit - limit, reason);
		return 0;
	}
}	

int     item_use(Item * item, unsigned int count, int reason)
{
	WRITE_DEBUG_LOG("player %llu use item %u count %u",
			item->pid, item->id, count);
			
	if (item->limit < count) {
		return -1;
	}

	//TODO: item effect

	return item_remove(item, count, reason);
}

int item_set_pos(Item * item, unsigned int pos)
{
	if (item->pos == pos) { return 0; }


	WRITE_DEBUG_LOG("player %llu item %u set pos %u -> %u",
			item->pid, item->id, item->pos, pos);
	DATA_Item_update_pos(item, pos);
	// add_notify(item, ET_ITEM_CHANGE_POS, 0, reason);
	return 0;
}

Compensate * compensate_get(Player *player, unsigned int id, time_t time)
{
	ItemSet *set;
	Compensate *c;
	struct map *tmap;
  
	set = player_get_item(player);
	if (NULL == set || NULL == set->m2)  {
		WRITE_DEBUG_LOG("%s: player %lld get compensate failed, id is %d, time is %ld.", __FUNCTION__, player_get_id(player), id, time);
		return NULL;
	}

	tmap = (struct map *) _agMap_ip_get(set->m2, id);
 	if (NULL == tmap) {
		WRITE_DEBUG_LOG("%s: player %lld compensate data is not exist, id is %d.", __FUNCTION__, player_get_id(player), id);
		return NULL;
	}

 	c = (Compensate *) _agMap_ip_get(tmap, time);

	return c;
}
 
void compensate_set(Player *player, Compensate *c)
{	
	ItemSet *set;
	struct map *tmap;

	set = player_get_item(player);
	if (NULL == set || NULL == set->m2) {
		WRITE_WARNING_LOG("%s: player %lld get compensate failed, id is %d, time is %ld.", __FUNCTION__, player_get_id(player), c->drop_id, c->time);
		return;
	}
 
	tmap = (struct map *) _agMap_ip_get(set->m2, c->drop_id);
	if (NULL == tmap) {
		tmap = _agMap_new(0);
		_agMap_ip_set(set->m2, c->drop_id, tmap);	
	}	

	if (NULL == _agMap_ip_get(tmap, c->time)) {
		_agMap_ip_set(tmap, c->time, c);
	}
			
	dlist_init(c);
	dlist_insert_tail(set->list2, c);
}
 
int compensate_item(Player *player, int id, int count, time_t update_time)
{
	int level, i, nperiod, remain, n, most;
	CompensateCfg *cfg; 
	time_t now, begin_time, now_begin_time, update_begin_time;
 	Compensate *c;
	ItemConfig *icfg;
	struct ItemGrowInfo *grow;
	 
	WRITE_DEBUG_LOG("%s: player %lld compensate item %d, count is %d, update_time is %ld.", __FUNCTION__, player_get_id(player), id, count, update_time);
	if (count <= 0 || update_time <= 0) {
		return -1;
	}
 
	now = agT_current();		
	
	icfg = get_item_base_config(id);
	if (NULL == icfg) {
		WRITE_WARNING_LOG("%s: player %lld get item config failed, id is %d.", __FUNCTION__, player_get_id(player), id);
		return -1;
	}	
	grow = icfg->grow;	
	for ( ; grow; grow = grow->next) {
		if (grow->end_time > now && now >= grow->begin_time) {
			break;
		}
	}
	if (NULL == grow) {
		WRITE_DEBUG_LOG("%s: player %lld item %d grow is NULL, now is %ld", __FUNCTION__, player_get_id(player), id, now);
		return -1;
	}
	 
	level = player_get_level(player);
 	cfg = get_compensate_cfg(id, level);
	if (NULL == cfg) {
		return -1;
	}

	remain = count % grow->amount;
	
	now_begin_time = COMPEN_TIME(now, grow->begin_time, grow->period);
	update_begin_time = COMPEN_TIME(update_time, grow->begin_time, grow->period);
	nperiod = (now_begin_time - update_begin_time) / grow->period;	// 需要补偿的周期数
	most = 30 * (86400 / grow->period);	// 最多补偿30天的离线奖励
	i = nperiod > most ? nperiod - most : 0;

	for ( ; i < nperiod; i++) {
		int period = grow->period < 86400 ? 86400 : grow->period;
		begin_time = COMPEN_TIME(update_time + grow->period * i, grow->begin_time, period);			
		if (i == 0 && remain != 0) {
			n = remain;
		} else {
			n = grow->amount;
		}	
		c = compensate_get(player, cfg->drop1, begin_time);
		n /= cfg->num;
		if (n == 0) { 
			return 0;
		}
		if (NULL == c) {
			c = (Compensate *) malloc(sizeof(Compensate));	
			memset(c, 0, sizeof(Compensate));
			c->pid = player_get_id(player);
			c->drop_id = cfg->drop1;
			c->time = begin_time;
			c->count = n;	
			c->level = level;	
			if (0 == DATA_Compensate_new(c)) {
				compensate_set(player, c);					
			}
		}
		else {
			DATA_Compensate_update_count(c, c->count + n);
		}
	} 	

	return 0;
}
 
Compensate * compen_item_next(Player *player, Compensate *cur)
{	
	ItemSet *set;

 	set = player_get_item(player);
	if (NULL == set || NULL == set->list2) {
		return NULL;	
	}

	cur = dlist_next(set->list2, cur);

	return cur;
}
 
int draw_item(Player *player, time_t time, struct DropInfo *drops, int size, int *real_size)
{
	ItemSet *set;
	Compensate *cur, *p;
	struct map *tmap;
	int ret = -1;
	int n = 0;
	unsigned i;
 
	set = player_get_item(player);
	if (NULL == set || NULL == set->list2) {
		WRITE_WARNING_LOG("%s: player %lld compensate item not exist, time is %ld.", __FUNCTION__, player_get_id(player), time);
		return -1;
	} 
 
	cur = set->list2;
	while (cur) {
		p = cur;		
		cur = dlist_next(set->list2, cur);		 

		if (p->time == time) {	
 			tmap = (struct map *) _agMap_ip_get(set->m2, p->drop_id);

			if (tmap) {
				_agMap_ip_set(tmap, p->time, NULL);
			}
		
			for (i = 0; i < p->count; i++) {
				if (n < size) {				
					drops[n].id = p->drop_id;
					drops[n].level = p->level;
					n++;
				}	
			}	
			ret = 0;
				
			dlist_remove(set->list2, p);
 			DATA_Compensate_delete(p);
		}
	}

	if (real_size) {
		*real_size = n;
	}
	
	return ret;
}

int get_item_count_by_sub_type(Player * player, unsigned int sub_type) {
	ItemSet * set = player_get_item(player);
	if (!set) {
		return 0;
	}

	long count = (long)_agMap_ip_get(set->m3, sub_type);
	return count;
}

void compensate_all_item(Player* player)
{
	CompensateCfg *cfg = NULL;

	while ((cfg = compensate_next(cfg)) != NULL) {
		// WRITE_DEBUG_LOG("%s: id = %d", __FUNCTION__, cfg->id);

		item_get(player, cfg->id);
	}
}
