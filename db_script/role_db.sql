set names utf8;


DROP DATABASE IF EXISTS `SGK_Game_<serverid>`;
CREATE DATABASE IF NOT EXISTS `SGK_Game_<serverid>` default charset utf8 COLLATE utf8_general_ci;

use SGK_Game_<serverid>;

create function from_unixtime_s(t int(11)) returns timestamp  return if (t <= 0, 0,  from_unixtime(t) );

DROP TABLE IF EXISTS `GuildExploreConfig`;
CREATE TABLE `GuildExploreConfig` (
  `mapid` int(10) NOT NULL,
  `map_property` int(10) NOT NULL,
  `explore_count` int(10) NOT NULL,
  `product_type` int(10) NOT NULL,
  `product_id` int(10) NOT NULL,
  `product_value` int(10) NOT NULL,
  `prob` int(10) NOT NULL,
  `worth` int(10) NOT NULL,
  `time_min` int(10) NOT NULL,
  `time_max` int(10) NOT NULL,
  PRIMARY KEY (`mapid`,`map_property`,`explore_count`,`product_type`,`product_id`,`product_value`,`prob`,`worth`,`time_min`,`time_max`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `GuildExploreMap`;
CREATE TABLE `GuildExploreMap` (
  `gid` int(11) NOT NULL,
  `mapid` int(11) NOT NULL,
  `progress` int(11) NOT NULL,
  `reward_flag` int(11) NOT NULL,
  `begin_time` datetime NOT NULL,
  `end_time` datetime NOT NULL,
  PRIMARY KEY (`gid`,`mapid`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `GuildExploreTeam`;
CREATE TABLE `GuildExploreTeam` (
  `gid` int(10) NOT NULL,
  `mapid` int(10) NOT NULL,
  `pid` bigint(20) NOT NULL,
  `order` int(10) NOT NULL,
  `speed` int(10) NOT NULL,
  `start_time` datetime NOT NULL,
  `next_reward_time` datetime NOT NULL,
  `reward_depot` varchar(1000) DEFAULT NULL,
  `formation_role1` int(10) NOT NULL,
  `formation_role2` int(10) NOT NULL,
  `formation_role3` int(10) NOT NULL,
  `formation_role4` int(10) NOT NULL,
  `formation_role5` int(10) NOT NULL,
  `explore_count` int(10) NOT NULL,
  `index` int(10) NOT NULL,
  PRIMARY KEY (`gid`,`mapid`,`pid`,`order`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `NotifyMessage`;
CREATE TABLE `NotifyMessage` (
  `id` int(32) NOT NULL AUTO_INCREMENT,
  `time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `to` bigint(20) NOT NULL,
  `type` int(32) NOT NULL DEFAULT '0',
  `cmd` int(32) NOT NULL DEFAULT '0',
  `data` text NOT NULL,
  PRIMARY KEY (`id`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `RECORD`;
CREATE TABLE `RECORD` (
  `K` varchar(100) NOT NULL,
  `V` int(10) unsigned DEFAULT NULL,
  PRIMARY KEY (`K`),
  KEY `K` (`K`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `TIMING_NOTIFY`;
CREATE TABLE `TIMING_NOTIFY` (
  `ID` int(32) NOT NULL AUTO_INCREMENT,
  `START` int(32) NOT NULL,
  `LAST_TIME` int(32) NOT NULL,
  `DURATION` int(32) NOT NULL,
  `INTERVAL` int(32) NOT NULL,
  `TYPE` int(32) NOT NULL,
  `MSG` text NOT NULL,
  `EXPIRE` int(32) NOT NULL DEFAULT '0',
  `GM_ID` int(32) NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `adult_player`;
CREATE TABLE `adult_player` (
  `pid` bigint(20) NOT NULL
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `arena_fight_record`;
CREATE TABLE `arena_fight_record` (
  `pid` bigint(20) unsigned NOT NULL,
  `enemy_id` bigint(20) unsigned NOT NULL,
  `has_win` int(10) unsigned NOT NULL,
  `fight_count` int(10) unsigned NOT NULL,
  `last_fight_time` datetime NOT NULL,
  `buff_increase_percent` int(10) unsigned DEFAULT NULL,
  `fight_data` text NOT NULL,
  `reward_id` int(10) NOT NULL,	
  PRIMARY KEY (`pid`,`enemy_id`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `arena_player_pool`;
CREATE TABLE `arena_player_pool` (
  `pid` bigint(20) unsigned NOT NULL,
  `enemy_power_history` varchar(255) DEFAULT '',
  `win_count` int(10) unsigned NOT NULL,
  `last_win_time` datetime NOT NULL,
  `fight_total_count` int(10) unsigned NOT NULL,
  `last_fight_time` datetime NOT NULL,
  `last_reset_time` datetime NOT NULL,
  `reward_flag` int(10) unsigned NOT NULL,
  `buff` varchar(255) DEFAULT '',
  `inspire_count` int(10) unsigned NOT NULL,
  `fight_data` text NOT NULL,
  `const_win_count` int(10) NOT NULL,
  PRIMARY KEY (`pid`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `buy_history`;
CREATE TABLE `buy_history` (
  `pid` bigint(20) unsigned NOT NULL DEFAULT '0',
  `today_buy_count` int(10) unsigned DEFAULT '0',
  `buy_count` int(10) unsigned DEFAULT '0',
  `shop_type` int(10) unsigned NOT NULL DEFAULT '0',
  `last_buy_time` int(10) unsigned DEFAULT '0',
  `today_fresh_count` int(10) unsigned DEFAULT '0',
  `last_fresh_time` int(10) unsigned DEFAULT '0',
  PRIMARY KEY (`pid`,`shop_type`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `chat_history`;
CREATE TABLE `chat_history` (
  `uuid` bigint(20) NOT NULL AUTO_INCREMENT,
  `id` int(11) DEFAULT '0',
  `from_player_id` bigint(20) unsigned NOT NULL,
  `from_player_name` varchar(256) NOT NULL,
  `rid` int(11) NOT NULL,
  `message` varchar(256) NOT NULL,
  `t` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`uuid`),
  KEY `id` (`id`),
  KEY `t` (`t`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `contact`;
CREATE TABLE `contact` (
  `pid` bigint(20) unsigned NOT NULL,
  `cid` bigint(20) NOT NULL,
  `type` int(32) NOT NULL DEFAULT '0',
  `rtype` int(32) NOT NULL DEFAULT '0',
  PRIMARY KEY (`pid`,`cid`),
  KEY `pid` (`pid`),
  KEY `cid` (`cid`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `gift_bag`;
CREATE TABLE `gift_bag` (
  `gid` int(11) DEFAULT '0',
  `is_consume` int(11) DEFAULT '0',
  `item_type` int(11) DEFAULT '0',
  `lucky_count` int(11) DEFAULT '0',
  `item_id` int(11) DEFAULT '0',
  `item_value` int(11) DEFAULT '0',
  `drop_id` int(11) NOT NULL DEFAULT '0',
  `group` int(11) DEFAULT NULL,
  `weight` int(11) DEFAULT '0',
  `need_broadcast` int(11) DEFAULT '0',
  `item_name` varchar(256) DEFAULT '',
  `begin_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `end_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  KEY `gid` (`gid`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `guild`;
CREATE TABLE `guild` (
  `gid` int(32) NOT NULL AUTO_INCREMENT,
  `name` char(64) NOT NULL,
  `camp` int(32) NOT NULL default 0,
  `exp` int(32) NOT NULL DEFAULT '0',
  `today_add_exp` int(32) NOT NULL DEFAULT '0',
  `add_exp_time` int(32) NOT NULL DEFAULT '0',
  `member_buy_count` int(32) NOT NULL DEFAULT '0',
  `founder` bigint(20) unsigned NOT NULL,
  `leader` bigint(20) unsigned NOT NULL,
  `dissolve` tinyint(6) NOT NULL DEFAULT '0',
  `notice` char(255) NOT NULL DEFAULT '',
  `desc` char(255) NOT NULL DEFAULT '',
  `createat` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `boss` timestamp NOT NULL DEFAULT '2012-03-06 07:00:00',
  `auto_confirm` int(32) NOT NULL DEFAULT '0',
  `wealth` int(32) NOT NULL DEFAULT '0',
  `today_add_wealth` int(32) NOT NULL DEFAULT '0',
  `add_wealth_time` int(32) NOT NULL DEFAULT '0', 
  `highest_wealth` int(32) NOT NULL DEFAULT '0',
  KEY (`gid`),
  UNIQUE KEY `name` (`name`),
  KEY `name_2` (`name`)
) DEFAULT CHARSET=utf8;
INSERT INTO guild(`gid`, `name`, `exp`, `founder`, `leader`, `dissolve`, `notice`, `desc`, `createat`, `boss`)VALUES(10000000, 'first', 0, 0, 0, 0, '', '', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

DROP TABLE IF EXISTS `guild_donate_record`;
CREATE TABLE `guild_donate_record` (
  `pid` bigint(20) unsigned NOT NULL,
  `donate_type` int(11) DEFAULT '0',
  `donate_time` int(11) DEFAULT '0',
  KEY `pid` (`pid`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `guild_exp_log`;
CREATE TABLE `guild_exp_log` (
  `id` tinyint(32) NOT NULL,
  `gid` int(32) NOT NULL,
  `time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `exp` int(32) NOT NULL DEFAULT '0',
  `pid` bigint(20) unsigned NOT NULL,
  `reason` int(32) NOT NULL DEFAULT '0',
  PRIMARY KEY (`gid`,`id`),
  KEY `gid` (`gid`)
) DEFAULT CHARSET=utf8;


DROP TABLE IF EXISTS `guildmember`;
CREATE TABLE `guildmember` (
  `gid` int(32) NOT NULL,
  `pid` bigint(20) unsigned NOT NULL,
  `title` int(32) NOT NULL DEFAULT '0',
  `joinat` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `total_cont` int(32) NOT NULL DEFAULT '0',
  `today_cont` int(32) NOT NULL DEFAULT '0',
  `cont_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `consumed_cont` int(32) NOT NULL DEFAULT '0',
  `roulette_play_times` int(32) NOT NULL DEFAULT '0',
  `roulette_create_date` int(32) NOT NULL DEFAULT '0',
  `reward_flag` int(32) NOT NULL,
  `last_draw_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `today_donate_count` int(32) NOT NULL,
  `donate_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (`gid`,`pid`),
  KEY `gid` (`gid`),
  KEY `pid` (`pid`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `guildrequest`;
CREATE TABLE `guildrequest` (
  `gid` int(32) NOT NULL,
  `rid` bigint(20) unsigned NOT NULL,
  `at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`gid`,`rid`),
  KEY `gid` (`gid`),
  KEY `rid` (`rid`)
) DEFAULT CHARSET=utf8;


DROP TABLE IF EXISTS `lucky_draw`;
CREATE TABLE `lucky_draw` (
  `gid` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `pool_type` tinyint(4) DEFAULT '0',
  `sub_type` tinyint(4) DEFAULT '0',
  `vip_min` int(10) unsigned DEFAULT '0',
  `vip_max` int(10) unsigned DEFAULT '10000',
  `player_lv_min` int(10) unsigned DEFAULT '0',
  `player_lv_max` int(10) unsigned DEFAULT '10000',
  `reward_item_type` int(10) unsigned DEFAULT '0',
  `reward_item_id` int(10) unsigned DEFAULT '0',
  `reward_item_value` int(10) unsigned DEFAULT '0',
  `weight` int(10) unsigned DEFAULT '0',
  `reward_item_name` varchar(256) DEFAULT 'normal',
  `reward_item_quality` int(10) unsigned DEFAULT '0',
  `begin_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `end_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (`gid`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `mail`;
CREATE TABLE `mail` (
  `mid` int(32) NOT NULL AUTO_INCREMENT,
  `type` int(32) NOT NULL DEFAULT '0',
  `from` bigint(20) unsigned NOT NULL,
  `to` bigint(20) unsigned NOT NULL,
  `title` char(64) NOT NULL DEFAULT '',
  `content` text NOT NULL,
  `appendix_opened` int(32) NOT NULL DEFAULT '0',
  `appendix` text NOT NULL,
  `flag` int(32) NOT NULL DEFAULT '0',
  `at` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (`mid`),
  KEY `from` (`from`),
  KEY `to` (`to`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `manor_manufacture_player_line`;
CREATE TABLE `manor_manufacture_player_line` (
  `pid` bigint(20) unsigned NOT NULL,
  `line` int(10) unsigned NOT NULL,
  `speed` int(11) NOT NULL DEFAULT '0',
  `next_gather_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `event_happen_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `next_gather_gid` int(11) NOT NULL DEFAULT '0',
  `current_order_begin_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `current_order_last_time` int(10) NOT NULL,
  `current_order_produce_rate` int(10) NOT NULL,
  `workman1_speed` int(10) NOT NULL,
  `workman2_speed` int(10) NOT NULL,
  `workman3_speed` int(10) NOT NULL,
  `workman4_speed` int(10) NOT NULL,
  `workman5_speed` int(10) NOT NULL,
  `workman1_produce_rate` int(10) NOT NULL,
  `workman2_produce_rate` int(10) NOT NULL,
  `workman3_produce_rate` int(10) NOT NULL,
  `workman4_produce_rate` int(10) NOT NULL,
  `workman5_produce_rate` int(10) NOT NULL,
  `storage1` int(10) NOT NULL,
  `storage2` int(10) NOT NULL,
  `storage3` int(10) NOT NULL,
  `storage4` int(10) NOT NULL,
  `storage5` int(10) NOT NULL,
  `storage6` int(10) NOT NULL,
  `storage_pool` int(10) NOT NULL,
  `order_limit` int(10) NOT NULL,
  PRIMARY KEY (`pid`,`line`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `manor_manufacture_player_line_level`;
CREATE TABLE `manor_manufacture_player_line_level` (
  `pid` bigint(20) unsigned NOT NULL,
  `line` int(10) unsigned NOT NULL,
  `level` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`pid`,`line`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `manor_manufacture_player_order`;
CREATE TABLE `manor_manufacture_player_order` (
  `pid` bigint(20) unsigned NOT NULL,
  `line` int(10) unsigned NOT NULL,
  `gid` int(10) unsigned NOT NULL,
  `left_count` int(10) unsigned NOT NULL,
  `gather_count` int(10) unsigned NOT NULL,
  `gather_product_item1_value` int(10) NOT NULL,
  `gather_product_item2_value` int(10) NOT NULL,
  `gather_product_item3_value` int(10) NOT NULL,
  `gather_product_item4_value` int(10) NOT NULL,
  `gather_product_item5_value` int(10) NOT NULL,
  `gather_product_item6_value` int(10) NOT NULL,
  `stolen_value1` int(10) NOT NULL,
  `stolen_value2` int(10) NOT NULL,
  `stolen_value3` int(10) NOT NULL,
  `stolen_value4` int(10) NOT NULL,
  `stolen_value5` int(10) NOT NULL,
  `stolen_value6` int(10) NOT NULL,
  PRIMARY KEY (`pid`,`line`,`gid`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `manor_manufacture_player_qualified_workman`;
CREATE TABLE `manor_manufacture_player_qualified_workman` (
  `pid` bigint(20) NOT NULL,
  `workman_id` int(10) NOT NULL,
  `property_id` int(10) NOT NULL,
  `property_value` int(10) DEFAULT NULL,
  PRIMARY KEY (`pid`,`workman_id`,`property_id`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `manor_manufacture_player_workman`;
CREATE TABLE `manor_manufacture_player_workman` (
  `pid` bigint(20) unsigned NOT NULL,
  `line` int(10) unsigned NOT NULL,
  `workman1` bigint(20) NOT NULL DEFAULT '0',
  `workman2` bigint(20) NOT NULL DEFAULT '0',
  `workman3` bigint(20) NOT NULL DEFAULT '0',
  `workman4` bigint(20) NOT NULL DEFAULT '0',
  `workman5` bigint(20) NOT NULL DEFAULT '0',
  `workman1_gid` int(10) NOT NULL DEFAULT '0',
  `workman2_gid` int(10) NOT NULL DEFAULT '0',
  `workman3_gid` int(10) NOT NULL DEFAULT '0',
  `workman4_gid` int(10) NOT NULL DEFAULT '0',
  `workman5_gid` int(10) NOT NULL DEFAULT '0',
  PRIMARY KEY (`pid`,`line`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `manor_workman_power`;
CREATE TABLE `manor_workman_power` (
  `pid` bigint(20) NOT NULL,
  `workman_id` bigint(20) NOT NULL,
  `now_power` int(10) NOT NULL,
  `power_upper_limit` int(10) NOT NULL,
  `is_busy` int(10) NOT NULL,
  `last_power_change_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `busy_time` int(10) NOT NULL,
  `free_time` int(10) NOT NULL,
  PRIMARY KEY (`pid`,`workman_id`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `manor_manufacture_product`;
CREATE TABLE `manor_manufacture_product` (
  `gid` bigint(20) unsigned NOT NULL,
  `line` int(11) NOT NULL DEFAULT '0',
  `type` int(11) DEFAULT NULL,
  `time_min` int(10) unsigned NOT NULL,
  `time_max` int(10) unsigned NOT NULL,
  `one_time_count_min` int(11) NOT NULL DEFAULT '1',
  `one_time_count_max` int(11) NOT NULL DEFAULT '1',
  `depend_item` int(11) NOT NULL DEFAULT '0',
  `consume_item1_type` int(10) unsigned NOT NULL DEFAULT '0',
  `consume_item1_id` int(10) unsigned NOT NULL DEFAULT '0',
  `consume_item1_value` int(10) unsigned NOT NULL DEFAULT '0',
  `product_item1_type` int(10) unsigned NOT NULL DEFAULT '0',
  `product_item1_id` int(10) unsigned NOT NULL DEFAULT '0',
  `product_item1_value` int(10) unsigned NOT NULL DEFAULT '0',
  `consume_item2_type` int(10) unsigned NOT NULL DEFAULT '0',
  `consume_item2_id` int(10) unsigned NOT NULL DEFAULT '0',
  `consume_item2_value` int(10) unsigned NOT NULL DEFAULT '0',
  `consume_item3_type` int(10) unsigned NOT NULL DEFAULT '0',
  `consume_item3_id` int(10) unsigned NOT NULL DEFAULT '0',
  `consume_item3_value` int(10) unsigned NOT NULL DEFAULT '0',
  `consume_item4_type` int(10) unsigned NOT NULL DEFAULT '0',
  `consume_item4_id` int(10) unsigned NOT NULL DEFAULT '0',
  `consume_item4_value` int(10) unsigned NOT NULL DEFAULT '0',
  `product_item2_type` int(10) unsigned NOT NULL DEFAULT '0',
  `product_item2_id` int(10) unsigned NOT NULL DEFAULT '0',
  `product_item2_value` int(10) unsigned NOT NULL DEFAULT '0',
  `product_item3_type` int(10) unsigned NOT NULL DEFAULT '0',
  `product_item3_id` int(10) unsigned NOT NULL DEFAULT '0',
  `product_item3_value` int(10) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`gid`)
) DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `open_gift_bag_history`;
CREATE TABLE `open_gift_bag_history` (
  `pid` bigint(20) unsigned NOT NULL DEFAULT '0',
  `gid` int(10) unsigned NOT NULL DEFAULT '0',
  `count` int(10) unsigned DEFAULT '0',
  `today_count` int(10) unsigned DEFAULT '0',
  `today_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (`pid`,`gid`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `player_shop`;
CREATE TABLE `player_shop` (
  `pid` bigint(20) unsigned NOT NULL DEFAULT '0',
  `shop_type` int(10) unsigned NOT NULL DEFAULT '0',
  `fresh_period` int(10) unsigned NOT NULL DEFAULT '0',
  `product_id` int(10) unsigned NOT NULL DEFAULT '0',
  `buy_count` int(10) unsigned DEFAULT '0',
  PRIMARY KEY (`pid`,`shop_type`,`fresh_period`,`product_id`),
  KEY `idx_psf` (`pid`,`shop_type`,`fresh_period`),
  KEY `shop_type` (`shop_type`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `pray_config`;
CREATE TABLE `pray_config` (
  `id` int(10) unsigned NOT NULL,
  `product_type` int(10) unsigned NOT NULL,
  `product_id` int(10) unsigned NOT NULL,
  `product_value` int(10) unsigned NOT NULL,
  `progress_needed` int(10) unsigned NOT NULL,
  `consume_type` int(10) unsigned NOT NULL,
  `consume_id` int(10) unsigned NOT NULL,
  `consume_value` int(10) unsigned NOT NULL,
  `cost` int(10) unsigned NOT NULL,
  `contribution` int(10) unsigned NOT NULL,
  `index` int(11) NOT NULL,
  `armylev` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`,`product_type`,`product_id`,`product_value`,`progress_needed`,`consume_type`,`consume_id`,`consume_value`,`cost`,`contribution`,`index`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `pray_list`;
CREATE TABLE `pray_list` (
  `gid` int(10) unsigned NOT NULL,
  `pid` bigint(20) NOT NULL,
  `id` int(10) unsigned NOT NULL,
  `index` int(10) unsigned NOT NULL,
  PRIMARY KEY (`gid`,`pid`,`id`,`index`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `pray_player`;
CREATE TABLE `pray_player` (
  `pid` bigint(20) NOT NULL,
  `id` int(10) unsigned NOT NULL,
  `progress` int(10) unsigned NOT NULL,
  `progress_flag` int(10) unsigned NOT NULL,
  `last_seek_help_time` datetime NOT NULL,
  `today_seek_help_count` int(10) unsigned NOT NULL,
  `last_help_time` datetime NOT NULL,
  `today_help_count` int(10) unsigned NOT NULL,
  `has_draw_reward` int(10) unsigned NOT NULL,
  `seek_help_flag` int(10) unsigned NOT NULL,
  `last_reset_time` datetime NOT NULL,
  PRIMARY KEY (`pid`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `product`;
CREATE TABLE `product` (
  `gid` int(255) DEFAULT NULL,
  `shop_type` int(255) DEFAULT NULL,
  `vip_min` int(255) DEFAULT NULL,
  `vip_max` int(255) DEFAULT NULL,
  `vip_extra` int(255) DEFAULT NULL,
  `player_lv_min` int(255) DEFAULT NULL,
  `player_lv_max` int(255) DEFAULT NULL,
  `product_item_type` int(255) DEFAULT NULL,
  `product_item_id` int(255) DEFAULT NULL,
  `product_item_value` int(255) DEFAULT NULL,
  `consume_item_type` int(255) DEFAULT NULL,
  `consume_item_id` int(255) DEFAULT NULL,
  `consume_item_value` int(255) DEFAULT NULL,
  `begin_time` datetime DEFAULT NULL,
  `end_time` datetime DEFAULT NULL,
  `is_active` int(255) DEFAULT NULL,
  `storage` int(255) DEFAULT NULL,
  `special_flag` int(255) DEFAULT NULL,
  `original_price` int(255) DEFAULT NULL,
  `discount` int(255) DEFAULT NULL,
  `weight` int(255) DEFAULT NULL,
  `consume1_item_type` int(255) DEFAULT NULL,
  `consume1_item_id` int(255) DEFAULT NULL,
  `consume1_item_value` int(255) DEFAULT NULL
) DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `sweepstakeconfig`;
CREATE TABLE `sweepstakeconfig` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `pool_type` varchar(255) NOT NULL,
  `begin_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `end_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `activity_type` int(10) unsigned NOT NULL,
  `player_data_id` int(10) unsigned NOT NULL,
  `reward_config_id` int(10) unsigned NOT NULL,
  `free_gap` int(10) unsigned NOT NULL,
  `init_time` int(10) unsigned NOT NULL,
  `guarantee_count` int(10) unsigned NOT NULL,
  `init_count` int(10) unsigned NOT NULL,
  `consume_type` int(10) unsigned NOT NULL,
  `consume_id` int(10) unsigned NOT NULL,
  `price` int(10) unsigned NOT NULL,
  `combo_price` int(10) unsigned NOT NULL,
  `combo_count` int(10) unsigned NOT NULL,
  PRIMARY KEY (`id`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `sweepstakefinalrewardconfig`;
CREATE TABLE `sweepstakefinalrewardconfig` (
  `uuid` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `id` int(10) unsigned NOT NULL,
  `rank_begin` int(10) unsigned NOT NULL,
  `rank_end` int(10) unsigned NOT NULL,
  `reward_type` int(10) unsigned NOT NULL,
  `reward_id` int(10) unsigned NOT NULL,
  `reward_value` int(10) unsigned NOT NULL,
  PRIMARY KEY (`uuid`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `sweepstakeplayerdata`;
CREATE TABLE `sweepstakeplayerdata` (
  `pid` bigint(20) unsigned NOT NULL,
  `dataid` int(10) unsigned NOT NULL,
  `last_free_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `total_count` int(10) unsigned NOT NULL,
  `has_used_gold` int(10) unsigned NOT NULL,
  `last_draw_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `today_draw_count` int(10) unsigned NOT NULL,
  `random_count` int(10) unsigned NOT NULL,
  `randnum` int(10) unsigned NOT NULL,
  `flag` int(10) unsigned NOT NULL,
  `current_pool` int(10) unsigned NOT NULL,
  `current_pool_draw_count` int(10) unsigned NOT NULL,
  `current_pool_end_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (`pid`,`dataid`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `sweepstakerank`;
CREATE TABLE `sweepstakerank` (
  `activity_id` int(10) unsigned NOT NULL,
  `pid` bigint(20) NOT NULL,
  `rank` int(10) unsigned NOT NULL,
  `score` int(10) unsigned NOT NULL,
  `score_update_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `has_draw_final_reward` int(10) unsigned NOT NULL,
  `reward_flag` int(10) unsigned NOT NULL,
  `has_draw_score_reward` int(10) unsigned NOT NULL,
  PRIMARY KEY (`activity_id`,`pid`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `sweepstakescorerewardconfig`;
CREATE TABLE `sweepstakescorerewardconfig` (
  `uuid` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `id` int(10) unsigned NOT NULL,
  `pos` int(10) unsigned NOT NULL,
  `score` int(10) unsigned NOT NULL,
  `reward_type` int(10) unsigned NOT NULL,
  `reward_id` int(10) unsigned NOT NULL,
  `reward_value` int(10) unsigned NOT NULL,
  PRIMARY KEY (`uuid`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `sweepstakesettlestatus`;
CREATE TABLE `sweepstakesettlestatus` (
  `id` int(10) unsigned NOT NULL,
  `settle_status` int(10) unsigned NOT NULL,
  PRIMARY KEY (`id`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `timeControl`;
CREATE TABLE `timeControl` (
  `gid` int(11) NOT NULL AUTO_INCREMENT,
  `id` int(11) NOT NULL,
  `activity_type` int(11) NOT NULL,
  `begin_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `end_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `duration_per_period` int(11) NOT NULL,
  `valid_time_per_period` int(10) unsigned NOT NULL,
  PRIMARY KEY (`gid`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `build_city_player`;
CREATE TABLE `build_city_player` (
  `pid` bigint(20) NOT NULL DEFAULT '0',
  `round_index` int(11) DEFAULT NULL,
  `today_count` int(11) DEFAULT NULL,
  `update_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (`pid`)
) DEFAULT CHARSET=utf8 ;

DROP TABLE IF EXISTS `build_city_boss`;
CREATE TABLE `build_city_boss` (
  `boss_id` int(11) NOT NULL,
  `exp` int(11) DEFAULT NULL default 0,
  PRIMARY KEY (`boss_id`)
) DEFAULT CHARSET=utf8 ;

DROP TABLE IF EXISTS `hero`;
CREATE TABLE `hero` (
	`uuid` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT,
	`pid` BIGINT UNSIGNED NOT NULL,
	`gid` INTEGER UNSIGNED NOT NULL,
	`exp` INTEGER NOT NULL,
	`stage` INTEGER NOT NULL,
	`star` INTEGER NOT NULL,
	`stage_slot` INTEGER NOT NULL,
	`weapon_stage` INTEGER NOT NULL,
	`weapon_star` INTEGER NOT NULL,
	`weapon_level` INTEGER NOT NULL,
	`weapon_stage_slot` INTEGER NOT NULL,
	`weapon_exp` INTEGER NOT NULL,
	`placeholder` INTEGER NOT NULL,
	`add_time` TIMESTAMP NOT NULL DEFAULT '0000-00-00 00:00:00',
	`exp_change_time` TIMESTAMP NOT NULL DEFAULT '0000-00-00 00:00:00',	
	PRIMARY KEY (`uuid`),
	INDEX (`pid`)
) DEFAULT CHARSET=utf8;
ALTER TABLE `hero` AUTO_INCREMENT = 6;

DROP TABLE IF EXISTS `reward`;
CREATE TABLE `reward` (
	`uuid` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT,
	`pid` BIGINT UNSIGNED NOT NULL,
	`reason` INTEGER UNSIGNED NOT NULL,
	`limit` TIMESTAMP NOT NULL DEFAULT '0000-00-00 00:00:00',
	`get` TIMESTAMP NOT NULL DEFAULT '0000-00-00 00:00:00',
	`autorecv` INTEGER UNSIGNED NOT NULL,
	`name` TEXT NOT NULL,
	PRIMARY KEY (`uuid`),
	INDEX (`pid`)
) DEFAULT CHARSET=utf8;
DROP TABLE IF EXISTS `dailydata`;
CREATE TABLE `dailydata` (
	`pid` BIGINT UNSIGNED NOT NULL,
	`id` INTEGER UNSIGNED NOT NULL,
	`update_time` TIMESTAMP NOT NULL DEFAULT '0000-00-00 00:00:00',
	`value` INTEGER UNSIGNED NOT NULL,
	`total` INTEGER UNSIGNED NOT NULL,
	PRIMARY KEY (`pid`,`id`)
) DEFAULT CHARSET=utf8;
DROP TABLE IF EXISTS `talent`;
CREATE TABLE `talent` (
	`pid` BIGINT UNSIGNED NOT NULL,
	`id` BIGINT UNSIGNED NOT NULL,
	`talent_type` INTEGER NOT NULL,
	`data` TEXT NOT NULL,
	`sum_point` INTEGER NOT NULL,
	`refid` INTEGER NOT NULL,
	PRIMARY KEY (`pid`,`id`,`talent_type`)
) DEFAULT CHARSET=utf8;
DROP TABLE IF EXISTS `quest`;
CREATE TABLE `quest` (
	`pid` BIGINT UNSIGNED NOT NULL,
	`id` INTEGER UNSIGNED NOT NULL,
	`status` INTEGER UNSIGNED NOT NULL,
	`count` INTEGER UNSIGNED NOT NULL,
	`record_1` INTEGER UNSIGNED NOT NULL,
	`record_2` INTEGER UNSIGNED NOT NULL,
	`consume_item_save_1` INTEGER UNSIGNED NOT NULL,
	`consume_item_save_2` INTEGER UNSIGNED NOT NULL,
	`accept_time` TIMESTAMP NOT NULL DEFAULT '0000-00-00 00:00:00',
	`submit_time` TIMESTAMP NOT NULL DEFAULT '0000-00-00 00:00:00',
	PRIMARY KEY (`pid`,`id`)
) DEFAULT CHARSET=utf8;
DROP TABLE IF EXISTS `rewardflag`;
CREATE TABLE `rewardflag` (
	`pid` BIGINT UNSIGNED NOT NULL,
	`id` INTEGER UNSIGNED NOT NULL,
	`value` BIGINT UNSIGNED NOT NULL,
	PRIMARY KEY (`pid`,`id`)
) DEFAULT CHARSET=utf8;
DROP TABLE IF EXISTS `heroskill`;
CREATE TABLE `heroskill` (
	`uid` BIGINT UNSIGNED NOT NULL,
	`pid` BIGINT UNSIGNED NOT NULL,
	`skill1` INTEGER NOT NULL,
	`skill2` INTEGER NOT NULL,
	`skill3` INTEGER NOT NULL,
	`skill4` INTEGER NOT NULL,
	`skill5` INTEGER NOT NULL,
	`skill6` INTEGER NOT NULL,
	`property_type` INTEGER NOT NULL,
	`property_value` INTEGER NOT NULL,
	PRIMARY KEY (`uid`,`pid`)
) DEFAULT CHARSET=utf8;
DROP TABLE IF EXISTS `equipvalue`;
CREATE TABLE `equipvalue` (
	`pid` BIGINT UNSIGNED NOT NULL,
	`uid` BIGINT UNSIGNED NOT NULL,
	`type` INTEGER NOT NULL,
	`id` INTEGER NOT NULL,
	`value` INTEGER NOT NULL,
	PRIMARY KEY (`pid`,`uid`,`type`,`id`)
) DEFAULT CHARSET=utf8;
DROP TABLE IF EXISTS `fight`;
CREATE TABLE `fight` (
	`pid` BIGINT UNSIGNED NOT NULL,
	`gid` INTEGER NOT NULL,
	`flag` INTEGER NOT NULL,
	`today_count` INTEGER NOT NULL,
	`update_time` INTEGER NOT NULL,
	`star` INTEGER NOT NULL,
	PRIMARY KEY (`pid`,`gid`)
) DEFAULT CHARSET=utf8;
DROP TABLE IF EXISTS `item`;
CREATE TABLE `item` (
	`pid` BIGINT UNSIGNED NOT NULL,
	`id` INTEGER UNSIGNED NOT NULL,
	`limit` INTEGER UNSIGNED NOT NULL,
	`pos` INTEGER UNSIGNED NOT NULL,
	`update_time` TIMESTAMP NOT NULL DEFAULT '0000-00-00 00:00:00',
	PRIMARY KEY (`pid`,`id`)
) DEFAULT CHARSET=utf8;
DROP TABLE IF EXISTS `compensate`;
CREATE TABLE `compensate` (
	`pid` BIGINT UNSIGNED NOT NULL,
	`drop_id` INTEGER UNSIGNED NOT NULL,
	`time` TIMESTAMP NOT NULL DEFAULT '0000-00-00 00:00:00',
	`count` INTEGER UNSIGNED NOT NULL,
	`level` INTEGER UNSIGNED NOT NULL,
	PRIMARY KEY (`pid`,`drop_id`,`time`)
) DEFAULT CHARSET=utf8;
DROP TABLE IF EXISTS `buff`;
CREATE TABLE `buff` (
	`pid` BIGINT UNSIGNED NOT NULL,
	`buff_id` INTEGER UNSIGNED NOT NULL,
	`end_time` TIMESTAMP NOT NULL DEFAULT '0000-00-00 00:00:00',
	`value` INTEGER UNSIGNED NOT NULL,
	PRIMARY KEY (`pid`,`buff_id`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `equip`;
CREATE TABLE `equip` (
	`uuid` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT,
	`pid` BIGINT UNSIGNED NOT NULL,
	`gid` INTEGER NOT NULL,
	`heroid` INTEGER NOT NULL,
	`placeholder` INTEGER NOT NULL,
	`exp` INTEGER NOT NULL,
	`hero_uuid` BIGINT UNSIGNED NOT NULL,
	`property_id_1` INTEGER NOT NULL,
	`property_value_1` INTEGER NOT NULL,
	`property_grow_1` INTEGER NOT NULL,
	`property_id_2` INTEGER NOT NULL,
	`property_value_2` INTEGER NOT NULL,
	`property_grow_2` INTEGER NOT NULL,
	`property_id_3` INTEGER NOT NULL,
	`property_value_3` INTEGER NOT NULL,
	`property_grow_3` INTEGER NOT NULL,
	`property_id_4` INTEGER NOT NULL,
	`property_value_4` INTEGER NOT NULL,
	`property_grow_4` INTEGER NOT NULL,
	`property_id_5` INTEGER NOT NULL,
	`property_value_5` INTEGER NOT NULL,
	`property_grow_5` INTEGER NOT NULL,
	`property_id_6` INTEGER NOT NULL,
	`property_value_6` INTEGER NOT NULL,
	`property_grow_6` INTEGER NOT NULL,
	`add_time` TIMESTAMP NOT NULL DEFAULT '0000-00-00 00:00:00',
	PRIMARY KEY (`uuid`),
	INDEX (`pid`)
) DEFAULT CHARSET=utf8;
DROP TABLE IF EXISTS `property`;
CREATE TABLE `property` (
	`pid` BIGINT UNSIGNED NOT NULL,
	`name` TEXT NOT NULL,
	`create` TIMESTAMP NOT NULL DEFAULT '0000-00-00 00:00:00',
	`login` TIMESTAMP NOT NULL DEFAULT '0000-00-00 00:00:00',
	`logout` TIMESTAMP NOT NULL DEFAULT '0000-00-00 00:00:00',
	`status` INTEGER UNSIGNED NOT NULL,
	`ip` TEXT NOT NULL,
	`played` INTEGER UNSIGNED NOT NULL,
	`head` INTEGER UNSIGNED NOT NULL,
	`vip_exp` INTEGER UNSIGNED NOT NULL,
	`title` INTEGER UNSIGNED NOT NULL,
	`total_star` INTEGER UNSIGNED NOT NULL,
    `total_star_change_time` TIMESTAMP NOT NULL DEFAULT '0000-00-00 00:00:00',
	`max_floor` INTEGER UNSIGNED NOT NULL,
    `max_floor_change_time` TIMESTAMP NOT NULL DEFAULT '0000-00-00 00:00:00',
	PRIMARY KEY (`pid`)
) DEFAULT CHARSET=utf8;
DROP TABLE IF EXISTS `heroitem`;
CREATE TABLE `heroitem` (
	`pid` BIGINT UNSIGNED NOT NULL,
	`uid` BIGINT UNSIGNED NOT NULL,
	`id` INTEGER UNSIGNED NOT NULL,
	`value` INTEGER UNSIGNED NOT NULL,
	`status` INTEGER UNSIGNED NOT NULL,
	PRIMARY KEY (`pid`,`uid`,`id`)
) DEFAULT CHARSET=utf8;
DROP TABLE IF EXISTS `rewardcontent`;
CREATE TABLE `rewardcontent` (
	`id` INTEGER UNSIGNED NOT NULL,
	`pid` BIGINT UNSIGNED NOT NULL,
	`type` INTEGER UNSIGNED NOT NULL,
	`key` INTEGER UNSIGNED NOT NULL,
	`value` INTEGER UNSIGNED NOT NULL,
	`uid` BIGINT UNSIGNED NOT NULL,
	PRIMARY KEY (`id`,`pid`,`type`,`key`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `manor_battle_info`;
CREATE TABLE `manor_battle_info` (
  `pid` bigint UNSIGNED not null,
  `property` int(11) not null,
  `condition`int(11) not null,
  `fight_id` int(11) not null,
  `fight_count` int(10) DEFAULT 0,
  PRIMARY KEY (`pid`, `property`, `condition`)
);

DROP TABLE IF EXISTS `npc_roll`;
CREATE TABLE `npc_roll` (
  `pid` BIGINT UNSIGNED NOT NULL,
  `type` INTEGER UNSIGNED NOT NULL,
  `today_count` INTEGER NOT NULL,
  `update_time` datetime NOT NULL,
  PRIMARY KEY (`pid`,`type`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `player_npc_reward_pool`;
CREATE TABLE `player_npc_reward_pool` (
  `gid` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `pid` BIGINT UNSIGNED NOT NULL,
  `fight_id` INTEGER UNSIGNED NOT NULL,
  `npc_id` INTEGER UNSIGNED NOT NULL,
  `fight_time` datetime NOT NULL,
  `valid_time` datetime NOT NULL,
  `drop1` INTEGER UNSIGNED NOT NULL,
  `drop2` INTEGER UNSIGNED NOT NULL,
  `drop3` INTEGER UNSIGNED NOT NULL,
  `level1` INTEGER UNSIGNED NOT NULL,
  `level2` INTEGER UNSIGNED NOT NULL,
  `level3` INTEGER UNSIGNED NOT NULL,
  `heros` varchar(255) NOT NULL,
  PRIMARY KEY (`gid`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `player_team_fight`;
CREATE TABLE `player_team_fight` (
  `pid` BIGINT UNSIGNED NOT NULL,
  `fight_id` INTEGER UNSIGNED NOT NULL,
  `count` INTEGER UNSIGNED NOT NULL,
  `update_time` datetime NOT NULL,
  `roll_count` INTEGER UNSIGNED NOT NULL,
  `last_roll_time` datetime NOT NULL,
  PRIMARY KEY (`pid`,`fight_id`)
) DEFAULT CHARSET=utf8; 

DROP TABLE IF EXISTS `team_fight`;
CREATE TABLE `team_fight` (
  `teamid` BIGINT UNSIGNED NOT NULL,
  `gid` INTEGER UNSIGNED NOT NULL,
  `flag` INTEGER UNSIGNED NOT NULL,
  `today_count` INTEGER UNSIGNED NOT NULL,
  `update_time` datetime NOT NULL,
  `star` INTEGER UNSIGNED NOT NULL,
  PRIMARY KEY (`teamid`, `gid`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `team_members`;
CREATE TABLE `team_members` (
  `id` BIGINT UNSIGNED NOT NULL,
  `group` INTEGER UNSIGNED NOT NULL,
  `leader` BIGINT UNSIGNED NOT NULL,
  `mem1` BIGINT UNSIGNED NOT NULL,
  `mem2` BIGINT UNSIGNED NOT NULL,
  `mem3` BIGINT UNSIGNED NOT NULL,
  `mem4` BIGINT UNSIGNED NOT NULL,
  `mem5` BIGINT UNSIGNED NOT NULL,
  `level_lower_limit` INTEGER UNSIGNED NOT NULL,
  `level_upper_limit` INTEGER UNSIGNED NOT NULL,
  `afk_mem1` BIGINT UNSIGNED NOT NULL,
  `afk_mem2` BIGINT UNSIGNED NOT NULL,
  `afk_mem3` BIGINT UNSIGNED NOT NULL,
  `afk_mem4` BIGINT UNSIGNED NOT NULL,
  `afk_mem5` BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (`id`)
) CHARSET=utf8;

DROP TABLE IF EXISTS `manor_player_order_price`;
CREATE TABLE `manor_player_order_price` (
  `pid` BIGINT UNSIGNED NOT NULL,
  `gid` INTEGER UNSIGNED NOT NULL,
  `discount` INTEGER UNSIGNED NOT NULL,
  `begin_time` datetime NOT NULL,
  `end_time` datetime NOT NULL,
  PRIMARY KEY (`pid`,`gid`)
) CHARSET=utf8;

DROP TABLE IF EXISTS `manor_tavern_hero_status`;
CREATE TABLE `manor_tavern_hero_status` (
  `pid` BIGINT UNSIGNED NOT NULL,
  `uuid` BIGINT UNSIGNED NOT NULL,
  `leave_time` datetime NOT NULL,
  `back_time` datetime NOT NULL,
  `finish` INTEGER UNSIGNED NOT NULL,
  `event_id` INTEGER UNSIGNED NOT NULL,
  PRIMARY KEY (`pid`,`uuid`)
)DEFAULT CHARSET=utf8;


drop table if exists `manor_task_playerInfo`;
create table `manor_task_playerInfo`(
  `pid` bigint UNSIGNED not null,
  `refresh_count` int(11) not null default 0,
  `last_whole_time` datetime not null,
  `last_whole_time2` datetime not null,
  `complete_count` int(11) not null default 0,
  `today_deadtime` datetime not null,
  `star_count` int(11) not null default 0,
  primary key (`pid`)
);

DROP TABLE IF EXISTS `manor_task_starboxreward`;
CREATE TABLE `manor_task_starboxreward` (
 `pid` bigint(20) NOT NULL,
 `gid` int(11) NOT NULL,
 `flag` int(11) NOT NULL,
 primary key (`pid`, `gid`)
);

drop table if exists `manor_player_task`;
create table `manor_player_task`(
  `pid` bigint UNSIGNED not null,
  `gid` int(11) not null,
  `task_type` int(11) not null,
  `last_refresh_time` datetime not null,
  `hold_task` int(11) not null default 0,
  `workman1_id` bigint UNSIGNED not null default 0, 
  `workman2_id` bigint UNSIGNED not null default 0,
  `workman3_id` bigint UNSIGNED not null default 0,
  `workman4_id` bigint UNSIGNED not null default 0,
  `workman5_id` bigint UNSIGNED not null default 0,
  `begin_time` datetime not null,
  primary key (`pid`, `gid`)
);


DROP TABLE IF EXISTS `bounty_player`;
CREATE TABLE `bounty_player` (
  `pid` bigint(20) NOT NULL DEFAULT '0',
  `active` int(11) NOT NULL,
  `normal_count` int(11) DEFAULT NULL,
  `double_count` int(11) DEFAULT NULL,
  `update_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (`pid`, `active`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `bounty_team`;
CREATE TABLE `bounty_team` (
  `id` bigint(20) NOT NULL DEFAULT '0',
  `active` int(11) NOT NULL,
  `quest` int(11) NOT NULL DEFAULT '0',
  `record` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`, `active`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `player_daily_quiz`;
CREATE TABLE `player_daily_quiz` (
  `pid` bigint(20) NOT NULL,
  `current_question_id` int(10) NOT NULL,
  `current_round` int(10) NOT NULL,
  `correct_count` int(10) NOT NULL,
  `finish_count` int(10) NOT NULL,
  `reward_flag` int(10) NOT NULL,
  `help_count` int(10) NOT NULL,
  `reward_depot` text NOT NULL,
  `update_time` datetime NOT NULL,
  `end_time` datetime NOT NULL,
  `sixty_rate_count` int(10) NOT NULL,
  `eighty_rate_count` int(10) NOT NULL,
  `hundred_rate_count` int(10) NOT NULL,
  PRIMARY KEY (`pid`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `defend_player_info`;
CREATE TABLE `defend_player_info` (
  `pid` bigint(20) NOT NULL,
  `box_count` int(11) NOT NULL DEFAULT '0',
  `box_deadtime` datetime NOT NULL,
  `team_id` bigint(20) NOT NULL,
  `player_index` int(11) NOT NULL,
  `collect_count` int(11) NOT NULL,
  `pitfall_time` datetime NOT NULL,
  `attract_time` datetime NOT NULL,
  `exchange_time` datetime NOT NULL,
  `move_time` datetime NOT NULL,
  `collect_time`datetime NOT NULL,
  `reward_id` int(11) NOT NULL,
  `exp_limit` int(11) NOT NULL DEFAULT '0',
  `is_stay` int(11) NOT NULL DEFAULT '0',
  `stay_time` datetime NOT NULL,
  `last_index` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`pid`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `defend_team_info`;
CREATE TABLE `defend_team_info` (
  `team_id` bigint(20) NOT NULL AUTO_INCREMENT,
  `player_id1` bigint(20) NOT NULL,
  `player_id2` bigint(20) NOT NULL,
  `player_id3` bigint(20) NOT NULL,
  `player_id4` bigint(20) NOT NULL,
  `player_id5` bigint(20) NOT NULL,
  `boss_id` bigint(20) NOT NULL,
  `boss_mode` int(11) NOT NULL,
  `boss_type` int(11) NOT NULL,
  `boss_hp` int(11) NOT NULL,
  `boss_index` int(11) NOT NULL,
  `game_begin` datetime NOT NULL,
  `boss_status` int(11) NOT NULL DEFAULT '0',
  `begin_time` datetime NOT NULL,
  `last_index` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`team_id`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `defend_team_resource`;
CREATE TABLE `defend_team_resource` (
  `team_id` bigint(20) NOT NULL,
  `resource_id` int(11) NOT NULL,
  `resource_value` int(11) NOT NULL,
  PRIMARY KEY(`team_id`, `resource_id`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `defend_team_map`;
CREATE TABLE `defend_team_map` (
  `team_id` bigint(20) NOT NULL,
  `site_id` int(11) NOT NULL,
  `site_type` int(11) NOT NULL,
  `resource1_type` int(11) NOT NULL,
  `resource1_value` int(11) NOT NULL,
  `resource2_type` int(11) NOT NULL,
  `resource2_value` int(11) NOT NULL,
  `resource2_probability` int(11) NOT NULL,
  `fight_probability` int(11) NOT NULL,
  `fight_id` int(11) NOT NULL,
  `pitfall_type` int(11) NOT NULL,
  `pitfall_level` int(11) NOT NUll,
  `attract_value` int(11) NOT NULL,
  `box_id` int(11) NOT NULL,
  `is_exchange` int(11) NOT NULL,
  `is_diversion` int(11) NOT NULL,	
  `last_collect_time` datetime NOT NULL DEFAULT '1970-1-1 8:0:0',
  `site_status` int(11) NOT NULL DEFAULT '0',
  `buff_id` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`team_id`, `site_id`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `player_manor_log`;
CREATE TABLE `player_manor_log` (
  `pid` BIGINT UNSIGNED NOT NULL,
  `index` INTEGER UNSIGNED NOT NULL,
  `type` INTEGER UNSIGNED NOT NULL,
  `content` text NOT NULL,
  PRIMARY KEY (`pid`,`index`)
) DEFAULT CHARSET=utf8;


DROP TABLE IF EXISTS `guild_buildings`;
CREATE TABLE `guild_buildings` (
  `gid` INTEGER UNSIGNED NOT NULL,
  `building_type` INTEGER UNSIGNED NOT NULL,
  `exp` INTEGER UNSIGNED NOT NULL,
  PRIMARY KEY (`gid`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `arena_player_box_reward`;
CREATE TABLE `arena_player_box_reward` (
  `pid` BIGINT UNSIGNED NOT NULL,
  `reward_id1` INTEGER UNSIGNED NOT NULL,
  `reward_id2` INTEGER UNSIGNED NOT NULL,
  `reward_id3` INTEGER UNSIGNED NOT NULL,
  `level` INTEGER UNSIGNED NOT NULL,
  PRIMARY KEY (`pid`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `answer_info`;
CREATE TABLE `answer_info` (
  `pid` bigint(20) NOT NULL,	
  `team_id` bigint(20) NOT NULL DEFAULT '0',				
  `is_AI` int(11) NOT NULL DEFAULT '0',									
  `credits` int(11) NOT NULL DEFAULT '0',					
  `deadtime` datetime NOT NULL,	
  `week_count` int(11) NOT NULL DEFAULT '0',				
  `answer_correct` int(11) NOT NULL, 						
  `is_answer` int(11) NOT NULL,
  `answer_time` datetime NOT NULL,							
  `correct_count` int(11) NOT NULL,						
  `next_type` int(11) NOT NULL,	
  PRIMARY KEY(`pid`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `answer_team_info`;
CREATE TABLE `answer_team_info` (
  `team_id` bigint(20) NOT NULL AUTO_INCREMENT,		
  `round` int(11) NOT NULL,
  `pindex` int(11) NOT NULL,				
  `qid` int(11) NOT NULL,
  `publish_time` datetime NOT NULL,			
  `pid1` bigint(20) NOT NULL,
  `pid2` bigint(20) NOT NULL,
  `pid3` bigint(20) NOT NULL,
  `pid4` bigint(20) NOT NULL,
  `pid5` bigint(20) NOT NULL,
  PRIMARY KEY(`team_id`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `present`;
CREATE TABLE `present` (
    `pid` BIGINT UNSIGNED NOT NULL,
    `target_id`  BIGINT UNSIGNED NOT NULL,
    `th` int(10) UNSIGNED NOT NULL,
    `present_time` datetime NOT NULL,
    `status` int(10) UNSIGNED NOT NULL,
    `overdue` int(10) UNSIGNED NOT NULL DEFAULT '0',
    `get_time` datetime NOT NULL,
    `remove_time` datetime NOT NULL,
    PRIMARY KEY (`pid`, `target_id`, `th`),
	KEY `target_id` (`target_id`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `pillage_arena_player_formation`;
CREATE TABLE `pillage_arena_player_formation` (
  `pid` bigint(20) NOT NULL,
  `attack_role1` BIGINT UNSIGNED NOT NULL,
  `attack_role2` BIGINT UNSIGNED NOT NULL,
  `attack_role3` BIGINT UNSIGNED NOT NULL,
  `attack_role4` BIGINT UNSIGNED NOT NULL,
  `attack_role5` BIGINT UNSIGNED NOT NULL,
  `defend_role1` BIGINT UNSIGNED NOT NULL,
  `defend_role2` BIGINT UNSIGNED NOT NULL,
  `defend_role3` BIGINT UNSIGNED NOT NULL,
  `defend_role4` BIGINT UNSIGNED NOT NULL,
  `defend_role5` BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (`pid`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `pillage_arena_player_log`;
CREATE TABLE `pillage_arena_player_log` (
  `pid` BIGINT UNSIGNED NOT NULL,
  `period` INTEGER UNSIGNED NOT NULL,
  `index` INTEGER UNSIGNED NOT NULL,
  `attacker` BIGINT UNSIGNED NOT NULL,
  `defender` BIGINT UNSIGNED NOT NULL,
  `wealth_change` INTEGER NOT NULL default '0',
  `extra_wealth` INTEGER NOT NULL default '0',
  PRIMARY KEY (`pid`,`period`,`index`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `pillage_arena_player_pool`;
CREATE TABLE `pillage_arena_player_pool` (
  `pid` BIGINT UNSIGNED NOT NULL,
  `period` INTEGER UNSIGNED NOT NULL,
  `wealth` BIGINT UNSIGNED NOT NULL,
  `win_count` INTEGER UNSIGNED NOT NULL,
  `fight_count` INTEGER UNSIGNED NOT NULL,
  `update_time` datetime NOT NULL,
  `today_win_streak_count` INTEGER UNSIGNED NOT NULL,
  `win_streak_update_time` datetime NOT NULL,
  `reward_time` datetime NOT NULL,
  `defend_win_count` INTEGER UNSIGNED NOT NULL,
  `defend_fight_count` INTEGER UNSIGNED NOT NULL,
  `compensation_count` INTEGER UNSIGNED NOT NULL,
  `depot` text NOT NULL,
  `today_attack_count` INTEGER UNSIGNED NOT NULL,
  `attack_time` datetime NOT NULL,
  `xwealth` BIGINT UNSIGNED NOT NULL,
  `xwealth_time` datetime NOT NULL,
  `match_count` INTEGER NOT NULL DEFAULT '0',
  `match_time` datetime NOT NULL,
  `pvp_win_count` INTEGER NOT NULL DEFAULT '0',
  `pvp_const_win_count` INTEGER NOT NULL DEFAULT '0',
  `pvp_fight_count` INTEGER NOT NULL DEFAULT '0',
  `const_win_count` INTEGER NOT NULL DEFAULT '0',
  PRIMARY KEY (`pid`,`period`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `pillage_arena_reward_settle_status`;
CREATE TABLE `pillage_arena_reward_settle_status` (
  `period` INTEGER UNSIGNED NOT NULL,
  `sub_period` INTEGER UNSIGNED NOT NULL,
  `finish` INTEGER UNSIGNED NOT NULL,
  PRIMARY KEY (`period`,`sub_period`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `manor_manufacture_player_line_open_status`;
CREATE TABLE `manor_manufacture_player_line_open_status` (
  `pid` BIGINT UNSIGNED NOT NULL,
  `line` INTEGER UNSIGNED NULL,
  `open` INTEGER UNSIGNED NOT NULL,
  `open_time` datetime NOT NULL,
  PRIMARY KEY (`pid`,`line`)
) CHARSET=utf8;

DROP TABLE IF EXISTS `ai_fight_data`;
CREATE TABLE `ai_fight_data` (
  `id` INTEGER UNSIGNED NOT NULL,
  `from` BIGINT UNSIGNED NOT NULL,
  `level` INTEGER UNSIGNED NOT NULL,
  `fight_data` text NOT NULL,
  PRIMARY KEY (`id`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `ai_info`;
CREATE TABLE `ai_info` (
  `pid` BIGINT UNSIGNED NOT NULL,
  `mode_pid` BIGINT UNSIGNED NOT NULL,
  `level_percent` INTEGER UNSIGNED NOT NULL,
  `fight_data_id` INTEGER UNSIGNED NOT NULL,
  `active_time` datetime NOT NULL,
  PRIMARY KEY (`pid`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `guild_war_member`;
CREATE TABLE `guild_war_member` (
    `gid` INT DEFAULT 0,
    `room_id` INT DEFAULT 0,
    `join_time` TIMESTAMP DEFAULT 0,
    `exp` INT DEFAULT 0,
    `order1` bigint(20) not null default 0,
    `order2` bigint(20) not null default 0,
    `order3` bigint(20) not null default 0,
    `order4` bigint(20) not null default 0,
    `inspire_sum` INT DEFAULT 0,
    PRIMARY KEY (`gid`, `room_id`)
);

DROP TABLE IF EXISTS `guild_war_room_info`;
CREATE TABLE `guild_war_room_info` (
    `room_id` INT DEFAULT 0,
    `prepare_time` TIMESTAMP DEFAULT 0,
    `check_time`   TIMESTAMP DEFAULT 0,
    `begin_time`   TIMESTAMP DEFAULT 0,
    `end_time`     TIMESTAMP DEFAULT 0,
    PRIMARY KEY (`room_id`)
);


DROP TABLE IF EXISTS `guild_war_report`;
CREATE TABLE `guild_war_report` (
    `room_id`   INT DEFAULT 0,
    `room_isbn` INT DEFAULT 0,
    `gid` INT DEFAULT 0,
    `origin_order` INT DEFAULT 0,
    `room_rank` INT,
    `room_rank_status` INT DEFAULT 0,
    `room_rank_time`  TIMESTAMP DEFAULT 0,
    PRIMARY KEY (`room_id`,`room_isbn`, `gid`)
);

DROP TABLE IF EXISTS `guild_war_sub_room_record`;
CREATE TABLE `guild_war_sub_room_record` (
  `room_id` int(11) NOT NULL DEFAULT '0',
  `room_isbn` int(11) NOT NULL DEFAULT '0',
  `sub_room_id` int(11) NOT NULL DEFAULT '0',
  `gid` int(11) NOT NULL DEFAULT '0',
  `g_type` int(11) DEFAULT '0',
  `pid1` bigint(20) DEFAULT NULL,
  `pid2` bigint(20) DEFAULT NULL,
  `pid3` bigint(20) DEFAULT NULL,
  `pid4` bigint(20) DEFAULT NULL,
  `pid5` bigint(20) DEFAULT NULL,
  `pid6` bigint(20) DEFAULT NULL,
  `pid7` bigint(20) DEFAULT NULL,
  `pid8` bigint(20) DEFAULT NULL,
  `pid9` bigint(20) DEFAULT NULL,
  `pid10` bigint(20) DEFAULT NULL,
  `pid11` bigint(20) DEFAULT NULL,
  `pid12` bigint(20) DEFAULT NULL,
  `pid13` bigint(20) DEFAULT NULL,
  `pid14` bigint(20) DEFAULT NULL,
  `pid15` bigint(20) DEFAULT NULL,
  `pid16` bigint(20) DEFAULT NULL,
  `pid17` bigint(20) DEFAULT NULL,
  `pid18` bigint(20) DEFAULT NULL,
  `pid19` bigint(20) DEFAULT NULL,
  `pid20` bigint(20) DEFAULT NULL,
  `pid21` bigint(20) DEFAULT NULL,
  `pid22` bigint(20) DEFAULT NULL,
  `pid23` bigint(20) DEFAULT NULL,
  `pid24` bigint(20) DEFAULT NULL,
  `inspire_sum` int(11) DEFAULT '0',
  PRIMARY KEY (`room_id`,`room_isbn`,`sub_room_id`,`gid`)
);

DROP TABLE IF EXISTS `guild_war_fight_record`;
CREATE TABLE `guild_war_fight_record` (
    room_id INT DEFAULT 0,
    room_isbn   INT DEFAULT 0,
    sub_room_id INT DEFAULT 0,
    fight_round INT DEFAULT 0,
    fight_type INT DEFAULT 0, 
    gid1 INT DEFAULT 0, 
    pid1 bigint(20) not null default 0,
    gid2 INT DEFAULT 0,
    pid2 bigint(20) not null default 0,
    fight_result INT DEFAULT 0,
    fight_record_id BIGINT DEFAULT 0,
    fight_record_time TIMESTAMP,
    INDEX(`room_id`),
    INDEX(`room_isbn`),
    INDEX(`sub_room_id`)
);

DROP TABLE IF EXISTS `player_guild_explore_event`;
CREATE TABLE `player_guild_explore_event` (
  `uuid` INTEGER UNSIGNED NOT NULL AUTO_INCREMENT,
  `pid` BIGINT UNSIGNED NOT NULL,
  `map_id` INTEGER UNSIGNED NOT NULL,
  `team_id` INTEGER UNSIGNED NOT NULL,
  `event_id` INTEGER UNSIGNED NOT NULL,
  `hero_uuid` BIGINT UNSIGNED NOT NULL,
  `begin_time` datetime NOT NULL,
  `end_time` datetime NOT NULL,
  PRIMARY KEY (`uuid`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `guild_event_log`;
CREATE TABLE `guild_event_log` (
  `gid` INTEGER UNSIGNED NOT NULL,
  `index` INTEGER UNSIGNED NOT NULL,
  `type` INTEGER UNSIGNED NOT NULL,
  `content` text NOT NULL,
  `time`    datetime NOT NULL,
  PRIMARY KEY (`gid`,`index`)
) CHARSET=utf8;

DROP TABLE IF EXISTS `guild_pray_log`;
CREATE TABLE `guild_pray_log` (
  `gid` INTEGER UNSIGNED NOT NULL,
  `index` INTEGER UNSIGNED NOT NULL,
  `type` INTEGER UNSIGNED NOT NULL,
  `content` text NOT NULL,
  PRIMARY KEY (`gid`,`index`)
) CHARSET=utf8;

DROP TABLE IF EXISTS `arena`;
CREATE TABLE `arena` (
  `pid` bigint(32) NOT NULL,
  `order` int(32) NOT NULL DEFAULT '0',
  `cwin` int(32) NOT NULL DEFAULT '0',
  `fight_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `fight_count` int(32) NOT NULL DEFAULT '0',
  `addFightCount` int(32) NOT NULL DEFAULT '0',
  `reward_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `xorder` int(32) NOT NULL DEFAULT '0',
  `xorder_date` int(32) NOT NULL DEFAULT '0',
  `daily_reward_flag` int(11) NOT NULL,
  `daily_reward_flag_update_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `today_win_count` int(11) NOT NULL,
  `today_win_count_update_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `last_refresh_enemy_list_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `addFightCount_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (`pid`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `arena_daily_max_order`;
CREATE TABLE `arena_daily_max_order` (
  `pid` bigint(20) unsigned NOT NULL,
  `max_order` int(10) unsigned NOT NULL,
  `reward_status` int(10) unsigned NOT NULL,
  `update_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (`pid`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `rank_arena_enemy_list`;
CREATE TABLE `rank_arena_enemy_list` (
  `pid` bigint(20) NOT NULL,
  `enemy_id` bigint(20) NOT NULL,
  PRIMARY KEY (`pid`,`enemy_id`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `rank_arena_formation`;
CREATE TABLE `rank_arena_formation` (
  `pid` bigint(20) NOT NULL,
  `role1` bigint(20) NOT NULL,
  `role2` bigint(20) NOT NULL,
  `role3` bigint(20) NOT NULL,
  `role4` bigint(20) NOT NULL,
  `role5` bigint(20) NOT NULL,
  PRIMARY KEY (`pid`)
) DEFAULT CHARSET=utf8;
	
DROP TABLE IF EXISTS `world_quiz`;
CREATE TABLE `world_quiz` (
  `pid` BIGINT UNSIGNED NOT NULL,
  `answer_count` INTEGER UNSIGNED NOT NULL DEFAULT '0',
  `correct_count` INTEGER UNSIGNED NOT NULL DEFAULT '0',
  `is_quiz` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY(`pid`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `trade_orders`;
CREATE TABLE `trade_orders` (
  `gid` bigint(20) NOT NULL AUTO_INCREMENT,
  `seller` bigint(20) NOT NULL,
  `commodity_type` int(11) NOT NULL,
  `commodity_id` int(11) NOT NULL,
  `commodity_value` int(11) NOT NULL,
  `commodity_uuid` bigint(20) NOT NULL,
  `commodity_equip_level` int(11)  DEFAULT NULL, 
  `commodity_equip_quality` int(11) DEFAULT NULL,
  `cost_type` int(11) NOT NULL,
  `cost_id` int(11) NOT NULL,
  `cost_value` int(11) NOT NULL,
  `putaway_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `concern_count` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`gid`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `trade_item_sale_record`;
CREATE TABLE `trade_item_sale_record` (
  `type` int(11) NOT NULL,
  `id` int(11) NOT NULL,
  `today_avg_price` float(32,11) NOT NULL,
  `last_trade_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `today_sales` int(11) NOT NULL,
  `avg_price1` float(32,11) NOT NULL,
  `avg_price2` float(32,11) NOT NULL,
  `avg_price3` float(32,11) NOT NULL,
  `avg_price4` float(32,11) NOT NULL,
  `avg_price5` float(32,11) NOT NULL,
  `avg_price6` float(32,11) NOT NULL,
  `avg_price7` float(32,11) NOT NULL,
  `avg_price8` float(32,11) NOT NULL,
  `avg_price9` float(32,11) NOT NULL,
  `avg_price11` float(32,11) NOT NULL,
  `avg_price10` float(32,11) NOT NULL,
  `avg_price12` float(32,11) NOT NULL,
  `avg_price13` float(32,11) NOT NULL,
  `avg_price14` float(32,11) NOT NULL,
  `sales1` int(11) NOT NULL,
  `sales2` int(11) NOT NULL,
  `sales3` int(11) NOT NULL,
  `sales4` int(11) NOT NULL,
  `sales5` int(11) NOT NULL,
  `sales6` int(11) NOT NULL,
  `sales7` int(11) NOT NULL,
  `sales8` int(11) NOT NULL,
  `sales9` int(11) NOT NULL,
  `sales10` int(11) NOT NULL,
  `sales11` int(11) NOT NULL,
  `sales12` int(11) NOT NULL,
  `sales13` int(11) NOT NULL,
  `sales14` int(11) NOT NULL,
  PRIMARY KEY (`type`,`id`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `trade_records`;
CREATE TABLE `trade_records` (
 `pid` BIGINT UNSIGNED NOT NULL,
 `type` int(11) NOT NULL,
 `gid` int(11) NOT NULL,
 `trader` BIGINT UNSIGNED NOT NULL,
 `commodity_type` int(11) NOT NULL,
 `commodity_id` int(11) NOT NULL,
 `commodity_value` int(11) NOT NULL,
 `commodity_uuid` int(11) NOT NULL,
 `cost_type` int(11) NOT NULL,
 `cost_id` int(11) NOT NULL,
 `cost_value` int(11) NOT NULL,
 PRIMARY KEY (`pid`,`type`,`gid`)
) DEFAULT CHARSET=utf8;


DROP TABLE IF EXISTS `trade_yesterday_sales`;
CREATE TABLE `trade_yesterday_sales` (
 `commodity_type` int(11) NOT NULL,
 `commodity_id` int(11) NOT NULL,
 `commodity_value` int(11) NOT NULL,
 `sales_num` int(11) NOT NULL,
 `sales_price` int(11) NOT NULL,
 PRIMARY KEY (`commodity_type`,`commodity_id`)
);

DROP TABLE IF EXISTS `trade_commodity_orders`;
CREATE TABLE `trade_commodity_orders` (
 `commodity_type` int(11) NOT NULL,
 `commodity_id` int(11) NOT NULL,
 `ai_sell_count` int(11) Default 0,
 `ai_buy_count` int(11) Default 0,
 `next_sell_time` datetime NOT NULL,
 `next_buy_time` datetime NOT NULL,
 PRIMARY KEY (`commodity_type`,`commodity_id`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `trade_commodity_concern`;
CREATE TABLE `trade_commodity_concern` (
 `pid` BIGINT UNSIGNED NOT NULL,
 `gid` int(11) NOT NULL
) DEFAULT CHARSET=utf8;

CREATE TABLE `fightdata` (
  `pid` bigint(20) unsigned NOT NULL,
  `power_dirty` int(10) unsigned NOT NULL,
  `power` bigint(20) unsigned NOT NULL,
  PRIMARY KEY (`pid`)
);

DROP TABLE IF EXISTS `group_score`;
CREATE TABLE `group_score` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `pid` int(11) NOT NULL,
  `groupid` int(11) NOT NULL,
  `score` int(11) NOT NULL,
  `extradata` varchar(500) NOT NULL,
  `time` datetime NOT NULL,
  PRIMARY KEY (`id`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `fish_player`;
CREATE TABLE `fish_player`(
	`pid` BIGINT UNSIGNED NOT NULL,
	`tid` BIGINT NOT NULL,
	`fish_status` int(11) NOT NULL DEFAULT '0',
	`fish_time` datetime NOT NULL,
	`fish_back_time` datetime NOT NULL,
	`points` int(11) NOT NULL DEFAULT '0',
	`assist_bit` int(11) NOT NULL DEFAULT '0',
	`status` int(11) NOT NULL DEFAULT '0',
	`power` int(11) NOT NULL DEFAULT '0',
	`th` int(11) NOT NULL DEFAULT '0',
	`nsec` int(11) NOT NULL DEFAULT '0',
	PRIMARY KEY(`pid`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `fish_team`;
CREATE TABLE `fish_team`(
	`tid` BIGINT NOT NULL,
	`pid1` BIGINT UNSIGNED NOT NULL DEFAULT '0',
	`pid2` BIGINT UNSIGNED NOT NULL DEFAULT '0',
	`pid3` BIGINT UNSIGNED NOT NULL DEFAULT '0',
	`pid4` BIGINT UNSIGNED NOT NULL DEFAULT '0',
	`pid5` BIGINT UNSIGNED NOT NULL DEFAULT '0',
	`fight_id` int(11) NOT NULL DEFAULT '0',
	PRIMARY KEY(`tid`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `fish_record`;
CREATE TABLE `fish_record` (
	`pid` BIGINT UNSIGNED NOT NULL,
	`order` int(11) NOT NULL,
	`type` int(11) NOT NULL,
	`id` int(11) NOT NULL,
	`value` int(11) NOT NULL,
	`tid` BIGINT NOT NULL,
	`time` datetime NOT NULL,
	PRIMARY KEY(`pid`, `order`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `Boss`;
CREATE TABLE `Boss` (
  `activity_id` INTEGER UNSIGNED NOT NULL,
  `period` INTEGER UNSIGNED NOT NULL,
  `group_id` INTEGER UNSIGNED NOT NULL,
  `id` BIGINT UNSIGNED NOT NULL,
  `damage` INTEGER UNSIGNED NOT NULL,
  `reward_flag` INTEGER UNSIGNED NOT NULL,
  `update_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `fight_count` INTEGER UNSIGNED NOT NULL,
  PRIMARY KEY (`activity_id`,`period`,`group_id`,`id`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `boss_open`;
CREATE TABLE `boss_open` (
  `activity_id` INTEGER UNSIGNED NOT NULL,
  `period` INTEGER UNSIGNED NOT NULL,
  `group_id` INTEGER UNSIGNED NOT NULL,
  `settle_reward` INTEGER UNSIGNED NOT NULL,
  `begin_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `end_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (`activity_id`,`period`,`group_id`)
) DEFAULT CHARSET=utf8;

CREATE TABLE `guild_quest` (
  `gid` INTEGER UNSIGNED NOT NULL,
  `pid` BIGINT UNSIGNED NOT NULL,
  `quest_id` INTEGER UNSIGNED NOT NULL,
  `status` INTEGER UNSIGNED NOT NULL,
  `count` INTEGER UNSIGNED NOT NULL,
  `record1` INTEGER UNSIGNED NOT NULL,
  `record2` INTEGER UNSIGNED NOT NULL,
  `record3` INTEGER UNSIGNED NOT NULL,
  `consume_item_save1` INTEGER UNSIGNED NOT NULL,
  `consume_item_save2` INTEGER UNSIGNED NOT NULL,
  `accept_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `submit_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `next_time_to_accept` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `step_reward_flag` int(11) NOT NULL,
  PRIMARY KEY (`gid`,`pid`,`quest_id`)
) DEFAULT CHARSET=utf8;

INSERT INTO `property` (pid, name, `create`, `status`, ip, played, head, vip_exp, title) VALUES(100000, 'system', CURRENT_TIMESTAMP, 0, '', 0, 0, 0, 0);

DROP TABLE IF EXISTS `player_common_data`;
CREATE TABLE `player_common_data` (
  `pid` BIGINT UNSIGNED NOT NULL,
  `type` int(11) NOT NULL,
  `inta` int(11) NOT NULL,
  `intb` int(11) NOT NULL,
  `intc` int(11) NOT NULL,
  `stra` varchar(255) NOT NULL,
  PRIMARY KEY (`pid`,`type`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `backyard`;
CREATE TABLE `backyard` (
 `pid` BIGINT UNSIGNED NOT NULL,
 `roomid` int(11) NOT NULL,
 `byname` char(50) NOT NULL,
 `expandcount` int(11) NOT NULL,
 `dzcount` int(11) NOT NULL, 
 PRIMARY KEY (`pid`,roomid)	
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `backyard_dz_count`;
CREATE TABLE `backyard_dz_count` (
 `pid` BIGINT UNSIGNED NOT NULL,
 `roomid` int(11) NOT NULL,
 `fid` BIGINT UNSIGNED NOT NULL,
 `dzcount` int(11) NOT NULL,
 `dztime` datetime NOT NULL,
 PRIMARY KEY (`pid`,`roomid`,`fid`)
)  DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `backyard_furniture_info`;
CREATE TABLE `backyard_furniture_info` (
 `pid` BIGINT UNSIGNED NOT NULL,
 `roomid` int(11) NOT NULL,
 `aid` int(11) NOT NULL AUTO_INCREMENT,
 `furid` int(11) NOT NULL,
 `posid` int(11) NOT NULL,
 `direction` int(11) NOT NULL,
 PRIMARY KEY (`aid`)	
) DEFAULT CHARSET=utf8;


DROP TABLE IF EXISTS `backyard_furniture`;
CREATE TABLE `backyard_furniture` (
 `pid` BIGINT UNSIGNED NOT NULL,
 `furid` int(11) NOT NULL,
 `count` int(11) NOT NULL,
 PRIMARY KEY (`pid`,`furid`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `friend_favor`;
CREATE TABLE `friend_favor` (
	`pid1` BIGINT UNSIGNED NOT NULL,
	`pid2` BIGINT UNSIGNED NOT NULL,
	`source` int(10) UNSIGNED NOT NULL,
	`value` float(32, 11) NOT NULL DEFAULT '0',
	`origin_time` datetime NOT NULL,
	`count` int(10) UNSIGNED NOT NULL DEFAULT '0',
    	PRIMARY KEY (`pid1`, `pid2`, `source`),
	INDEX(`pid2`, `source`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `backyard_fairy_slot`;
CREATE TABLE `backyard_fairy_slot` (
 `pid` BIGINT UNSIGNED NOT NULL,
 `roomid` int(11) NOT NULL,
 `sid` int(11) NOT NULL,
 `unlockstatus` int(11) NOT NULL,
 `fairyuuid` int(11) NOT NULL,
 `addtime` datetime NOT NULL,
 PRIMARY KEY (`pid`,`roomid`,`sid`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `backyard_fairy`;
CREATE TABLE `backyard_fairy` (
 `pid` BIGINT UNSIGNED NOT NULL,
 `fairyuuid` int(11) NOT NULL,
 `fairyid` int(11) NOT NULL,
 `goodfeel` int(11) NOT NULL,
 PRIMARY KEY (`pid`,`fairyuuid`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `random_npc`;
CREATE TABLE `random_npc` (
 `pid` BIGINT UNSIGNED NOT NULL,
 `refresh_time` datetime NOT NULL,
 `quest_ids` char(128) NOT NULL,
 PRIMARY KEY(`pid`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `team_reward`;
CREATE TABLE `team_reward` ( 
 `pid` BIGINT UNSIGNED NOT NULL,
 `th` int(11) NOT NULL,
 `quest_id` int(11) NOT NULL,
 `type` int(11) NOT NULL,
 `id` int(11) NOT NULL,
 `value` int(11) NOT NULL,
 `reward_time` datetime NOT NULL,
 PRIMARY KEY(`pid`, `th`),
 INDEX(`th`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `player_shared_quest`;
CREATE TABLE `player_shared_quest` (
  `pid` BIGINT UNSIGNED NOT NULL,
  `quest_id` INTEGER UNSIGNED NOT NULL,
  `status` INTEGER UNSIGNED NOT NULL,
  `count` INTEGER UNSIGNED NOT NULL,
  `record1` INTEGER UNSIGNED NOT NULL,
  `record2` INTEGER UNSIGNED NOT NULL,
  `consume_item_save1` INTEGER UNSIGNED NOT NULL,
  `consume_item_save2` INTEGER UNSIGNED NOT NULL,
  `accept_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `submit_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (`pid`,`quest_id`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `shared_quest`;
CREATE TABLE `shared_quest` (
  `id` INTEGER UNSIGNED NOT NULL,
  `quest_id` INTEGER UNSIGNED NOT NULL,
  `finish_count` INTEGER UNSIGNED NOT NULL,
  `start_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (`id`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `team_battle_time`;
CREATE TABLE `team_battle_time` (
  `teamid` BIGINT UNSIGNED NOT NULL,
  `battle_id` INTEGER UNSIGNED NOT NULL,
  `battle_begin_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `battle_close_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (`teamid`,`battle_id`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `rank_flag`;
CREATE TABLE `rank_flag` (
  `id` INTEGER UNSIGNED NOT NULL AUTO_INCREMENT,
  `open_flag` INTEGER UNSIGNED NOT NULL,
  `first_begin_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `begin_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (`id`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `boss_info`;
CREATE table `boss_info` (
  `id` int(11) NOT NULL PRIMARY KEY AUTO_INCREMENT,
  `refresh_time` datetime NOT NULL,
  `npc_id` int(11) NOT NULL,
  `fight_id` int(11) NOT NULL,
  `fight_data` text NOT NULL,
  `terminator` BIGINT UNSIGNED NOT NULL, 
  `is_escape` int(11) NOT NULL,
  `duration` int(11) NOT NULL,
  `cd` int(11) NOT NULL,
  `boss_level` int(11) NOT NULL,
  `is_accu_damage` int(11) NOT NULL
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `world_boss`;
CREATE TABLE `world_boss` (
  `type` int(11) NOT NULL,
  `id` int(11) NOT NULL,
  PRIMARY KEY(`type`, `id`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `guild_boss`;
CREATE TABLE `guild_boss` (
  `guild_id` INTEGER UNSIGNED NOT NULL,
  `type` int(11) NOT NULL,
  `id` int(11) NOT NULL,
  PRIMARY KEY(`guild_id`, `type`, `id`),
  INDEX(`type`),
  INDEX(`id`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `boss_fight_record`;
CREATE TABLE `boss_fight_record` (
  `id` int(11) NOT NULL,
  `pid` BIGINT UNSIGNED NOT NULL,
  `th` int(11) NOT NULL,
  `npc_id` int(11) NOT NULL,
  `fight_id` int(11) NOT NULL,
  `damage` int(11) NOT NULL,
  `fight_time` datetime NOT NULL,
  `fight_data` text NOT NULL,
  `player_fight_data` text NOT NULL,
  `seed` int(11) NOT NULL,
  PRIMARY KEY(`id`, `pid`, `th`),
  INDEX(`pid`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `world_player`;
CREATE table `world_player` (
  `id` int(11) NOT NULL,
  `pid` BIGINT UNSIGNED NOT NULL,
  `last_fight_time` datetime NOT NULL,	
  `damage` int(11) NOT NULL,
  `reward_flag1` int(11) NOT NULL,
  `reward_flag2` int(11) NOT NULL,
  `reward_flag3` int(11) NOT NULL,
  `reward_flag4` int(11) NOT NULL,
  PRIMARY KEY (`id`, `pid`),
  INDEX(`pid`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `player_day_info`;
CREATE table `player_day_info` (
  `pid` BIGINT UNSIGNED NOT NULL,
  `time` datetime NOT NULL,
  `damage` INTEGER UNSIGNED NOT NULL,
  PRIMARY KEY(`pid`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `manor_manufacture_player_line_produce_rate`;
CREATE TABLE `manor_manufacture_player_line_produce_rate` (
  `pid` BIGINT UNSIGNED NOT NULL,
  `line` INTEGER UNSIGNED NOT NULL,
  `line_produce_rate` INTEGER NOT NULL,
  `line_produce_rate_begin_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `line_produce_rate_end_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `line_produce_rate_reason` INTEGER UNSIGNED NOT NULL,
  `line_produce_rate_depend_fight` INTEGER UNSIGNED NOT NULL,
  `line_produce_rate_extra_data` INTEGER UNSIGNED NOT NULL,
  PRIMARY KEY (`pid`,`line`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `manor_manufacture_player_line_pool_storage`;
CREATE TABLE `manor_manufacture_player_line_pool_storage` (
  `pid` BIGINT UNSIGNED NOT NULL,
  `line` INTEGER UNSIGNED NOT NULL,
  `gid` INTEGER UNSIGNED NOT NULL,
  `type` INTEGER UNSIGNED NOT NULL,
  `id` INTEGER UNSIGNED NOT NULL,
  `value` INTEGER UNSIGNED DEFAULT NULL,
  `stolen_value` INTEGER UNSIGNED DEFAULT NULL,
  PRIMARY KEY (`pid`,`line`,`gid`,`type`,`id`)
) DEFAULT CHARSET=utf8;


DROP TABLE IF EXISTS `manor_manufacture_line_thieves`;
CREATE TABLE `manor_manufacture_line_thieves` (
  `pid` BIGINT UNSIGNED NOT NULL,
  `line` INTEGER UNSIGNED NOT NULL,
  `thief` BIGINT UNSIGNED NOT NULL,
  `begin_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `end_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `depend_fight_id` INTEGER UNSIGNED NOT NULL,
  `stolen_goods` text NOT NULL,
  PRIMARY KEY (`pid`,`line`,`thief`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `manor_manufacture_line_event_cd`;
CREATE TABLE `manor_manufacture_line_event_cd` (
 `pid` bigint(20) unsigned NOT NULL,
 `line` int(10) unsigned NOT NULL,
 `event_type` int(10) unsigned NOT NULL,
 `time_cd` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
 PRIMARY KEY (`pid`,`line`,`event_type`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `guild_quest_attenders`;
CREATE TABLE `guild_quest_attenders` (
  `gid` INTEGER UNSIGNED NOT NULL,
  `pid` BIGINT UNSIGNED NOT NULL,
  `quest_id` INTEGER UNSIGNED NOT NULL,
  `attender_pid` BIGINT UNSIGNED NOT NULL,
  `attender_reward_flag` INTEGER UNSIGNED NOT NULL,
  `contribution` INTEGER UNSIGNED NOT NULL,
  PRIMARY KEY (`gid`,`pid`,`quest_id`,`attender_pid`)
) DEFAULT CHARSET=utf8;


DROP TABLE IF EXISTS `team_battle`;
CREATE TABLE `team_battle` (
  `teamid` bigint(20) NOT NULL,
  `battle_id` int(11) NOT NULL,
  `begin_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `end_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `seed` bigint(20) not NULL default 0,
  PRIMARY KEY (`teamid`,`battle_id`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `team_battle_npc`;
CREATE TABLE `team_battle_npc` (
  `teamid` bigint(20) NOT NULL,
  `battle_id` int(11) NOT NULL,
  `npc_uuid` int(11) NOT NULL,
  `npc_id` int(11) NOT NULL,
  `data1` int(11) NOT NULL,
  `data2` int(11) NOT NULL,
  `data3` int(11) NOT NULL,
  `data4` int(11) NOT NULL,
  `data5` int(11) NOT NULL,
  `dead` int(11) NOT NULL,
  PRIMARY KEY (`teamid`,`battle_id`,`npc_uuid`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `team_battle_player`;
CREATE TABLE `team_battle_player` (
  `teamid` bigint(20) NOT NULL,
  `battle_id` int(11) NOT NULL,
  `pid` bigint(20) NOT NULL,
  `data1` int(11) NOT NULL,
  `data2` int(11) NOT NULL,
  `data3` int(11) NOT NULL,
  `data4` int(11) NOT NULL,
  `data5` int(11) NOT NULL,
  PRIMARY KEY (`teamid`,`battle_id`,`pid`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `rank_score_reward`;
CREATE TABLE `rank_score_reward` (
`rankid` int(10) unsigned NOT NULL,
`period` int(10) unsigned NOT NULL,
`id` bigint(20) NOT NULL,
`score` int(10) unsigned NOT NULL,
`time` bigint(20) NOT NULL,
PRIMARY KEY (`rankid`,`period`,`id`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `rank_player_rewardtime`;
CREATE TABLE `rank_player_rewardtime` (
`rankid` int(10) unsigned NOT NULL,
`period` int(10) unsigned NOT NULL,
`pid` bigint(20) NOT NULL,
`rewardtime` datetime NOT NULL,
PRIMARY KEY (`rankid`,`period`,`pid`)
)DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `arena_formation`;
CREATE TABLE `arena_formation` (
  `pid` BIGINT UNSIGNED NOT NULL,
  `type` INTEGER UNSIGNED NOT NULL,
  `fight_data` text NOT NULL,
  `cap` INTEGER UNSIGNED NOT NULL,
  PRIMARY KEY (`pid`,`type`)
)DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `arena_fight_log`;
CREATE TABLE `arena_fight_log` (
  `fid` BIGINT UNSIGNED NOT NULL,
  `attacker` BIGINT UNSIGNED NOT NULL,
  `target` BIGINT UNSIGNED NOT NULL,
  `winner` INTEGER UNSIGNED NOT NULL,
  `ftime` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `pos1` INTEGER UNSIGNED NOT NULL,
  `pos2` INTEGER UNSIGNED NOT NULL,
  `fight_data` text NOT NULL,
  PRIMARY KEY (`fid`)
)DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `rank_player_offer_score`;
CREATE TABLE `rank_player_offer_score` (
 `rankid` int(10) unsigned NOT NULL,
 `period` int(10) unsigned NOT NULL,
 `gid` int(10) unsigned NOT NULL,
 `pid` bigint(20) NOT NULL,
 `score` int(10) NOT NULL,
 PRIMARY KEY (`rankid`,`period`,`gid`,`pid`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `auto_fight_record`;
CREATE TABLE `auto_fight_record` (
  `fight_id` BIGINT UNSIGNED NOT NULL,
  `winner` BIGINT UNSIGNED NOT NULL,
  `fight_data` text NOT NULL,
  PRIMARY KEY (`fight_id`)
) DEFAULT CHARSET=utf8;
