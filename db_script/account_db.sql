set names utf8;

-- DROP DATABASE IF EXISTS `SGK_Account_<serverid>`;
-- CREATE DATABASE IF NOT EXISTS `SGK_Account_<serverid>` default charset utf8 COLLATE utf8_general_ci;
-- use `SGK_Account_<serverid>`;

DROP TABLE IF EXISTS `account`;
CREATE TABLE IF NOT EXISTS `account` (
        `account`       CHAR(255),
        `from`          INT(32) NOT NULL,
        `game`          INT(32) NOT NULL,
        `id`            INT(32) NOT NULL AUTO_INCREMENT,
        `create`        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY(`id`),
        UNIQUE (`account`, `from`),
        INDEX (`account`, `from`),
        INDEX (`account`, `from`, `game`)
) DEFAULT CHARSET=utf8;

replace into account (`account`, `from`, `game`, `id`) values('system', 0, 0, 100000);

-- GRANT ALL PRIVILEGES ON SGK_Account_<serverid>.* to agame@localhost Identified by 'agame@123';
