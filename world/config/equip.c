#include <stdlib.h>
#include <string.h>
#include "xmlHelper.h"
#include "logic_config.h"
#include "map.h"
#include "array.h"
#include "equip.h"
#include "package.h"
#include "hero.h"

#include "config_type.h"
#include "../db_config/TABLE_config_equipment1.h"
#include "../db_config/TABLE_config_equipment1.LOADER.h"

#include "../db_config/TABLE_config_equipment_lev1.h"
#include "../db_config/TABLE_config_equipment_lev1.LOADER.h"

#include "../db_config/TABLE_config_equipment_with_level.h"
#include "../db_config/TABLE_config_equipment_with_level.LOADER.h"

#include "../db_config/TABLE_equipment_with_affix.h"
#include "../db_config/TABLE_equipment_with_affix.LOADER.h"

#include "../db_config/TABLE_config_ability_pool1.h"
#include "../db_config/TABLE_config_ability_pool1.LOADER.h"

#include "../db_config/TABLE_config_scroll.h"
#include "../db_config/TABLE_config_scroll.LOADER.h"

#include "../db_config/TABLE_config_suit.h"
#include "../db_config/TABLE_config_suit.LOADER.h"

static struct map * _equip_map = 0;
static struct map * _equip_with_level_map = 0;
static struct map * _equip_with_affix_map = 0;
static struct map * _equip_affix_map = 0;
static struct map * _equip_affix_pool_map = 0;

static int parse_equipment_config(struct config_equipment1 * row) {
	if (_agMap_ip_get(_equip_map, row->id) != 0) {
		WRITE_ERROR_LOG("id %d of config_equipment duplicate", row->id);
		return -1;
	}

	struct EquipConfig * cfg = LOGIC_CONFIG_ALLOC(EquipConfig, 1);
	memset(cfg, 0, sizeof(struct EquipConfig));

	cfg->gid = row->id;
	cfg->type = row->type;

	// cfg->eat_type = row->sub_type;

	cfg->quality = row->quality;

	cfg->propertys[0].type = row->type0; cfg->propertys[0].value = row->value0;
	cfg->propertys[1].type = row->type1; cfg->propertys[1].value = row->value1;
	cfg->propertys[2].type = row->type2; cfg->propertys[2].value = row->value2;
	cfg->propertys[3].type = row->type3; cfg->propertys[3].value = row->value3;

	cfg->ability_pool[0] = row->ability_pool1;
	cfg->ability_pool[1] = row->ability_pool2;
	cfg->ability_pool[2] = row->ability_pool3;
	cfg->ability_pool[3] = row->ability_pool4;
	cfg->ability_pool[4] = row->ability_pool5;
	cfg->ability_pool[5] = row->ability_pool6;


	int i;
	for (i = 0; i < 6; i++) {
		if (cfg->ability_pool[i] != 0 && _agMap_ip_get(_equip_affix_pool_map, cfg->ability_pool[i]) == 0) {
			WRITE_ERROR_LOG("equip %d ability_pool %d not exist", cfg->gid, cfg->ability_pool[i]);
			return -1;
		}
	}

	cfg->stage_consume[0].type  = 41;
	cfg->stage_consume[0].id    = row->swallow_id;
	cfg->stage_consume[0].value = row->swallow;
	cfg->stage_consume[0].increase_value = row->swallow_incr;

	cfg->stage_consume[1].type  = 41;
	cfg->stage_consume[1].id    = row->swallow_id2;
	cfg->stage_consume[1].value = row->swallow2;
	cfg->stage_consume[1].increase_value = row->swallow_incr2;
	
	// cfg->stage_consume_exp = row->swallow;
	// cfg->product_exp       = row->swallowed;

	cfg->decompose[0].type  = 41;
	cfg->decompose[0].id    = row->swallowed_id;
	cfg->decompose[0].value = row->swallowed;
	cfg->decompose[0].increase_value = row->swallowed_incr;

	cfg->decompose[1].type  = 41;
	cfg->decompose[1].id    = row->swallowed_id2;
	cfg->decompose[1].value = row->swallowed2;
	cfg->decompose[1].increase_value = row->swallowed_incr2;

	cfg->next_stage_id = row->evo_id;

	cfg->suit = row->suit_id;

	cfg->min_level = row->min_level;
	cfg->max_level = row->max_level;

	cfg->init.min_level = row->init_min_level;
	cfg->init.max_level = row->init_max_level;

	cfg->equip_level = row->equip_level;

	cfg->stage = row->swallowed_level;

	if (cfg->init.min_level > cfg->init.max_level) {
		WRITE_ERROR_LOG("equip %d init_min_level(%d) > init_max_level(%d)", cfg->gid, cfg->init.min_level, cfg->init.max_level);
		return -1;
	}

	_agMap_ip_set(_equip_map, cfg->gid, cfg);

	return 0;
}


