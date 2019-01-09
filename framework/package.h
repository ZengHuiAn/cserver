#ifndef _A_GAME_COMM_PACKAGE_H_
#define _A_GAME_COMM_PACKAGE_H_

#include <stdint.h>

#pragma pack(push, 1)

struct client_header {
	uint32_t len;
	uint32_t flag;
	uint32_t cmd;
};

struct translate_header {
	uint32_t len;
	uint32_t sn;
	unsigned long long playerid;
	uint32_t flag;
	uint32_t cmd;
	unsigned int serverid;
};

#define         PLAYER_STATUS_NORMAL		0x00	//正常
#define         PLAYER_STATUS_BAN		0x01	//封号
#define         PLAYER_STATUS_MUTE		0x02	//禁言

#define LOGOUT_NORMAL		0
#define LOGOUT_ANOTHER_LOGIN	1
#define LOGOUT_ADDICTED    	2
#define LOGOUT_ADMIN_KICK	3
#define LOGOUT_CONNECT		4
#define LOGOUT_ADMIN_BAN	5

#define RET_SUCCESS			0
#define RET_ERROR			1
#define RET_EXIST			2
#define RET_NOT_EXIST			3
#define RET_PARAM_ERROR			4
#define RET_INPROGRESS			5
#define RET_MAX_LEVEL			6
#define RET_DEPEND			7
#define RET_RESOURCES			8
#define RET_FULL			9
#define RET_NOT_ENOUGH			10
#define RET_PREMISSIONS			11
#define RET_PERMISSION			RET_PREMISSIONS
#define RET_COOLDOWN			12
#define RET_ALREADYAT			13
#define RET_SERVICE_STATUS_ERROR	14
#define RET_MUTEX 15

#define RET_CHARACTER_NOT_EXIST		RET_NOT_EXIST

#define RET_CHARACTER_STATUS_BAN	20
#define RET_CHARACTER_STATUS_MUTE	21
#define RET_CHARACTER_STATUS_ADDICTED	22
#define RET_VERSION_MISSMATCH     812

#define RET_VIP_PREMISSIONS			30

#define RET_FIGHT_CHECK_DEPEND_FAIL     31
#define RET_FIGHT_CHECK_LEVEL_FAIL      32
#define RET_FIGHT_CHECK_COUNT_FAIL      33
#define RET_FIGHT_CHECK_BATTLE_FAIL     34
#define RET_FIGHT_CHECK_CHAPTER_FAIL    35
#define RET_FIGHT_CHECK_AUTO_FAIL       36
#define RET_FIGHT_CHECK_YJDQ_FAIL       37
#define RET_FIGHT_CHECK_SPACE_FAIL      38
#define RET_FIGHT_CHECK_STAR_FAIL       39

#define RET_TARGET_NOT_EXIST		50
#define RET_CHARACTER_EXIST		51
#define RET_CHARACTER_NAME_EXIST	52
#define RET_FIGHT_FAILED		53
#define RET_REWARD_NOT_EXIST		54
#define RET_CHECK_RETURN_ITEM           55
#define RET_ITEM_NOT_ENOUGH		280


#define REASON_CREATE_PLAYER          1
#define REASON_EQUIP_LEVEL_UP	      1001
#define REASON_EQUIP_STAGE_UP         1002
#define REASON_EQUIP_REPLACE_PROPERTY 1003
#define REASON_EQUIP_REFRESH_PROPERTY 1004
#define REASON_PVE_FIGHT              1005
#define REASON_TALENT                 1006
#define REASON_QUEST                  1007
#define REASON_ONE_TIME_REWARD_STAR   1008
#define REASON_ITEM_AUTO_GROW         1009
#define REASON_DROP_ITEM_CONSUME      1010
#define REASON_NICK_NAME 	          1011
#define REASON_EQUIP_EAT              1012
#define REASON_EQUIP_AFFIX_GROW       1013
#define REASON_EQUIP_CHANGE_POSITION  1014
#define REASON_EQUIP_DECOMPOSE        1015
#define REASON_FIGHT_RESET	      1016
#define REASON_COMPENSATE	      1017
#define REASON_EXP_RANK_REWARD    1018
#define REASON_STAR_RANK_REWARD   1019
#define REASON_TOWER_RANK_REWARD  1021
#define REASON_TRADE              1020

