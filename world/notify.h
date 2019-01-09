#ifndef _A_GAME_NOTIFICATION_H_
#define _A_GAME_NOTIFICATION_H_

#include "amf.h"

#include "module.h"
#include "package.h"

DECLARE_MODULE(notify)


#if 0
#define NOTIFY_PROPERTY			1
#define NOTIFY_RESOURCE			2
#define NOTIFY_BUILDING			3	//[key]
#define NOTIFY_TECHNOLOGY		4	//[key]
#define NOTIFY_CITY			5
#define NOTIFY_HERO_LIST		6
#define NOTIFY_HERO			7	//[key]
#define NOTIFY_ITEM_COUNT		8	//[key]
#define NOTIFY_COOLDOWN			9
#define NOTIFY_EQUIP_LIST		10	
#define NOTIFY_EQUIP			11	//[key]
#define NOTIFY_FARM			12
#define NOTIFY_STRATEGY			13
#define NOTIFY_STORY			14
#define NOTIFY_COMPOSE			15
#define NOTIFY_DAILY			16
#define NOTIFY_QUEST			17	//[key]
#define ARENA_ATTACK			18      // 竞技场攻击通知

#define NOTIFY_GUILD_REQUEST	        19	// 请求加入军团 [gid, [pid, name]]
#define NOTIFY_GUILD_JOIN	        20	// 加入军团     [gid, [pid, pname]]
#define NOTIFY_GUILD_LEAVE	        21	// 离开军团     [gid, [pid, pname], [oid, oname]]
#define NOTIFY_GUILD_NOTIFY	        22	// 军团公告     [gid, notify]
#define NOTIFY_GUILD_LEADER	        23	// 团长变更     [gid, [leaderid, leadername], [oid, oname]]
#define NOTIFY_GUILD_TITLE	        24	// 职位变更 	[gid, [pid, pname], [oid, oname], changetype, title]
#define NOTIFY_GUILD_AUDIT	        25	// 同意加入变更 [[gid, gname], [oid, oname], type];

#define NOTIFY_MAIL_NEW			26	// 新邮件通知   [id, type, title, status, [fromid, fromname]]

#define NOTIFY_FIRE			27

#define NOTIFY_TACTIC		28
#define NOTIFY_TACTIC_STATUS	29
#endif

int notification_add(unsigned long long playerid, unsigned int type, amf_value * change);
int notification_set(unsigned long long playerid, unsigned int type, unsigned int key, amf_value * change);

void notification_clean_player(unsigned long long playerid);
int notification_clean();

int notification_record_count(unsigned long long playerid, unsigned int event, unsigned int count);

#endif
