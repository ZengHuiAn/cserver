#include <stdlib.h>
#include <string.h>
#include "xmlHelper.h"
#include "logic_config.h"
#include "hero.h"
#include "map.h"
#include "array.h"
#include "package.h"
#include "equip.h"


#include "config_type.h"

#include "../db_config/TABLE_config_role.h"
#include "../db_config/TABLE_config_role.LOADER.h"

#include "../db_config/TABLE_config_role_property_extension.h"
#include "../db_config/TABLE_config_role_property_extension.LOADER.h"

#include "../db_config/TABLE_config_level_up.h"
#include "../db_config/TABLE_config_level_up.LOADER.h"

#include "../db_config/TABLE_config_star_up.h"
#include "../db_config/TABLE_config_star_up.LOADER.h"

#include "../db_config/TABLE_config_weapon.h"
#include "../db_config/TABLE_config_weapon.LOADER.h"

#include "../db_config/TABLE_config_weapon_evo.h"
#include "../db_config/TABLE_config_weapon_evo.LOADER.h"

#include "../db_config/TABLE_config_role_star.h"
#include "../db_config/TABLE_config_role_star.LOADER.h"

#include "../db_config/TABLE_star_promote.h"
#include "../db_config/TABLE_star_promote.LOADER.h"

#include "../db_config/TABLE_config_weapon_lev.h"
#include "../db_config/TABLE_config_weapon_lev.LOADER.h"

#include "../db_config/TABLE_config_pet.h"
#include "../db_config/TABLE_config_pet.LOADER.h"

#include "../db_config/TABLE_config_chief.h"
#include "../db_config/TABLE_config_chief.LOADER.h"
#include "../db_config/TABLE_config_role_stage_up.h"
#include "../db_config/TABLE_config_role_stage_up.LOADER.h"

#include "../db_config/TABLE_config_add_exp_by_item.h"
#include "../db_config/TABLE_config_add_exp_by_item.LOADER.h"

static struct map * hero_by_weapon = NULL;
static struct map * hero_base_config = NULL;
static struct map * exp_config_by_item = NULL;

static int parse_hero_config(struct config_role * row)
{
	int32_t id = row->id;
	if (id <= 0) {
		WRITE_ERROR_LOG("hero config gid(%d) <= 0", id);
		return -1;
	}

	struct HeroConfig * pCfg = LOGIC_CONFIG_ALLOC(HeroConfig, 1);
	memset(pCfg, 0, sizeof(HeroConfig));

	pCfg->id                = id;
	pCfg->mode              = row->mode;
	pCfg->star              = row->starRound;
	pCfg->scale             = row->scale;
	pCfg->mp_type           = row->mp_type;
	pCfg->cur_mp            = row->cur_mp;
	pCfg->weapon            = row->weapon;
	pCfg->reward_id         = row->reward_id;
	pCfg->reward_value      = row->reward_value;
	pCfg->multiple          = row->multiple;
	pCfg->talent_id         = row->talent_id;
	pCfg->fight_talent_id   = row->roletalent_id1;
	pCfg->work_talent_id    = row->roletalent_id2;
	pCfg->rate		= row->exp_rate;

	pCfg->propertys[0].type  = row->type0; pCfg->propertys[0].value = row->value0;
	pCfg->propertys[1].type  = row->type1; pCfg->propertys[1].value = row->value1;
	pCfg->propertys[2].type  = row->type2; pCfg->propertys[2].value = row->value2;
	pCfg->propertys[3].type  = row->type3; pCfg->propertys[3].value = row->value3;
	pCfg->propertys[4].type  = row->type4; pCfg->propertys[4].value = row->value4;
	pCfg->propertys[5].type  = row->type5; pCfg->propertys[5].value = row->value5;
	pCfg->propertys[6].type  = row->type6; pCfg->propertys[6].value = row->value6;
	pCfg->propertys[7].type  = row->type7; pCfg->propertys[7].value = row->value7;

	if (_agMap_ip_set(hero_base_config, pCfg->id, pCfg)  != 0) {
		WRITE_WARNING_LOG("duplicate hero config %d", pCfg->id);
		return -1;
	}


	if (_agMap_ip_set(hero_by_weapon, pCfg->weapon, pCfg) != 0) {	
		WRITE_WARNING_LOG("weapon %d is used by more than one hero", pCfg->weapon);
		return -1;
	}

	return 0;
}

