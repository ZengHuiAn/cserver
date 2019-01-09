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
#include "config/hero.h"
#include "logic/aL.h"
#include "config/reward.h"
#include "talent.h"
#include "config/talent.h"
#include "modules/item.h"
#include "config/item.h"
#include "config/quest.h"
#include "aifightdata.h"
#include "config/common.h"
#include "rankreward.h"

#define CLAMP_(v, l, h) (((v)<=(l))?(l):(((v)>=(h))?(h):(v)))
#define LEADING_ROLE_PLACE 1 //主角上阵位置


typedef struct tagHeroSet {
	struct map *m;
	struct map *uuid;
	struct Hero * list;
	struct Hero * fight_formation[HERO_INTO_BATTLE_MAX];

	struct map * skills;
} HeroSet;

enum HeroNotifyType {
	Hero_ADD                        = 0,
	Hero_LEVEL_CHANGE               = 1,
	Hero_STAGE_CHANGE               = 2,
	Hero_STAR_CHANGE                = 3,
	Hero_EXP_CHANGE                 = 4,
	Hero_STAGE_SLOT_CHANGE          = 5,
	Hero_Weapon_STAR_CHANGE         = 6,
	Hero_Weapon_STAGE_CHANGE        = 7,
	Hero_Weapon_STAGE_SLOT_CHANGE   = 8,
	Hero_FIGHT_FORMATION            = 9,
};

int transfrom_exp_to_level(int exp, int type, int gid)
{
	int index = 1;
	int level = 1;
	struct UpgradeConfig * pCfg = NULL;
	for (; (pCfg = get_upgrade_config(index, type)) != NULL; ++index)
	{
		int exp2 = exp;
		struct HeroConfig * hero_cfg = get_hero_config(gid);
		int rate = hero_cfg ? hero_cfg->rate : 10000;
		if (type == UpGrade_Hero) {
			exp2 = exp * (10000.0 / rate);
		}
		if (exp2 >= pCfg->consume_value && level < index)
		{
			level = index;
		}
	}

	return level;
}

int get_exp_by_level(int level, int type, int gid)
{
	int index = 1;
	// int exp = 0;
	struct HeroConfig * hero_cfg = get_hero_config(gid);
	int rate = hero_cfg ? hero_cfg->rate : 10000;

	struct UpgradeConfig * pCfg = NULL;
	for (; (pCfg = get_upgrade_config(index, type)) != NULL; ++index)
	{
		if (level == pCfg->level) {
			if (type == UpGrade_Hero) {
				return pCfg->consume_value * (rate / 10000.0);	
			} else {
				return pCfg->consume_value;
			}
		}
		/*if (exp >= pCfg->consume_value && level < index)
		{
			level = index;
		}*/
	}

	int idx = index - 1;
	pCfg = get_upgrade_config(idx, type);
	if (pCfg) { 
		if (type == UpGrade_Hero) {
			return pCfg->consume_value * (rate / 10000.0);	
		} else {
			return pCfg->consume_value;
		}
	}

	return -1;
}

void hero_init()
{

}

void * hero_new(Player * player)
{
	HeroSet * set = (HeroSet*)malloc(sizeof(HeroSet));
	memset(set, 0, sizeof(HeroSet));
	set->m = _agMap_new(0);
	set->uuid = _agMap_new(0);
	set->skills = _agMap_new(0);
	set->list = NULL;
	return set;
}

