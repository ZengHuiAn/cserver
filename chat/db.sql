drop table if exists `chat_history`;
CREATE TABLE `chat_history` (
  `uuid` bigint(20) NOT NULL AUTO_INCREMENT,
  `id` int(11) DEFAULT '0',
  `from_player_id` bigint unsigned NOT NULL,
  `from_player_name` varchar(256) NOT NULL,
  `rid` int(11) NOT NULL,
  `message` varchar(256) NOT NULL,
  `t` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`uuid`),
  KEY `id` (`id`),
  KEY `t` (`t`)
) DEFAULT CHARSET=utf8;

drop table if exists `contact`;
CREATE TABLE `contact` (
  `pid` bigint unsigned NOT NULL,
  `cid` bigint NOT NULL,
  `type` int(32) NOT NULL DEFAULT '0',
  `rtype` int(32) NOT NULL DEFAULT '0',
  PRIMARY KEY (`pid`,`cid`),
  KEY `pid` (`pid`),
  KEY `cid` (`cid`)
) DEFAULT CHARSET=utf8;

drop table if exists `mail`;
CREATE TABLE `mail` (
  `mid` int(32) NOT NULL AUTO_INCREMENT,
  `type` int(32) NOT NULL DEFAULT '0',
  `from` bigint unsigned NOT NULL,
  `to` bigint unsigned  NOT NULL,
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

drop table if exists `NotifyMessage`;
CREATE TABLE `NotifyMessage` (
  `id` int(32) NOT NULL AUTO_INCREMENT,
  `time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `to` bigint NOT NULL,
  `type` int(32) NOT NULL DEFAULT '0',
  `cmd` int(32) NOT NULL DEFAULT '0',
  `data` text NOT NULL,
  PRIMARY KEY (`id`)
) DEFAULT CHARSET=utf8;

drop table if exists `TIMING_NOTIFY`;
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
