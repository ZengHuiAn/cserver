#ifndef _SGK_CONFIG_FIGHT_H_
#define _SGK_CONFIG_FIGHT_H_

#include "config/hero.h"

#define SGK_FIGHT_BUFFER_MAX_SIZE 8192

#define FIGHT_SPACE_TIME 5
#define NPC_PROPERTY_COUNT 30

#define MAX_DROP_WITH_ITEM_GROUP 5 

#define FIGHT_TYPE_FIRE 5   //试练塔
#define FIGHT_TYPE_STAR 6   //需要统计到星星排行榜的战斗

enum PVE_FightResultType
{
	PVE_FIGHT_FAIL,
	PVE_FIGHT_SUCCESS,
};

#define NPC_SKILL_COUNT 4
struct NpcConfig
{
	int id;
	int mode;
	int property_id;
	int skills[NPC_SKILL_COUNT];
	float scale;
	int drop;
	float effect_scale;
	int enter_script;
};

struct NpcConfig * get_npc_config(int id);

struct NpcProperty
{
	struct NpcProperty * next;

	int property_id;
	int lev;
	struct HeroProperty propertys[NPC_PROPERTY_COUNT];
};

int get_npc_property_config(int property_id, int lev, struct HeroProperty propertys[NPC_PROPERTY_COUNT * 2]);

#define CHAPTER_PIC_COUNT 5
struct ChapterConifg
{
	int chapter_id;
	int lev_limit;
	int rely_chapter;
	int finish_id;

	struct {
		int type;
		int id;
		int value;
	} reset_cost;

	struct BattleConfig * battles;
};

struct ChapterConifg * get_chapter_config(int chapter_id);

struct BattleConfig
{
	struct BattleConfig * prev;
	struct BattleConfig * next;

	int battle_id;
	int chapter_id;
	int mode_id;
	float scale;
	float x;
	float y;
	int lev_limit;
	int rely_battle;
	int finish_id;
	int quest_id;

	struct {
		int type;
		int id;
		int value;
	} fight_cost;


	struct {
		int type;
		int id;
		int value;
	} reset_cost;

	struct PVE_FightConfig * fights;
};

struct BattleConfig * get_battle_config(int battle_id);

#define PVE_STAR_LIMIT_COUNT 2

#define PVE_REARD_TYPE_LEVEL_BY_PLAYER 1

struct PVE_FightConfig
{
	struct PVE_FightConfig * prev;
	struct PVE_FightConfig * next;

	int gid;
	int battle_id;
	int depend_level_id;
	int depend_fight0_id;
	int depend_fight1_id;
	int depend_star_count;

	int count_per_day;
	int rank;//类型 ?
	int support_god_hand;
	
	struct {
		int id;
		int type;
		int value;
	} cost;

	struct {
		int id;
		int type;
		int value;
	} check;

	int can_yjdq;//扫荡
	int duration;//回合限制
	int exp;
	int win_type;
	int win_para;
	int fight_type;
	int reset_consume_id;
	int reward_type;

	struct
	{
		int type;
		int v1;
		int v2;
	} star[PVE_STAR_LIMIT_COUNT];


	int drop[3];

	const char * scene;
};

struct PVE_FightConfig * get_pve_fight_config(int gid);
struct BattleConfig * get_pve_fight_battle_config(int gid);//找到一个副本从属的battle
struct ChapterConifg * get_pve_fight_chapter_config(int gid);//找到一个副本从属的chapter

#define FIGHT_DROP_COUNT 3
struct WaveConfig
{
	struct WaveConfig * prev;
	struct WaveConfig * next;

	int gid;
	int wave;
	int role_pos;
	int role_id;
	int role_lev;
	int drop[FIGHT_DROP_COUNT];
	float x;
	float y;
	float z;

	int share_mode;
	int share_count;
};

struct WaveConfig * get_wave_config(int gid);

struct DropConfig
{
	struct DropConfig * prev;
	struct DropConfig * next;
	int drop_id;
	int first_drop;
	int group;
	int drop_rate;
	int type;
	int id;
	int min_value;
	int max_value;
	int min_incr;
	int max_incr;
	int act_time;
	int end_time;
	int act_drop_rate;
	int act_value_rate;

	int level_limit_min;
	int level_limit_max;
};

struct DropConfig * get_drop_config(int drop_id);

struct DropWithItemConfig {
	struct DropWithItemConfig * next;

	int priority;
	int weight;

	int item_id;
	int item_count;

	int group;

	DropConfig * drop;
};

struct DropWithItemConfig * get_drop_with_item_config(int drop_id, int group);


#define ONE_TIME_REWARD_COUNT 4

struct OnetimeRewardConfig
{
	unsigned int id;

	struct {
		int type;
		int id;
		int value;
	} condition;

	struct {
		int type;
		int id;
		int value;
	} consume;

	struct {
		int type;
		int id;
		int value;
	} rewards[ONE_TIME_REWARD_COUNT];
};

struct OnetimeRewardConfig * get_one_time_reward_config(unsigned int id);



int load_fight_config();

#define HERO_INTO_PVE_FIGHT_MAX 5
//pve_fight_recommend
struct PVE_FightRecommendConfig
{
	struct PVE_FightRecommendConfig * prev;
	struct PVE_FightRecommendConfig * next;

	int gid;

	struct
	{
		int role_type;
		int role_id;
		int role_lv;
	} roles[HERO_INTO_PVE_FIGHT_MAX];
};
struct PVE_FightRecommendConfig * get_pve_fight_recommend_config(int gid);

#endif
