#include <assert.h>
#include <string.h>
#include "data/Hero.h"
#include "database.h"
#include "log.h"
#include "package.h"
#include "notify.h"
#include "mtime.h"
#include "map.h"
#include "stringCache.h"
#include "event_manager.h"
#include "backend.h"
#include "protocol.h"
#include <stdint.h>
#include "dlist.h"
#include "config/hero.h"
#include "logic/aL.h"
#include "config/reward.h"
#include "title.h"
#include "player.h"
#include "config/title.h"
#include "modules/property.h"
#include "modules/hero.h"
#include "modules/item.h"
#include "modules/quest.h"
#include "modules/fight.h"


#define CHECK(n, title, player) check_##n(title, player)

static int check_player_level(int title, Player * player);
static int check_player_item(int title, Player * player);
static int check_role_capacity(int title, Player * player);
static int check_role_stage(int title, Player * player);
static int check_role_star(int title, Player * player);
static int check_weapon_stage(int title, Player * player);
static int check_weapon_star(int title, Player * player);
static int check_fight(int title, Player * player);
static int check_quest_finish(int title, Player * player);

int check_player_title(Player * player, int title)
{
	if (title == 0) return 1;
	struct TitleConfig * cfg = get_title_config(title);
	if (!cfg) {
		WRITE_DEBUG_LOG("cannt get title cfg for title:%u", title);
		return 0;
	}

	switch (cfg->type) 
	{
		case TITLE_TYPE_NONE:
			return 1;
		case TITLE_TYPE_PLAYER_LEVEL:
			return CHECK(player_level, title, player);
		case TITLE_TYPE_PLAYER_ITEM:
			return CHECK(player_item, title, player);
		case TITLE_TYPE_ROLE_CAPACITY:
			return CHECK(role_capacity, title, player);	
		case TITLE_TYPE_ROLE_STAGE:
			return CHECK(role_stage, title, player);
		case TITLE_TYPE_ROLE_STAR:
			return CHECK(role_star, title, player);
		case TITLE_TYPE_WEAPON_STAGE:
			return CHECK(weapon_stage, title, player);
		case TITLE_TYPE_WEAPON_STAR:
			return CHECK(weapon_star, title, player);
		case TITLE_TYPE_FIGHT:
			return CHECK(fight, title, player);
		case TITLE_TYPE_QUEST_FINISH:
			return CHECK(quest_finish, title, player);
		default:
			return 0;
	}
}

static int check_player_level(int title, Player * player)
{
	struct TitleConfig * cfg = get_title_config(title);
	if (!cfg) {
		WRITE_DEBUG_LOG("cannt get title cfg for title:%u", title);
		return 0;
	}

	struct Property * property = player_get_property(player);	
	if (cfg->being_icon != 0 && (property->head != (unsigned int)cfg->being_icon))
	{
		return 0;
	}

	int player_level = player_get_level(player);
	if (player_level >= cfg->condition2) 
	{
		return 1;
	}	
	else 
	{
		return 0;
	}	
}

static int check_player_item(int title, Player * player)
{
	struct TitleConfig * cfg = get_title_config(title);
	if (!cfg) {
		WRITE_DEBUG_LOG("cannt get title cfg for title:%u", title);
		return 0;
	}

	struct Property * property = player_get_property(player);
    if (cfg->being_icon != 0 && (property->head != (unsigned int)cfg->being_icon))
    {
        return 0;
    }

	int item_id = cfg->condition1;
	int item_value = cfg->condition2;

	Item * item = item_get(player, item_id);
	if (item->limit >= (unsigned int)item_value)
	{
		return 1;	
	}	
	else
	{
		return 0;
	}
}

static int check_role_capacity(int title, Player * player)
{
	struct TitleConfig * cfg = get_title_config(title);
    if (!cfg) {
        WRITE_DEBUG_LOG("cannt get title cfg for title:%u", title);
        return 0;
    }

	struct Property * property = player_get_property(player);
    if (cfg->being_icon != 0 && (property->head != (unsigned int)cfg->being_icon))
    {
        return 0;
    }
	
	return 0;	
}