static int load_hero_base_config()
{
	hero_base_config = LOGIC_CONFIG_NEW_MAP();
	hero_by_weapon = LOGIC_CONFIG_NEW_MAP();
	return foreach_row_of_config_role(parse_hero_config, 0);
}


static int parse_hero_property_extension_config(struct config_role_property_extension * row)
{
	int32_t gid = row->gid;

	struct HeroConfig * pCfg = (struct HeroConfig*)_agMap_ip_get(hero_base_config, gid);
	if (pCfg == 0) {
		WRITE_WARNING_LOG("exten proeprty of hero %d not exists", gid);
		return 0;
	}

	if (row->type == 0 || row->value == 0) {
		return 0;
	}

	struct HeroPropertyList * list = LOGIC_CONFIG_ALLOC(HeroPropertyList, 1);

	list->type = row->type;
	list->value = row->value;
	
	list->next = pCfg->ext_property;
	pCfg->ext_property = list;

	return 0;
}

static int load_hero_extern_property()
{
	return foreach_row_of_config_role_property_extension(parse_hero_property_extension_config, 0);
}

struct HeroConfig * get_hero_config(unsigned int gid)
{
	return (struct HeroConfig *)_agMap_ip_get(hero_base_config, gid);
}

struct HeroConfig * get_hero_config_by_weapon(unsigned int wid)
{
	return (struct HeroConfig *)_agMap_ip_get(hero_by_weapon, wid);
}

static struct map * upgrade_config_map = NULL;
static int _max_upgrade_level = 0;
static int get_max_upgrade_level(struct config_level_up * row)
{
	if (row->level > _max_upgrade_level) {
		_max_upgrade_level = row->level;
	}	
	return 0;
}

static int parse_upgrade_config(struct config_level_up * row)
{
	struct UpgradeConfig * pCfg = LOGIC_CONFIG_ALLOC(UpgradeConfig, 1);
	memset(pCfg, 0, sizeof(struct UpgradeConfig));

	if (row->level == 1 && row->value > 0) {
		WRITE_WARNING_LOG("load config_level_up fail, value > 0 when level is 1 for column %d", row->column);
		return -1;
	}

	pCfg->level             = row->level;
	pCfg->type              = row->column;
	pCfg->consume_type      = row->type;
	pCfg->consume_id        = row->id;
	pCfg->consume_value     = row->value;

	struct array * arr = (struct array *)_agMap_ip_get(upgrade_config_map, pCfg->type);
	if (arr == NULL)
	{
		arr = array_new(_max_upgrade_level + 1);
		_agMap_ip_set(upgrade_config_map, pCfg->type, arr);
	}

	array_set(arr, pCfg->level, pCfg);

	return 0;
}

static int load_upgrade_config()
{
	upgrade_config_map = LOGIC_CONFIG_NEW_MAP();

	foreach_row_of_config_level_up(get_max_upgrade_level, 0);


	return foreach_row_of_config_level_up(parse_upgrade_config, 0);
}

struct UpgradeConfig * get_upgrade_config(int level, int type)
{
	struct array * arr = (struct array *)_agMap_ip_get(upgrade_config_map, type);
	if (arr == NULL) {
		return NULL;
	}

	if (level < 0 || level >= (int)array_size(arr)) {
		return NULL;
	}

	struct UpgradeConfig *pCfg = (struct UpgradeConfig *)array_get(arr, level);
	if (pCfg == 0 || pCfg->level == 0) {
		return NULL;
	}
	return pCfg;
}

