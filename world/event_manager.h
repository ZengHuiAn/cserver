#ifndef _A_GAME_EVENT_H_
#define _A_GAME_EVENT_H_

#include "module.h"

DECLARE_MODULE(event_manager);

#define EVENT_LOGIN				1
struct EventLogin {
	unsigned long long pid;
};

#define EVENT_LOGOUT				2
struct EventLogout {
	unsigned long long pid;
};

#define EVENT_CREATE_PLAYER			3
struct EventCreatePlayer {
	unsigned long long pid;
};

#define EVENT_BUILDING_UPGRADE			4
struct EventBuildingUpgrade {
	unsigned long long pid;
	unsigned int bid;
};

#define EVENT_TECHNOLOGY_UPGRADE		5
struct EventTechnologyUpgrade {
	unsigned long long pid;
	unsigned int tid;
};

#define EVENT_STORY_FINISHED 			6
struct EventStoryFinished {
	unsigned long long pid;
	unsigned int fid;
	unsigned int result;
};

#define EVENT_LEVY_TAX				7
struct EventLevyTax {
	unsigned long long pid;
};

#define EVENT_SET_COUNTRY			8
struct EventSetCountry {
	unsigned long long pid;
};

#define EVENT_EQUIP_UPGRADE			9
struct EventEquipUpgrade {
	unsigned long long pid;
	unsigned int uuid;
};

#define EVENT_QUEST_STATUS_UPDATE		10
struct EventQuestStatusUpdate {
	unsigned long long pid;
	unsigned int qid;
	unsigned int status;
};

#define EVENT_HERO_LEVEL_UP			11
struct EventHeroLevelup {
	unsigned long long pid;
	unsigned int hid;
};

#define EVENT_HERO_EMPLOY 	12
struct EventHeroEmploy {
	unsigned long long pid;
	unsigned int hid;
};

#define EVENT_KING_LEVEL_UP 	13
struct EventKingLevelup {
	unsigned long long pid;
	unsigned int level;
	int change;
};

#define EVENT_KING_VIP_CHANG	14
struct EventKingVipChange {
	unsigned long long pid;
	unsigned int level;
	int change;
};

#define EVENT_KING_AVATAR_CHANGE 15
struct EventKingAvatarChange {
	unsigned long long pid;
};

#define EVENT_RESOURCE_CHANGE 16
struct EventResourceChange {
	unsigned long long pid;
	unsigned int id;
	int change;
	unsigned int value;
	unsigned int reason;
};

#define EVENT_PLAYER_TOWER	17
struct EventPlayerTower {
	unsigned long long pid;
	unsigned int tower;
};

#define EVENT_STAR_COUNT 18
struct EventStarCount{
	unsigned long long pid;
};

#define EVENT_ARMAMENT 19
struct EventArmament{
	unsigned long long pid;
};

#define EVENT_FIRE 20
struct EventFire{
	unsigned long long pid;
};

int agEvent_dispatch(unsigned int id, const void * param, size_t len);
int agEvent_watch(unsigned int id, void (*cb)(unsigned int id, const void * param, size_t len, const void * ctx), const void * ctx);
int agEvent_schedule();

#define BUILD_EVENT(ID, STRUCT) \
	assert(id == ID && len == sizeof(struct STRUCT)); \
	struct STRUCT * event = (struct STRUCT*)param;

#endif
