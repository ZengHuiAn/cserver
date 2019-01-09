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
#include "array.h"
#include "stringCache.h"
#include "event_manager.h"
#include "backend.h"
#include "protocol.h"
#include <stdint.h>
#include "dlist.h"
#include "logic/aL.h"

#include "modules/hero.h"
#include "modules/equip.h"

#include "config/hero.h"
#include "config/equip.h"
#include "config/reward.h"
#include "config/common.h"
#include "config/talent.h"

#include "calc/calc.h"

#define DIAMOND_ID 90006

#define EQUIP_CHIP_ID(equip_gid) (equip_gid) - 10000

typedef struct EquipSet {
	struct map * m;
	struct Equip * list;
	struct map * fight_formation;

	struct map   * values;
} EquipSet;


enum EquipNotifyType
{
	Equip_ADD,
	Equip_LEVEL_CHANGE,
	Equip_STAGE_CHANGE,
	Equip_FIGHT_FORMATION,
	Equip_DELETE,
	Equip_PROPERTY,
};

amf_value * build_equip_message(struct Equip * equip)
{
	if (equip->gid == 0) {
		amf_value * v = amf_new_array(3);
		amf_set(v, 0, amf_new_integer(0));
		amf_set(v, 1, amf_new_integer(0));
		amf_set(v, 2, amf_new_integer(equip->uuid));
		return v;
	}


	amf_value * v = amf_new_array(10);

	amf_set(v, 0, amf_new_integer(equip->gid));
	amf_set(v, 1, amf_new_integer(equip->heroid));
	amf_set(v, 2, amf_new_integer(equip->uuid));
	amf_set(v, 3, amf_new_integer(equip->level));
	amf_set(v, 4, amf_new_double(equip->hero_uuid));
	amf_set(v, 5, amf_new_integer(equip->placeholder));

	amf_value * affix = amf_new_array(0);
	amf_value * payback = amf_new_array(0);

	amf_set(v, 6, affix);
	amf_set(v, 7, amf_new_integer(equip->add_time));
	amf_set(v, 8, payback);
	amf_set(v, 9, amf_new_integer(equip->exp));
	
	// amf_value * values = amf_new_array(0);

	
	int i;
	for (i = 0; i < EQUIP_PROPERTY_POOL_MAX; i++) {
		int id, value, grow;

		equip_get_affix(equip, i+1, &id, &value, &grow);

		if (id > 0) {
			amf_value * a = amf_new_array(3);
			amf_set(a, 0, amf_new_integer(id));
			amf_set(a, 1, amf_new_integer(value));
			amf_set(a, 2, amf_new_integer(grow));

			amf_push(affix, a);
		}
	}

	Player * player = player_get(equip->pid);
	if (player) {
		struct EquipValue * values = equip_get_values(player, equip);
		struct EquipValue * ite = 0;
		while((ite = dlist_next(values, ite)) != 0) {
			amf_value * val = amf_new_array(3);
			amf_set(val, 0, amf_new_integer(ite->type));
			amf_set(val, 1, amf_new_integer(ite->id));
			amf_set(val, 2, amf_new_integer(ite->value));
			amf_push(payback, val);
		}
	}

	return v;
}

static int equip_add_notify(struct Equip * pEquip, int type)
{
	notification_set(pEquip->pid, NOTIFY_EQUIP, pEquip->uuid, build_equip_message(pEquip));
	return 0;
}

void equip_init()
{

}

static int equip_in_battle_count()
{
	static int max_equip_array_size = 0;
	if (max_equip_array_size == 0) {
		max_equip_array_size = EQUIP_INTO_BATTLE_MAX;

		struct CommonCfg * commonCfg1 = get_common_config(12);
		struct CommonCfg * commonCfg2 = get_common_config(13);

		int addon_group_1 = commonCfg1 ? commonCfg1->para2 : 0;
		int addon_group_2 = commonCfg2 ? commonCfg2->para2 : 0;

		max_equip_array_size += ((addon_group_1 > addon_group_2) ? addon_group_1 : addon_group_2) * EQUIP_INTO_BATTLE_MAX;
	}
	return max_equip_array_size;
}

