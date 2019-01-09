#ifndef _A_GAME_WORLD_H_
#define _A_GAME_WORLD_H_

#include "player.h"
/*
// 仅仅用于向后兼容老代码
#define REWARD_TYPE_HERO      		2
#define         REWARD_HERO_EXP		2000 	
#define REWARD_TYPE_QUEST     		40
#define REWARD_TYPE_BUILDING  		51
#define REWARD_TYPE_STORY		80
//
*/

/*
#define REWARD_TYPE_KING                1       // 君主
#define REWARD_TYPE_ARMAMENT            10      // 武备
#define REWARD_TYPE_HERO_ID             21      // 武将
#define REWARD_TYPE_TACTIC              23      // 命格
#define REWARD_TYPE_INSCRIPTION         24      // 铭文
#define REWARD_TYPE_RESOURCE            90      // 资源
#define REWARD_KING_EXP                 1000
#define REWARD_KING_VIP_EXP             1002
#define REWARD_KING_MONTHCARD           1003
*/

#define REWARD_TYPE_ITEM                41      // 道具
#define REWARD_TYPE_HERO                42      // hero
#define REWARD_TYPE_EQUIP               43      // equip
#define REWARD_TYPE_ITEM_PACKAGE        44      // 组合礼包
#define REWARD_TYPE_INSCRIPTION		    45      // 铭文
#define CONSUME_ITEM_PACKAGE            46      
#define REWARD_TYPE_PERMIT		        56	
#define REWARD_TYPE_OPEN_CHECK          57	    // 检查开放条件
#define REWARD_TYPE_HEROITEM            90      // 武将专属道具
#define REWARD_TYPE_QUEST               91      // 任务
#define REWARD_TYPE_BUFF                93      // buff
#define REWARD_TYPE_DROP                94      // drop
#define REWARD_TYPE_GUILD_ITEM          95      // 军团道具 

// int addReward(struct Player * player, struct Reward * reward, int reason); //, ...);


#endif