#define NOTIFY_PROPERTY			1	// 属性
#define NOTIFY_ADDICTED_CHANGE	51	// [type, hour]  type:0 登录通知   1 每小时弹框 2 踢出弹框
#define NOTIFY_ITEM_COUNT		39
#define NOTIFY_REWARD_CHANGE		49
#define NOTIFY_HERO_INFO   50 //角色信息变化
#define NOTIFY_TALENT_INFO 52 //天赋信息变通
#define NOTIFY_EQUIP       53
#define NOTIFY_FIGHT       54
#define NOTIFY_HERO_ITEM   55
#define NOTIFY_QUEST       56
#define NOTIFY_REWARDFLAG  57
#define NOTIFY_QUEST_REWARD 58
#define NOTIFY_FIRE         59
#define NOTIFY_BUFF         61

#define C_ECHO 		 0
#define C_LOGIN_REQUEST  1 		//登入请求
#define C_LOGIN_RESPOND  2 		//登入返回

#define C_LOGOUT_REQUEST  3 		//登出请求
#define C_LOGOUT_RESPOND  4 		//登出返回

#define C_QUERY_PLAYER_REQUEST 5 	//查询玩家信息请求
#define C_QUERY_PLAYER_RESPOND 6 	//查询玩家信息返回

#define C_CREATE_PLAYER_REQUEST 7	//创建角色请求
#define C_CREATE_PLAYER_RESPOND 8	//创建角色返回

#define C_QUERY_HERO_REQUEST 9 
#define C_QUERY_HERO_RESPOND 10 //查询玩家角色列表

#define C_HERO_ADD_EXP_REQUEST 11
#define C_HERO_ADD_EXP_RESPOND 12

#define C_HERO_STAR_UP_REQUEST 13
#define C_HERO_STAR_UP_RESPOND 14

#define C_HERO_STAGE_UP_REQUEST 15
#define C_HERO_STAGE_UP_RESPOND 16

#define C_HERO_STAGE_SLOT_UNLOCK_REQUEST 17
#define C_HERO_STAGE_SLOT_UNLOCK_RESPOND 18

#define C_TEST_ADD_HERO_REQUEST 19 //添加角色
#define C_TEST_ADD_HERO_RESPOND 20

#define C_QUERY_TALENT_REQUEST 21
#define C_QUERY_TALENT_RESPOND 22

#define C_RESET_TALENT_REQUEST 23
#define C_RESET_TALENT_RESPOND 24

#define C_UPDATE_TALENT_REQUEST 25
#define C_UPDATE_TALENT_RESPOND 26

#define C_QUERY_PLAYER_POWER_REQUEST 27
#define C_QUERY_PLAYER_POWER_RESPOND 28

#define C_GM_SEND_REWARD_REQUEST 29
#define C_GM_SEND_REWARD_RESPOND 30

#define C_HERO_UPDATE_FIGHT_FORMATION_REQUEST 31
#define C_HERO_UPDATE_FIGHT_FORMATION_RESPOND 32

#define C_QUERY_EQUIP_INFO_REQUEST 33
#define C_QUERY_EQUIP_INFO_RESPOND 34

#define C_EQUIP_LEVEL_UP_REQUEST 35
#define C_EQUIP_LEVEL_UP_RESPOND 36

#define C_EQUIP_STAGE_UP_REQUEST 37
#define C_EQUIP_STAGE_UP_RESPOND 38

#define C_EQUIP_UPDATE_FIGHT_FORMATION_REQUEST 39
#define C_EQUIP_UPDATE_FIGHT_FORMATION_RESPOND 40

#define C_EQUIP_REPLACE_PROPERTY_REQUEST 41 // 更换属性
#define C_EQUIP_REPLACE_PROPERTY_RESPOND 42

#define C_EQUIP_EAT_REQUEST 43   // 装备吞噬
#define C_EQUIP_EAT_RESPOND 44

#define C_FIGHT_PREPARE_REQUEST 45
#define C_FIGHT_PREPARE_RESPOND 46

#define C_FIGHT_CHECK_REQUEST 47
#define C_FIGHT_CHECK_RESPOND 48

#define C_QUERY_FIGHT_REQUEST 49
#define C_QUERY_FIGHT_RESPOND 50

#define C_NICK_NAME_CHANGE_REQUEST 51 // 修改昵称请求
#define C_NICK_NAME_CHANGE_RESPOND 52 // 修改昵称返回