static int parse_equipment_lev_config(struct config_equipment_lev1 * row) {
	struct EquipConfig * cfg = (struct EquipConfig*) _agMap_ip_get(_equip_map, row->id);
	if (cfg == 0) {
		WRITE_ERROR_LOG("equip %d in config_equipment_lev not exists", row->id);
		return -1;
	}

	cfg->level_up_type = row->column;

	cfg->levelup_propertys[0].type = row->type0; cfg->levelup_propertys[0].value = row->value0;
	cfg->levelup_propertys[1].type = row->type1; cfg->levelup_propertys[1].value = row->value1;
	cfg->levelup_propertys[2].type = row->type2; cfg->levelup_propertys[2].value = row->value2;
	cfg->levelup_propertys[3].type = row->type3; cfg->levelup_propertys[3].value = row->value3;

	return 0;
}

static int parse_equip_with_affix_config(struct equipment_with_affix * row) {
	struct EquipWithAffixConfig * cfg = LOGIC_CONFIG_ALLOC(EquipWithAffixConfig, 1);

	cfg->id = row->id;
	cfg->equip_id = row->equip_id;

	cfg->ability_pool[0] = row->ability_pool1;
	cfg->ability_pool[1] = row->ability_pool2;
	cfg->ability_pool[2] = row->ability_pool3;
	cfg->ability_pool[3] = row->ability_pool4;
	cfg->ability_pool[4] = row->ability_pool5;
	cfg->ability_pool[5] = row->ability_pool6;

	if (_agMap_ip_get(_equip_map, cfg->equip_id) == 0) {
		WRITE_ERROR_LOG("equip_with_affix %d equip id %d not exists", cfg->id, cfg->equip_id);
		return -1;
	}

	if (_agMap_ip_set(_equip_with_affix_map, cfg->id, cfg)) {
		WRITE_ERROR_LOG("duplicate equip_with_affix %d", cfg->id);
		return -1;
	}
	
	return 0;
}


static int parse_equip_with_level_config(struct config_equipment_with_level * row) {
	struct EquipWithLevelConfig * cfg = LOGIC_CONFIG_ALLOC(EquipWithLevelConfig, 1);
	cfg->id = row->id;
	cfg->equip_id = row->item_id;
	cfg->min_level = row->min_lev;
	cfg->max_level = row->max_lev;

	if (cfg->min_level <= 0) {
		WRITE_ERROR_LOG("equip_with_level %d min_level(%d) <= 0", cfg->id, cfg->min_level);
	}

	if (cfg->min_level > cfg->max_level) {
		WRITE_ERROR_LOG("equip_with_level %d min_level(%d) > max_level(%d)", cfg->id, cfg->min_level, cfg->max_level);
		return -1;
	}

	if (_agMap_ip_get(_equip_map, cfg->equip_id) == 0) {
		WRITE_ERROR_LOG("equip_with_level %d equip id %d not exists", cfg->id, cfg->equip_id);
		return -1;
	}

	if (_agMap_ip_set(_equip_with_level_map, cfg->id, cfg)) {
		WRITE_ERROR_LOG("duplicate equip_with_level %d", cfg->id);
		return -1;
	}
	
	return 0;
}