static void add_equip_to_hero(EquipSet * set, struct Equip * equip)
{
	int pos = equip->placeholder & 0xff;
	if (pos == 0 || pos > EQUIP_INTO_BATTLE_MAX) {
		return;
	}

	int group = (equip->placeholder & 0xff00) >> 8;

	int slot = group * EQUIP_INTO_BATTLE_MAX + pos;
	if (slot <= 0 || slot > equip_in_battle_count()) {
		return;
	}

	struct array * arr = (struct array *)_agMap_ip_get(set->fight_formation, equip->hero_uuid);
	if (arr == NULL) {
		arr = array_new(equip_in_battle_count());
		_agMap_ip_set(set->fight_formation, equip->hero_uuid, arr);
	}

	assert(array_get(arr, slot-1) == 0);

	array_set(arr, slot-1, equip);
}

static void remove_equip_from_hero(EquipSet * set , struct Equip * equip) 
{
	int pos = equip->placeholder & 0xff;
	if (pos == 0 || pos > EQUIP_INTO_BATTLE_MAX) {
		return;
	}

	int group = (equip->placeholder & 0xff00) >> 8;

	int slot = group * EQUIP_INTO_BATTLE_MAX + pos;
	if (slot <= 0 || slot > equip_in_battle_count()) {
		return;
	}

	struct array * arr = (struct array *)_agMap_ip_get(set->fight_formation, equip->hero_uuid);
	assert(arr);
	assert(array_get(arr, slot-1) == equip);

	array_set(arr, slot - 1, 0);
}

static struct Equip * get_equip_from_hero(EquipSet * set, unsigned long long hero_uuid, int placeholder)
{
	int pos = placeholder & 0xff;
	if (pos == 0 || pos > EQUIP_INTO_BATTLE_MAX) {
		return 0;
	}

	int group = (placeholder & 0xff00) >> 8;
	int slot = group * EQUIP_INTO_BATTLE_MAX + pos;
	if (slot <= 0 || slot > equip_in_battle_count()) {
		return 0;
	}

	struct array * arr = (struct array *)_agMap_ip_get(set->fight_formation, hero_uuid);
	return (struct Equip *) (arr ? array_get(arr, slot-1) : 0);
}

void * equip_load(Player * player)
{
	unsigned long long pid = player_get_id(player);
	struct Equip * list = NULL;
	if (DATA_Equip_load_by_pid(&list, pid) != 0)
	{
		return NULL;
	}

	EquipSet * set = (EquipSet *)malloc(sizeof(EquipSet));
	memset(set, 0, sizeof(EquipSet));

	set->m = _agMap_new(0);
	set->fight_formation = _agMap_new(0);
	while (list)
	{
		struct Equip * cur = list;
		list = list->next;

		dlist_init(cur);
		dlist_insert_tail(set->list, cur);
		_agMap_ip_set(set->m, cur->uuid, cur);

		struct EquipConfig * cfg = get_equip_config(cur->gid);
		cur->level = cfg ? calc_level_by_exp(cur->exp, cfg->level_up_type) : 1;

		if (cur->placeholder == 0) {
			cur->hero_uuid = 0;
			cur->heroid = 0;
		}

		add_equip_to_hero(set, cur);
	}


	// load storage;
	set->values = _agMap_new(0);
	struct EquipValue * values = NULL;
	if (DATA_EquipValue_load_by_pid(&values, pid) != 0) {
		return NULL;
	}

	while (values) {
		struct EquipValue * cur = values;
		values = values->next;

		dlist_init(cur);

		if (cur->id != 0 && _agMap_ip_get(set->m, cur->uid) == 0) {
				DATA_EquipValue_delete(cur);
				continue;
		}

		struct EquipValue * head = (struct EquipValue*)_agMap_ip_get(set->values, cur->uid);
		if (head == 0) {
			dlist_insert_tail(head, cur);
			_agMap_ip_set(set->values, cur->uid, head);
		} else {
			assert(cur->uid == head->uid);
			dlist_insert_tail(head, cur);
		}
	}

	return set;
}

