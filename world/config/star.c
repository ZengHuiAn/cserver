#include <stdlib.h>
#include <string.h>

#include "xmlHelper.h"
#include "logic_config.h"
#include "star.h"
#include "map.h"

#define ATOLL(x) ((x) ? atoll(x) : 0)
#define _GET_U32(node, name) ATOLL(xmlGetValue(xmlGetChild(node, name, 0), "0"))

/* relationship */
static struct map * star_reward_map = 0;
static int parseStarRewardConfig(xml_node_t * node, void * data){
	// check gid
	unsigned int battle_id =_GET_U32(node, "battle_id");
	if (battle_id == 0){
		WRITE_ERROR_LOG("battle_id is 0");
		return -1;
	}

	// prepare
	PSTAR_REWARD_CONFIG cfg =LOGIC_CONFIG_ALLOC(tagSTAR_REWARD_CONFIG, 1);
	memset(cfg, 0, sizeof(STAR_REWARD_CONFIG));
	char szTmp[32] ={0};

	// set
	cfg->battle_id = battle_id;
	int i=0;
	for(i=0; i<YQ_BATTLE_REWARD_COUNT*YQ_BATTLE_REWARD_ITEM_COUNT; ++i){
		sprintf(szTmp, "reward_item%d_type", i);
		cfg->reward_item[i].type =_GET_U32(node, szTmp);
		sprintf(szTmp, "reward_item%d_id", i);
		cfg->reward_item[i].id =_GET_U32(node, szTmp);
		sprintf(szTmp, "reward_item%d_value", i);
		cfg->reward_item[i].value =_GET_U32(node, szTmp);
	}

	// save to map
	void * p = _agMap_ip_set(star_reward_map, cfg->battle_id, cfg);
	if(p != 0){
		WRITE_ERROR_LOG("star reward with same battle_id %u", battle_id);
		return -1;
	}
	return 0;
}
int load_star_reward_config(){
	// prepare
	star_reward_map = LOGIC_CONFIG_NEW_MAP();

	// load
	xml_doc_t * doc =xmlOpen("../etc/config/story/star_reward.xml");
	if (doc == 0) {
		WRITE_ERROR_LOG("star_reward.xml not found.");
		return -1;
	}
	xml_node_t * root = xmlDocGetRoot(doc);
	int ret = foreachChildNodeWithName(root, "Item", parseStarRewardConfig, 0);
	xmlClose(doc);
	return ret;
}
PSTAR_REWARD_CONFIG get_star_reward_config_by_battle_id(uint32_t battle_id){
	// check
	if(battle_id == 0){
		return 0;
	}

	// get
	return (PSTAR_REWARD_CONFIG)_agMap_ip_get(star_reward_map, battle_id);
}

