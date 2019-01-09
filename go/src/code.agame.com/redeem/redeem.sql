
create database if not exists `aGameMobile`;

use `aGameMobile`;

-- 兑换码
DROP TABLE IF EXISTS `redeem_type`;
CREATE TABLE `redeem_type` (
	`type`  int(32) not null,
	`name` varchar(255) not null,
	`channel` varchar(32) not null default '',
	`group` int(32) not null default 1,
	`limit` TIMESTAMP NOT NULL DEFAULT '0000-00-00 00:00:00',
	PRIMARY KEY (`type`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `redeem_content`;
CREATE TABLE `redeem_content` (
	`type`   int(32) not null,
        `rtype`  varchar(32) not null,
        `rid`    int(32) not null,
        `rvalue` int(32) not null,
        PRIMARY  KEY(`type`, `rtype`, `rid`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `redeem_code`;
CREATE TABLE `redeem_code` (
  `code` char(64) NOT NULL,
  `type` int(32) NOT NULL,
  `account` varchar(128) not null default '',
  `sid` varchar(128) not null default ''
  -- PRIMARY KEY (`code`),
  -- KEY `pid` (`pid`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `gift_card`;
CREATE TABLE `gift_card` (
  `code`     char(64) NOT NULL,
  `password` char(64) NOT NULL,
  `type`     int(32) NOT NULL,
  `value`    int(32) NOT NULL,
--  `cost`     int(32) NOT NULL,
  `account`  varchar(128) not null default '',
  `sid`      varchar(128) not null default '',
  `status`   int(32) not null default 0,
  PRIMARY KEY (`code`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `gift_card_time`;
CREATE TABLE `gift_card_time` (
    card_type   int(32) NOT NULL, 
    card_value  int(32) NOT NULL,
    fresh_hour  int(32) NOT NULL,  
    in_sell     int(32) NOT NULL default 0
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `gift_card_config`;
CREATE TABLE `gift_card_config` (
    card_type   int(32) NOT NULL, 
    card_value  int(32) NOT NULL,
    card_cost   int(32) NOT NULL default 9999999,
    card_name   char(64) NOT NULL default '',
    PRIMARY KEY(`card_type`, `card_value`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `gift_card_info`;
CREATE TABLE `gift_card_info` (
    card_type  int(32) NOT NULL, 
    card_value int(32) NOT NULL,
    fresh_day  int(32) NOT NULL, 
    fresh_hour int(32) NOT NULL,  
    in_sell    int(32) NOT NULL default 0,
    fake_in_sell     int(32) NOT NULL default 0,
    PRIMARY KEY (`card_type`,`card_value`)
) DEFAULT CHARSET=utf8;

insert into gift_card_time(card_type,card_value,fresh_hour, in_sell) values(1,100,12,100);
insert into gift_card_time(card_type,card_value,fresh_hour, in_sell) values(1,100,18,100);
insert into gift_card_time(card_type,card_value,fresh_hour, in_sell) values(1,100,21,100);

insert into gift_card_config(card_type,card_value,card_cost, card_name) values(1,100,2888, "京东卡");

GRANT ALL PRIVILEGES ON aGameMobile.* to agame Identified by 'agame@123';
