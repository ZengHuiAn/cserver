-- git version 20227c4

alert table answer_info add `total_count` int(11) NOT NULL DEFAULT '0';
alert table fish_player add `nsec` int(11) NOT NULL DEFAULT '0';

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
