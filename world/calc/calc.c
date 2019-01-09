
#include "config/equip.h"
#include "config/hero.h"
#include "config/talent.h"
#include "config/item.h"
#include "config/buff.h"

#include "modules/hero.h"
#include "modules/equip.h"
#include "modules/talent.h"
#include "modules/item.h"
#include "modules/property.h"
#include "modules/buff.h"

#include "player.h"
#include "log.h"
#include "mtime.h"

#include "calc.h"
#include "logic/aL.h"
#include "config/common.h"

#include "config/fashion.h"
#include "modules/hero_item.h"

#define PLOG(...)  // WRITE_DEBUG_LOG(__VA_ARGS__)
#define CHECK_PROPERTY 1307


int calc_level_by_exp(int exp, int type)
{
	struct UpgradeConfig * cfg =get_upgrade_config(1, type);
	if (cfg == 0) {
		return 0;
	}

	int i;
	for (i = 1; 1; i++) {
		struct UpgradeConfig * cfg =get_upgrade_config(i, type);
		if (cfg == 0 || cfg->consume_value > exp) {
			return i - 1;
		} 
	}

	return 0;
}


static struct CommonProperty * hero_property_add(struct CommonProperty * head, int type, int value)
{
	if (type == 0 || value == 0) {
		return head;
	}

	struct CommonProperty * ite = head;
	for (ite = head; ite; ite = ite->next) {
		if (ite->type == type) {

			if (type == CHECK_PROPERTY) { PLOG("   %d + %d -> %d", ite->value, value, ite->value+value); }

			ite->value += value;
			return head;
		}
	}

	struct CommonProperty * cur = (struct CommonProperty*)malloc(sizeof(struct CommonProperty));
	cur->next = head;
	cur->type = type;
	cur->value = value;


	if (type == CHECK_PROPERTY) { PLOG("   0 + %d -> %d", value, value); }

	return cur;

}

void release_hero_property(struct CommonProperty * head)
{
	while(head) {
		struct CommonProperty * cur = head;
		head = head->next;;

		free(cur);
	}
}

// 武将+武器 基础属性
static struct CommonProperty * hero_property_calc_base(struct Hero* hero,  struct CommonProperty * head)
{
	struct HeroConfig * cfg = get_hero_config(hero->gid);
	if (!cfg) {
		return head;
	}


	PLOG("hero %llu base", hero->uuid);

	int i;
	for (i = 0; i < HERO_PROPERTY_COUNT_BASE; i++) {
		head = hero_property_add(head, cfg->propertys[i].type, cfg->propertys[i].value);
	}

	struct HeroPropertyList * ite;
	for (ite = cfg->ext_property; ite; ite = ite->next) {
		head = hero_property_add(head, ite->type, ite->value);
	}

	struct WeaponConfig * wcfg = get_weapon_config(cfg->weapon);
	if (wcfg) {
		for (i = 0; i < HERO_WEAPON_PROPERTY_COUNT_BASE; i++) {
			head = hero_property_add(head, wcfg->propertys[i].type, wcfg->propertys[i].value);
		}
	} else {
		WRITE_WARNING_LOG("weapon config %d not exists", cfg->weapon);
	}

	return head;
};


// 武将+武器 升级属性
static struct CommonProperty * calc_level(int gid, int level, struct CommonProperty * head) {
	struct LevelPropertyConfig * cfg = get_level_property_config(gid);
	if (!cfg) {
		return head;
	}


	int i;
	for (i = 0; i < HERO_PROPERTY_COUNT_LEVEL; i++) {
		head = hero_property_add(head, cfg->propertys[i].type, cfg->propertys[i].value * level);
	}
	return head;
}

static struct CommonProperty * hero_property_calc_level(struct Hero* hero,  struct CommonProperty * head)
{
	struct HeroConfig * cfg = get_hero_config(hero->gid);
	if (!cfg) {
		return head;
	}

	PLOG("hero %llu level", hero->uuid);

	head = calc_level(hero->gid, hero->level, head);
	head = calc_level(cfg->weapon, hero->weapon_level, head);

