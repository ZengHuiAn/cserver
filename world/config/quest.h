#ifndef _SGK_CONFIG_QUEST_H_
#define _SGK_CONFIG_QUEST_H_


#define QUEST_EVENT_COUNT 2
#define QUEST_CONSUME_COUNT 2
#define QUEST_REWARD_COUNT 3

#define QuestEventType_PLAYER 1
#define QuestEventType_FIGHT  2
#define QuestEventType_BATTLE 3


#define QuestEvnetType_SHOP_BUY               32
#define QuestEvnetType_ARENA_FIGHT            33
#define QuestEventType_HERO                   34  //状态值
#define QuestEventType_GUILD_DONATE           35
#define QuestEventType_GUILD_EXPLORE          36
#define QuestEventType_EQUIP                  37  //状态值
#define QuestEventType_EQUIP_PROPERTY_REFRESH 39
#define QuestEventType_EQUIP_EAT              41 
#define QuestEventType_CHAT                   44 
#define QuestEventType_GIFT                   45 
#define QuestEventType_ITEM_CONSUME           46
#define QuestEventType_SHOP_FRESH             47
#define QuestEventType_EQUIP_LEVEL_UP         49
#define QuestEventType_EQUIP_STAGE_UP         50 
#define QuestEventType_WEAPON_STAGE_UP        51   //进阶多少个武器到某一阶
#define QuestEventType_HERO_STAR_UP           52   //升星多少个hero到某一星
#define QuestEventType_MANOR_GATHER           53
#define QuestEventType_MANOR_TASK_FINISH      54
#define QuestEventType_LUCKY_DRAW             55
#define QuestEventType_TASK_SUBMIT            56
#define QuestEventType_AFFIX_GROW             57
#define QuestEventType_TEAM_FIGHT			  58
#define QuestEventType_WEAPON_STAR_UP		  59
#define QuestEventType_ONLINE_TIME            60
#define QuestEventType_HERO_STAGE_UP          61
#define QuestEventType_HERO_LEVEL             62  //状态值
#define QuestEventType_HUFU_QUALITY           63  //状态值
#define QuestEventType_MINGWEN_QUALITY        64  //状态值
#define QuestEventType_LEADING_ROLE_WEAR_HUFU 65  //状态值  主角穿X品质的护符X件
#define QuestEventType_LEADING_ROLE_WEAR_MINGWEN 66  //状态值  主角穿X品质的铭文X件
#define QuestEventType_WEEK_QUIZ              67 
#define QuestEventType_HERO_WEAR_SUIT_HUFU    68  //状态值  角色穿戴护符x件套  （6-11位）
//#define QuestEventType_HERO_WEAR_SUIT_MINGWEN 69  //状态值  角色穿戴铭文X件套   （0-5位）
#define QuestEventType_LINGHUN                70  //消耗灵魂方晶（道具id为55001到55999）
#define QuestEventType_ITEM_VALUE             71  //状态值 拥有道具大于等于X
#define QuestEventType_HERO_STAGE             72  //状态值 角色阶数大于等于X
#define QuestEventType_PILLAGE_ARENA          73  //财力竞技场
#define QuestEventType_WEAPON_STAR            74  //状态值 武器星星数大于等于X
#define QuestEventType_WEAPON_TALENT          81  //状态值 X个英雄道具加了Y个技能点
#define QuestEventType_HUFU_STAGE             82  //状态值 X个护符进阶Y阶
#define QuestEventType_HUFU_SUIT              83  //状态值 拥有Y件套装效果数量X
#define QuestEventType_HERO_CAPACITY          84  //状态值 X个角色战力达到多少 
#define QuestEventType_TEAM_FIGHT_ID          88  //通过团队战斗fight
#define QuestEventType_ITEM_SUBTYPE           91  //状态值 sub_type为Y的道具拥有X个 
#define QuestEventType_FIGHT_STATISTIC        92  //用于战斗统计任务 
#define QuestEventType_SOMETYPE_TASK_FINISH   93  //某个类型的任务完成X次 
#define QuestEventType_EQUIP_ADD_WITHOUT_TRADE 97  //获得装备（不包括交易来的装备） 
#define QuestEventType_FIGHT_STAR              98  //状态值 某场战斗的星星值
#define QuestEventType_CHAPTER                 99  //打某个章节X次的计数
#define QuestEventType_FIGHT_FINISH            100 //状态值 某场战斗胜利
#define QuestEventType_PLAYER_TOTAL_STAR       101 //状态值 玩家的总星星数
#define QuestEventType_HUFU_LEVEL              102 //状态值 X个护符升级Y级

#define QUEST_CONSUME_ITEM_FLAG_CONSUME_ON_SUBMIT (1 << 0)
#define QUEST_CONSUME_ITEM_FLAG_CLEAN_ON_SUBMIT   (1 << 1)
#define QUEST_CONSUME_ITEM_FLAG_CONSUME_ON_ACCEPT (1 << 2)
#define QUEST_CONSUME_ITEM_FLAG_CLEAN_ON_ACCEPT   (1 << 3)
#define QUEST_CONSUME_ITEM_FLAG_CLEAN_ON_CANCEL   (1 << 4)
#define QUEST_CONSUME_ITEM_FLAG_CHECK_ON_ACCEPT   (1 << 5)
#define QUEST_CONSUME_ITEM_FLAG_CHECK_ON_SUBMIT   (1 << 6)

#define OVERRIDE_QUEST_EVENT_NUM 20 

struct QuestConfig {
	struct QuestConfig * prev;
	struct QuestConfig * next;

	struct QuestConfig * group_next;

    int id;
	int type;
	int group;

    char auto_accept;
    char only_accept_by_other_activity;

	struct {
		int quest;
		int fight;
		int level;
		int item;
	} depend;

	int next_quest;
	int next_quest_group;
	int next_quest_menu;

	struct {
		int type;
		int id;
		unsigned int count;
	} event[QUEST_EVENT_COUNT];

	struct {
		int type;
		int id;
		int value;
		int need_reset;
	} consume[QUEST_CONSUME_COUNT];

	struct {
		int type;
		int id;
		int value;
		int richvalue;
		int count;
	} reward[QUEST_REWARD_COUNT];

	struct {
		time_t begin;
		time_t end;
		time_t period;
		time_t duration;
	} time;

	struct {
		int type;
		int id;
		int value;
	} extra_reward;

	int count_limit;
	int time_limit;

	int drop_id;
	int drop_count;

	int relative_to_born;
	int type_flag;

	int extra_reward_time_limit;
};

struct QuestDelayConfig {
	int id;
	int delay;
};

struct QuestPoolItem {
	struct QuestPoolItem * next;
	int quest;
	int weight;
	int lev_min;
	int lev_max;
};

struct QuestPool {
	int id;
	int weight;

	struct QuestPoolItem * items;
};

struct OverrideQuestEvent {
	int type;          //事件类型
	int min_id[OVERRIDE_QUEST_EVENT_NUM];	       //取较小值的事件id
	int max_id[OVERRIDE_QUEST_EVENT_NUM];          //取较大值的事件id
};

struct QuestConfig * get_quest_from_pool(int id, int level);
struct QuestConfig * get_quest_from_menu(int id, int level, int selected);
struct QuestConfig * get_quest_config(int id);
struct QuestConfig * auto_accept_quest_next(struct QuestConfig * it);

struct QuestConfig * get_quest_list_of_group(int group);
struct QuestDelayConfig * get_quest_delay(int id);

int quest_need_override_max(int type, int id);
int quest_need_override_min(int type, int id);
int event_can_trigger_by_client(int type, int id);

int load_quest_config();

#endif