static int load_equip_base_config() {
	_equip_map = LOGIC_CONFIG_NEW_MAP();
	_equip_with_level_map = LOGIC_CONFIG_NEW_MAP();
	_equip_with_affix_map = LOGIC_CONFIG_NEW_MAP();

	if (foreach_row_of_config_equipment1(parse_equipment_config, 0) != 0) {
		return -1;
	}

	if (foreach_row_of_config_equipment_lev1(parse_equipment_lev_config, 0) != 0) {
		return -1;
	}

	if (foreach_row_of_config_equipment_with_level(parse_equip_with_level_config, 0) != 0) {
		return -1;
	}

	if (foreach_row_of_equipment_with_affix(parse_equip_with_affix_config, 0) != 0) {
		return -1;
	}


    return 0;
}

struct EquipConfig * get_equip_config(int gid) {
	return (struct EquipConfig*)_agMap_ip_get(_equip_map, gid);
}

struct EquipWithLevelConfig * get_equip_with_level_config(int gid) {
	return (struct EquipWithLevelConfig*)_agMap_ip_get(_equip_with_level_map, gid);
}

struct EquipWithAffixConfig * get_equip_with_affix_config(int gid) {
	return (struct EquipWithAffixConfig*)_agMap_ip_get(_equip_with_affix_map, gid);
}

////////////////////////////////////////////////////////////////////////////////
// affix
static int parse_affix_config(struct config_scroll* row) {
	if (_agMap_ip_get(_equip_affix_map, row->scroll) != 0) {
		WRITE_ERROR_LOG("id %d of config_affix duplicate", row->scroll);
		return -1;
	}

	if (row->max_value < row->min_value)  {
		WRITE_ERROR_LOG("value of config_scroll %d , value range error %d,%d", row->scroll, row->min_value, row->max_value);
		return -1;
	}


	struct EquipAffixConfig * cfg = LOGIC_CONFIG_ALLOC(EquipAffixConfig, 1);
	memset(cfg, 0, sizeof(struct EquipAffixConfig));

	cfg->id = row->scroll;
	cfg->property.type = row->type;
	cfg->property.min  = row->min_value;
	cfg->property.max  = row->max_value;
	cfg->property.level_ratio = row->property_lev_per;

	cfg->quality = row->quality;
	cfg->suit_id = row->suit_id;

	cfg->keep_origin_on_attach = row->keep; // 使用该卷轴是否保留原来位置的属性

	cfg->equip_type = row->from; // 该卷轴可以使用的装备类型
	cfg->slots      = row->by; // 该卷轴可以使用的位置

	cfg->refresh.pool = row->ability_pool; // 刷新属性时候使用的池子
	cfg->refresh.cost.type  = 41; // 刷新属性需要消耗的物品
	cfg->refresh.cost.id    = row->cost_id; // 刷新属性需要消耗的物品
	cfg->refresh.cost.value = row->cost_value; // 刷新属性需要消耗的物品


	cfg->grow.range.min = row->grow_min;
	cfg->grow.range.max = row->grow_max;
	cfg->grow.func.a    = row->grow_a;
	cfg->grow.func.u    = row->grow_u;
	cfg->grow.limit_per_level = row->lev_max_value; // 属性上限随装备等级成长值

	cfg->grow.cost[0].type  = 41;
	cfg->grow.cost[0].id    = row->grow_cost_id;
	cfg->grow.cost[0].value = row->grow_cost_value;

	cfg->grow.cost[1].type  = 41;
	cfg->grow.cost[1].id    = row->grow_cost_id2;
	cfg->grow.cost[1].value = row->grow_cost_value2;

	cfg->decompose.type  = 41;
	cfg->decompose.id    = row->swallowed_id;
	cfg->decompose.value = row->swallowed;
	
	_agMap_ip_set(_equip_affix_map, cfg->id, cfg);

	return 0;
}