static struct map * star_up_config = NULL;
static int parse_star_up_config(struct config_star_up * row)
{
	struct StarUpConfig * pCfg = LOGIC_CONFIG_ALLOC(StarUpConfig, 1);
	memset(pCfg, 0, sizeof(struct StarUpConfig));

	pCfg->star  = row->star;
	pCfg->piece = row->total_piece;
	pCfg->coin  = row->total_coin;

	if (_agMap_ip_set(star_up_config, pCfg->star, pCfg) != 0) {
		WRITE_ERROR_LOG("parseStarUpConfig %d duplicate data", pCfg->star);
	}

	return 0;
}

static int load_starup_config()
{
	star_up_config = LOGIC_CONFIG_NEW_MAP();
	return foreach_row_of_config_star_up(parse_star_up_config, 0);
}

struct StarUpConfig * get_starup_config(int star)
{
	return (struct StarUpConfig *)_agMap_ip_get(star_up_config, star);
}

struct map * evo_config = NULL;
static int parse_evo_config(struct config_weapon_evo * row)
{
	struct EvoConfig * pCfg = LOGIC_CONFIG_ALLOC(EvoConfig, 1);
	memset(pCfg, 0, sizeof(struct EvoConfig));

	pCfg->id                = row->id;
	pCfg->quality           = row->quality;
	pCfg->evo_lev           = row->evo_lev;
	pCfg->cost0_type1       = row->cost0_type1;
	pCfg->cost0_id1         = row->cost0_id1;
	pCfg->cost0_value1      = row->cost0_value1;
	pCfg->cost0_type2       = row->cost0_type2;
	pCfg->cost0_id2         = row->cost0_id2;
	pCfg->cost0_value2      = row->cost0_value2;


	pCfg->propertys[0].type = row->effect0_type1; pCfg->propertys[0].value = row->effect0_value1; 
	pCfg->propertys[1].type = row->effect0_type2; pCfg->propertys[1].value = row->effect0_value2; 
	pCfg->propertys[2].type = row->effect0_type3; pCfg->propertys[2].value = row->effect0_value3; 
	

	pCfg->slot[0].cost_type = row->cost1_type; pCfg->slot[0].cost_id = row->cost1_id; pCfg->slot[0].cost_value = row->cost1_value; 
	pCfg->slot[0].effect_type = row->effect1_type; pCfg->slot[0].effect_value = row->effect1_value; 

	pCfg->slot[1].cost_type = row->cost2_type; pCfg->slot[1].cost_id = row->cost2_id; pCfg->slot[1].cost_value = row->cost2_value;
	pCfg->slot[1].effect_type = row->effect2_type; pCfg->slot[1].effect_value = row->effect2_value;

	pCfg->slot[2].cost_type = row->cost3_type; pCfg->slot[2].cost_id = row->cost3_id; pCfg->slot[2].cost_value = row->cost3_value;
	pCfg->slot[2].effect_type = row->effect3_type; pCfg->slot[2].effect_value = row->effect3_value;

	pCfg->slot[3].cost_type = row->cost4_type; pCfg->slot[3].cost_id = row->cost4_id; pCfg->slot[3].cost_value = row->cost4_value;
	pCfg->slot[3].effect_type = row->effect4_type; pCfg->slot[3].effect_value = row->effect4_value;

	pCfg->slot[4].cost_type = row->cost5_type; pCfg->slot[4].cost_id = row->cost5_id; pCfg->slot[4].cost_value = row->cost5_value;
	pCfg->slot[4].effect_type = row->effect5_type; pCfg->slot[4].effect_value = row->effect5_value;

	pCfg->slot[5].cost_type = row->cost6_type; pCfg->slot[5].cost_id = row->cost6_id; pCfg->slot[5].cost_value = row->cost6_value;
	pCfg->slot[5].effect_type = row->effect6_type; pCfg->slot[5].effect_value = row->effect6_value;

	struct array * arr = (struct array *)_agMap_ip_get(evo_config, pCfg->id);
	if (arr == NULL)
	{
		arr = array_new(MAXIMUN_EVO + 1);
		_agMap_ip_set(evo_config, pCfg->id, arr);
	}

	array_set(arr, pCfg->evo_lev, pCfg);

	return 0;
}