#define C_FIGHT_COUNT_RESET_REQUEST 53	// 挑战次数重置请求
#define C_FIGHT_COUNT_RESET_RESPOND 54 

#define C_HERO_LEVEL_UP_REQUEST 70
#define C_HERO_LEVEL_UP_RESPOND 71

#define C_EQUIP_REFRESH_PROPERTY_REQUEST 72
#define C_EQUIP_REFRESH_PROERPTY_RESPOND 73

#define C_QUERY_HERO_ITEM_REQUEST 74 //查询角色专属道具
#define C_QUERY_HERO_ITEM_RESPOND 75 

#define C_QUERY_QUEST_REQUEST 76 // 查询任务
#define C_QUERY_QUEST_RESPOND 77 

#define C_SET_QUEST_STATUS_REQUEST 78 // 完成、放弃任务
#define C_SET_QUEST_STATUS_RESPOND 79 

#define C_QUERY_ONE_TIME_REWARD_REQUEST 80 // 查询一次性奖励
#define C_QUERY_ONE_TIME_REWARD_RESPOND 81

#define C_RECV_ONE_TIME_REWARD_REQUEST 82 // 领取一次性奖励
#define C_RECV_ONE_TIME_REWARD_RESPOND 83

#define C_PVE_FIGHT_FAST_PASS_REQUEST 84 // 扫荡
#define C_PVE_FIGHT_FAST_PASS_RESPOND 85

#define C_HERO_SELECT_SKILL_REQUEST 86 // 角色选择技能
#define C_HERO_SELECT_SKILL_RESPOND 87 

#define C_EQUIP_DECOMPOSE_REQUEST 88
#define C_EQUIP_DECOMPOSE_RESPOND 89

#define C_EQUIP_AFFIX_GROW_REQUEST 90
#define C_EQUIP_AFFIX_GROW_RESPOND 91

#define C_HERO_ITEM_SET_REQUEST 92
#define C_HERO_ITEM_SET_RESPOND 93

#define C_HERO_ADD_EXP_BY_ITEM_REQUEST 94
#define C_HERO_ADD_EXP_BY_ITEM_RESPOND 95

#define C_GET_FASHION_REQUEST 96
#define C_GET_FASHION_RESPOND 97

#define C_TICK_REQUEST          100 //心跳
#define C_TICK_RESPOND          101 //心跳

#define C_PLAYER_DATA_CHANGE 		104

#define C_EQUIP_SELL_TO_SYSTEM_REQUEST 106
#define C_EQUIP_SELL_TO_SYSTEM_RESPOND 107

#define C_EQUIP_BUY_FROM_SYSTEM_REQUEST 108
#define C_EQUIP_BUY_FROM_SYSTEM_RESPOND 109

#define C_QUERY_EQUIP_INFO_BY_UUID_REQUEST 110
#define C_QUERY_EQUIP_INFO_BY_UUID_RESPOND 111

#define C_QUERY_ITEM_REQUEST		165
#define C_QUERY_ITEM_RESPOND		166

#define C_QUERY_REWARD_REQUEST		193
#define C_QUERY_REWARD_RESPOND		194

#define C_RECEIVE_REWARD_REQUEST	195
#define C_RECEIVE_REWARD_RESPOND	196

#define C_QUERY_BUFF_REQUEST		197
#define C_QUERY_BUFF_RESPOND		198

#define C_QUERY_COMPEN_ITEM_REQUEST	199	// 查询补偿奖励
#define C_QUERY_COMPEN_ITEM_RESPOND	200	

#define C_DRAW_COMPEN_ITEM_REQUEST	201	// 领取补偿奖励
#define C_DRAW_COMPEN_ITEM_RESPOND	202

#define C_QUEST_ON_EVENT_REQUEST    203  //客户端触发任务事件
#define C_QUEST_ON_EVENT_RESPOND    204

#define C_QUEST_GM_FORCE_SET_STATUS_REQUEST 205  //gm 强制完成任务
#define C_QUEST_GM_FORCE_SET_STATUS_RESPOND 206

#define C_QUERY_ITEM_PACKAGE_REQUEST 428 // 查询物品合集请求
#define C_QUERY_ITEM_PACKAGE_RESPOND 429 // 查询物品合集返回

