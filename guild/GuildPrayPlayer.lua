require "yqmath"
require "yqlog_sys"
require "printtb"
require "yqmath"
local database = require "database"
local yqinfo = yqinfo
local ipairs = ipairs
local table = table
local math = math
local sprinttb = sprinttb
local GuildPrayConfig = require "GuildPrayConfig" 
local StableTime = require "StableTime"
local Class = require "Class"
local PlayerManager = require "PlayerManager"
local loop = loop

module "GuildPrayPlayer"


local instance = {}
local GuildPrayPlayer = {}
BASE_TIME = 1490112000   --2017-3-22

function GuildPrayPlayer:_init_(pid)
	self._player = {}
	local ok, result = database.query("SELECT pid, id, progress, progress_flag, UNIX_TIMESTAMP(last_seek_help_time) as last_seek_help_time, today_seek_help_count, UNIX_TIMESTAMP(last_help_time) as last_help_time, today_help_count, has_draw_reward, seek_help_flag, UNIX_TIMESTAMP(last_reset_time) as last_reset_time FROM pray_player where pid = %d", pid)
    if ok and #result >= 1 then
       	 for i = 1, #result do
           	local row = result[i];
			self._player = {
				_pid = row.pid,
				_id  = row.id,
				_progress = row.progress,
				_progress_flag = row.progress_flag,
				_last_seek_help_time = row.last_seek_help_time,
				_today_seek_help_count = row.today_seek_help_count,
				_last_help_time = row.last_help_time,
				_today_help_count = row.today_help_count,	
				_has_draw_reward = row.has_draw_reward,
				_seek_help_flag = row.seek_help_flag,
				_last_reset_time = row.last_reset_time
			}
        end
   	elseif ok and #result == 0 then
		local player = PlayerManager.Get(pid);
		if not player or not player.guild then
			yqinfo("fail to init GuildPrayPlayer , player %d donnt has guild", pid)
			return false
		end
		local cfg = GuildPrayConfig.Get():getRandomConfig(player.guild.level)
		if not cfg then
			yqinfo("[GuildPrayPlayer] Player %d fail to insert into pray_player, cfg is nil", pid)
			return false	
		end
		local cfgID = cfg.id  
		database.update("INSERT INTO pray_player(pid, id, progress, progress_flag, last_seek_help_time, today_seek_help_count, last_help_time, today_help_count, has_draw_reward, seek_help_flag, last_reset_time) VALUES(%d, %d, %d, %d,from_unixtime_s(%d), %d, from_unixtime_s(%d), %d, %d, %d, from_unixtime_s(%d))",pid, cfgID, 0, 0, 0, 0, 0, 0, 0, 0, 0)
		self._player = {
				_pid = pid,
				_id  = cfgID,
				_progress = 0,
				_progress_flag = 0,
				_last_seek_help_time = 0,
				_today_seek_help_count = 0,
				_last_help_time = 0,
				_today_help_count = 0,
				_has_draw_reward = 0,
				_seek_help_flag = 0,
				_last_reset_time = 0,
		}
	end 
end

--freshType 0免费 1付费
function GuildPrayPlayer:forceFresh(freshType)
	local pid = self._player._pid
	local player = PlayerManager.Get(self._player._pid);
	if not player or not player.guild then
		yqinfo("fail to forceFresh , player %d donnt has guild", pid)
		return 1
	end

	if freshType == 0 then
		local cfg = GuildPrayConfig.Get():getRandomConfig(player.guild.level)
		if not cfg then
			yqinfo("[GuildPrayPlayer] Player %d fail to forceFresh, cfg is nil", pid)
			return 1
		end
		local cfgID = cfg.id
		database.update("UPDATE pray_player SET id=%d, progress=%d, progress_flag=%d, has_draw_reward=%d, seek_help_flag=%d, last_reset_time=from_unixtime_s(%d) WHERE pid = %d ",cfgID, 0, 0, 0, 0, loop.now(), self._player._pid)
		self._player._id = cfgID
		self._player._progress = 0 
		self._player._progress_flag = 0 
		self._player._has_draw_reward = 0 
		self._player._seek_help_flag = 0 
		self._player._last_reset_time = loop.now() 
	else	
		local cfg = GuildPrayConfig.Get():getRandomConfig(player.guild.level)
		if not cfg then
			yqinfo("[GuildPrayPlayer] Player %d fail to forceFresh, cfg is nil", pid)
			return 1
		end
		local cfgID = cfg.id  
		database.update("UPDATE pray_player SET id=%d, progress=%d, progress_flag=%d,  seek_help_flag=%d WHERE pid = %d ",cfgID, 0, 0, 0, self._player._pid)
		self._player._id = cfgID
		self._player._progress =0 
		self._player._progress_flag =0 
		self._player._seek_help_flag =0 
	end
	return 0
