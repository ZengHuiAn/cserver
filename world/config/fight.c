#include <stdlib.h>
#include <string.h>
#include "xmlHelper.h"
#include "logic_config.h"
#include "hero.h"
#include "map.h"
#include "array.h"
#include "package.h"
#include "fight.h"
#include "dlist.h"


#include "config_type.h"

#include "../db_config/TABLE_config_npc.h"
#include "../db_config/TABLE_config_npc.LOADER.h"

#include "../db_config/TABLE_config_wave_config.h"
#include "../db_config/TABLE_config_wave_config.LOADER.h"

#include "../db_config/TABLE_config_npc_property_config.h"
#include "../db_config/TABLE_config_npc_property_config.LOADER.h"

#include "../db_config/TABLE_config_chapter_config.h"
#include "../db_config/TABLE_config_chapter_config.LOADER.h"

#include "../db_config/TABLE_config_battle_config.h"
#include "../db_config/TABLE_config_battle_config.LOADER.h"

#include "../db_config/TABLE_config_pve_fight_config.h"
#include "../db_config/TABLE_config_pve_fight_config.LOADER.h"

#include "../db_config/TABLE_config_fight_reward.h"
#include "../db_config/TABLE_config_fight_reward.LOADER.h"

#include "../db_config/TABLE_config_one_time_reward.h"
#include "../db_config/TABLE_config_one_time_reward.LOADER.h"

#include "../db_config/TABLE_config_pve_fight_recommend.h"
#include "../db_config/TABLE_config_pve_fight_recommend.LOADER.h"

#include "../db_config/TABLE_drop_with_item.h"
#include "../db_config/TABLE_drop_with_item.LOADER.h"


static struct map * drop_map = NULL;
static struct map * drop_with_item_map = NULL;

static int parse_drop(struct config_fight_reward * row) 
{
	int drop_id = row->drop_id;
	if (drop_id <= 0) {
		WRITE_ERROR_LOG("parse fight reward fail, drop_id %d <= 0;", drop_id);
		return -1;
	}

	struct DropConfig * pCfg = LOGIC_CONFIG_ALLOC(DropConfig, 1);
	memset(pCfg, 0, sizeof(struct DropConfig));

	dlist_init(pCfg);

	if (row->group < 0 || row->group >= 32) {
		WRITE_ERROR_LOG("parse fight reward fail, drop_id %d group %d error;", drop_id, row->group);
		return -1;
	}

	pCfg->drop_id           = drop_id;
	pCfg->first_drop        = row->first_drop;
	pCfg->group             = row->group;
	pCfg->drop_rate         = row->drop_rate;
	pCfg->type              = row->type;
	pCfg->id                = row->id;
	pCfg->min_value         = row->min_value;
	pCfg->max_value         = row->max_value;
	pCfg->min_incr          = row->min_incr;
	pCfg->max_incr          = row->max_incr;
	pCfg->act_time          = row->act_time;
	pCfg->end_time          = row->end_time;
	pCfg->act_drop_rate     = row->act_drop_rate;
	pCfg->act_value_rate    = row->act_value_rate;

	pCfg->level_limit_min   = row->level_limit_min;
	pCfg->level_limit_max   = row->level_limit_max;

	if (pCfg->min_value > pCfg->max_value) {
		WRITE_ERROR_LOG("item of drop_id %d error: min_value (%d) > max_value(%d)", pCfg->drop_id, pCfg->min_value, pCfg->max_value);
		return -1;
	}

	if (pCfg->min_incr> pCfg->max_incr) {
		WRITE_ERROR_LOG("item of drop_id %d error: min_incr(%d) > max_incr(%d)", pCfg->drop_id, pCfg->min_incr, pCfg->max_incr);
		return -1;
	}

	struct DropConfig * head = (struct DropConfig*)_agMap_ip_get(drop_map, pCfg->drop_id);
	if (head) {
		dlist_insert_tail(head, pCfg);
	} else {
		pCfg->next = pCfg->prev = pCfg;
		_agMap_ip_set(drop_map, pCfg->drop_id, pCfg);
	}

	return 0;
}