static int load_evo_config()
{
	evo_config = LOGIC_CONFIG_NEW_MAP();
	return foreach_row_of_config_weapon_evo(parse_evo_config, 0);
}

struct EvoConfig * get_evo_config(int gid, int evo_level)
{
	struct array * arr = (struct array *)_agMap_ip_get(evo_config, gid);
	if (arr == NULL)
	{
		return NULL;
	}

	struct EvoConfig * pCfg = (struct EvoConfig *)array_get(arr, evo_level);
	return pCfg;
}

static struct map * weapon_map = NULL;
static int parse_weapon_config(struct config_weapon * row)
{
	int id = row->id;

	struct WeaponConfig * pCfg = LOGIC_CONFIG_ALLOC(WeaponConfig, 1);
	memset(pCfg, 0, sizeof(struct WeaponConfig));

	pCfg->id   = id;
	pCfg->star = row->star;

	pCfg->propertys[0].type = row->type0; pCfg->propertys[0].value = row->value0;
	pCfg->propertys[1].type = row->type1; pCfg->propertys[1].value = row->value1;
	pCfg->propertys[2].type = row->type2; pCfg->propertys[2].value = row->value2;
	pCfg->propertys[3].type = row->type3; pCfg->propertys[3].value = row->value3;
	pCfg->propertys[4].type = row->type4; pCfg->propertys[4].value = row->value4;
	pCfg->propertys[5].type = row->type5; pCfg->propertys[5].value = row->value5;
	pCfg->propertys[6].type = row->type6; pCfg->propertys[6].value = row->value6;

	pCfg->skills[0] = row->skill0;
	pCfg->skills[1] = row->skill1;
	pCfg->skills[2] = row->skill2;
	pCfg->skills[3] = row->skill3;
	pCfg->skills[4] = row->skill4;
	pCfg->skills[5] = row->skill5;

	pCfg->assist_skills[0].id = row->assist_skill1; pCfg->assist_skills[0].weight = row->weight1;
	pCfg->assist_skills[1].id = row->assist_skill2; pCfg->assist_skills[1].weight = row->weight2;
	pCfg->assist_skills[2].id = row->assist_skill3; pCfg->assist_skills[2].weight = row->weight3;

	pCfg->assist_cd = row->assistCd;
	pCfg->talent_id = row->talent_id;

	_agMap_ip_set(weapon_map, id, pCfg);

	return 0;
}

static int load_weapon_config()
{
	weapon_map = LOGIC_CONFIG_NEW_MAP();
	return foreach_row_of_config_weapon(parse_weapon_config, 0);
}

struct WeaponConfig * get_weapon_config(int id)
{
	return (struct WeaponConfig *)_agMap_ip_get(weapon_map, id);
}

static struct map * star_map = NULL;
static struct map * star_promote_map = NULL;

static int parse_star_promote_config(struct star_promote * row)
{
	struct StarPromoteConfig * pCfg = LOGIC_CONFIG_ALLOC(StarPromoteConfig, 1);
	memset(pCfg, 0, sizeof(struct StarPromoteConfig));

	pCfg->id         = row->id;

	pCfg->chance_1   = row->promote_chance1;
	pCfg->rate_1     = row->promote_percentage1;

	pCfg->chance_2   = row->promote_chance2;
	pCfg->rate_2     = row->promote_percentage2;

	void * p = _agMap_ip_set(star_promote_map, pCfg->id, pCfg);
	if (p != 0) {
		WRITE_ERROR_LOG("duplicate id %d in config_star_promote", pCfg->id);
		return -1;
	}
	
	return 0;
}