void * hero_load(Player * player)
{
	if (player == NULL)
	{
		return NULL;
	}

	unsigned long long pid = player_get_id(player);

	struct Hero * list = NULL;
	if (DATA_Hero_load_by_pid(&list, pid) != 0) {
		return NULL;
	}

	HeroSet * set = (HeroSet*)malloc(sizeof(HeroSet));
	memset(set, 0, sizeof(HeroSet));
	set->m = _agMap_new(0);
	set->uuid = _agMap_new(0);
	set->skills = _agMap_new(0);
	set->list = NULL;
	while (list)
	{
		struct Hero * cur = list;
		list = list->next;

		dlist_init(cur);
		dlist_insert_tail(set->list, cur);

		cur->level              = transfrom_exp_to_level(cur->exp, UpGrade_Hero, cur->gid);
		cur->weapon_level       = transfrom_exp_to_level(cur->weapon_exp, UpGrade_Weapon, cur->gid);

		_agMap_ip_set(set->m, cur->gid, cur);
		_agMap_ip_set(set->uuid, cur->uuid, cur);

		if (cur->placeholder > 0 && cur->placeholder <= HERO_INTO_BATTLE_MAX) {
			set->fight_formation[cur->placeholder - 1] = cur;
		} else if (cur->placeholder > HERO_INTO_BATTLE_MAX) {
			WRITE_WARNING_LOG("player %llu hero %d placeholder %d abnormal", pid, cur->gid, cur->placeholder);
		}
	}


	struct HeroSkill * skills = NULL;
	if (DATA_HeroSkill_load_by_pid(&skills, pid) != 0) {
		return NULL;
	}

	while (skills)
	{
		struct HeroSkill * cur = skills;
		skills = skills->next;

		dlist_init(cur);

		_agMap_ip_set(set->skills, cur->uid, cur);
	}
		
	return set;
}

int hero_update(Player * player, void * data, time_t now)
{
	return 0;
}

int hero_save(Player * player, void * data, const char * sql, ...)
{
	return 0;
}

static void free_skills(uint64_t key, void *p, void * ctx)
{
	DATA_HeroSkill_release( (struct HeroSkill *) p);
}

int hero_release(Player * player, void * data)
{
	HeroSet * set = (HeroSet *)data;
	if (set != NULL)
	{
		while(set->list)
		{
			struct Hero * node = set->list;
			dlist_remove(set->list, node);
			DATA_Hero_release(node);
		}
		_agMap_delete(set->uuid);
		_agMap_delete(set->m);

		_agMap_ip_foreach(set->skills, free_skills, 0);
		_agMap_delete(set->skills);

		free(set);

	}
	return 0;
}

struct Hero * hero_get(Player * player, unsigned int gid, unsigned long long uuid)
{
	if (player == NULL)
	{
		return NULL;
	}

	HeroSet * set = (HeroSet*)player_get_module(player, PLAYER_MODULE_HERO);
	if (set == NULL)
	{
		WRITE_ERROR_LOG("%s player %llu get module hero fail", __FUNCTION__, player_get_id(player));
		return NULL;
	}
	return (struct Hero*)(uuid ? _agMap_ip_get(set->uuid, uuid) : _agMap_ip_get(set->m, gid));
}


amf_value * hero_build_message(struct Hero * pHero)
{
	if (pHero == 0) {
		return 0;
	}

	amf_value * c = amf_new_array(13);
	amf_set(c,  0, amf_new_integer(pHero->gid));
	amf_set(c,  1, amf_new_integer(pHero->level));
	amf_set(c,  2, amf_new_integer(pHero->stage_slot));
	amf_set(c,  3, amf_new_integer(pHero->stage));
	amf_set(c,  4, amf_new_integer(pHero->star));
	amf_set(c,  5, amf_new_integer(pHero->exp));
	amf_set(c,  6, amf_new_integer(pHero->weapon_star));
	amf_set(c,  7, amf_new_integer(pHero->weapon_stage));
	amf_set(c,  8, amf_new_integer(pHero->weapon_stage_slot));
	amf_set(c,  9, amf_new_integer(pHero->weapon_level));
	amf_set(c, 10, amf_new_integer(pHero->weapon_exp));
	amf_set(c, 11, amf_new_integer(pHero->placeholder));
	amf_set(c, 12, amf_new_double(pHero->uuid));

	struct HeroSkill * skill = hero_get_selected_skill(player_get(pHero->pid), pHero->uuid);
	if (skill != 0) {
		amf_push(c, amf_new_integer(skill->skill1));
		amf_push(c, amf_new_integer(skill->skill2));
		amf_push(c, amf_new_integer(skill->skill3));
		amf_push(c, amf_new_integer(skill->skill4));
		amf_push(c, amf_new_integer(skill->property_type));
		amf_push(c, amf_new_integer(skill->property_value));
	} else {
		amf_push(c, amf_new_integer(0));
		amf_push(c, amf_new_integer(0));
		amf_push(c, amf_new_integer(0));
		amf_push(c, amf_new_integer(0));
		amf_push(c, amf_new_integer(0));
		amf_push(c, amf_new_integer(0));
	}

	amf_push(c, amf_new_double(pHero->add_time));
	return c;
}