static int parse_drop_with_item(struct drop_with_item * row) 
{
	if (row->drop_id == 0) {
		return 0;
	}


	struct DropConfig * drop = get_drop_config(row->drop_id);
	if (drop == 0) {
		WRITE_ERROR_LOG("drop %d in drop_with_item not exists", row->drop_id);
		return -1;
	}

	struct DropWithItemConfig * pCfg = LOGIC_CONFIG_ALLOC(DropWithItemConfig, 1);
	memset(pCfg, 0, sizeof(struct DropWithItemConfig));

	pCfg->next = 0;
	pCfg->priority   = row->priority;
	pCfg->weight     = row->weight;

	pCfg->item_id    = row->item_id;
	pCfg->item_count = row->item_count;

	pCfg->drop       = drop;
	pCfg->group      = row->group;

	struct DropWithItemConfig ** array = (struct DropWithItemConfig **)_agMap_ip_get(drop_with_item_map, row->id);
	if (array == 0) {
		array = (struct DropWithItemConfig **)malloc(sizeof(struct DropWithItemConfig*) * MAX_DROP_WITH_ITEM_GROUP);
		memset(array, 0, sizeof(struct DropWithItemConfig *) * MAX_DROP_WITH_ITEM_GROUP);
		_agMap_ip_set(drop_with_item_map, row->id, array);
	}

	struct DropWithItemConfig * head = array[pCfg->group];

	if (head == 0 || row->priority <= head->priority) {
		pCfg->next = head;
		array[pCfg->group] = pCfg;		
	} else {
		struct DropWithItemConfig * ite = head;
		while(ite->next && ite->next->priority <= row->priority) {
			ite = ite->next;
		}

		pCfg->next = ite->next;
		ite->next = pCfg;
	}

	/*struct DropWithItemConfig * head = (struct DropWithItemConfig*)_agMap_ip_get(drop_with_item_map, row->id);
	if (head == 0) {
		_agMap_ip_set(drop_with_item_map, row->id, pCfg);
	} else {
		struct DropWithItemConfig * ite = head;
		while(ite->next && ite->next->priority <= row->priority) {
			ite = ite->next;
		}

		pCfg->next = ite->next;
		ite->next = pCfg;
	}*/

	return 0;
}

static int load_drop_config()
{
	drop_map = LOGIC_CONFIG_NEW_MAP();
	if (foreach_row_of_config_fight_reward(parse_drop, 0) != 0) {
		return -1;
	}

	
	drop_with_item_map = LOGIC_CONFIG_NEW_MAP();
	if (foreach_row_of_drop_with_item(parse_drop_with_item, 0) != 0) {
		return -1;
	}
	return 0;
}

struct DropConfig * get_drop_config(int drop_id)
{
	return (struct DropConfig *)_agMap_ip_get(drop_map, drop_id);
}

struct DropWithItemConfig * get_drop_with_item_config(int id, int group)
{
	//return (struct DropWithItemConfig*)_agMap_ip_get(drop_with_item_map, id);
	struct DropWithItemConfig ** array = (struct DropWithItemConfig**)_agMap_ip_get(drop_with_item_map, id);
	if (!array) return 0;

	if (group < 0) {
		if (array) {
			return (DropWithItemConfig *)1;
		} else {
			return 0;
		}
	} 

	return array[group] ? array[group] : 0;
}