#define C_QUERY_CONSUME_ITEM_PACKAGE_REQUEST 430 //查询消耗物品集合
#define C_QUERY_CONSUME_ITEM_PACKAGE_RESPOND 431

#define S_SERVICE_REGISTER_RESPOND	1005	

#define S_SERVICE_REGISTER_REQUEST	1004	// 注册服务
#define S_SERVICE_REGISTER_RESPOND	1005	// 注册服务

#define S_SERVICE_BROADCAST_REQUEST	1006	// 服务广播
#define S_SERVICE_BROADCAST_RESPOND	1007


#define S_SET_PLAYER_STATUS_REQUEST		3014
#define S_SET_PLAYER_STATUS_RESPOND		3015	//PSetPlayerStatusRespond

#define S_GET_PLAYER_INFO_REQUEST       3004	// PGetPlayerInfoRequest
#define S_GET_PLAYER_INFO_RESPOND       3005    // PGetPlayerInfoRespond

#define S_ADD_PLAYER_NOTIFICATION_REQUEST	3006 
#define S_ADD_PLAYER_NOTIFICATION_RESPOND	3007

#define S_ADMIN_REWARD_REQUEST		3008	//PAdminRewardRequest
#define S_ADMIN_REWARD_RESPOND		3009	//PAdminAddExpRespond

#define S_GET_PLAYER_HERO_INFO_REQUEST       3010	// PGetPlayerHeroInfoRequest
#define S_GET_PLAYER_HERO_INFO_RESPOND       3011   // PGetPlayerHeroInfoRespond

#define S_GET_PLAYER_RETURN_INFO_REQUEST 3036
#define S_GET_PLAYER_RETURN_INFO_RESPOND 3037

#define S_ADMIN_SET_ADULT_REQUEST	3022	// PAdminSetAdultRequest
#define S_ADMIN_SET_ADULT_RESPOND	3023	// aGameRespond

#define S_GET_FORMATION_REQUEST  3026		// GetFormationRequest
#define S_GET_FORMATION_RESPOND  3027		// GetFormationRespond

#define S_ADMIN_PLAYER_KICK_REQUEST		3016	//PAdminPlayerKickRequest
#define S_ADMIN_PLAYER_KICK_RESPOND		3017	//PAdminPlayerKickRespond

#define S_CHANGE_BUFF_REQUEST 3018  //PChangeBuffRequest
#define S_CHANGE_BUFF_RESPOND 3019  //aGameRespond

#define S_SAVE_HERO_CAPACITY_REQUEST 3020 
#define S_SAVE_HERO_CAPACITY_RESPOND 3021

#define S_UNLOAD_PLAYER_REQUEST 6017 //卸载玩家请求
#define S_UNLOAD_PLAYER_RESPOND 6018 //卸载玩家返回

// auth server
#define S_AUTH_REQUEST 30001 // 认证请求 AuthRequest
#define S_AUTH_RESPOND 30002 // 认证返回 aGameRespond

/***item_package******/
#define S_SET_ITEM_PACKAGE_REQUEST 6041 //设置item package 请求
#define S_SET_ITEM_PACKAGE_RESPOND 6042 //设置item package 返回

#define S_DEL_ITEM_PACKAGE_REQUEST 6043 //删除item package 请求
#define S_DEL_ITEM_PACKAGE_RESPOND 6044 //删除item package 返回

#define S_QUERY_ITEM_PACKAGE_REQUEST 6045 //请求item package 请求
#define S_QUERY_ITEM_PACKAGE_RESPOND 6046 //请求item package 返回
/********************/

#define S_QUERY_PLAYER_FIGHT_INFO_REQUEST 1016 // 查询战斗数据请求
#define S_QUERY_PLAYER_FIGHT_INFO_RESPOND 1017 // 查询战斗数据返回

#define S_PLAYER_FIGHT_PREPARE_REQUEST 1018 // 准备玩家副本战斗数据
#define S_PLAYER_FIGHT_PREPARE_RESPOND 1019 // 

#define S_PLAYER_FIGHT_CONFIRM_REQUEST 1020 // 副本战斗确认
#define S_PLAYER_FIGHT_CONFIRM_RESPOND 1021 // 

#define S_NOTIFY_QUSET_EVENT_REQUEST 1022 // 通知任务事件
#define S_NOTIFY_QUSET_EVENT_RESPOND 1023