	return head;
};


// 武将+武器 进阶属性
static struct CommonProperty * calc_stage(int gid, int stage, int slot, struct CommonProperty * head)
{
	for (int i = 0; i <= stage; i++) {
		struct EvoConfig * cfg = get_evo_config(gid, i);
		if (!cfg) {
			continue;
		}

		int j;
		for (j = 0; j < HERO_PROPERTY_COUNT_EVO; j++) {
			head = hero_property_add(head, cfg->propertys[j].type, cfg->propertys[j].value);
		}

		for (j = 0; j < EVO_SLOT_COUNT; j++) {
			if ( i < stage || (slot &  (1<<j)) ) {
				head = hero_property_add(head, cfg->slot[j].effect_type, cfg->slot[j].effect_value);
			}
		}
	}

	return head;
}


static struct CommonProperty * hero_property_calc_stage(struct Hero* hero,  struct CommonProperty * head)
{
	struct HeroConfig * cfg = get_hero_config(hero->gid);
	if (!cfg) {
		return head;
	}

	PLOG("hero %llu stage", hero->uuid);

	head = calc_stage(hero->gid, hero->stage, hero->stage_slot, head);
	head = calc_stage(cfg->weapon, hero->weapon_stage, hero->weapon_stage_slot, head);

	return head;
}


// 武将+武器 升星属性
static struct CommonProperty * calc_star(int gid, int star, struct CommonProperty * head)
{
	int i, j;
	for (i = 1; i <= star; i++) {
		struct StarConfig * cfg = get_star_config(gid, i);	
		if (!cfg) {
			continue;
		}

		for (j = 0; j < HERO_PROPERTY_COUNT_STAR; j++) {
			head = hero_property_add(head, cfg->propertys[j].type, cfg->propertys[j].value);
		}
	}

	return head;
}


struct CommonProperty * hero_property_calc_star(struct Hero* hero,  struct CommonProperty * head)
{
	struct HeroConfig * cfg = get_hero_config(hero->gid);
	if (!cfg) {
		return head;
	}

	PLOG("hero %llu star", hero->uuid);

	head = calc_star(hero->gid, hero->star, head);
	head = calc_star(cfg->weapon, hero->weapon_star, head);

	return head;
};


// 武将+武器 天赋属性
static struct CommonProperty * calc_talent(struct Talent * talent, int talentid, struct CommonProperty * head) {
	if (!talent) {
		return head;
	}

	int i;
	for (i = 0; i < TALENT_MAXIMUM_DATA_SIZE; i++) {
		int val = talent->data[i] - '0';
		if (val > 0) {
			struct TalentSkillConfig * cfg = get_talent_skill_config(talentid, i+1);

			if (cfg == 0) {
				WRITE_WARNING_LOG("talent %d, id %d not exists", talentid, i + 1);
				continue;
			}

			
			if (val > cfg->point_limit) {
				val = cfg->point_limit;
			}

			int j;
			for (j = 0; j < TALENT_EFFECT_COUNT; j++) {
				head = hero_property_add(head, cfg->effect[j].type, cfg->effect[j].value + cfg->effect[j].incr * (val-1));
			}
		}
	}
	return head;
} 

static struct CommonProperty * hero_property_calc_talent(struct Hero* hero,  struct CommonProperty * head)
{
	struct HeroConfig * cfg = get_hero_config(hero->gid);
	if (!cfg) {
		return head;
	}

	struct Player * player = player_get(hero->pid);
	if (!player) {
		return head;
	}

	PLOG("hero %llu talent", hero->uuid);

	head = calc_talent(talent_get(player, TalentType_Hero,       hero->uuid), cfg->talent_id, head);
	head = calc_talent(talent_get(player, TalentType_Hero_fight, hero->uuid), cfg->fight_talent_id, head);
	head = calc_talent(talent_get(player, TalentType_Hero_work,  hero->uuid), cfg->work_talent_id, head);