static struct map * npc_property_map = NULL;
static int parse_npc_property_config(struct config_npc_property_config * row)
{
	int property_id = row->property_id;
	int level = row->lev;

	struct NpcProperty * pCfg = LOGIC_CONFIG_ALLOC(NpcProperty, 1);
	memset(pCfg, 0, sizeof(struct NpcProperty));

	pCfg->property_id       = property_id;
	pCfg->lev               = level;


#define NPC_PROPERTY(n) pCfg->propertys[n-1].type = row->type##n; pCfg->propertys[n-1].value = row->value##n;

	NPC_PROPERTY( 1);
	NPC_PROPERTY( 2);
	NPC_PROPERTY( 3);
	NPC_PROPERTY( 4);
	NPC_PROPERTY( 5);
	NPC_PROPERTY( 6);
	NPC_PROPERTY( 7);
	NPC_PROPERTY( 8);
	NPC_PROPERTY( 9);
	NPC_PROPERTY(10);
	NPC_PROPERTY(11);
	NPC_PROPERTY(12);
	NPC_PROPERTY(13);
	NPC_PROPERTY(14);
	NPC_PROPERTY(15);
	NPC_PROPERTY(16);
	NPC_PROPERTY(17);
	NPC_PROPERTY(18);
	NPC_PROPERTY(19);
	NPC_PROPERTY(20);
	NPC_PROPERTY(21);
	NPC_PROPERTY(22);
	NPC_PROPERTY(23);
	NPC_PROPERTY(24);
	NPC_PROPERTY(25);
	NPC_PROPERTY(26);
	NPC_PROPERTY(27);
	NPC_PROPERTY(28);
	NPC_PROPERTY(29);
	NPC_PROPERTY(30);

#undef NPC_PROPERTY

	struct NpcProperty * head = (struct NpcProperty*) _agMap_ip_get(npc_property_map, pCfg->property_id);
	if (head == 0 || pCfg->lev <= head->lev) {
		if (head && pCfg->lev == head->lev) {
			WRITE_ERROR_LOG("duplicate npc_property_config %d lev %d", pCfg->property_id, pCfg->lev);
			return -1;
		}

		pCfg->next = head;
		_agMap_ip_set(npc_property_map, pCfg->property_id, pCfg);
		return 0;
	} else {
		struct NpcProperty * ite = head;
		while(ite->next && pCfg->lev > ite->next->lev) {
			ite = ite->next;
		}

		if (ite->next != 0 && pCfg->lev == ite->next->lev) {
			WRITE_ERROR_LOG("duplicate npc_property_config %d lev %d", pCfg->property_id, pCfg->lev);
			return -1;
		}

		pCfg->next = ite->next;
		ite->next = pCfg;
	}

	return 0;
}

static int load_npc_property_config()
{
	npc_property_map = LOGIC_CONFIG_NEW_MAP();
	return foreach_row_of_config_npc_property_config(parse_npc_property_config, 0);
}

struct NpcProperty * get_npc_property_config_raw(int property_id)
{
	return (struct NpcProperty*)_agMap_ip_get(npc_property_map, property_id);
}


struct HeroPropertyRange {
	int type;
	int value_min;
	int value_max;
};

static void set_property(struct HeroPropertyRange * propertys, int n, int type, int value, int isMax)
{
	if (type == 0 || value == 0) {
		return;
	}

	int i;
	for (i = 0; i < n ; i++) {
		if (propertys[i].type == type || propertys[i].type == 0) {
			propertys[i].type = type;
			if (isMax) {
				propertys[i].value_max += value;
			} else {
				propertys[i].value_min += value;
			}
			return;
		}
	}
}

int error_count = 0;

int get_npc_property_config(int property_id, int lev, struct HeroProperty propertys[NPC_PROPERTY_COUNT * 2])
{
	struct NpcProperty * head = (struct NpcProperty *)_agMap_ip_get(npc_property_map, property_id);
	if (head == 0) {
		WRITE_WARNING_LOG("npc property %d not found", property_id);
		error_count ++;
		return 0;
	}

	if (lev < head->lev) {
		WRITE_WARNING_LOG("npc property %d, lev %d too small, use %d", property_id, lev, head->lev);
	}

	struct NpcProperty * ite = head;
	while(ite->next) {
		if (ite->lev <= lev && ite->next->lev > lev) {
			break;
		}
		ite = ite->next;
	}

	if (ite->next == 0 && ite->lev < lev) {
		WRITE_WARNING_LOG("npc property_id %d, lev %d too big, use %d", property_id, lev, ite->lev);
	}

	struct HeroPropertyRange propertys_range[NPC_PROPERTY_COUNT * 2];
	memset(propertys_range, 0, sizeof(propertys_range));

	int i;
	if (ite->next == 0) {
		for(i = 0; i < NPC_PROPERTY_COUNT; i++) {
			propertys[i].type = ite->propertys[i].type;
			propertys[i].value = ite->propertys[i].value;
		}
		return 0;
	}

	struct NpcProperty * next = ite->next;
	for (i = 0; i < NPC_PROPERTY_COUNT; i++) {
		set_property(propertys_range, NPC_PROPERTY_COUNT * 2, ite->propertys[i].type, ite->propertys[i].value, 0);
		set_property(propertys_range, NPC_PROPERTY_COUNT * 2, next->propertys[i].type, next->propertys[i].value, 1);
	}

	int lev_min = ite->lev;
	int lev_max = next->lev;
	for (i = 0; i < NPC_PROPERTY_COUNT * 2; i++) {
		propertys[i].type = propertys_range[i].type;
		propertys[i].value = propertys_range[i].value_min + (propertys_range[i].value_max - propertys_range[i].value_min) *  (lev - lev_min) / (lev_max - lev_min);
	}
	return 0;
}