static int hero_add_notify(struct Hero *pHero, int type)
{
	if (pHero) {
		return notification_set(pHero->pid, NOTIFY_HERO_INFO, pHero->uuid, hero_build_message(pHero));
	}
	return 1;
}


struct Hero * hero_next(struct Player * player, struct Hero * hero)
{
	HeroSet * set = (HeroSet*)player_get_module(player, PLAYER_MODULE_HERO);
	if (set == NULL) {
		return 0;
	}

	return dlist_next(set->list, hero);
}


struct Hero * hero_add(Player * player, unsigned int gid, unsigned int level, unsigned int stage, unsigned int star, unsigned int exp)
{
/*
	struct HeroConfig * pCfg = get_hero_config(gid);
	if (pCfg == NULL)
	{
		WRITE_DEBUG_LOG("add hero fail, player %llu, gid %u, not found config", player_get_id(player), gid);
		return RET_NOT_EXIST;
	}
*/

	HeroSet * set = (HeroSet*)player_get_module(player, PLAYER_MODULE_HERO);
	if (set == NULL) {
		return 0;
	}

/*
	struct Hero * pHero = (struct Hero *)_agMap_ip_get(set->m, gid);
	if (pHero != NULL && !pCfg->multiple)//hero已经存在, 转换为碎片
	{
		struct ItemConfig * pItemCfg = get_item_base_config(PIECE_ID_RANGE(gid));
		if (pItemCfg != NULL)
		{
			item_add(player, pItemCfg->id, pItemCfg->compose_num, 1);
			WRITE_DEBUG_LOG("%s player %llu hero %d is exist, add piece %d %d", __FUNCTION__, player_get_id(player), gid, pItemCfg->id, pItemCfg->compose_num);
			return RET_SUCCESS;
		}
		WRITE_DEBUG_LOG("%s player %llu hero %d is exist, add piece %d fail, not found config", __FUNCTION__, player_get_id(player), gid, PIECE_ID_RANGE(gid));
		return RET_NOT_EXIST;
	}
*/

	stage = CLAMP_(stage, 0, MAXIMUN_EVO);
	level = CLAMP_(level, 1, MAXIMUM_LEVEL);
	star  = CLAMP_(star,  0, MAXIMUM_STAR);

	struct Hero * pNew = (struct Hero *)malloc(sizeof(struct Hero));
	memset(pNew, 0, sizeof(struct Hero));
	pNew->gid = gid;
	pNew->pid = player_get_id(player);
	pNew->level = level;
	pNew->stage = stage;
	pNew->star = star;
	pNew->exp = exp;
	pNew->placeholder = 0;
	pNew->weapon_level = level;
	pNew->add_time = agT_current();

	DATA_Hero_new(pNew);

	dlist_init(pNew);
	dlist_insert_tail(set->list, pNew);

	_agMap_ip_set(set->m, gid, pNew);
	_agMap_ip_set(set->uuid, pNew->uuid, pNew);

	hero_add_notify(pNew, Hero_ADD);

	WRITE_DEBUG_LOG("player %llu add hero %d, uuid %llu success", player_get_id(player), pNew->gid, pNew->uuid);

	return pNew;
}

#define SWITCH_EVO_SLOT_COST(index, pCfg, type, id, value)\
	do { type = pCfg->slot[index-1].cost_type, id = pCfg->slot[index-1].cost_id; value = pCfg->slot[index-1].cost_value; } while(0)