	struct WeaponConfig * wcfg = get_weapon_config(cfg->weapon);
	if (wcfg) {
		head = calc_talent(talent_get(player, TalentType_Weapon, hero->uuid), wcfg->talent_id, head);
	}


	// selectable skill talent
	struct HeroSkillGroupConfig * skill_group = get_hero_skill_group_config(cfg->id);
	for (;skill_group; skill_group=skill_group->next) {
		if (skill_group->talent_type != TalentType_Weapon) {
			PLOG("hero %llu addition talent %d", hero->uuid, skill_group->group);
			head = calc_talent(talent_get(player, skill_group->talent_type,  hero->uuid), skill_group->talent_id, head);
		}
	}

	PLOG("hero %llu selectable skill property", hero->uuid);

	// selectable skill group property
	struct HeroSkill * skill = hero_get_selected_skill(player, hero->uuid);
	if (skill) {
		head = hero_property_add(head, skill->property_type, skill->property_value);
	}
	
	return head;
};


// 装备、铭文 属性
struct CommonProperty * calc_equip_property(struct Equip * equip, struct CommonProperty * head, int ratio)
{
	if (!equip) {
		return head;
	}

	int i;

	// base
	struct EquipConfig * cfg = get_equip_config(equip->gid);
	if (!cfg) {
		return head;
	}

	float rate = ratio / 10000.0;

	PLOG("hero %llu equip %llu pos %d base", equip->hero_uuid, equip->uuid, equip->placeholder);

	for (i = 0; i < EQUIP_PROPERTY_INIT_MAX; i++) {
		head = hero_property_add(head, cfg->propertys[i].type, cfg->propertys[i].value * rate);
	}

	// level up 
	PLOG("hero %llu equip %llu pos %d level up", equip->hero_uuid, equip->uuid, equip->placeholder);
	for (i = 0; i < EQUIP_PROPERTY_LEVELUP_MAX; i++) {
		head = hero_property_add(head, cfg->levelup_propertys[i].type, cfg->levelup_propertys[i].value * equip->level * rate);
	}

	// stage have no effect
	