static struct map * npc_map = NULL;
static int parse_npc_config(struct config_npc * row) 
{
	struct NpcConfig * pCfg = LOGIC_CONFIG_ALLOC(NpcConfig, 1);
	memset(pCfg, 0, sizeof(struct NpcConfig));

	pCfg->id           = row->id;
	pCfg->mode         = row->mode;
	pCfg->property_id  = row->property_id;
	pCfg->scale        = row->scale; 
	pCfg->drop         = row->drop;
	pCfg->effect_scale = row->effect_scale;

	pCfg->skills[0]    = row->skill1;
	pCfg->skills[1]    = row->skill2;
	pCfg->skills[2]    = row->skill3;
	pCfg->skills[3]    = row->skill4;

	pCfg->enter_script = row->enter_script;

	if (get_npc_property_config_raw(pCfg->property_id) == 0) {
		WRITE_ERROR_LOG("npc property %d of npc %d not exists", pCfg->property_id, pCfg->id);
		error_count ++;
		return 0;
	}


	if (pCfg->drop != 0 && get_drop_config(pCfg->drop) ==0) {
		WRITE_ERROR_LOG("npc drop %d of npc %d not exists", pCfg->drop, pCfg->id);
		error_count ++;
		return 0;
	}

	if (_agMap_ip_set(npc_map, pCfg->id, pCfg) != 0) {
		WRITE_ERROR_LOG("duplicate npc config %d", row->id);
		error_count ++;
		return 0;
	}

	return 0;
}

static int load_npc_config()
{
	npc_map = LOGIC_CONFIG_NEW_MAP();
	int ret = foreach_row_of_config_npc(parse_npc_config, 0);
	if (error_count > 0) {
		return -1;
	}
	return ret;
}

struct NpcConfig * get_npc_config(int id)
{
	struct NpcConfig * pCfg = (struct NpcConfig *)_agMap_ip_get(npc_map, id);
	return pCfg;
}

static struct map * chapter_map = NULL;
static int parse_chapter_config(struct config_chapter_config * row)
{
	int chapter_id = row->chapter_id;
	if (chapter_id < 0) {
		WRITE_ERROR_LOG("parse chapter config fail, chapter_id < 0");
		return -1;
	}

	struct ChapterConifg * pCfg = LOGIC_CONFIG_ALLOC(ChapterConifg, 1);
	memset(pCfg, 0, sizeof(struct ChapterConifg));

	pCfg->chapter_id        = chapter_id;
	pCfg->lev_limit         = row->lev_limit;
	pCfg->rely_chapter      = row->rely_chapter;
	pCfg->finish_id         = row->finish_id;

	pCfg->reset_cost.type         = row->reset_consume_item_type;
	pCfg->reset_cost.id           = row->reset_consume_item_id;
	pCfg->reset_cost.value        = row->reset_consume_item_count;

	if (_agMap_ip_set(chapter_map, pCfg->chapter_id, pCfg) != 0) {
		WRITE_ERROR_LOG("duplicate chapter_id %d in config_chapter_config", pCfg->chapter_id);
		return -1;
	}

	return 0;
}

static int load_chapter_config()
{
	chapter_map = LOGIC_CONFIG_NEW_MAP();
	return foreach_row_of_config_chapter_config(parse_chapter_config, 0);
}

struct ChapterConifg * get_chapter_config(int chapter_id)
{
	struct ChapterConifg * pCfg = (struct ChapterConifg *)_agMap_ip_get(chapter_map, chapter_id);
	return pCfg;
}