int hero_stage_up(Player * player, struct Hero * pHero, int type, int * old_stage)
{
	if (player == NULL && pHero == NULL)
	{
		return RET_ERROR;
	}

	int up_type = type;
	int reason = 0;
	int slot = 0;
	int stage = 0;
	int notify = 0;
	int id = 0;
	switch (up_type)
	{
		case Up_Hero:
			{
				reason = RewardAndConsumeReason_Hero_Stage_Up;
				slot = pHero->stage_slot;
				stage = pHero->stage;
				notify = Hero_STAGE_SLOT_CHANGE;
				id = pHero->gid;
			}
			break;

		case Up_Weapon:
			{
				reason = RewardAndConsumeReason_Hero_Weapon_Stage_Up;
				slot = pHero->weapon_stage_slot;
				stage = pHero->weapon_stage;
				notify = Hero_Weapon_STAGE_CHANGE;
				struct HeroConfig * pHeroCfg = get_hero_config(pHero->gid);
				if (pHeroCfg != NULL)
				{
					id = pHeroCfg->weapon;
				}
				else
				{
					WRITE_ERROR_LOG("%s player %llu stage up fail, not found config, up type %d", __FUNCTION__, player_get_id(player), up_type);

				}
			}
			break;

		default:
			WRITE_ERROR_LOG("%s player %llu stage up param error, up_type : %d", __FUNCTION__, player_get_id(player), up_type);
			return RET_PARAM_ERROR;
	}

	if (old_stage) {
		*old_stage = stage;
	}

	/* 进阶等级判断 */
	struct CommonCfg * commonCfg = get_common_config(STAGE_UP_BEGIN + stage + 1);			
	if (NULL == commonCfg) {
		WRITE_WARNING_LOG("player %lld hero %d stage up fail, not found limit config %d, up type is %d.", player_get_id(player), pHero->gid, STAGE_UP_BEGIN + stage + 1, up_type);
		return RET_NOT_EXIST;
	}
	if (pHero->level < (unsigned int)commonCfg->para2) {
		WRITE_WARNING_LOG("player %lld hero %d stage up fail, hero level %d is less than %d.", player_get_id(player), pHero->gid, pHero->level, commonCfg->para2);
		return RET_PERMISSION;	 
	}	

	struct EvoConfig * pCfg = get_evo_config(id, stage + 1);
	if (pCfg == NULL)
	{
		WRITE_ERROR_LOG(" id %d stage %d config not exists", id, stage + 1);
		return RET_NOT_EXIST;
	}

	int index = 0;
	for (; index < EVO_SLOT_COUNT; ++index)
	{

		int slot_consume_type, slot_consume_id, slot_consume_value;
		SWITCH_EVO_SLOT_COST(index + 1, pCfg, slot_consume_type, slot_consume_id, slot_consume_value);
		if (slot_consume_type == 0) {
			continue;
		}


		int compare = (1 << index);
		int status = slot & compare;
		if (status == 0)
		{
			WRITE_DEBUG_LOG("player %llu hero %d stage up fail, slot %d is lock, up type %d", player_get_id(player), id, index, up_type);
			return RET_EXIST;
		}
	}

	if (CheckForConsume(player, pCfg->cost0_type1, pCfg->cost0_id1, pHero->uuid, pCfg->cost0_value1) != 0)
	{
		return RET_NOT_ENOUGH;
	}
	if (CheckForConsume(player, pCfg->cost0_type2, pCfg->cost0_id2, pHero->uuid, pCfg->cost0_value2) != 0)
	{
		return RET_NOT_ENOUGH;
	}

	CheckAndConsume(player, pCfg->cost0_type1, pCfg->cost0_id1, pHero->uuid, pCfg->cost0_value1, reason);
	CheckAndConsume(player, pCfg->cost0_type2, pCfg->cost0_id2, pHero->uuid, pCfg->cost0_value2, reason);

	if (up_type == Up_Hero)
	{
		DATA_Hero_update_stage(pHero, stage + 1);
		DATA_Hero_update_stage_slot(pHero, 0);
	}
	else if (up_type == Up_Weapon)
	{
		DATA_Hero_update_weapon_stage(pHero, stage + 1);
		DATA_Hero_update_weapon_stage_slot(pHero, 0);
	}

	hero_add_notify(pHero, notify);

	WRITE_DEBUG_LOG("player %llu hero %d stage up success, current stage %d, up type %d", player_get_id(player), id, stage + 1, up_type);

	//quest
	if (up_type == Up_Weapon) {
		aL_quest_on_event(player, QuestEventType_WEAPON_STAGE_UP, stage+1, 1);
	}

	if (up_type == Up_Hero) {
		aL_quest_on_event(player, QuestEventType_HERO_STAGE_UP, stage+1, 1);
	}

	return 0;
}