void * equip_new(Player * player)
{
	EquipSet * set = (EquipSet *)malloc(sizeof(EquipSet));
	memset(set, 0, sizeof(EquipSet));
	set->list = NULL;
	set->m = _agMap_new(0);
	set->fight_formation = _agMap_new(0);
	set->values = _agMap_new(0);
	return set;
}

int equip_update(Player * player, void * data, time_t now)
{
	return 0;
}

int equip_save(Player * player, void * data, const char * sql, ...)
{
	return 0;
}

static void free_array(uint64_t, void * p, void *)
{
	struct array * arr = (struct array*)p;
	array_free(arr);
}

static void free_values(uint64_t, void * p, void *)
{
	struct EquipValue * value = (struct EquipValue *)p;
	while(value) {
		struct EquipValue * cur = value;
		dlist_remove(value, cur);

		DATA_EquipValue_release(cur);
	}
}

int equip_release(Player * player, void * data)
{
	EquipSet * set = (EquipSet *)data;
	if (set == NULL) {
		return -1;
	}

	while (set->list) {
		struct Equip * node = set->list;
		dlist_remove(set->list, node);
		DATA_Equip_release(node);
	}

	_agMap_ip_foreach(set->fight_formation, free_array, 0);
	_agMap_ip_foreach(set->values, free_values, 0);

	_agMap_delete(set->m);
	_agMap_delete(set->fight_formation);
	_agMap_delete(set->values);
	free(set);

	return 0;
}


struct Equip * equip_get(Player * player,  unsigned long long uuid)
{
	EquipSet * set = (EquipSet *)player_get_module(player, PLAYER_MODULE_EQUIP);
	return (struct Equip *)_agMap_ip_get(set->m, uuid);
}

struct Equip * equip_get_by_hero(Player * player, unsigned long long uid, int pos)
{
	EquipSet * set = (EquipSet *)player_get_module(player, PLAYER_MODULE_EQUIP);
	return get_equip_from_hero(set, uid, pos);
}

struct Equip * equip_next(Player * player,  struct Equip * ite)
{
	EquipSet * set = (EquipSet *)player_get_module(player, PLAYER_MODULE_EQUIP);
	return dlist_next(set->list, ite);
}

struct Equip * equip_add(Player * player, int gid, struct EquipAffixInfo affix[EQUIP_PROPERTY_POOL_MAX], int exp)
{
	EquipSet * set = (EquipSet *)player_get_module(player, PLAYER_MODULE_EQUIP);

	struct Equip * pEquip = (struct Equip *)malloc(sizeof(struct Equip));
	memset(pEquip, 0, sizeof(struct Equip));

	pEquip->gid = gid;
	pEquip->pid = player_get_id(player);
	pEquip->exp = exp;

	struct EquipConfig * cfg = get_equip_config(gid);
	pEquip->level = cfg ? calc_level_by_exp(exp, cfg->level_up_type) : 1;

	pEquip->property_id_1 = affix[0].id; pEquip->property_value_1 = affix[0].value; pEquip->property_grow_1 = affix[0].grow;
	pEquip->property_id_2 = affix[1].id; pEquip->property_value_2 = affix[1].value; pEquip->property_grow_2 = affix[1].grow;
	pEquip->property_id_3 = affix[2].id; pEquip->property_value_3 = affix[2].value; pEquip->property_grow_3 = affix[2].grow;
	pEquip->property_id_4 = affix[3].id; pEquip->property_value_4 = affix[3].value; pEquip->property_grow_4 = affix[3].grow;
	pEquip->property_id_5 = affix[4].id; pEquip->property_value_5 = affix[4].value; pEquip->property_grow_5 = affix[4].grow;
	pEquip->property_id_6 = affix[5].id; pEquip->property_value_6 = affix[5].value; pEquip->property_grow_6 = affix[5].grow;
	pEquip->add_time = agT_current();