static struct map * battle_map = NULL;
static int parse_battle_config(struct config_battle_config * row)
{
	int battle_id = row->battle_id;
	if (battle_id < 0) {
		WRITE_ERROR_LOG("parse battle config fail, battle_id < 0");
		return -1;
	}

	struct BattleConfig * pCfg = LOGIC_CONFIG_ALLOC(BattleConfig, 1);
	memset(pCfg, 0, sizeof(struct BattleConfig));

	pCfg->battle_id         = row->battle_id;
	pCfg->chapter_id        = row->chapter_id;
	pCfg->mode_id           = row->mode_id;
	pCfg->scale             = row->scale;
	pCfg->x                 = row->x;
	pCfg->y                 = row->y;
	pCfg->lev_limit         = row->lev_limit;
	pCfg->rely_battle       = row->rely_battle;
	pCfg->finish_id         = row->finish_id;
	pCfg->quest_id          = row->quest_id;

	pCfg->fight_cost.type         = row->consume_type1;
	pCfg->fight_cost.id           = row->consume_id1;
	pCfg->fight_cost.value        = row->consume_count1;

	pCfg->reset_cost.type         = row->reset_consume_item_type;
	pCfg->reset_cost.id           = row->reset_consume_item_id;
	pCfg->reset_cost.value        = row->reset_consume_item_count;

	ChapterConifg * chapter = get_chapter_config(pCfg->chapter_id);
	if (chapter == 0) {
		WRITE_ERROR_LOG("parse battle config %d fail, chapter %d not found", battle_id, pCfg->chapter_id);
		return -1;
	}

	dlist_init(pCfg);
	dlist_insert_tail(chapter->battles, pCfg);

	if (_agMap_ip_set(battle_map, pCfg->battle_id, pCfg) != 0) {
		WRITE_ERROR_LOG("duplicate battle_id %d in config_battle_config", pCfg->chapter_id);
		return -1;
	}

	return 0;
}

static int load_battle_config()
{
	battle_map = LOGIC_CONFIG_NEW_MAP();

	return foreach_row_of_config_battle_config(parse_battle_config, 0);
}

struct BattleConfig * get_battle_config(int battle_id)
{
	struct BattleConfig * pCfg = (struct BattleConfig *)_agMap_ip_get(battle_map, battle_id);
	return pCfg;
}

static struct map * pve_fight_map = NULL;
static int parse_pve_fight_config(struct config_pve_fight_config * row) 
{
	int gid = row->gid;
	if (gid <= 0) {
		WRITE_ERROR_LOG("parse pve fight config fail, gid <= 0");
		return -1;
	}

	struct PVE_FightConfig * pCfg = LOGIC_CONFIG_ALLOC(PVE_FightConfig, 1);
	memset(pCfg, 0, sizeof(struct PVE_FightConfig));

	pCfg->gid               = gid;
	pCfg->battle_id         = row->battle_id;
	pCfg->depend_level_id   = row->depend_level_id;
	pCfg->depend_fight0_id  = row->depend_fight0_id;
	pCfg->depend_fight1_id  = row->depend_fight1_id;
	pCfg->depend_star_count = row->depend_star_count;
	pCfg->count_per_day     = row->count_per_day;
	pCfg->rank              = row->rank;
	pCfg->support_god_hand  = row->support_god_hand;
	pCfg->cost.type         = row->cost_item_type;
	pCfg->cost.id           = row->cost_item_id;
	pCfg->cost.value        = row->cost_item_value;
	pCfg->can_yjdq          = row->can_yjdq;
	pCfg->duration          = row->duration;
	pCfg->exp               = row->exp;
	pCfg->win_type          = row->win_type;
	pCfg->win_para          = row->win_para;
	pCfg->fight_type        = row->fight_type;
	pCfg->reset_consume_id  = row->reset_consume_id;
	pCfg->reward_type       = row->reward_type;

	pCfg->check.type         = row->check_item_type;
	pCfg->check.id           = row->check_item_id;
	pCfg->check.value        = row->check_item_value;

	pCfg->star[0].type = row->star1_type; pCfg->star[0].v1 = row->star1_para1; pCfg->star[0].v2 = row->star1_para2;
	pCfg->star[1].type = row->star2_type; pCfg->star[1].v1 = row->star2_para1; pCfg->star[1].v2 = row->star2_para2;

	pCfg->drop[0] = row->drop1; pCfg->drop[1] = row->drop2; pCfg->drop[2] = row->drop3;

	pCfg->scene             = agSC_get(row->scene_bg_id, 0);

	if (pCfg->battle_id > 0) {
		struct BattleConfig * pBattle = get_battle_config(pCfg->battle_id);
		if (pBattle == NULL) {
			WRITE_ERROR_LOG("parse pve fight config %d fail, battle %d not found", gid, pCfg->battle_id);
			return -1;
		}

		dlist_init(pCfg);
		dlist_insert_tail(pBattle->fights, pCfg);
	}


	if (_agMap_ip_set(pve_fight_map, pCfg->gid, pCfg) != 0) {
		WRITE_ERROR_LOG("duplicate fight id %d in config_pve_fight_config", gid);
		return -1;
	}

	return 0;
}