#define S_QUERY_RECOMMEND_FIGHT_INFO_REQUEST 1024 // 查询指定阵容战斗数据请求
#define S_QUERY_RECOMMEND_FIGHT_INFO_RESPOND 1025 // 查询指定阵容战斗数据请求

#define C_QUERY_PLAYER_TITLE_REQUEST 1026 // 查询玩家头衔是否可装备请求
#define C_QUERY_PLAYER_TITLE_RESPOND 1027 //

#define S_QUERY_UNACTIVE_AI_REQUEST 1028 //查询未活跃AI
#define S_QUERY_UNACTIVE_AI_RESPOND 1029

#define S_UPDATE_AI_ACTIVE_TIME_REQUEST 1030
#define S_UPDATE_AI_ACTIVE_TIME_RESPOND 1031

#define S_CHANGE_AI_NICK_NAME_REQUEST 1032
#define S_CHANGE_AI_NICK_NAME_RESPOND 1033

#define C_QUERY_RANK_REQUEST 1034
#define C_QUERY_RANK_RESPOND 1035

#define C_QUERY_FIRE_REQUEST 1036
#define C_QUERY_FIRE_RESPOND 1037

#define S_GET_SERVER_INFO_REQUEST 1902	// 查询服务器相关信息
#define S_GET_SERVER_INFO_RESPOND 1903 

#define S_TRADE_WITH_SYSTEM_REQUEST 1904
#define S_TRADE_WITH_SYSTEM_RESPOND 1905

enum RewardAndConsumeReason
{
        RewardAndConsumeReason_GM = 10, 
        RewardAndConsumeReason_Hero_Star_Up,
        RewardAndConsumeReason_Hero_Stage_Up,
        RewardAndConsumeReason_Hero_Stage_Slot_Unlock,
        RewardAndConsumeReason_Hero_Weapon_Star_Up,
        RewardAndConsumeReason_Hero_Weapon_Stage_Up,
        RewardAndConsumeReason_Hero_Weapon_Stage_Slot_Unlock,
        RewardAndConsumeReason_Hero_Level_Up,
        RewardAndConsumeReason_Hero_Weapon_Level_Up,
        RewardAndConsumeReason_Equip_Level_Up,
        RewardAndConsumeReason_Equip_Compound,
        RewardAndConsumeReason_Equip_ReturnItem,
        RewardAndConsumeReason_PVE_Fight_Cost,
};

//将sid和pid组合到一起
#define TRANSFORM_PLAYERID_TO_64(value_64, sid, pid)\
	{\
		unsigned long long tmp = value_64;\
		unsigned int *_p_ = (unsigned int *)&(tmp);\
		*_p_ = (pid);\
		++_p_;\
		*_p_ = (sid);\
		value_64 = tmp;\
	}

//将pid转换为sid或pid _bool_:true sid, _bool_:false pid
#define TRANSFORM_PLAYERID(value_64, _bool_, uint_32)\
		if (_bool_)\
		{\
			uint_32 = (unsigned int)((value_64) >> 32);\
		}\
		else\
		{\
			uint_32 = (unsigned int)(value_64);\
		}

#define AG_SERVER_ID agC_get_server_id()

#define CHECK_PID_AND_TRANSFORM(_pid_)\
		{\
			if (_pid_ > 0) {\
				unsigned int sid = 0;\
				TRANSFORM_PLAYERID(_pid_, 1, sid);\
				if (sid == 0 && (_pid_) > 100000) { \
					TRANSFORM_PLAYERID_TO_64(_pid_, AG_SERVER_ID, _pid_);\
				}\
			}\
		}

#define NTOHL_PID_AND_SID(_pid_, _serverid_)\
        {\
            if (_pid_ > 0) {\
                unsigned int sid = 0;\
                TRANSFORM_PLAYERID(_pid_, 1, sid);\
                if (sid == 0)\
                {\
                    TRANSFORM_PLAYERID_TO_64(_pid_, _serverid_, _pid_);\
                }\
            }\
        }

#define ATOLL(x) ((x) ? atoll(x) : 0)
#define _GET_U32(node, name) ATOLL(xmlGetValue(xmlGetChild(node, name, 0), "0"))

#define ATOLF(x) ((x) ? atof(x) : 0.f)
#define _GET_FLOAT(node, name) ATOLF(xmlGetValue(xmlGetChild(node, name, 0), "0"))

#pragma pack(pop)

#endif
