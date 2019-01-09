#ifndef SGK_OPENLEV_H
#define SGK_OPENLEV_H

#include "config_type.h"

#define ROLE_TITLE 1102			// 角色称号
#define ROLE_STAR_UP 1103		// 角色升星
#define ROLE_LEVEL_UP 1104		// 角色升级

#define ROLE_STAGE_UP 1106		// 角色进阶
#define ROLE_STAR_UP2 1107		// 盗能

#define ROLE_EQUIP_LEVEL_UP 1121	// 装备强化
#define ROLE_EQUIP_STAGE_UP 1122	// 装备进阶


#define ROLE_EQUIP_INDEX 1124		// 装备位置1

#define ROLE_EQUIP_LEVEL_UP2 1141	// 铭文强化

#define ROLE_EQUIP_INDEX2 1143		// 铭文位置1

#define ROLE_EQUIP_GROUP 1180		// 第一套装备
#define ROLE_EQUIP_GROUP2 1190		// 第一套铭文

#define ROLE_ONLINE 1702		// 上阵位置2

#define ROLE_ASSIST_INDEX 1706		// 援助位置1

typedef struct OpenLevCofig
{
	int id;
	int open_lev;

	struct {
		int type;
		int id;
		int count;
	} condition;
} OpenLevCofig;

OpenLevCofig * get_openlev_config(int id);

int load_openlev_config();

#endif // SGK_OPENLEV_H