int hero_stage_slot_unlock(Player * player, struct Hero * pHero, int index, int type)
{
	if (player == NULL || pHero == NULL)
	{
		return RET_ERROR;
	}

	if (index <= 0 || index > EVO_SLOT_COUNT)
	{
		WRITE_DEBUG_LOG("hero_stage_slot_unlock fail, index error, player %llu, hero %u, index %d", player_get_id(player), pHero->gid, index);
		return RET_PARAM_ERROR;
	}

	int up_type = type;
	int stage = 0;
	int slot = 0;
	int reason = 0;
	int notify = 0;
	int id = 0;

	switch (up_type)
	{
		case Up_Hero:
			{
				stage = pHero->stage;
				slot = pHero->stage_slot;
				reason = RewardAndConsumeReason_Hero_Stage_Slot_Unlock;
				notify = Hero_STAGE_SLOT_CHANGE;
				id = pHero->gid;
			}
			break;

		case Up_Weapon:
			{
				stage = pHero->weapon_stage;
				slot = pHero->weapon_stage_slot;
				reason = RewardAndConsumeReason_Hero_Weapon_Stage_Slot_Unlock;
				notify = Hero_Weapon_STAGE_SLOT_CHANGE;
				struct HeroConfig * pHeroCfg = get_hero_config(pHero->gid);
				if (pHeroCfg != NULL)
				{
					id = pHeroCfg->weapon;
				}
				else
				{
					WRITE_ERROR_LOG("%s player %llu stage slot unlock fail, not found config, up type %d", __FUNCTION__, player_get_id(player), up_type);
					return RET_NOT_EXIST;
				}
			}
			break;

		default:
			WRITE_ERROR_LOG("%s player %llu stage slot unlock param error, up type %d", __FUNCTION__, player_get_id(player), up_type);
			return RET_PARAM_ERROR;
	}

	struct EvoConfig * pCfg = get_evo_config(id, stage);
	if (pCfg == NULL)
	{
		WRITE_DEBUG_LOG("hero_stage_slot_unlock get config fail, player %llu, hero %u, stage %d", player_get_id(player), id, stage);
		return RET_NOT_EXIST;
	}

	int compare = (1 << (index - 1));
	int status = slot & compare;
	if (status != 0)
	{
		WRITE_DEBUG_LOG("hero_stage_slot_unlock player %llu, hero %u, status %d index %d has been activated, up type : %d", player_get_id(player), id, slot, index, up_type);
		return RET_EXIST;
	}

	int consume_type = 0;
	int consume_id = 0;
	int consume_value = 0;
	SWITCH_EVO_SLOT_COST(index, pCfg, consume_type, consume_id, consume_value);
	if (consume_type != 0 && CheckAndConsume(player, consume_type, consume_id, pHero->uuid, consume_value, reason) != 0)
	{
		WRITE_DEBUG_LOG("player %llu hero %d slot %d unlock fail, check consume fail, up type %d", player_get_id(player), id, index, up_type);
		return RET_NOT_ENOUGH;
	}

	int new_slot = slot | compare;
	if (up_type == Up_Hero)
	{
		DATA_Hero_update_stage_slot(pHero, new_slot);
	}
	else
	{
		DATA_Hero_update_weapon_stage_slot(pHero, new_slot);
	}

	hero_add_notify(pHero, notify);

	WRITE_DEBUG_LOG("player %llu hero %d stage unlock slot %d success, current slot status %d up type %d", player_get_id(player), id, index, new_slot, up_type);

	return 0;
}

int hero_add_normal_star(struct Hero * pHero, int star) {
	if (pHero) {
		DATA_Hero_update_star(pHero, pHero->star + star);
		hero_add_notify(pHero, Hero_STAR_CHANGE);
	}
	return 0;
}

int hero_add_weapon_star(struct Hero * pHero, int star) {
	if (pHero) {
		DATA_Hero_update_weapon_star(pHero, pHero->weapon_star + star);
		hero_add_notify(pHero, Hero_Weapon_STAR_CHANGE);
	}
	return 0;
}