	DATA_Equip_new(pEquip);

	dlist_init(pEquip);
	dlist_insert_tail(set->list, pEquip);
	_agMap_ip_set(set->m, pEquip->uuid, pEquip);

	WRITE_DEBUG_LOG("player %llu add equip %llu(%d)", player_get_id(player), pEquip->uuid, gid)

	equip_add_notify(pEquip, Equip_ADD);

	return pEquip;
}

int equip_delete(struct Player * player, struct Equip * equip, int reason)
{
	WRITE_DEBUG_LOG("player %llu delete equip %llu(%d)", player_get_id(player), equip->uuid, equip->gid);

	EquipSet * set = (EquipSet *)player_get_module(player, PLAYER_MODULE_EQUIP);

	if (equip->hero_uuid != 0) {
		struct array * arr = (struct array *)_agMap_ip_get(set->fight_formation, equip->hero_uuid);
		if (arr) {
			array_set(arr, equip->placeholder - 1, 0);
		}
	}

	struct EquipValue * values = (struct EquipValue*) _agMap_ip_get(set->values, equip->uuid);
	if (values) {
		_agMap_ip_set(set->values, equip->uuid, 0);

		while(values) {
			struct EquipValue * cur = values;
			dlist_remove(values, cur);
			DATA_EquipValue_delete(cur);
		}
	}

	_agMap_ip_set(set->m, equip->uuid, 0);
	dlist_remove(set->list, equip);

	equip->gid = 0;

	equip_add_notify(equip, Equip_DELETE);
	DATA_Equip_delete(equip);

	return 0;
}

int equip_change_exp(struct Equip * equip, int exp)
{
	if (equip->exp == exp) {
		return 0;
	}

	WRITE_DEBUG_LOG("player %llu equip %llu(%d) change , exp %d => %d", equip->pid, equip->uuid, equip->gid, equip->exp, exp);

	struct EquipConfig * cfg = get_equip_config(equip->gid);
	equip->level = cfg ? calc_level_by_exp(exp, cfg->level_up_type) : 1;

	DATA_Equip_update_exp(equip, exp);

	equip_add_notify(equip, Equip_LEVEL_CHANGE);

	return 0;
}

int equip_change_gid(struct Equip * equip, int gid)
{
	if (equip->gid == gid) {
		return 0;
	}

	WRITE_DEBUG_LOG("player %llu equip %llu(%d) change gid %d => %d", equip->pid, equip->uuid, equip->gid, equip->gid, gid);

	DATA_Equip_update_gid(equip, gid);

	equip_add_notify(equip, Equip_STAGE_CHANGE);

	return 0;
}

int equip_change_pos(struct Player * player, struct Equip * equip, int heroid, unsigned long long bag, int pos)
{
	if (bag == 0) { pos = 0; }

	if (equip->hero_uuid == bag && equip->placeholder == pos) {
		return 0;
	}

	WRITE_DEBUG_LOG("player %llu change equip %llu(%d) pos %lld:%d => %lld:%d", player_get_id(player), equip->uuid,equip->gid, equip->hero_uuid, equip->placeholder, bag, pos);

	struct EquipSet * set = (struct EquipSet*)player_get_module(player, PLAYER_MODULE_EQUIP);

	if (equip->hero_uuid != 0) {
		remove_equip_from_hero(set, equip);
	}

	DATA_Equip_update_heroid(equip, heroid);
	DATA_Equip_update_placeholder(equip, pos);
	DATA_Equip_update_hero_uuid(equip, bag);

	if (bag != 0) {
		add_equip_to_hero(set, equip);
	}

	equip_add_notify(equip, Equip_FIGHT_FORMATION);

	return 0;
}

