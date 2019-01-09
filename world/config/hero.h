#ifndef _SGK_HERO_CONFIG_H_
#define _SGK_HERO_CONFIG_H_

#define PIECE_ID_RANGE(id) (id) + 10000

int load_hero_config();

struct HeroProperty {
	int type;
	int value;
};


struct HeroPropertyList {
	struct HeroPropertyList * next;
	int type;
	int value;
};


// base
#define HERO_PROPERTY_COUNT_BASE  8
struct HeroConfig {
	int id;
	int weapon;
	int mode;
	int star;
	int scale;

	struct HeroProperty propertys[HERO_PROPERTY_COUNT_BASE];

	int mp_type;
	int cur_mp;
	int reward_id;
	int reward_value;

	int multiple;

	int talent_id;
	int fight_talent_id;
	int work_talent_id;
	int rate;	

	struct HeroPropertyList * ext_property;
};

struct HeroConfig * get_hero_config(unsigned int gid);
struct HeroConfig * get_hero_config_by_weapon(unsigned int wid);

// weapon base
#define HERO_WEAPON_PROPERTY_COUNT_BASE 7
#define HERO_WEAPON_SKILL_COUNT 6
#define HERO_WEAPON_ASSIST_SKILL_COUNT 3

struct WeaponConfig
{
	int id;
	int star;

	struct HeroProperty propertys[HERO_WEAPON_PROPERTY_COUNT_BASE];

	int skills[HERO_WEAPON_SKILL_COUNT];

	struct {
		int id;
		int weight;
	} assist_skills[HERO_WEAPON_ASSIST_SKILL_COUNT];
	int assist_cd;

    int talent_id;
};

struct WeaponConfig * get_weapon_config(int id);

// level
#define HERO_PROPERTY_COUNT_LEVEL 7
struct LevelPropertyConfig
{
	unsigned int id;

	struct HeroProperty propertys[HERO_PROPERTY_COUNT_LEVEL];
};

struct LevelPropertyConfig * get_level_property_config(int id);

enum UpGradeType
{
	UpGrade_Hero            = 1,
	UpGrade_Weapon          = 2,
	UpGrade_Equip           = 3,
	UpGrade_Inscription     = 4,
};

#define MAXIMUM_LEVEL 100
struct UpgradeConfig
{
	int level;
	int type;
	int consume_id;
	int consume_type;
	int consume_value;
};

struct UpgradeConfig * get_upgrade_config(int level, int type);


// stage
#define MAXIMUN_EVO 20 //阶位上限
#define UPPER_EVO_COST_MAX 2 //进阶消耗物品数量
#define UPPER_EVO_PROPERTY_MAX 3 //进阶属性数量

#define HERO_PROPERTY_COUNT_EVO 3
#define EVO_SLOT_COUNT 6 //插槽数量

struct EvoSlotConfig {
	int cost_type;
	int cost_id;	
	int cost_value;	

	int effect_type;
	int effect_value;
};

struct EvoConfig
{
	int id;
	int evo_lev;
	int quality;

	int cost0_type1;
	int cost0_id1;
	int cost0_value1;
	int cost0_type2;
	int cost0_id2;
	int cost0_value2;

	struct HeroProperty propertys[HERO_PROPERTY_COUNT_EVO];
	struct EvoSlotConfig slot[EVO_SLOT_COUNT];
};

struct EvoConfig * get_evo_config(int gid, int evo_level);

// star
#define MAXIMUM_STAR 30
struct StarUpConfig
{
	int piece;
	int coin;
	int star;
};

struct StarUpConfig * get_starup_config(int star);


#define MAXIMUN_STAR 500
#define HERO_PROPERTY_COUNT_STAR 7


struct StarPromoteConfig 
{
	int id;

	int chance_1;
	int rate_1;

	int chance_2;
	int rate_2;
};

#define STAR_UP_CONSUME_COUNT 3

struct StarConfig
{
	int id;
	int level;

	struct HeroProperty propertys[HERO_PROPERTY_COUNT_STAR];

	int reward_id;
	int reward_value;
	int num;
	int effect_type;
	int effect_value;
	int buff;

	struct {
		int type;
		int id;
		int value;
	} consume[STAR_UP_CONSUME_COUNT];