int hero_add_normal_exp(struct Hero * pHero, int32_t exp)
{
	if (pHero == NULL) {
		return RET_ERROR;
	}

	if (exp <= 0) {
		WRITE_DEBUG_LOG("player %llu hero %u add normal exp %d fail", pHero->pid, pHero->gid, exp);
		return RET_PARAM_ERROR;
	}
	
	WRITE_DEBUG_LOG("player %llu hero %d add normal exp %d", pHero->pid, pHero->gid, exp);

	CommonCfg *cfg = get_common_config(18);
	int factor = cfg ? cfg->para1 : 1;
	/* 次要角色等级不能超过主角 */
	if (pHero->gid != LEADING_ROLE) {
		Player *player = player_get(pHero->pid);
		if (player && transfrom_exp_to_level(pHero->exp + exp, UpGrade_Hero, pHero->gid) > get_leading_role_level(player) * factor) {
			return RET_MAX_LEVEL;		
		}	
	}

	DATA_Hero_update_exp(pHero, pHero->exp + exp);
			
	unsigned int old_leve = pHero->level;
	time_t now = agT_current();
	pHero->level = transfrom_exp_to_level(pHero->exp, UpGrade_Hero, pHero->gid);
	if (exp > 0) {
		DATA_Hero_update_exp_change_time(pHero, agT_current());
		if (pHero->pid == LEADING_ROLE) {
			rank_exp_set(pHero->pid, pHero->exp);
		}
	}

	if (pHero->gid == LEADING_ROLE && pHero->pid >= AI_MAX_ID) {
		agL_write_user_logger(PLAYER_EXP_LOGGER, LOG_FLAT, "%d,%lld,%d,%d,%d", (int)now, pHero->pid, pHero->level, pHero->exp, exp);
		if (pHero->level != old_leve) {
			agL_write_user_logger(PLAYER_LEVEL_UP_LOGGER, LOG_FLAT, "%d,%lld,%u,%u", (int)now, pHero->pid, pHero->level, old_leve);
		} 
	}

	hero_add_notify(pHero, Hero_EXP_CHANGE);

	if (pHero->gid == LEADING_ROLE) {
		updateMaxLevel(pHero->exp);
	}

	if ((pHero->gid == LEADING_ROLE) && (pHero->level > old_leve)) {
		onLevelChange(pHero->pid, pHero->level);
	}

	return RET_SUCCESS;
}

int hero_add_weapon_exp(struct Hero * pHero, int32_t exp)
{
	if (pHero == NULL) {
		return RET_ERROR;
	}

	if (exp <= 0) {
		WRITE_DEBUG_LOG("player %llu hero %u add weapon exp %d fail", pHero->pid, pHero->gid, exp);
		return RET_PARAM_ERROR;
	}

	WRITE_DEBUG_LOG("player %llu hero %d add weapon exp %d", pHero->pid, pHero->gid, exp);

	DATA_Hero_update_weapon_exp(pHero, pHero->weapon_exp + exp);
	pHero->weapon_level = transfrom_exp_to_level(pHero->weapon_exp, UpGrade_Weapon, pHero->gid);

	hero_add_notify(pHero, Hero_EXP_CHANGE);

	return RET_SUCCESS;
}

//place 1 - 5
static int hero_cancel_battle(struct Hero * pHero, HeroSet * set)
{
	if (pHero == NULL || set == NULL)
	{
		return RET_ERROR;
	}

	if (pHero->placeholder == 0)
	{
		return 0;
	}

	if (pHero->gid == LEADING_ROLE)//主角不可以下阵
	{
		return RET_PREMISSIONS;
	}

	if (pHero->placeholder <= 0 || pHero->placeholder > HERO_INTO_BATTLE_MAX)
	{
		return RET_PARAM_ERROR;
	}

	if (pHero->gid == LEADING_ROLE)//主角不能下阵
	{
		return RET_PREMISSIONS;
	}

	int old = pHero->placeholder;

	struct Hero * p = set->fight_formation[old - 1];
	if (p != NULL)
	{
		if (p->gid != pHero->gid)
		{
			WRITE_ERROR_LOG("player %llu cancel battle error, hero %d placeholder %d, fight_formation[%d] hero %d", pHero->pid, pHero->gid, old, old - 1, p->gid);
			return RET_ERROR;
		}
	}

	set->fight_formation[old - 1] = NULL;

	DATA_Hero_update_placeholder(pHero, 0);

	hero_add_notify(pHero, Hero_FIGHT_FORMATION);

	WRITE_DEBUG_LOG("player %llu hero %d cancel battle, placeholder %d to 0", pHero->pid, pHero->gid, old);

	return RET_SUCCESS;
}

