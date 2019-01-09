#ifndef _SGK_CONFIG_EQUIP_H_
#define _SGK_CONFIG_EQUIP_H_

// #define EQUIP_LEVEL_UP_COST 90002
// #define INSCRIPT_PROPERTY_POOL_MAX 6
// #define EQUIP_OR_INSCRIPTION_BOUNDARY 64 //小于64 铭文 大于等于64 装备

#define EQUIP_PROPERTY_INIT_MAX 4
#define EQUIP_PROPERTY_LEVELUP_MAX 4
#define EQUIP_PROPERTY_SUIT_MAX 2
#define EQUIP_PROPERTY_POOL_MAX 6
#define EQUIP_AFFIX_GROW_COST_COUNT 2

#define IS_EQUIP_TYPE_1(type) ( ((type) & 0xfc0) != 0 )		// 芯片
#define IS_EQUIP_TYPE_2(type) ( ((type) & 0x03f) != 0 )		// 守护

struct EquipAffixConfig {
	int id;

	int type;

	// 基础属性
	struct {
		int type;
		int min;
		int max;

		int level_ratio; // 属性值随装备等级成长比例(万分比，向下取整)
	} property;

	struct {
		int type;
		int id;
		int value;
	} decompose;

	// 洗练
	struct {
		struct {
			int type;
			int id;
			int value;
		} cost[EQUIP_AFFIX_GROW_COST_COUNT];

		struct {
			int min;
			int max;
		} range; // 无消耗则不能刷新

		struct {
			int a;
			int u;
		} func;

		int limit_per_level;    // 属性上限随装备等级成长值
	} grow;

	// 套装
	int quality;
	int suit_id;

	// 装备
    int equip_type; // row->from; // 该卷轴可以使用的装备类型
    int slots;      // row->by;   // 该卷轴可以使用的位置

	// 前缀相关
    int keep_origin_on_attach; // = row->keep; // 使用该卷轴是否保留原来位置的属性

	struct {
		int pool; // row->ability_pool; // 刷新属性时候使用的池子
		struct {
			int type;
			int id; // row->cost_id; // 刷新属性需要消耗的物品
			int value; // row->cost_value; // 刷新属性需要消耗的物品数量
		} cost;
	} refresh;
};

struct EquipAffixPoolItem {
	struct EquipAffixPoolItem * next;

	struct EquipAffixConfig * cfg;
	int weight;
};

struct EquipAffixPoolConfig {
	int gid;	
	int weight;
	struct EquipAffixPoolItem * items;
};


#define EQUIP_STAGE_UP_CONSUME_COUNT 2
#define EQUIP_DECOMPOSE_COUNT 2

struct EquipConfig {
	int gid;
	int type;
	int eat_group; // 废弃、同类型可以吞噬
	int quality;
	
	struct {
		int type;
		int value;
	} propertys[EQUIP_PROPERTY_INIT_MAX];

	struct {
		int type;
		int value;
	} levelup_propertys[EQUIP_PROPERTY_LEVELUP_MAX];

	int level_up_type;
	
	int ability_pool[EQUIP_PROPERTY_POOL_MAX];

	struct {
		int type;
		int id;
		int value;
		int increase_value;
	} stage_consume[EQUIP_STAGE_UP_CONSUME_COUNT];

	struct {
		int type;
		int id;
		int value;
		int increase_value;
	} decompose[EQUIP_DECOMPOSE_COUNT];

	int next_stage_id;

	int suit;

	int min_level;
	int max_level;

	struct {
		int max_level;
		int min_level;
	} init;

	int equip_level;
	int stage;
};

struct EquipWithLevelConfig {
	int id;
	int equip_id;
	int min_level;
	int max_level;
};

struct EquipWithAffixConfig {
	int id;
	int equip_id;

	int ability_pool[EQUIP_PROPERTY_POOL_MAX];
};

struct EquipSuitConfig {
	int suit_id;
	int quality;
	int count;
	
	struct {
		int type;
		int value;
	} propertys[EQUIP_PROPERTY_SUIT_MAX];
};

struct EquipConfig *           get_equip_config(int gid);
struct EquipAffixConfig *      get_equip_affix_config(int id);
struct EquipAffixPoolConfig *  get_equip_affix_pool_config(int id);
struct EquipSuitConfig *       get_equip_suit_config(int suit_id, int quality, int count);
struct EquipWithLevelConfig * get_equip_with_level_config(int gid);
struct EquipWithAffixConfig * get_equip_with_affix_config(int gid);

int load_equip_config();

#endif