end

function GuildPrayPlayer:getPlayerInfo()
	return self._player;
end

function GuildPrayPlayer:getCfgID()
	return self._player._id and self._player._id or nil
end

function GuildPrayPlayer:getProgress()
	return self._player._progress and self._player._progress or nil
end

function GuildPrayPlayer:getProgressFlag()
	return self._player._progress_flag and self._player._progress_flag or nil
end

function GuildPrayPlayer:getLastSeekHelpTime()
	return self._player._last_seek_help_time and self._player._last_seek_help_time or nil
end

function GuildPrayPlayer:getTodaySeekHelpCount()
	if self._player._today_seek_help_count then
		if self._player._last_seek_help_time and StableTime.get_begin_time_of_day(loop.now()) > StableTime.get_begin_time_of_day(self._player._last_seek_help_time) then
			self._player._today_seek_help_count = 0
		end		
	end
	return self._player._today_seek_help_count and self._player._today_seek_help_count or nil
end

function GuildPrayPlayer:getLastHelpTime()
	return self._player._last_help_time and self._player._last_help_time or nil
end

function GuildPrayPlayer:getTodayHelpCount()
	if self._player._today_help_count then
		if self._player._last_help_time and StableTime.get_begin_time_of_day(loop.now()) > StableTime.get_begin_time_of_day(self._player._last_help_time) then
			self._player._today_help_count = 0
		end		
	end
	return self._player._today_help_count and self._player._today_help_count or nil
end

function GuildPrayPlayer:getHasDrawReward()
	return self._player._has_draw_reward and self._player._has_draw_reward or nil
end

function GuildPrayPlayer:getSeekHelpFlag()
	return self._player._seek_help_flag and self._player._seek_help_flag or nil
end

function GuildPrayPlayer:getLastResetTime()
	return self._player._last_reset_time and self._player._last_reset_time or nil
end

function GuildPrayPlayer:updateData(progress, progressFlag, lastSeekHelpTime, todaySeekHelpCount, lastHelpTime, todayHelpCount, hasDrawReward, seekHelpFlag, lastResetTime)
	if not database.update("UPDATE pray_player set progress=%d, progress_flag=%d, last_seek_help_time = from_unixtime_s(%d), today_seek_help_count=%d, last_help_time = from_unixtime_s(%d), today_help_count=%d, has_draw_reward=%d, seek_help_flag=%d, last_reset_time = from_unixtime_s(%d) where pid=%d", progress, progressFlag, lastSeekHelpTime, todaySeekHelpCount, lastHelpTime, todayHelpCount, hasDrawReward, seekHelpFlag, lastResetTime, self._player._pid)	then
		yqinfo("[GuildPrayPlayer] Player %d fail to updataData for GuildPrayPlayer, mysql error", self._player._pid)
		return 1
	end
	self._player._progress = progress
	self._player._progress_flag = progressFlag
	self._player._last_seek_help_time = lastSeekHelpTime
	self._player._today_seek_help_count = todaySeekHelpCount
	self._player._last_help_time = lastHelpTime
	self._player._today_help_count = todayHelpCount
	self._player._has_draw_reward = hasDrawReward
	self._player._seek_help_flag = seekHelpFlag 
	self._player._last_reset_time = lastResetTime 
	return 0
end

function Get(pid)
	if not instance[pid] then
		instance[pid] = Class.New(GuildPrayPlayer, pid)
	end
	return instance[pid]
end
