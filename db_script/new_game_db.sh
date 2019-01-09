#!/bin/bash
if [ "$1" == "" ]; then echo "Usage $0 serverid"; exit; fi
tail -n +5 "$0" | sed "s/<serverid>/$1/g" | sed "s/agame@localhost/agame/g"
exit

set names utf8;

DROP DATABASE IF EXISTS `SGK_Game_<serverid>`;
CREATE DATABASE IF NOT EXISTS `SGK_Game_<serverid>` default charset utf8 COLLATE utf8_general_ci;

use SGK_Game_<serverid>;

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
  `add_wealth_time` int(32) NOT NULL DEFAULT '0', KEY (`gid`),
  UNIQUE KEY `name` (`name`),
  KEY `name_2` (`name`)
) DEFAULT CHARSET=utf8;

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

DROP TABLE IF EXISTS `rewardflag`;
CREATE TABLE `rewardflag` (
    `pid` BIGINT UNSIGNED NOT NULL,
    `id` INTEGER UNSIGNED NOT NULL,
    `value` BIGINT UNSIGNED NOT NULL,
    PRIMARY KEY (`pid`,`id`)
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
  `workman1` int(11) NOT NULL DEFAULT '0',
  `workman2` int(11) NOT NULL DEFAULT '0',
  `workman3` int(11) NOT NULL DEFAULT '0',
  `workman4` int(11) NOT NULL DEFAULT '0',
  `workman5` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`pid`,`line`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `manor_workman_power`;
CREATE TABLE `manor_workman_power` (
  `pid` bigint(20) NOT NULL,
  `workman_id` int(10) NOT NULL,
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
	PRIMARY KEY (`uuid`),
	INDEX (`pid`)
) DEFAULT CHARSET=utf8;
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
	`id` INTEGER NOT NULL,
	`talent_type` INTEGER NOT NULL,
	`data` TEXT NOT NULL,
	`sum_point` INTEGER NOT NULL,
	`refid` INTEGER NOT NULL,
	PRIMARY KEY (`pid`,`id`,`talent_type`)
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
	PRIMARY KEY (`pid`,`id`)
) DEFAULT CHARSET=utf8;
DROP TABLE IF EXISTS `equip`;
CREATE TABLE `equip` (
	`uuid` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT,
	`pid` BIGINT UNSIGNED NOT NULL,
	`gid` INTEGER NOT NULL,
	`heroid` INTEGER NOT NULL,
	`placeholder` INTEGER NOT NULL,
	`exp` INTEGER NOT NULL,
	`stage_exp` INTEGER NOT NULL,
	`property_id_1` INTEGER NOT NULL,
	`property_value_1` INTEGER NOT NULL,
	`property_id_2` INTEGER NOT NULL,
	`property_value_2` INTEGER NOT NULL,
	`property_id_3` INTEGER NOT NULL,
	`property_value_3` INTEGER NOT NULL,
	`property_id_4` INTEGER NOT NULL,
	`property_value_4` INTEGER NOT NULL,
	`property_id_5` INTEGER NOT NULL,
	`property_value_5` INTEGER NOT NULL,
	`property_id_6` INTEGER NOT NULL,
	`property_value_6` INTEGER NOT NULL,
	`hero_uuid` BIGINT UNSIGNED NOT NULL,
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
	PRIMARY KEY (`pid`)
) DEFAULT CHARSET=utf8;
DROP TABLE IF EXISTS `heroitem`;
CREATE TABLE `heroitem` (
	`pid` BIGINT UNSIGNED NOT NULL,
	`uid` BIGINT UNSIGNED NOT NULL,
	`id` INTEGER UNSIGNED NOT NULL,
	`value` INTEGER UNSIGNED NOT NULL,
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
  `element` int(11) not null,
  `role_num` int(11) not null,
  `add_property` int(11) not null,
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
  `heros` varchar(255) NOT NULL,
  PRIMARY KEY (`gid`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `player_team_fight`;
CREATE TABLE `player_team_fight` (
  `pid` BIGINT UNSIGNED NOT NULL,
  `fight_id` INTEGER UNSIGNED NOT NULL,
  `count` INTEGER UNSIGNED NOT NULL,
  `update_time` datetime NOT NULL,
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

DROP TABLE IF EXISTS `quest`;
CREATE TABLE `quest` (
    `uuid` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT,
    `pid` BIGINT UNSIGNED NOT NULL,
    `id` INTEGER UNSIGNED NOT NULL,
    `status` INTEGER UNSIGNED NOT NULL,
    `record_1` INTEGER UNSIGNED NOT NULL,
    `record_2` INTEGER UNSIGNED NOT NULL,
    `consume_item_save_1` INTEGER UNSIGNED NOT NULL,
    `consume_item_save_2` INTEGER UNSIGNED NOT NULL,
    `accept_time` TIMESTAMP NOT NULL DEFAULT '0000-00-00 00:00:00',
    `expired_time` TIMESTAMP NOT NULL DEFAULT '0000-00-00 00:00:00',
    PRIMARY KEY (`uuid`),
    INDEX (`pid`)
) DEFAULT CHARSET=utf8;

drop table if exists `manor_task_playerInfo`;
create table `manor_task_playerInfo`(
  `pid` bigint UNSIGNED not null,
  `refresh_count` int(11) not null default 0,
  `last_whole_time` datetime not null,
  `last_whole_time2` datetime not null,
  `complete_count` int(11) not null default 0,
  `today_deadtime` datetime not null,
  primary key (`pid`)
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
  `normal_count` int(11) DEFAULT NULL,
  `double_count` int(11) DEFAULT NULL,
  `update_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (`pid`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `bounty_team`;
CREATE TABLE `bounty_team` (
  `id` bigint(20) NOT NULL DEFAULT '0',
  `quest` int(11) DEFAULT NULL,
  `record` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
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