//place 1 - 5
static int hero_into_battle(struct Hero * pHero, int place, HeroSet * set)
{
	if (pHero == NULL || set == NULL)
	{
		return -1;
	}

	if (place == pHero->placeholder)
	{
		return RET_SUCCESS;
	}

	if (place == 0)
	{
		return RET_PARAM_ERROR;
	}

	if (pHero->gid == LEADING_ROLE && place != LEADING_ROLE_PLACE)//上阵的是主角, 但位置不是主角专属位置
	{
		return RET_PREMISSIONS;
	}

	if (pHero->gid != LEADING_ROLE && place == LEADING_ROLE_PLACE)//不是主角但是上阵位置是主角专属
	{
		return RET_PREMISSIONS;
	}

	if (place > 0 && place <= HERO_INTO_BATTLE_MAX)
	{
		struct Hero * p = set->fight_formation[place - 1];
		if (p != NULL)
		{
			int r = hero_cancel_battle(p, set);
			if (r != RET_SUCCESS)
			{
				return r;
			}
		}

		int old = pHero->placeholder;
		if (pHero->placeholder > 0 && pHero->placeholder <= HERO_INTO_BATTLE_MAX)
		{
			set->fight_formation[pHero->placeholder - 1] = NULL;
		}

		DATA_Hero_update_placeholder(pHero, place);
		set->fight_formation[place - 1] = pHero;

		hero_add_notify(pHero, Hero_FIGHT_FORMATION);

		WRITE_DEBUG_LOG("player %llu hero %d into battle, place %d to place %d", pHero->pid, pHero->gid, old, place);
		return RET_SUCCESS;
	}

	WRITE_DEBUG_LOG("player %llu hero %d into battle fail, place %d error", pHero->pid, pHero->gid, place);
	return RET_PARAM_ERROR;
}

int hero_update_fight_formation(Player * player, struct Hero * pHero, int new_place)
{
	if (player == NULL || pHero == NULL)
	{
		return RET_ERROR;
	}

	if (new_place == pHero->placeholder)
	{
		return RET_SUCCESS;
	}

	HeroSet * set = (HeroSet *)player_get_module(player, PLAYER_MODULE_HERO);
	if (set == NULL)
	{
		WRITE_ERROR_LOG("%s player %llu get hero module fail", __FUNCTION__, player_get_id(player));
		return RET_ERROR;
	}

	int old = pHero->placeholder;
	int r = 0;
	if (new_place == 0) //cancel nattle
	{
		r = hero_cancel_battle(pHero, set);
	}
	else// into battle
	{
		r = hero_into_battle(pHero, new_place, set);
	}

	if (r == RET_SUCCESS)
	{
		hero_add_notify(pHero, Hero_FIGHT_FORMATION);
		WRITE_DEBUG_LOG("%s player %llu update %d placeholder %d to %d success", __FUNCTION__, player_get_id(player), pHero->gid, old, new_place);
	}

	return r;
}

