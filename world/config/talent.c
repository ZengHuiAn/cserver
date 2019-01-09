#include <stdlib.h>
#include <string.h>
#include "xmlHelper.h"
#include "logic_config.h"
#include "hero.h"
#include "map.h"
#include "array.h"
#include "package.h"
#include "talent.h"


#include "config_type.h"
#include "db_config/TABLE_config_talent.h"
#include "db_config/TABLE_config_talent.LOADER.h"

static struct map * talents_map = NULL;//保存所有的天赋信息

static int parse_talent(struct config_talent * row) 
{
	struct TalentSkillConfig * pCfg = LOGIC_CONFIG_ALLOC(TalentSkillConfig, 1);
	memset(pCfg, 0, sizeof(TalentSkillConfig));

	pCfg->id                = row->id;
	pCfg->group             = row->group;
	pCfg->talent_id         = row->weapon_id;
	pCfg->sub_group         = row->sub_group;
	pCfg->depend_id1        = row->depend_id1;
	pCfg->depend_id2        = row->depend_id2;
	pCfg->depend_id3        = row->depend_id3;
	pCfg->depend_point      = row->depend_point;
	pCfg->point_limit       = row->point_limit;
	pCfg->mutex_id1         = row->mutex_id1;
	pCfg->mutex_id2         = row->mutex_id2;

	pCfg->depend_level      = row->depend_level;

	pCfg->effect[0].type    = row->effect_type1; pCfg->effect[0].value   = row->init_value1; pCfg->effect[0].incr    = row->incr_value1;
	pCfg->effect[1].type    = row->effect_type2; pCfg->effect[1].value   = row->init_value2; pCfg->effect[1].incr    = row->incr_value2;
	pCfg->effect[2].type    = row->effect_type3; pCfg->effect[2].value   = row->init_value3; pCfg->effect[2].incr    = row->incr_value3;
	pCfg->effect[3].type    = row->effect_type4; pCfg->effect[3].value   = row->init_value4; pCfg->effect[3].incr    = row->incr_value4;

	pCfg->consume[0].type   = row->consume_type_1;
	pCfg->consume[0].id     = row->consume_id_1;
	pCfg->consume[0].value  = row->consume_value_1;
	pCfg->consume[0].incr   = row->consume_inc_1;
	pCfg->consume[0].payback= row->consume_payback_1;

	pCfg->consume[1].type   = row->consume_type_2;
	pCfg->consume[1].id     = row->consume_id_2;
	pCfg->consume[1].value  = row->consume_value_2;
	pCfg->consume[1].incr   = row->consume_inc_2;
	pCfg->consume[1].payback= row->consume_payback_2;

	struct array * arr = (struct array *)_agMap_ip_get(talents_map, pCfg->talent_id);
	if (arr == NULL) {
		arr = array_new(TALENT_MAXIMUM_DATA_SIZE);
		_agMap_ip_set(talents_map, pCfg->talent_id, arr);
	}

	if ((pCfg->id - 1) < 0 || (pCfg->id - 1) >= TALENT_MAXIMUM_DATA_SIZE) {
		WRITE_ERROR_LOG("parse talent config fail, config index %d error", pCfg->id);
		return -1;
	}

	array_set(arr, pCfg->id - 1, pCfg);

	return 0;
}

static int load_talent_skill_config()
{
	talents_map = LOGIC_CONFIG_NEW_MAP();
	return foreach_row_of_config_talent(parse_talent, 0);
}

struct TalentSkillConfig * get_talent_skill_config(int talentid, int index)
{
	struct array * arr = (struct array *)_agMap_ip_get(talents_map, talentid);
	if (arr == NULL)
	{
		return NULL;
	}
	if ((index - 1) < 0)
	{
		return NULL;
	}
	struct TalentSkillConfig * pCfg = (struct TalentSkillConfig *)array_get(arr, index - 1);
	return pCfg;
}


/*
int check_talent_real(int talentid)
{
	struct array * arr = (struct array *)_agMap_ip_get(talents_map, talentid);
	if (arr != NULL)
	{
		return 0;
	}

	return -1;
}

static struct map * skill_map = NULL;
static int parseSkillConfig(xml_node_t * node, void * data)
{
	if (node == NULL)
	{
		WRITE_ERROR_LOG("parseSkillConfig fail");
		return -1;
	}

	struct SkillConfig * pCfg = LOGIC_CONFIG_ALLOC(SkillConfig, 1);
	memset(pCfg, 0, sizeof(struct SkillConfig));

	pCfg->id                = _GET_U32(node, "id");
	pCfg->cast_cd           = _GET_U32(node, "cast_cd");
	pCfg->init_cd           = _GET_U32(node, "init_cd");
	pCfg->script            = _GET_U32(node, "script");
	pCfg->consume_type      = _GET_U32(node, "consume_type");
	pCfg->consume_value     = _GET_U32(node, "consume_value");
	pCfg->type1             = _GET_U32(node, "type1");
	pCfg->value1            = _GET_U32(node, "value1");
	pCfg->type2             = _GET_U32(node, "type2");
	pCfg->value2            = _GET_U32(node, "value2");
	pCfg->type3             = _GET_U32(node, "type3");
	pCfg->value3            = _GET_U32(node, "value3");
	pCfg->type4             = _GET_U32(node, "type4");
	pCfg->value4            = _GET_U32(node, "value4");
	pCfg->type5             = _GET_U32(node, "type5");
	pCfg->value5            = _GET_U32(node, "value5");
	pCfg->type6             = _GET_U32(node, "type6");
	pCfg->value6            = _GET_U32(node, "value6");

	_agMap_ip_set(skill_map, pCfg->id, pCfg);

	return 0;
}
*/

static int load_skill_config()
{
/*
	skill_map = LOGIC_CONFIG_NEW_MAP();

	xml_doc_t * doc = xmlOpen("../etc/config/hero/config_skill.xml");
	if (doc == NULL)
	{
		WRITE_ERROR_LOG("open config_skill.xml fail");
		return -1;
	}

	xml_node_t * root  = xmlDocGetRoot(doc);
	if (root == NULL)
	{
		WRITE_ERROR_LOG("config_skill.xml not found root node");
		return -1;
	}

	int ret = foreachChildNodeWithName(root, "Item", parseSkillConfig, 0);
	xmlClose(doc);
	return ret;
*/
	return 0;
}

int load_talent_config()
{
	if (load_talent_skill_config() != 0 ||
			load_skill_config() != 0)
	{
		return -1;
	}

	return 0;
}