	struct StarPromoteConfig * promote;
};

struct StarConfig * get_star_config(int id, int star);

enum CommonConfig
{
	CommonConfig_CompoundHero               = 1,

	CommonConfig_CompoundWhiteEquip         = 11,
	CommonConfig_CompoundGreenEquip         = 12,
	CommonConfig_CompoundBlueEquip          = 13,
	CommonConfig_CompoundPurpleEquip        = 14,
	CommonConfig_CompoundOrangeEquip        = 15,

	CommonConfig_RewardExpWhiteEquip        = 21,
	CommonConfig_RewardExpGreenEquip        = 22,
	CommonConfig_RewardExpBlueEquip         = 23,
	CommonConfig_RewardExpPurpleEquip       = 24,
	CommonConfig_RewardExpOrangeEquip       = 25,

	CommonConfig_CostExpWhiteEquip          = 31,
	CommonConfig_CostExpGreenEquip          = 32,
	CommonConfig_CostExpBlueEquip           = 33,
	CommonConfig_CostExpPurpleEquip         = 34,
	CommonConfig_CostExpOrangeEquip         = 35,

	CommonConfig_WeaponTalentSpace          = 41,
	CommonConfig_HeroTalentSpace            = 42,

	CommonConfig_EquipReturnItem            = 61,
	CommonConfig_EquipReturnItemEx          = 62,
	CommonConfig_EquipReturnItemCost        = 63,

	CommonConfig_InscriptionReturnItem      = 64,
	CommonConfig_InscriptionReturnItemEx    = 65,
	CommonConfig_InscriptionReturnItemCost  = 66,
};

struct CommonConfigInfo
{
	int id;
	float para;
};

float get_common_config_value_by_index(int common);

enum CommonOperation
{
	Common_Compound_Hero,//合成角色
	Common_Compound_Equip,//合成各种品质装备
	Common_Equip_Resole_Exp,//分解各种品质装备时产出的exp
	Common_Equip_Stage_Exp,//各种品质装备升阶所需exp
	Common_Weapon_Skill_Star_Space,//武器升星产生技能点的间隔
	Common_Hero_Skill_Level_Space,//角色升级产生技能点的间隔
	Common_Inscription_Resole_Exp,//各品质铭文分解产出的exp
	Common_Equip_Level_Return_Item_Rate,//装备被消耗时返还的资源比例
	Common_Equip_Level_Diamond_Return_Item_Rate,//装备被消耗时返还的资源比例, 钻石加成
	Common_Equip_Level_Diamond_Return_Item_Cost,//装备被消耗时返还的资源比例, 使用钻石加成时钻石消耗数量
	Common_Inscription_Level_Return_Item_Rate,//铭文被消耗时返还的资源比例
	Common_Inscription_Level_Diamond_Return_Item_Rate,//铭文被消耗时返还的资源比例, 钻石加成
	Common_Inscription_Level_Diamond_Return_Item_Cost,//铭文被消耗时返还的资源比例, 使用钻石加成时钻石消耗数量

};

float get_common_operation_value(int oper_type, int para1, int para2);

struct PetConfig
{
	int id;
	int type;
	int skill;
	int def_order;
	int hp_type;
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

struct PetConfig * get_pet_config(int petid);

#define HERO_SKILL_GROUP_COUNT 6

struct HeroSkillGroupConfig {
	struct HeroSkillGroupConfig * next;

	int heroid;

	int group;

	int skill[HERO_SKILL_GROUP_COUNT];

	int talent_id;
	int talent_type;

	int property_type;
	int property_value;
	
	int init_skill;
};

struct HeroSkillGroupConfig * get_hero_skill_group_config(int heroid);

struct HeroStageConfig {
	int heroid;
	int stage;
	int min_level;
	int max_level;
};

struct HeroStageConfig * get_hero_stage_config(int heroid, int stage);

struct ExpConfig {
	int id;
	int consume_type;
	int consume_id;
	int consume_value;
	int hero_gid;
	int limit_lv;
	int fixed_exp;
	int quest_id;
	int quest_exp;
};

struct ExpConfig * get_exp_config_by_item(int id);

#endif
