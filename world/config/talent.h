#ifndef _SGK_TALENT_CONFIG_H_
#define _SGK_TALENT_CONFIG_H_

#define TALENT_MAXIMUM_DATA_SIZE 45
#define TALENT_SKILL_PROPERTY_MAX 2
#define TALENT_DEPEND_COUNT 3
#define TALENT_MUTEX_COUNT 2

enum TalentType
{
	TalentType_Hero   = 1,
	TalentType_Weapon = 2,
	TalentType_Equip  = 3,

	TalentType_Hero_fight  = 4,
	TalentType_Hero_work = 5,

	TalentType_HeroSkill_min = 10,
	TalentType_HeroSkill_max = 20,

	TalentType_MAX,
};

int load_talent_config();

#define TALENT_POINT_HERO_SPACE_LEVEL 5
#define TALENT_POINT_WEAPON_SPACE_STAR 1
#define TALENT_POINT_EQUIP_SPACE_STAR 1

#define TALENT_CONSUME_COUNT 2
#define TALENT_EFFECT_COUNT 4
#define TALENT_DEPEND_COUNT 3
#define TALENT_MUTEX_COUNT 2

struct TalentSkillConfig
{
	int talent_id;

	int group;
	int id;
	int sub_group;

	int depend_id1;
	int depend_id2;
	int depend_id3;
	int depend_point;
	int depend_level;

	int point_limit;

	int mutex_id1;
	int mutex_id2;

	struct {
		int type;
		int value;
		int incr;
	} effect[TALENT_EFFECT_COUNT];

	struct {
		int type;
		int id;
		int value;
		int incr;
		int payback;
	} consume[TALENT_CONSUME_COUNT];
};

struct TalentSkillConfig * get_talent_skill_config(int talentid, int index);

/*
int check_talent_real(int talentid);

struct SkillConfig
{
	int id;
	int cast_cd;
	int init_cd;
	int script;
	int consume_type;
	int consume_value;
	int type1;
	int value1;
	int type2;
	int value2;
	int type3;
	int value3;
	int type4;
	int value4;
	int type5;
	int value5;
	int type6;
	int value6;
};

struct SkillConfig * get_skill_config(int id);
*/

#endif
