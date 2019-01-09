set names utf8;
DROP DATABASE IF EXISTS `aGameMobileLog_<serverid>`;
CREATE DATABASE IF NOT EXISTS `aGameMobileLog_<serverid>` default charset utf8 COLLATE utf8_general_ci;
use `aGameMobileLog_<serverid>`;

DROP TABLE IF EXISTS `login`;
CREATE TABLE `login` (
        `uuid`  INTEGER UNSIGNED NOT NULL AUTO_INCREMENT,
        `time`  TIMESTAMP NOT NULL DEFAULT '0000-00-00 00:00:00',
        `pid`   INTEGER UNSIGNED NOT NULL,
        `ip`    TEXT NOT NULL,
        PRIMARY KEY (`uuid`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `logout`;
CREATE TABLE `logout` (
        `uuid`          INTEGER UNSIGNED NOT NULL AUTO_INCREMENT,
        `time`          TIMESTAMP NOT NULL DEFAULT '0000-00-00 00:00:00',
        `pid`           INTEGER UNSIGNED NOT NULL,
        `level`         TEXT NOT NULL,
        `duration`      INTEGER UNSIGNED NOT NULL,
        PRIMARY KEY (`uuid`)
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS itemlog;
CREATE TABLE itemlog(
        uuid        INT AUTO_INCREMENT,
        evt_type    INT DEFAULT 0,
        `time`      TIMESTAMP DEFAULT '0000-00-00 00:00:00',
        pid         INT DEFAULT 0,
        id          INT DEFAULT 0,
        `count`     INT DEFAULT 0,
        `change`    INT DEFAULT 0,
        PRIMARY KEY(uuid)
);

GRANT ALL PRIVILEGES ON aGameMobileLog_<serverid>.* to agame@localhost Identified by 'agame@123';