static int load_equip_affix_config() {
	_equip_affix_map = LOGIC_CONFIG_NEW_MAP();
	return foreach_row_of_config_scroll(parse_affix_config, 0);
}

struct EquipAffixConfig * get_equip_affix_config(int id) {
	return (struct EquipAffixConfig*)_agMap_ip_get(_equip_affix_map, id);
}
////////////////////////////////////////////////////////////////////////////////
// affix pool
static int parse_affix_pool_config(struct config_ability_pool1 * row) {
	struct EquipAffixConfig * affix = get_equip_affix_config(row->scroll);
	if (affix == 0) {
		WRITE_ERROR_LOG("config of affix %d in poll %d not exists", row->scroll, row->pool_id);
		return -1;
	}

	struct EquipAffixPoolConfig * pool = (struct EquipAffixPoolConfig*)_agMap_ip_get(_equip_affix_pool_map, row->pool_id);
	if (pool == 0) {
		pool = LOGIC_CONFIG_ALLOC(EquipAffixPoolConfig, 1);
		memset(pool, 0, sizeof(struct EquipAffixPoolConfig));
		_agMap_ip_set(_equip_affix_pool_map, row->pool_id, pool);
	}

	pool->weight += row->weight;

	struct EquipAffixPoolItem * item = LOGIC_CONFIG_ALLOC(EquipAffixPoolItem, 1);
	item->cfg = affix;
	item->weight = row->weight;

	item->next = pool->items;
	pool->items = item;
	
	return 0;
}

static int load_equip_affix_pool_config() {
	_equip_affix_pool_map = LOGIC_CONFIG_NEW_MAP();

	return foreach_row_of_config_ability_pool1(parse_affix_pool_config, 0);
}

struct EquipAffixPoolConfig * get_equip_affix_pool_config(int id) {
	return (struct EquipAffixPoolConfig*)_agMap_ip_get(_equip_affix_pool_map, id);
}


////////////////////////////////////////////////////////////////////////////////
// affix pool
static struct map * _equip_suit_map = 0;
struct EquipSuitConfig * get_equip_suit_config(int suit_id, int quality, int count)
{
	uint64_t key = suit_id;
	key = (key << 16) | (count << 8) | quality;
	return (struct EquipSuitConfig*) _agMap_ip_get(_equip_suit_map, key);
}


static int parse_suit_config(struct config_suit * row) {
	int suit_id = row->suit_id;
	int quality = row->quality;
	int count = row->count;

	if (suit_id <= 0 || suit_id >= 65535 || quality < 0 || quality >= 255 || count <= 0 || count >= 255) {
		WRITE_ERROR_LOG("error config of suit %d %d %d", suit_id, quality, count);
		return -1;
	}

	uint64_t key = suit_id;
	key = (key << 16) | (count << 8) | quality;

	if (_agMap_ip_get(_equip_suit_map, key) != 0) {
		WRITE_ERROR_LOG("duplicate config of suit %d %d %d", suit_id, quality, count);
		return -1;
	}

	struct EquipSuitConfig * cfg = LOGIC_CONFIG_ALLOC(EquipSuitConfig, 1);

	cfg->suit_id = suit_id;
	cfg->quality = quality;
	cfg->count = count;

	cfg->propertys[0].type = row->type1; cfg->propertys[0].value = row->value1;
	cfg->propertys[1].type = row->type2; cfg->propertys[1].value = row->value2;


	_agMap_ip_set(_equip_suit_map, key, cfg);
	
	return 0;
}

static int load_equip_suit_config() {
	_equip_suit_map = LOGIC_CONFIG_NEW_MAP();
	return foreach_row_of_config_suit(parse_suit_config, 0);
}

int load_equip_config()
{
	if (load_equip_affix_config() != 0 
			|| load_equip_affix_pool_config() != 0
			|| load_equip_suit_config() != 0
			|| load_equip_base_config() != 0
	   )
	{
		return -1;
	}
	return 0;
}