static int parse_role_star_config(struct config_role_star * row)
{
	struct StarConfig * pCfg = LOGIC_CONFIG_ALLOC(StarConfig, 1);
	memset(pCfg, 0, sizeof(struct StarConfig));

	// pCfg->id                = row->id;
	// pCfg->level             = row->level;
	pCfg->reward_value      = row->reward_value;
	pCfg->reward_id         = row->reward_id;
	pCfg->num               = row->num;
	pCfg->effect_type       = row->effect_type;
	pCfg->effect_value      = row->effect_value;
	pCfg->buff              = row->buff;

	pCfg->propertys[0].type = row->type0; pCfg->propertys[0].value = row->value0; 
	pCfg->propertys[1].type = row->type1; pCfg->propertys[1].value = row->value1; 
	pCfg->propertys[2].type = row->type2; pCfg->propertys[2].value = row->value2; 
	pCfg->propertys[3].type = row->type3; pCfg->propertys[3].value = row->value3; 
	pCfg->propertys[4].type = row->type4; pCfg->propertys[4].value = row->value4; 
	pCfg->propertys[5].type = row->type5; pCfg->propertys[5].value = row->value5; 
	pCfg->propertys[6].type = row->type6; pCfg->propertys[6].value = row->value6; 

	pCfg->consume[0].type = 41; pCfg->consume[0].id = row->cost_id1; pCfg->consume[0].value = row->cost_value1;
	pCfg->consume[1].type = 41; pCfg->consume[1].id = row->cost_id2; pCfg->consume[1].value = row->cost_value2;
	pCfg->consume[0].type = 41; pCfg->consume[2].id = row->cost_id3; pCfg->consume[2].value = row->cost_value3;

	if (row->level < 0 || row->level > MAXIMUN_STAR) {
		WRITE_ERROR_LOG("parseStarConfig fail, level %d error", row->level);
		return -1;
	}

	struct array * pArray = (struct array *)_agMap_ip_get(star_map, row->id);
	if (pArray == NULL) {
		pArray = array_new(MAXIMUN_STAR + 1);
		_agMap_ip_set(star_map, row->id, pArray);
	}
	array_set(pArray, row->level, pCfg);

	pCfg->promote = (struct StarPromoteConfig*)_agMap_ip_get(star_promote_map, row->id);

	return 0;
}

static int load_star_config()
{
	star_promote_map = LOGIC_CONFIG_NEW_MAP();
	if (foreach_row_of_star_promote(parse_star_promote_config, 0) != 0) {
		return -1;		
	}

	star_map = LOGIC_CONFIG_NEW_MAP();
	return foreach_row_of_config_role_star(parse_role_star_config, 0);
}

struct StarConfig * get_star_config(int id, int star)
{
	if (star < 0 || star > MAXIMUN_STAR) {
		return 0;
	}

	struct array * arr = (struct array *)_agMap_ip_get(star_map, id);
	if (!arr) {
		return 0;
	}

	struct StarConfig * cfg = 0;
	int i;
	for (i = star; i >= 0; i --) {
		cfg = (struct StarConfig*)array_get(arr, i);
		if (cfg) {
			if (i != star) { 
				array_set(arr, star, cfg);
			}
			break;
		}
	}

	return cfg;
}