	// 前缀 
#define MERGE_RANDOM_PROPERTY(n) \
	do { \
		if (equip->property_id_##n > 0) { \
			PLOG("hero %llu equip %llu pos %d affix %d", equip->hero_uuid, equip->uuid, equip->placeholder, n); \
			struct EquipAffixConfig * affix_cfg = get_equip_affix_config(equip->property_id_##n); \
			if (affix_cfg) { \
				int value = calc_affix_value(equip->property_id_##n, equip->property_value_##n, equip->property_grow_##n, affix_cfg, equip->level); \
				head = hero_property_add(head, affix_cfg->property.type, value * rate); \
			} \
		} \
	} while(0)


	MERGE_RANDOM_PROPERTY(1);
	MERGE_RANDOM_PROPERTY(2);
	MERGE_RANDOM_PROPERTY(3);
	MERGE_RANDOM_PROPERTY(4);
	MERGE_RANDOM_PROPERTY(5);
	MERGE_RANDOM_PROPERTY(6);

#undef MERGE_RANDOM_PROPERTY

	return head;
}


struct SuitIn {
	int suit;
	int quality;
};

struct SuitOut {
	int suit;
	int quality[10];
};

// 套装
static int calc_suit(struct SuitIn * in, struct SuitOut * out, int n)
{
	int i, j, k;
	for (i = 0; i < n; i++) {
		if (in[i].suit == 0) {
			continue;
		}

		for (j = 0; j < n; j++) {
			if (out[j].suit == in[i].suit || out[j].suit == 0) {
				out[j].suit = in[i].suit;
				for (k = 0; k <= in[i].quality && k < 10; k++) {
					out[j].quality[k] = out[j].quality[k] + 1;
				}
				break;
			}
		}
	}
	return 0;
}

//全局buff属性
struct CommonProperty * calc_buff_property(struct Hero * hero, struct CommonProperty * head)
{
	//WRITE_DEBUG_LOG("begin calc_buff_property >>>>>>>>>>>>>>>>>>>>>");
	struct Player * player = player_get(hero->pid);
	if (!player) {
		return head;
	}

	WRITE_DEBUG_LOG("calc_buff_property");


	Buff * ite = 0; // buff_next(Player * player, Buff * buff) 
	while((ite = buff_next(player, ite)) != 0) {
		struct BuffConfig * cfg = get_buff_config(ite->buff_id);	
		if (cfg && (cfg->hero_id == 0 || cfg->hero_id == (int)hero->gid)) {
			head = hero_property_add(head, cfg->type, cfg->value * ite->value);
		}
	}

	return head;
}

// 时装属性
static CommonProperty * calc_fashion_property(struct Hero * hero, struct CommonProperty * head)
{
	WRITE_DEBUG_LOG("calc fashion property, pid is %lld.", hero->pid);

	struct Player * player = player_get(hero->pid);
	if (NULL == player) {
		return head;
	}

	HeroItem * item = NULL;
	while ((item = hero_item_next(player, item))) {
		if (item->status == 1 && item->uid == hero->uuid) {
			struct Fashion * cfg = get_fashion_by_item(hero->gid, item->id);
			if (cfg) {
				head = hero_property_add(head, cfg->effect_type, cfg->effect_value);
			}
		}
	}

	return head;
}

// 武将+武器+装备+铭文+套装 属性
struct CommonProperty * calc_hero_property(struct Hero * hero, struct CommonProperty * head)
{
	struct Player * player = player_get(hero->pid);
	if (!player) {
		return head;
	}


	head = hero_property_calc_base(hero, head);
	head = hero_property_calc_level(hero, head);
	head = hero_property_calc_stage(hero, head);
	head = hero_property_calc_star(hero, head);
	head = hero_property_calc_talent(hero, head);

#define SUIT_SLOT_COUNT (EQUIP_INTO_BATTLE_MAX + EQUIP_INTO_BATTLE_MAX * EQUIP_PROPERTY_POOL_MAX)

	struct SuitIn  equip_suit_in[SUIT_SLOT_COUNT];
	struct SuitOut equip_suit_out[SUIT_SLOT_COUNT];

	memset(equip_suit_in, 0, sizeof(equip_suit_in));
	memset(equip_suit_out, 0, sizeof(equip_suit_out));



	// 额外装备属性
	struct CommonCfg * commonCfg12 = get_common_config(12);
	struct CommonCfg * commonCfg13 = get_common_config(13);

	int i, j, k;
	for (i = 1; i <= EQUIP_INTO_BATTLE_MAX; i++) {
		struct Equip * equip = equip_get_by_hero(player, hero->uuid, i);
		if (equip == 0) {
			continue;
		}

		head = calc_equip_property(equip, head, 10000);

		int addon_group_count = 0;
		int addon_property    = 0;
		if (IS_EQUIP_TYPE_1(i) && commonCfg12) {
			addon_group_count = commonCfg12->para2;
			addon_property    = commonCfg12->para1;
		} else if(IS_EQUIP_TYPE_2(i) && commonCfg13) {
			addon_group_count = commonCfg13->para2;
			addon_property    = commonCfg13->para1;
		}

		if (addon_property > 0) {
			int group;
			for (group = 1; group <= addon_group_count; group ++) {
				struct Equip * equip = equip_get_by_hero(player, hero->uuid, (group << 8) | i);
				if (equip == 0) {
					continue;
				}
				calc_equip_property(equip, head, addon_property);
			}
		}

		struct EquipConfig * eCfg = get_equip_config(equip->gid);
		if (eCfg) {
			equip_suit_in[i-1].suit = eCfg->suit;
			equip_suit_in[i-1].quality = eCfg->quality;
		}

		// TODO: 前缀套装
		for (j = 0; j < EQUIP_PROPERTY_POOL_MAX; j++) {
			int property_id = 0, property_value = 0, property_grow = 0;
			if (equip_get_affix(equip, j+1, &property_id, &property_value, &property_grow) == 0) {
				if (property_id == 0) {
					continue;
				}
				struct EquipAffixConfig * affix_cfg = get_equip_affix_config(property_id);
				if (affix_cfg) {
					equip_suit_in[i*EQUIP_PROPERTY_POOL_MAX+j].suit    = affix_cfg->suit_id;
					equip_suit_in[i*EQUIP_PROPERTY_POOL_MAX+j].quality = affix_cfg->quality;
				}
			}
		}
	}

	// 装备套装
	if (calc_suit(equip_suit_in, equip_suit_out, SUIT_SLOT_COUNT) == 0) {
		for (i = 0; i < SUIT_SLOT_COUNT; i++) {
			int suit = equip_suit_out[i].suit;
			if (suit == 0) {
				continue;
			}

			int count_quality[10] = {0};
			for (j = 9; j >= 0; j--) { // quality
				for (k = equip_suit_out[i].quality[j]; k > 1; k--) { // suit count must > 1
					if (count_quality[k] != 0) {
						continue;
					}

					struct EquipSuitConfig * suitCfg = get_equip_suit_config(suit, j, k);
					if (suitCfg) {
						PLOG("equip suit %d, count %d, quality %d", suit, k, j);
						head = hero_property_add(head, suitCfg->propertys[0].type, suitCfg->propertys[0].value);
						head = hero_property_add(head, suitCfg->propertys[1].type, suitCfg->propertys[1].value);

						count_quality[k] = j;
					}
				}
			}
		}
	}

	//全局buff
	head = calc_buff_property(hero, head);
	head = calc_fashion_property(hero, head);

	return head;
}

int calc_item_grow_count(struct Player * player, int id, int count, time_t update_time, int * modified, int * over_flow)
{
	time_t now = agT_current();

	if (modified) *modified = 0;

	struct ItemConfig * cfg = get_item_base_config(id);
	if (cfg == 0) {
		return count;
	}

	struct ItemGrowInfo * grow = cfg->grow;
	
	for(; grow; grow = grow->next) {
		if (grow->end_time > now) {
			break;
		}
	}

	// remove old data
	cfg->grow = grow;


	// not grow;
	if (grow == 0 || grow->begin_time > now) {
		return count;	
	}


	int start_time = update_time;
	time_t begin_time = grow->begin_time;

	struct Property * property = player_get_property(player);
	if (property->create > begin_time) {
		begin_time += ((property->create - begin_time) / grow->period) * grow->period;
	}

	//reset
    if (grow->is_reset != 0) {
        int p2 = (now        - (begin_time - grow->is_reset)) / grow->is_reset;
        int p3 = (start_time - (begin_time - grow->is_reset)) / grow->is_reset;
        if (p2 != p3) {
			if (modified) *modified = 1;
            count = 0;
        }
    }

	// same period
	if ((update_time-grow->begin_time) / grow->period >= (now-grow->begin_time) / grow->period) {
		return count;
	}

	if (modified) *modified = 1;
	
	int old_count = count;
	int new_count = 0;
	
	// reach limit
	/*if (count >= grow->limit) {
		return count;
	}*/

	if (begin_time >= start_time) {
		start_time = begin_time - 1; // give item when period start
	}

	int p1 = (now        - (begin_time - grow->period)) / grow->period;
	int p2 = (start_time - (begin_time - grow->period)) / grow->period;

#define MAX(a, b) \
	(a) > (b) ? (a) : (b)
	
	count += (p1 - p2) * grow->amount;
	if (count > grow->limit) {
		new_count = MAX(old_count, grow->limit);
		if (over_flow) {
			*over_flow = count - new_count;
		}
	} else {
		new_count = count;
	}

	return new_count;
}

int calc_affix_value(int id, int value, int grow, struct EquipAffixConfig * cfg, int level)
{
	cfg = cfg ? cfg : get_equip_affix_config(id);

	if (cfg == 0) {
		return 0;
	}

	float f = cfg->property.level_ratio /  10000.0;
	value += value * (level - 1) * f + grow;
	return value;
}

int calc_affix_grow_max_value(struct EquipAffixConfig * cfg, int level)
{
	return cfg->property.max + (level - 1) * cfg->grow.limit_per_level;
}