static int check_role_stage(int title, Player * player)
{
	struct TitleConfig * cfg = get_title_config(title);
    if (!cfg) {
        WRITE_DEBUG_LOG("cannt get title cfg for title:%u", title);
        return 0;
    }

	struct Property * property = player_get_property(player);
    if (cfg->being_icon != 0 && (property->head != (unsigned int)cfg->being_icon))
    {
        return 0;
    }

	int gid = cfg->condition1;	
	int stage = cfg->condition2;
	struct Hero * hero = hero_get(player, gid, 0);	

	if (!hero)
	{
		return 0;
	}
	
	if (hero->stage >= stage)
	{
		return 1;	
	}
	else
	{
		return 0;
	}
}

static int check_role_star(int title, Player * player)
{
	struct TitleConfig * cfg = get_title_config(title);
    if (!cfg) {
        WRITE_DEBUG_LOG("cannt get title cfg for title:%u", title);
        return 0;
    }

	struct Property * property = player_get_property(player);
    if (cfg->being_icon != 0 && (property->head != (unsigned int)cfg->being_icon))
    {
        return 0;
    }

	int gid = cfg->condition1;	
	int star = cfg->condition2;
	struct Hero * hero = hero_get(player, gid, 0);	

	if (!hero)
    {
        return 0;
    }
	
	if (hero->star >= star)
	{
		return 1;	
	}
	else
	{
		return 0;
	}
}

static int check_weapon_stage(int title, Player * player)
{
	struct TitleConfig * cfg = get_title_config(title);
    if (!cfg) {
        WRITE_DEBUG_LOG("cannt get title cfg for title:%u", title);
        return 0;
    }

	struct Property * property = player_get_property(player);
    if (cfg->being_icon != 0 && (property->head != (unsigned int)cfg->being_icon))
    {
        return 0;
    }

	int gid = cfg->condition1;	
	int weapon_stage = cfg->condition2;
	struct Hero * hero = hero_get(player, gid, 0);	

	if (!hero)
    {
        return 0;
    }
	
	if (hero->weapon_stage >= weapon_stage)
	{
		return 1;	
	}
	else
	{
		return 0;
	}
}

static int check_weapon_star(int title, Player * player)
{
	struct TitleConfig * cfg = get_title_config(title);
    if (!cfg) {
        WRITE_DEBUG_LOG("cannt get title cfg for title:%u", title);
        return 0;
    }

	struct Property * property = player_get_property(player);
    if (cfg->being_icon != 0 && (property->head != (unsigned int)cfg->being_icon))
    {
        return 0;
    }

	int gid = cfg->condition1;	
	int weapon_star = cfg->condition2;
	struct Hero * hero = hero_get(player, gid, 0);	

	if (!hero)
    {
        return 0;
    }
	
	if (hero->weapon_star >= weapon_star)
	{
		return 1;	
	}
	else
	{
		return 0;
	}
}

static int check_fight(int title, Player * player)
{
	struct TitleConfig * cfg = get_title_config(title);
    if (!cfg) {
        WRITE_DEBUG_LOG("cannt get title cfg for title:%u", title);
        return 0;
    }

	struct Property * property = player_get_property(player);
    if (cfg->being_icon != 0 && (property->head != (unsigned int)cfg->being_icon))
    {
        return 0;
    }

	int gid = cfg->condition1;	
	int star = cfg->condition2;
	struct Fight * fight = fight_get(player, gid);
	
	if (fight->star >= star)
	{
		return 1;	
	}
	else
	{
		return 0;
	}
}

static int check_quest_finish(int title, Player * player)
{
	struct TitleConfig * cfg = get_title_config(title);
    if (!cfg) {
        WRITE_DEBUG_LOG("cannt get title cfg for title:%u", title);
        return 0;
    }

	struct Property * property = player_get_property(player);
    if (cfg->being_icon != 0 && (property->head != (unsigned int)cfg->being_icon))
    {
        return 0;
    }

	int id = cfg->condition1;	
	int count = cfg->condition2;
	struct Quest * quest = quest_get(player, id);

	if (!quest) 
	{
		return 0;
	}
	
	if (quest->status == QUEST_STATUS_FINISH && quest->count >= (unsigned int)count)
	{
		return 1;	
	}
	else
	{
		return 0;
	}
}