static struct map * lev_property_map = NULL;
static int parse_weapon_lev_config(struct config_weapon_lev * row)
{
	struct LevelPropertyConfig * pCfg = LOGIC_CONFIG_ALLOC(LevelPropertyConfig, 1);
	memset(pCfg, 0, sizeof(struct LevelPropertyConfig));

	pCfg->id = row->id;

	pCfg->propertys[0].type = row->type0; pCfg->propertys[0].value = row->value0; 
	pCfg->propertys[1].type = row->type1; pCfg->propertys[1].value = row->value1; 
	pCfg->propertys[2].type = row->type2; pCfg->propertys[2].value = row->value2; 
	pCfg->propertys[3].type = row->type3; pCfg->propertys[3].value = row->value3; 
	pCfg->propertys[4].type = row->type4; pCfg->propertys[4].value = row->value4; 
	pCfg->propertys[5].type = row->type5; pCfg->propertys[5].value = row->value5; 
	pCfg->propertys[6].type = row->type6; pCfg->propertys[6].value = row->value6; 

	if (_agMap_ip_set(lev_property_map, pCfg->id, pCfg) != 0) {
		WRITE_WARNING_LOG("duplicate weapon level up config %d", pCfg->id);
		return -1;
	}

	return 0;
}

static int load_level_property_config()
{
	lev_property_map = LOGIC_CONFIG_NEW_MAP();
	return foreach_row_of_config_weapon_lev(parse_weapon_lev_config, 0);
}

struct LevelPropertyConfig * get_level_property_config(int id)
{
	return (struct LevelPropertyConfig *)_agMap_ip_get(lev_property_map, id);
}

static struct map * pet_map = NULL;
static int parse_pet_config(struct config_pet * row)
{
	struct PetConfig * pCfg = LOGIC_CONFIG_ALLOC(PetConfig, 1);
	memset(pCfg, 0, sizeof(struct PetConfig));

	pCfg->id        = row->id;
	pCfg->type      = row->type;
	pCfg->skill     = row->skill;
	pCfg->def_order = row->def_order;
	pCfg->hp_type   = row->hp_type;
	pCfg->type1     = row->type1;
	pCfg->value1    = row->value1;
	pCfg->type2     = row->type2;
	pCfg->value2    = row->value2;
	pCfg->type3     = row->type3;
	pCfg->value3    = row->value3;
	pCfg->type4     = row->type4;
	pCfg->value4    = row->value4;
	pCfg->type5     = row->type5;
	pCfg->value5    = row->value5;
	pCfg->type6     = row->type6;
	pCfg->value6    = row->value6;

	if (_agMap_ip_set(pet_map, pCfg->id, pCfg) != 0) {
		WRITE_WARNING_LOG("duplicate weapon level up config %d", pCfg->id);
		return -1;
	}

	return 0;
}

static int load_pet_config()
{
	pet_map = LOGIC_CONFIG_NEW_MAP();
	return foreach_row_of_config_pet(parse_pet_config, 0);
}

struct PetConfig * get_pet_config(int petid)
{
	struct PetConfig * pCfg = (struct PetConfig *)_agMap_ip_get(pet_map, petid);
	return pCfg;
}



struct map * chief_map = 0;


static int parse_chief_config(struct config_chief * row)
{
	struct HeroSkillGroupConfig * cfg = LOGIC_CONFIG_ALLOC(HeroSkillGroupConfig, 1);
    memset(cfg, 0, sizeof(struct HeroSkillGroupConfig));

	cfg->heroid = row->role_id;

	cfg->group = row->id;

	cfg->skill[0] = row->skill0;
	cfg->skill[1] = row->skill1;
	cfg->skill[2] = row->skill2;
	cfg->skill[3] = row->skill3;
	cfg->skill[4] = row->skill4;
	cfg->skill[5] = row->skill5;

	cfg->talent_id = row->skill_tree;
	cfg->talent_type = row->type;

	cfg->property_type  = row->property_type;
	cfg->property_value = row->property_value;

	cfg->init_skill = row->init_skill;

	struct HeroSkillGroupConfig * head = (struct HeroSkillGroupConfig *)_agMap_ip_get(chief_map, cfg->heroid);
	if (head == 0) {
		_agMap_ip_set(chief_map, cfg->heroid, cfg);
	} else {
		if (cfg->init_skill) {
			cfg->next = head;
			_agMap_ip_set(chief_map, cfg->heroid, cfg);
		} else {
			cfg->next = head->next;
			head->next = cfg;
		}
	}
	return 0;
}