struct EquipValue * equip_get_values(Player * player, struct Equip * equip)
{
	struct EquipSet * set = (struct EquipSet*)player_get_module(player, PLAYER_MODULE_EQUIP);
	return(struct EquipValue *) _agMap_ip_get(set->values, equip->uuid);
}

int equip_add_value(Player * player, struct Equip * equip, int type , int id, int value)
{
	if (type == 0 || id == 0 || value == 0) {
		return 0;
	}

	struct EquipSet * set = (struct EquipSet*)player_get_module(player, PLAYER_MODULE_EQUIP);
	struct EquipValue * values = (struct EquipValue *) _agMap_ip_get(set->values, equip->uuid);

	if (values) {
		struct EquipValue * ite = 0;
		while((ite = dlist_next(values, ite)) != 0) {
			if (ite->type == type && ite->id == id) {
				DATA_EquipValue_update_value(ite, ite->value + value);
				return 0;
			}
		}
	}

	struct EquipValue * cur = (struct EquipValue*)malloc(sizeof(struct EquipValue));
	memset(cur, 0, sizeof(struct EquipValue));

	cur->pid   = player_get_id(player);
	cur->uid   = equip->uuid;
	cur->type  = type;
	cur->id    = id;
	cur->value = value;

	dlist_init(cur);

	DATA_EquipValue_new(cur);

	
	if(values) {
		dlist_insert_tail(values, cur);
	} else {
		dlist_insert_tail(values, cur);
		_agMap_ip_set(set->values, cur->uid, values);
	}

	return 0;
}



int equip_get_affix(struct Equip * equip, int index, int * id, int * value, int * addon)
{
	switch(index) {
		case 1: *id = equip->property_id_1; *value = equip->property_value_1; *addon = equip->property_grow_1; return 0;
		case 2: *id = equip->property_id_2; *value = equip->property_value_2; *addon = equip->property_grow_2; return 0;
		case 3: *id = equip->property_id_3; *value = equip->property_value_3; *addon = equip->property_grow_3; return 0;
		case 4: *id = equip->property_id_4; *value = equip->property_value_4; *addon = equip->property_grow_4; return 0;
		case 5: *id = equip->property_id_5; *value = equip->property_value_5; *addon = equip->property_grow_5; return 0;
		case 6: *id = equip->property_id_6; *value = equip->property_value_6; *addon = equip->property_grow_6; return 0;
		default: *id = 0; *value = 0; *addon = 0; return -1;
	}
}

int equip_update_affix(struct Equip * equip, int index, int id, int value, int grow)
{
#define UPDATE_AFFIX(n) \
	do {\
		if (equip->property_id_##n != id || equip->property_value_##n != value || equip->property_grow_##n != grow) { \
			WRITE_DEBUG_LOG("player %llu equip %llu(%d) change affix at %d, %d: (%d+%d) => %d: (%d+%d)", \
					equip->pid, equip->uuid, equip->gid, n, \
					equip->property_id_##n, equip->property_value_##n, equip->property_grow_##n, \
					id, value, grow); \
			DATA_Equip_update_property_id_##n(equip, id); \
			DATA_Equip_update_property_value_##n(equip, value); \
			DATA_Equip_update_property_grow_##n(equip, grow); \
			equip_add_notify(equip, Equip_PROPERTY); \
		} \
	} while(0)


	switch(index) {
		case 1: UPDATE_AFFIX(1); break;
		case 2: UPDATE_AFFIX(2); break;
		case 3: UPDATE_AFFIX(3); break;
		case 4: UPDATE_AFFIX(4); break;
		case 5: UPDATE_AFFIX(5); break;
		case 6: UPDATE_AFFIX(6); break;
		default: return -1;
	}

	return 0;

#undef UPDATE_AFFIX
}