static int load_pve_fight_config()
{
	pve_fight_map = LOGIC_CONFIG_NEW_MAP();

	return foreach_row_of_config_pve_fight_config(parse_pve_fight_config, 0);
}

struct PVE_FightConfig * get_pve_fight_config(int gid)
{
	struct PVE_FightConfig * pCfg = (struct PVE_FightConfig *)_agMap_ip_get(pve_fight_map, gid);
	return pCfg;
}

struct BattleConfig * get_pve_fight_battle_config(int gid)
{
	struct PVE_FightConfig * pCfg = get_pve_fight_config(gid);
	if (pCfg == NULL)
	{
		return NULL;
	}

	struct BattleConfig * pBattle = get_battle_config(pCfg->battle_id);
	return pBattle;
}

struct ChapterConifg * get_pve_fight_chapter_config(int gid)
{
	struct BattleConfig * pBattle = get_pve_fight_battle_config(gid);
	if (pBattle == NULL)
	{
		return NULL;
	}

	struct ChapterConifg * pChapter = get_chapter_config(pBattle->chapter_id);
	return pChapter;
}

static struct map * wave_map = NULL;
static int parse_wave_config(struct config_wave_config * row)
{
	int gid = row->gid;

	struct WaveConfig * pCfg = LOGIC_CONFIG_ALLOC(WaveConfig, 1);
	memset(pCfg, 0, sizeof(struct WaveConfig));

	pCfg->gid       = gid;
	pCfg->wave      = row->wave;
	pCfg->role_pos  = row->role_pos; 
	pCfg->role_id   = row->role_id;
	pCfg->role_lev  = row->role_lev;
	pCfg->x         = row->x;
	pCfg->y         = row->y;
	pCfg->z         = row->z;


	pCfg->drop[0]   = row->drop1;
	pCfg->drop[1]   = row->drop2;
	pCfg->drop[2]   = row->drop3;

	pCfg->share_mode = row->share_mode;
	pCfg->share_count = row->share_count;

	dlist_init(pCfg);

	struct WaveConfig * head = (struct WaveConfig*)_agMap_ip_get(wave_map, pCfg->gid);
	if (head == 0) {
		pCfg->next = pCfg->prev = pCfg;
		_agMap_ip_set(wave_map, pCfg->gid, pCfg);
	} else {
		dlist_insert_tail(head, pCfg);
	}

	return 0;
}

static int load_wave_config()
{
	wave_map = LOGIC_CONFIG_NEW_MAP();
	return foreach_row_of_config_wave_config(parse_wave_config, 0);
}

struct WaveConfig * get_wave_config(int gid)
{
	struct WaveConfig * pCfg = (struct WaveConfig *)_agMap_ip_get(wave_map, gid);
	return pCfg;
}

static struct map * one_time_reward_list = 0;
struct OnetimeRewardConfig * get_one_time_reward_config(unsigned int id)
{
	return (OnetimeRewardConfig*)_agMap_ip_get(one_time_reward_list, id);
}