static int load_chief_config() 
{
	chief_map = LOGIC_CONFIG_NEW_MAP();	
	return foreach_row_of_config_chief(parse_chief_config, 0);
}

struct HeroSkillGroupConfig * get_hero_skill_group_config(int heroid)
{
	return (struct HeroSkillGroupConfig*)_agMap_ip_get(chief_map, heroid);
}

struct map * _stage_map = 0;
#define MAX_STAGE 6

static int parse_stage_up_config(struct config_role_stage_up *row) 
{
	if (row->stage > MAX_STAGE) {
		WRITE_ERROR_LOG("parse role stage up failed, stage is %d.", row->stage);
		return -1;
	}

	struct HeroStageConfig * cfg = 	LOGIC_CONFIG_ALLOC(HeroStageConfig, 1);
	if (NULL == cfg) {
		return -1;
	}
	memset(cfg, 0, sizeof(struct HeroStageConfig));

	cfg->heroid = row->role_id;
	cfg->stage = row->stage;
	cfg->min_level = row->min_level;
	cfg->max_level = row->max_level;	 
	
	struct array * pArray = (struct array *)_agMap_ip_get(_stage_map, cfg->heroid);
	if (NULL == pArray) {
		pArray = array_new(MAX_STAGE + 1);
		_agMap_ip_set(_stage_map, cfg->stage, pArray);	
	}
	array_set(pArray, cfg->stage, cfg);
	
	return 0;
}

static int load_stage_config() 
{
	_stage_map = LOGIC_CONFIG_NEW_MAP();
	return foreach_row_of_config_role_stage_up(parse_stage_up_config, 0);	
}

struct HeroStageConfig * get_hero_stage_config(int heroid, int stage)
{
	struct array *arr = (struct array *)_agMap_ip_get(_stage_map, heroid);
	if (arr) {
		return (struct HeroStageConfig *)array_get(arr, stage);
	}
	return NULL;
}

static int parse_exp_config_by_item(struct config_add_exp_by_item *row) 
{
	struct ExpConfig * cfg = 	LOGIC_CONFIG_ALLOC(ExpConfig, 1);
	if (NULL == cfg) {
		return -1;
	}
	memset(cfg, 0, sizeof(struct ExpConfig));

	cfg->id = row->gid;
	cfg->consume_type = row->item_type;
	cfg->consume_id = row->item_id;
	cfg->consume_value = row->item_value;
	cfg->hero_gid = row->role_id;
	cfg->limit_lv = row->limit_lv;
	cfg->fixed_exp = row->fixed_exp;
	cfg->quest_id = row->quest_id;
	cfg->quest_exp = row->quest_exp;

	if (_agMap_ip_set(exp_config_by_item, cfg->id, cfg)  != 0) {
		WRITE_WARNING_LOG("duplicate add exp config by item%d", cfg->id);
		return -1;
	}

	return 0;
}

static int load_exp_config_by_item() 
{
	exp_config_by_item = LOGIC_CONFIG_NEW_MAP();
	return foreach_row_of_config_add_exp_by_item(parse_exp_config_by_item, 0);	
}

struct ExpConfig * get_exp_config_by_item(int id)
{
	return (struct ExpConfig*)_agMap_ip_get(exp_config_by_item, id);
}

int load_hero_config()
{
	if (load_hero_base_config() != 0
			|| load_hero_extern_property() != 0
			|| load_upgrade_config() != 0
			|| load_starup_config() != 0
			|| load_evo_config() != 0
			|| load_weapon_config() != 0
			|| load_star_config() != 0
			|| load_level_property_config() != 0
			|| load_pet_config() != 0
			|| load_chief_config() != 0
			|| load_stage_config() != 0
			|| load_exp_config_by_item() != 0)
	{
		return -1;
	}
	return 0;
}