static int DATA_Equip_change_pid(struct Equip * equip, unsigned long long pid)
{
	if (equip->pid == pid) return 0;
	equip->pid = pid;
	int ret = database_update(role_db, "update equip set pid = %llu where uuid = %llu", pid, equip->uuid);
	
	return ret;
}

static int DATA_EquipValue_change_pid(struct EquipValue * equip_value, unsigned long long pid)
{
	if (equip_value->pid == pid) return 0;
	equip_value->pid = pid;
	int ret = database_update(role_db, "update equipvalue set pid = %llu where uid = %llu", pid, equip_value->uid);
	
	return ret;
}

int equip_trade(Player * seller, Player * buyer, struct Equip * equip)
{
	assert(seller && buyer && equip);

	int talent_count = get_total_talent_count(seller, TalentType_Equip, equip->uuid);
	if (talent_count > 0) {
		WRITE_DEBUG_LOG("%s: equip trade fail, equip:%llu talent is not empty", __FUNCTION__, equip->uuid);				
		return -1;
	}

	/*if (player_get_id(seller) != SYSTEM_PID && player_get_id(buyer) != SYSTEM_PID) {
		WRITE_DEBUG_LOG("%s: equip trade fail, both of seller:%llu and buyer:%llu are not system", __FUNCTION__, player_get_id(seller), player_get_id(buyer));				
		return -1;	
	}*/

	struct EquipSet * set = (struct EquipSet*)player_get_module(seller, PLAYER_MODULE_EQUIP);
	struct EquipSet * buyer_set = (struct EquipSet*)player_get_module(buyer, PLAYER_MODULE_EQUIP);
	if (!set) {
		WRITE_DEBUG_LOG("%s: equip trade fail, cannt get equipset of seller %llu", __FUNCTION__, player_get_id(seller));				
		return -1;
	}
	
	if (!buyer_set) {
		WRITE_DEBUG_LOG("%s: equip trade fail, cannt get equipset of buyer %llu", __FUNCTION__, player_get_id(buyer));				
		return -1;
	}

	if (!equip) {
		return -1;
	}

	if (equip->pid != player_get_id(seller)) {
		WRITE_DEBUG_LOG("%s: equip trade fail, equip not owned by seller:%llu", __FUNCTION__, player_get_id(seller));				
		return -1;
	}

	if (equip->hero_uuid > 0 || equip->placeholder != 0) {
		WRITE_DEBUG_LOG("%s: equip trade fail, equip equiped by hero gid:%d uuid:%llu playerholder:%d", __FUNCTION__, equip->heroid, equip->hero_uuid, equip->placeholder);				
		return -1;
	}			

	//delete
	assert(_agMap_ip_get(set->m, equip->uuid) != NULL);
	_agMap_ip_set(set->m, equip->uuid, 0);
	dlist_remove(set->list, equip);
	struct EquipValue * values = (struct EquipValue*) _agMap_ip_get(set->values, equip->uuid);
	if (values) {
		_agMap_ip_set(set->values, equip->uuid, 0);

		while(values) {
			struct EquipValue * cur = values;
			dlist_remove(values, cur);

			//add values
			DATA_EquipValue_change_pid(cur, player_get_id(buyer));
			struct EquipValue * head = (struct EquipValue*)_agMap_ip_get(buyer_set->values, cur->uid);
			if (head == 0) {
				dlist_insert_tail(head, cur);
				_agMap_ip_set(buyer_set->values, cur->uid, head);
			} else {
				assert(cur->uid == head->uid);
				dlist_insert_tail(head, cur);
			}
		}
	}
	int gid = equip->gid;
	equip->gid = 0;
	equip_add_notify(equip, Equip_DELETE);

	// add map
	DATA_Equip_change_pid(equip, player_get_id(buyer));
	_agMap_ip_set(buyer_set->m, equip->uuid, equip);
	dlist_init(equip);
	dlist_insert_tail(buyer_set->list, equip);
	equip->gid = gid;
	equip_add_notify(equip, Equip_ADD);

	return 0;
}