static int parse_one_time_reward(struct config_one_time_reward * row)
{
	struct OnetimeRewardConfig * cfg = LOGIC_CONFIG_ALLOC(OnetimeRewardConfig, 1);

	cfg->id = row->id;

	cfg->condition.type  = row->condition_type;
	cfg->condition.id    = row->condition_id;
	cfg->condition.value = row->condition_value;

	cfg->consume.type  = row->consume_type;
	cfg->consume.id    = row->consume_id;
	cfg->consume.value = row->consume_value;


	cfg->rewards[0].type  = row->reward1_type;
	cfg->rewards[0].id    = row->reward1_id;
	cfg->rewards[0].value = row->reward1_value;

	cfg->rewards[1].type  = row->reward2_type;
	cfg->rewards[1].id    = row->reward2_id;
	cfg->rewards[1].value = row->reward2_value;

	cfg->rewards[2].type  = row->reward3_type;
	cfg->rewards[2].id    = row->reward3_id;
	cfg->rewards[2].value = row->reward3_value;

	cfg->rewards[3].type  = row->reward4_type;
	cfg->rewards[3].id    = row->reward4_id;
	cfg->rewards[3].value = row->reward4_value;


	if (_agMap_ip_set(one_time_reward_list, cfg->id, cfg) != 0) {
		WRITE_DEBUG_LOG("duplicate one time reward %d", cfg->id);
		return -1;
	}

	return 0;
}

static int load_one_time_reward() 
{
	one_time_reward_list = LOGIC_CONFIG_NEW_MAP();
	return foreach_row_of_config_one_time_reward(parse_one_time_reward, 0);
}


// config_pve_fight_recommend
static struct map * pve_fight_recommend_map = NULL;
static int parse_pve_fight_recommend_config(struct config_pve_fight_recommend * row) 
{
	int gid = row->gid;
	if (gid <= 0) {
		WRITE_ERROR_LOG("parse pve fight recommend config fail, gid <= 0");
		return -1;
	}

	struct PVE_FightRecommendConfig * pCfg = LOGIC_CONFIG_ALLOC(PVE_FightRecommendConfig, 1);
	memset(pCfg, 0, sizeof(struct PVE_FightRecommendConfig));

	pCfg->gid                 = gid;
	pCfg->roles[0].role_type  = row->type1;
	pCfg->roles[0].role_id    = row->role1;
	pCfg->roles[0].role_lv    = row->role_lv1;
	pCfg->roles[1].role_type  = row->type2;
	pCfg->roles[1].role_id    = row->role2;
	pCfg->roles[1].role_lv    = row->role_lv2;
	pCfg->roles[2].role_type  = row->type3;
	pCfg->roles[2].role_id    = row->role3;
	pCfg->roles[2].role_lv    = row->role_lv3;
	pCfg->roles[3].role_type  = row->type4;
	pCfg->roles[3].role_id    = row->role4;
	pCfg->roles[3].role_lv    = row->role_lv4;
	pCfg->roles[4].role_type  = row->type5;
	pCfg->roles[4].role_id    = row->role5;
	pCfg->roles[4].role_lv    = row->role_lv5;

	if (_agMap_ip_set(pve_fight_recommend_map, pCfg->gid, pCfg) != 0) {
		WRITE_ERROR_LOG("duplicate fight id %d in config_pve_fight_recommend", gid);
		return -1;
	}

	return 0;
}

static int load_pve_fight_recommend_config()
{
	pve_fight_recommend_map = LOGIC_CONFIG_NEW_MAP();

	return foreach_row_of_config_pve_fight_recommend(parse_pve_fight_recommend_config, 0);
}

struct PVE_FightRecommendConfig * get_pve_fight_recommend_config(int gid)
{
	struct PVE_FightRecommendConfig * pCfg = (struct PVE_FightRecommendConfig *)_agMap_ip_get(pve_fight_recommend_map, gid);
	return pCfg;
}



int load_fight_config()
{
	if (load_drop_config() != 0 ||
			load_npc_property_config() != 0 ||
			load_npc_config() != 0 ||
			load_chapter_config() != 0 ||
			load_battle_config() != 0 ||
			load_pve_fight_config() != 0 ||
			load_wave_config() != 0  ||
			load_one_time_reward() != 0 ||
			load_pve_fight_recommend_config() != 0
	   )
	{
		return -1;
	}

	return 0;
}
