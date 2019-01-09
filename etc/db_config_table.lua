
--部分字段需要取别名
local alias = {
        [1] = {alias = "UNIX_TIMESTAMP(act_time) as act_time", real = "act_time"},
        [2] = {alias = "UNIX_TIMESTAMP(end_time) as end_time", real = "end_time"},
};

local alias2 = {
        [1] = {alias = "UNIX_TIMESTAMP(begin_time) as begin_time", real = "begin_time"},
        [2] = {alias = "UNIX_TIMESTAMP(end_time) as end_time", real = "end_time"},
}

local db_table = {
    {{"config_battle_config"},                     nil,        "config/fight/",     {"desc", "sound"                                    }},
    {{"config_chapter_config"},                    nil,        "config/fight/",     {"name", "background"                               }},
    {{"config_common"},                            nil,        "config/hero/",      {"desc"                                             }},
    {{"config_common_consume"},			   nil,	       "config/hero/",	    {							}},
    {{"config_config"},                            nil,        "config/hero/",      {"info"                                             }},
    {{"config_item"},                              nil,        "config/item/",      {"info"                                     }},		--"name", "info"                                     }},
    {{"item_generate"},                            nil,        "config/item/",      {                                                   }},
    {{"config_level_up"},                          nil,        "config/hero/",      {                                                   }},
    {{"config_npc"},                               nil,        "config/fight/",     {                                                   }},
    {{"config_all_npc"},                           nil,        "config/fight/",     {                                                   }},
    {{"config_all_activity"},                      nil,        "config/fight/",     {"activity_time", "desc", "desc2"                   }},
    {{"config_npc_property_config"},               nil,        "config/fight/",     {                                                   }},
    {{"config_pve_fight_config"
		 ,"config_team_pve_fight_config"
		 ,"config_manor_fight_config"},            nil,        "config/fight/",     {"scene_name", "music", "boss_music"       }},
    {{"config_pve_fight_recommend"},               nil,        "config/fight/",     {"scene_name", "music", "boss_music"                }},
    {{"config_role"},                              nil,        "config/hero/",      {"name", "icon"                                     }},
	{{"config_role_property_extension"},           nil,        "config/hero/",      {                                                   }},
    {{"config_star_up"},                           nil,        "config/hero/",      {                                                   }},
    {{"config_wave_config", 
         "config_team_wave_config", 
         "config_manor_wave_config",        },     nil,        "config/fight/",     {                                                   }},
    {{"config_weapon"},                            nil,        "config/hero/",      {"name", "icon"                                     }},
    {{"config_one_time_reward"},                   nil,        "config/fight/",     {"name", "icon"                                     }},
    {{"config_pet"},                               nil,        "config/hero/",      {                                                   }},
    {{"config_parameter"},                         nil,        "config/hero/",      {"name", "showType", "desc", "PropertyFormula"      }},
    {{"config_skill"},                             nil,        "config/hero/",      {                                                   }},
    {{"config_skill_music"},                       nil,        "config/hero/",      {                                                   }},

    {{"config_weapon_evo", "config_role_evo"},     nil,        "config/hero/",      {"desc"                                             }},
    {{"config_weapon_lev", "config_role_lev"},     nil,        "config/hero/",      {                                                   }},
    {{"config_talent",
         "config_skill_tree",
         "config_roletitle",   },                  nil,        "config/hero/",      {"name", "desc"                                     }},
    {{"config_role_star", "config_weapon_star"},   nil,        "config/hero/",      {"name", "desc"                                     }},
    {{"star_promote",                         },   nil,        "config/hero/",      {                                                   }},
    {{"config_role_stage_up"},			   nil,	       "config/hero/",	    nil							},
    {{"config_fight_reward"},                      alias,      "config/fight/",     {                                                   }},
    {{"config_battle_buff"},                       alias,      "config/fight/",     {                                                   }},
    {{"drop_with_item"},                           alias,      "config/fight/",     {                                                   }},
    {{"config_ability_pool1"},                     nil,        "config/equip/",     {                                                   }},
    {{"config_equipment1", "config_inscription1"}, nil,        "config/equip/",     {"name", "info", "icon"                             }},
    {{"config_equipment_with_level"},              nil,        "config/equip/",                                                          },
    {{"equipment_with_affix"},                     nil,        "config/equip/",                                                          },
    {{"config_equipment_lev1"},                    nil,        "config/equip/",     {                                                   }},
    {{"config_scroll"},                            nil,        "config/equip/",     {                                                   }},
    {{"config_suit"},                              nil,        "config/equip/",     {"desc"                                             }},
    {{"born_item"},                                nil,        "config/player/",    {                                                   }},

    {{"config_team_battle_config"},                alias2,     "config/team/",      {                                                   }},
    {{"config_team_pve_fight_config"},             nil,        "config/team/",      {                                                   }},
    {{"config_team_wave_config"},                  nil,        "config/team/",      {                                                   }},

	{{"team_fight_score"},                         nil,        "config/team/",      {													}},
    {{"config_manor_fight_config"},                nil,        "config/manor/",     {"scene_name", "music", "boss_music"                }},
    {{"config_manor_fight_add"},                   nil,        "config/manor/",     {"name"                                             }},
    {{"config_manor_property_lv"},		nil,		"config/manor/", nil},
	{{"config_manor_accelerate_consum"},           nil,        "config/manor/",     {"name"                                             }},	
	{{"config_work_type"},                         nil,        "config/manor/",     {"name"                                             }},
	{{"public_quests"},			nil,	"config/quest/",	nil},
	{{"config_phase_reward"},		nil,	"config/quest/",	nil},
	{{"rank_boss"},				nil,	"config/quest/",	nil},

	--军团
    {{"config_team_donate"},                       nil,        "config/guild/",     {"Name", "BulidExpName"                             }},
    {{"config_team_summary"},                      nil,        "config/guild/",     {                                                   }},
    {{"config_team_number"},                       nil,        "config/guild/",     {"SalaryTime2"                                      }},
    {{"config_team_award"},                        nil,        "config/guild/",     {                                                   }},
    {{"config_team_permission"},                   nil,        "config/guild/",     {                                                   }},
    {{"config_guild_building_level"},              nil,        "config/guild/",     {                                                   }},
    {{"config_team_accident"},                     nil,        "config/guild/",     {                                                   }},
    {{"guild_boss"},                               nil,        "config/guild/",     {                                                   }},
    {{"config_guild_boss_reward"},                 nil,        "config/guild/",     {                                                   }},
    {{"config_guild_quest"},                       nil,        "config/guild/",     {                                                   }},
    {{"config_guild_quest_stepreward"},            nil,        "config/guild/",     {                                                   }},
    {{"config_shared_quest"},                      nil,        "config/guild/",     {                                                   }},
    {{"shared_quest_pool"},                 nil,        "config/guild/",     {                                                   }},
    {{"config_exploremap_message"},		nil,	"config/guild/",	nil},
    {{"config_guild_activity"},			nil,	"config/guild/",	nil},
    {{"config_guild_item"},			               nil,	       "config/guild/",	nil},

    -- 任务
    {{"config_quest"},                             nil,        "config/quest/",     {"name", "desc"                                     }},
    {{"config_advance_quest",
	"config_per_achievement"},                     nil,        "config/quest/",     {"name", "desc1", "desc2"                           }},
    {{"quest_pool"},                               nil,        "config/quest/",     {"name", "desc"                                     }},
    {{"config_7day_delay"},                        nil,        "config/quest/",     {                                                   }},
    {{"quest_rule"},                               nil,        "config/quest/",     {                                                   }},
    {{"quest_event_permission"},                   nil,        "config/quest/",     {                                                   }},
    {{"config_quest_menu"},                        nil,        "config/quest/",     {                                                   }},
	

    -- 建设城市
    {{"activity_build_city"},                      nil,        "config/manor/",     {"name", "desc"                                     }},
    {{"config_activity_buildcity"},                nil,        "config/manor/",     {"name", "desc"                                     }},
    
    {{"config_manor_task"},                        nil,        "config/manor/",     {"name"                                             }},
    {{"config_manor_task_item"},                   nil,        "config/manor/",     {"name"                                             }},
    {{"config_manor_task_equation"},		nil,		"config/manor/",	nil},
    {{"config_manor_task_starbox"},		nil,		"config/manor/",        nil},

    -- 悬赏
    {{"config_bounty_quest"},                      nil,        "config/bounty/",    {"name", "desc"                                     }},
    {{"bounty_fight"},                             nil,        "config/bounty/",    {                                                   }},
    {{"bounty_reward"},                            nil,        "config/bounty/",    {                                                   }},

	{{"config_Arena_reward"},                      nil,        "config/arena/",     nil},
	{{"config_arena_buff_type"},                   nil,        "config/arena/",     nil},
	{{"config_arena_rank"},                        nil,        "config/arena/",     nil},
	{{"config_random_arena_ai"},		       nil,	   "config/arena/",     nil},
	{{"config_rank_jjc"},		       			   nil,	       "config/arena/",     nil},

	{{"config_meiridati"},                         nil,        "config/quiz/",     nil},
	{{"config_reward_meiridati"},                  nil,        "config/quiz/",     nil},
	{{"config_reward_zhoudati"},                  nil,        "config/quiz/",     nil},
	{{"config_dailyanswer"},		   nil,	       "config/quiz/",	    nil},
	{{"config_dailyanswer_reward"},	    	   nil,	       "config/quiz/",	    nil},
	{{"ainame_zhoudati"},			   nil,	       "config/quiz/",	    nil},
	{{"config_datijingsai"},                         nil,        "config/quiz/",     nil},

    {{"config_hessboard"},            	           nil,        "config/fight/",     {"name"}},
    {{"config_hessboard_exchange"},                nil,        "config/fight/",     {"name"}},
    {{"config_hessboard_pitfall"},                 nil,        "config/fight/",     {"name"}},
    {{"config_hessboard_monster"},                 nil,        "config/fight/",     {"name"}},
    {{"config_diversion"},                         nil,        "config/fight/",     {"name"}},
    {{"config_hessboard_time"},                    nil,        "config/fight/",     {"name"}},
    {{"config_hessboard_resoure"},                 nil,        "config/fight/",     {"name"}},
    {{"config_hessboard_package"},                 nil,        "config/fight/",     {"name"}},
    {{"config_hessboard_buff"},                    nil,        "config/fight/",     {"name"}},
    {{"config_monster_condition"},                 nil,        "config/fight/",     {"name"}},
	
    {{"config_friend_gift"},                 	   nil,        "config/chat/",     nil},
    {{"config_arguments"},			   alias2,        "config/chat/",	   nil},
    {{"config_arguments_reward"},		   nil,	       "config/chat",      nil},

	-- 商店
    {{"config_shop_fresh"},                        nil,        "config/shop/",      },
    {{"config_guild_shop_limit"},                  nil,        "config/shop/",      },
	{{"config_product_price"},                     nil,        "config/shop/",      },

	-- 主角技能
	{{"config_chief"},                             nil,        "config/hero/",      },
    -- 功能开启
    {{"config_openlev"},			   nil,	       "config/item/", {"effect"}},

	-- 头衔
    {{"config_honor_condition"},			   nil,	       "config/title/", {"name"}},

	--consume
    {{"config_trading_firm"},			           nil,	       "config/consume/", nil},
    {{"config_trading_transform"},			       nil,	       "config/consume/", nil},
	{{"config_arena_property"}, 		 	nil,		"config/arena/", nil},

	-- 钓鱼活动配置
    {{"config_fish"}, 				   nil,		"config/fish/", nil},
    {{"config_fish_consume"},			   nil,		"config/fish/", nil},
    {{"config_fish_reward"},			   nil,		"config/fish/", nil},

	-- AI
	{{"config_random_position"},                    nil,            "config/ai/", nil},
	{{"config_all_position"},                       nil,            "config/ai/", nil},
	{{"config_all_map"},                            nil,            "config/ai/", nil},
	{{"config_AI_extraEXP"},                        nil,            "config/ai/", nil},
	{{"config_AI_tasksimulation"},                  nil,            "config/ai/", nil},
	{{"config_AI_levellimit"},                      nil,            "config/ai/", nil},
	{{"config_AI_image"},                           nil,            "config/ai/", nil},

    --全局buff
    {{"config_buff"},                                   nil,                "config/buff/", nil},
    {{"config_delay_exp"},				nil,		    "config/item/", nil},

    -- 玩家common数据
    {{"config_common_data_cost"},			nil,		     "config/quiz/" ,nil},	
    --  {{"config_product"}, 				nil,		     "config/shop",  nil    },
    --{{"product"},					nil,		     "config/shop", nil	},
    -- 后宫数据
    --[[
    {{"config_unlock"},					nil,		      "config/quiz", nil},
    {{"config_furniture"},				nil,		      "config/quiz", nil},
    {{"config_furniture_suit"},				nil,			"config/quiz", nil},
    {{"config_goodfeel"},                         	nil,                    "config/quiz", nil},--]]
    --{{"config_harem"},                         		nil,                    "config/quiz", nil}
    -- 时装
    {{"config_fashion"},				nil,		    "config/item/", nil},
    {{"random_event"},					alias2,		    "config/manor/", nil},

    {{"consume_package"},				nil,		    "config/item/", nil},
    -- npc好感度
    {{"config_arguments_npc"},				nil,			"config/item/", {"qinmi_name", "xunlu_npc_id", "desc"}},

    {{"config_add_exp_by_item"},    	nil,		    "config/hero/", nil},
    {{"config_rank_reward"},        	nil,		    "config/rank/", nil},

    {{"config_manor_manufacture_pool"},	nil,		    "config/manor/",nil},
    {{"config_trading_ai"},             nil,                "config/consume",nil},
    {{"beltline_quest_pool"},	    nil,		    "config/manor/",nil},
    {{"config_manor_event"},	    nil,		    "config/manor/",nil},
    {{"config_manor_life1"},	    nil,		    "config/manor/",nil},

    {{"config_team_activity"},               nil,        "config/fight/",     nil},
    {{"config_team_activity_npc"},           nil,        "config/fight/",     nil},
    {{"config_team_activity_tables"},        nil,        "config/fight/",     nil},
    {{"config_team_activity_mine"},        nil,        "config/fight/",     nil},

    {{"config_rank_rewards"},	nil,		"config/quiz/",		   nil},
    {{"config_rank_rewards_content"}, nil,            "config/quiz/",            nil},

	{{"config_AI_role_battle"}, nil, "config/fight", nil}

}

return db_table;