int hero_check_leading(Player * player)
{
	if (player == NULL)
	{
		return -1;
	}

	HeroSet * set = (HeroSet *)player_get_module(player, PLAYER_MODULE_HERO);
	if (set == NULL)
	{
		WRITE_ERROR_LOG("%s player %llu get hero module fail", __FUNCTION__, player_get_id(player));
		return -1;
	}

	if (_agMap_ip_get(set->m, LEADING_ROLE) == NULL)
	{
		struct HeroConfig * pCfg = get_hero_config(LEADING_ROLE);
		if (pCfg == NULL)
		{
			return -1;
		}

		struct Hero * pNew = (struct Hero *)malloc(sizeof(struct Hero));
		memset(pNew, 0, sizeof(struct Hero));
		pNew->gid = LEADING_ROLE;
		pNew->pid = player_get_id(player);
		pNew->level = 1;
		pNew->stage = 0;
		pNew->star = 0;
		pNew->exp = 0;
		pNew->placeholder = 0;
		pNew->weapon_level = 1;
		pNew->add_time = agT_current();

		DATA_Hero_new(pNew);

		dlist_init(pNew);
		dlist_insert_tail(set->list, pNew);

		_agMap_ip_set(set->m, LEADING_ROLE, pNew);
		_agMap_ip_set(set->uuid, pNew->uuid, pNew);

		hero_add_notify(pNew, Hero_ADD);

		hero_into_battle(pNew, LEADING_ROLE_PLACE, set);
	}
	if (_agMap_ip_get(set->m, LEADING_ROLE) != NULL)//已经有主角了
	{
		return 0;
	}

	struct HeroConfig * pCfg = get_hero_config(LEADING_ROLE);
	if (pCfg == NULL)
	{
		WRITE_DEBUG_LOG("%s player %llu, gid %u, not found config", __FUNCTION__, player_get_id(player), LEADING_ROLE);
		return RET_NOT_EXIST;
	}

	struct Hero * pNew = (struct Hero *)malloc(sizeof(struct Hero));
	memset(pNew, 0, sizeof(struct Hero));
	pNew->gid = LEADING_ROLE;
	pNew->pid = player_get_id(player);
	pNew->level = 1;
	pNew->stage = 0;
	pNew->star = 0;
	pNew->exp = 0;
	pNew->placeholder = 0;
	pNew->weapon_level = 1;
	pNew->add_time = agT_current();

	DATA_Hero_new(pNew);

	dlist_init(pNew);
	dlist_insert_tail(set->list, pNew);

	_agMap_ip_set(set->m, LEADING_ROLE, pNew);
	_agMap_ip_set(set->uuid, pNew->uuid, pNew);

	hero_add_notify(pNew, Hero_ADD);

	hero_into_battle(pNew, LEADING_ROLE_PLACE, set);

	return 0;
}

int get_leading_role_level(Player * player)
{
	if (player == NULL)
	{
		return 0;
	}

	struct Hero * pHero = hero_get(player, LEADING_ROLE, 0);
	if (pHero == NULL)
	{
		return 0;
	}

	return pHero->level;
}


struct Hero * hero_get_by_pos(Player * player, int pos)
{
	if (pos <= 0  || pos > HERO_INTO_BATTLE_MAX) {
		return 0;
	}

	HeroSet * set = (HeroSet *)player_get_module(player, PLAYER_MODULE_HERO);
	if (set == NULL) {
		return 0;
	}

	return set->fight_formation[pos - 1];
}

struct HeroSkill * hero_get_selected_skill(Player * player, unsigned long long uuid)
{
	return 0;
/*
	HeroSet * set = (HeroSet *)player_get_module(player, PLAYER_MODULE_HERO);
	return (struct HeroSkill*)_agMap_ip_get(set->skills, uuid);
*/
}

int hero_set_selected_skill(Player * player, unsigned long long uuid, 
		int skill1, int skill2, int skill3, int skill4, int skill5, int skill6,
		int property_type, int property_value)
{
/*
	HeroSet * set = (HeroSet *)player_get_module(player, PLAYER_MODULE_HERO);
	struct HeroSkill* skills = (struct HeroSkill*)_agMap_ip_get(set->skills, uuid);
	if (skills == 0) {
		skills = (struct HeroSkill*)malloc(sizeof(struct HeroSkill));
		memset(skills, 0, sizeof(struct HeroSkill));

		skills->uid = uuid;
		skills->pid = player_get_id(player);

		skills->skill1 = skill1;
		skills->skill2 = skill2;
		skills->skill3 = skill3;
		skills->skill4 = skill4;
		skills->skill5 = skill5;
		skills->skill6 = skill6;

		skills->property_type  = property_type;
		skills->property_value = property_value;

	    HeroSet * set = (HeroSet *)player_get_module(player, PLAYER_MODULE_HERO);
        _agMap_ip_set(set->skills, skills->uid, skills);

		DATA_HeroSkill_new(skills);
	} else {
		DATA_HeroSkill_update_skill1(skills, skill1);
		DATA_HeroSkill_update_skill2(skills, skill2);
		DATA_HeroSkill_update_skill3(skills, skill3);
		DATA_HeroSkill_update_skill4(skills, skill4);
		DATA_HeroSkill_update_property_type(skills, property_type);
		DATA_HeroSkill_update_property_value(skills, property_value);
	}


	struct Hero * hero = hero_get(player, 0, uuid);
	if (hero) {
		hero_add_notify(hero, 0);
	}
*/

	return 0;
}
