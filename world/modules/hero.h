#ifndef _SGK_HERO_H_
#define _SGK_HERO_H_ 

#include "player.h"
#include "data/Hero.h"
#include "data/HeroSkill.h"
#include "aiLevel.h"

#ifndef LEADING_ROLE
# define LEADING_ROLE 11000 //主角
#endif

#ifndef HERO_INTO_BATTLE_MAX
# define HERO_INTO_BATTLE_MAX 5
#endif

DECLARE_PLAYER_MODULE(hero);
	
enum HeroUpType
{
	Up_Hero   = 0,
	Up_Weapon = 1,
};

struct Hero * hero_next(struct Player * player, struct Hero * hero);


//add
struct Hero * hero_add(Player * player, unsigned int gid, unsigned int level, unsigned int stage, unsigned int star, unsigned int exp);

//get
struct Hero * hero_get(Player * player, unsigned int gid, unsigned long long uuid);
struct Hero * hero_get_by_pos(Player * player, int pos);

//stage up
int hero_stage_up(Player * player, struct Hero * pHero, int type, int * old_stage);
int hero_stage_slot_unlock(Player * player, struct Hero * pHero, int index, int type);
//start up
int hero_add_normal_star(struct Hero * pHero, int star);
int hero_add_weapon_star(struct Hero * pHero, int star);

//hero add exp
int hero_add_normal_exp(struct Hero * pHero, int32_t exp);
int hero_add_weapon_exp(struct Hero * pHero, int32_t exp);

//level up
int hero_level_up(Player * player, struct Hero * pHero);

int hero_update_fight_formation(Player * player, struct Hero * pHero, int new_place);

int hero_check_leading(Player * player);

//返回主角等级
int get_leading_role_level(Player * player);

struct HeroSkill * hero_get_selected_skill(Player * player, unsigned long long uuid);
int hero_set_selected_skill(Player * player, unsigned long long uuid, int skill1, int skill2, int skill3, int skill4, int skill5, int skill6, int property_type, int property_value);


amf_value * hero_build_message(struct Hero * pHero);

int transfrom_exp_to_level(int exp, int type, int gid);
int get_exp_by_level(int level, int type, int gid);

#endif
