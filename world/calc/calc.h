#ifndef _AGAEM_CALC_H_
#define _AGAEM_CALC_H_

struct CommonProperty {
	struct CommonProperty * next;
	int type;
	int value;
};


int calc_level_by_exp(int exp, int type);
int calc_item_grow_count(struct Player * player, int id, int count, time_t update_time, int * modified, int * over_flow);

int calc_affix_value(int id, int value, int grow, struct EquipAffixConfig * cfg, int level);
int calc_affix_grow_max_value(struct EquipAffixConfig * cfg, int level);

struct CommonProperty * calc_equip_property(struct Equip * equip, struct CommonProperty * head);
struct CommonProperty * calc_hero_property(struct Hero * hero, struct CommonProperty * head);
void release_hero_property(struct CommonProperty * head);

#endif
