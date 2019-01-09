require "yqmath"
require "yqlog_sys"
require "printtb"
require "yqmath"
require "protobuf"
local database = require "database"
local yqinfo = yqinfo
local ipairs = ipairs
local table = table
local math = math
local sprinttb = sprinttb
local StableTime = require "StableTime"
require "EventManager"
require "GuildPrayConfig" 
require "GuildPrayPlayer"
require "GuildPrayList"
require "PlayerManager"
local GuildPrayLog = require "GuildPrayLog"

local function encode(protocol, msg)
	local code = protobuf.encode("com.agame.protocol." .. protocol, msg);
	if code == nil then
		print(string.format(" * encode %s failed", protocol));		
		return nil;
	end
	return code;
end

local function sendServiceRespond(conn, cmd, channel, protocol, msg)
	local code = encode(protocol, msg);
	local sid = tonumber(bit32.rshift_long(channel, 32))
	if code then
		return conn:sends(2, cmd, channel, sid, code);
	else
		return false;
	end
end

local MAX_HELPED_COUNT = 3
local MAX_HELP_COUNT = 10
local COST = {type = 41, id = 90006}
local CONTRIBUTION = {type = 41, id = 90021}

local function canUpdate(flag, index) 
	local mask = 2^(index-1)
	if bit32.band(flag, mask) == 0 then
		return true, bit32.bor(flag, mask)
	else
		return false
	end
end

-- dataFormat 0 amf格式 包含cost  1 含有type id value的key  
local function getConsumeByIDAndIndex(id, index, dataFormat)
	dataFormat = dataFormat or 0
	local GuildPrayConfig = GuildPrayConfig.Get()
	local prayConfig = GuildPrayConfig:getConfigContent(id)
	if dataFormat == 0 then
		if prayConfig and prayConfig.consume and prayConfig.consume[index] then
			return {prayConfig.consume[index].type, prayConfig.consume[index].id, prayConfig.consume[index].value, prayConfig.consume[index].cost, prayConfig.consume[index].contribution}
		else
			return nil
		end
	else
		if prayConfig and prayConfig.consume and prayConfig.consume[index] then
			return {type = prayConfig.consume[index].type, id = prayConfig.consume[index].id, value = prayConfig.consume[index].value}, prayConfig.consume[index].cost, prayConfig.consume[index].contribution
		else
			return nil
		end
	end
end

local function getPrayList(prayList)
	local amf_value = {}
	for k, v in pairs(prayList or {}) do
		for k2, v2 in pairs(v) do
			table.insert(amf_value, {
				k,
				v2._id,
				v2._index,
				getConsumeByIDAndIndex(v2._id, v2._index),
			})
		end
	end
	return amf_value
end

function deleteGuildPrayList(gid, pid) 
	local GuildPrayList = GuildPrayList.Get(gid)
	local success, deleteTb = GuildPrayList:deletePlayerAllPrayList(pid)

	--local guild = GuildManager.Get(gid)
	--if guild then
	--	for k, v in pairs(deleteTb) do
	--		EventManager.DispatchEvent("GUILD_PRAY_LIST_CHANGE", {guild = guild, list = {pid, v.id, v.index, getConsumeByIDAndIndex(v.id, v.index)}, type = 0});
	--	end
	--end

	local PrayPlayer = GuildPrayPlayer.Get(pid)
	if not PrayPlayer then
		yqinfo("Player %d fail to deleteGuildPrayList ", pid)
		return 
	end
	if (0 ~= PrayPlayer:updateData(PrayPlayer:getProgress(), PrayPlayer:getProgressFlag(), PrayPlayer:getLastSeekHelpTime(), PrayPlayer:getTodaySeekHelpCount(), PrayPlayer:getLastHelpTime(), PrayPlayer:getTodayHelpCount(), PrayPlayer:getHasDrawReward(), 0, PrayPlayer:getLastResetTime())) then
		yqinfo("Player %d fail to deleteGuildPrayList when leave guild, update player data fail", pid)
	end
end

function process_guild_query_pray_player_info(conn, pid , req)
	yqinfo("Player %d begin to query player info", pid)
	local sn = req[1]

	local player = PlayerManager.Get(pid);
	-- 玩家不存在
	if player.name == nil then
		yqinfo("Player %d fail to query pray info, player not exitst", pid)
		return conn:sendClientRespond(Command.C_GUILD_PRAY_QUERY_PLAYER_INFO_RESPOND, pid, {sn, Command.RET_CHARACTER_NOT_EXIST});
	end

	-- 玩家没有军团
	if player.guild == nil then --or player.level < 10 then
		yqinfo("Player %d fail to query pray info, dont has guild", pid)
		return conn:sendClientRespond(Command.C_GUILD_PRAY_QUERY_PLAYER_INFO_RESPOND, pid, {sn, Command.RET_GUILD_NOT_EXIST});
	end
	
	local GuildPrayPlayer = GuildPrayPlayer.Get(pid)	
	local playerInfo = GuildPrayPlayer:getPlayerInfo() 
	local todaySeekHelpCount = GuildPrayPlayer:getTodaySeekHelpCount()
	local todayHelpCount = GuildPrayPlayer:getTodayHelpCount()
	local amf_value = {
			playerInfo._id,
			playerInfo._progress,
			playerInfo._progress_flag,
			--playerInfo._last_seek_help_time,
			todaySeekHelpCount,
			--playerInfo._last_help_time,
			todayHelpCount,
			playerInfo._has_draw_reward,
			playerInfo._seek_help_flag,
			playerInfo._last_reset_time,
		}
	if playerInfo._id then
		local GuildPrayConfig = GuildPrayConfig.Get()
		local prayConfig = GuildPrayConfig:getConfigContent(playerInfo._id) 
		if prayConfig then
			table.insert(amf_value, prayConfig.product_type)
			table.insert(amf_value, prayConfig.product_id)
			table.insert(amf_value, prayConfig.product_value)
			local consume = {}
			for k, v in ipairs(prayConfig.consume or {}) do
				table.insert(consume, {v.type, v.id, v.value, v.cost})	
			end
			table.insert(amf_value, consume)
		end
	end

	yqinfo("Player %d success to query pray player info", pid)
	return conn:sendClientRespond(Command.C_GUILD_PRAY_QUERY_PLAYER_INFO_RESPOND, pid, {sn, Command.RET_SUCCESS, amf_value});
end

function process_guild_pray_reset(conn, pid, req)
	local sn = req[1]
	local type = req[2]  -- 0 免费  1 消耗
	if not type then
		yqinfo("Player %d fail to pray reset , arg 2nd is nil", pid)
		return conn:sendClientRespond(Command.C_GUILD_PRAY_RESET_RESPOND, pid, {sn, Command.RET_PARAM_ERROR});
	end	
	yqinfo("Player %d begin to pray reset type:%d", pid, type)

	local player = PlayerManager.Get(pid);
	-- 玩家不存在
	if player.name == nil then
		yqinfo("Player %d fail to  pray reset, player not exist", pid)
		return conn:sendClientRespond(Command.C_GUILD_PRAY_RESET_RESPOND, pid, {sn, Command.RET_CHARACTER_NOT_EXIST});
	end

	-- 玩家没有军团
	if player.guild == nil then --or player.level < 10 then
		yqinfo("Player %d fail to pray reset, dont has guild", pid)
		return conn:sendClientRespond(Command.C_GUILD_PRAY_RESET_RESPOND, pid, {sn, Command.RET_GUILD_NOT_EXIST});
	end

	--check
	local GuildPrayPlayer = GuildPrayPlayer.Get(pid)	
	if not GuildPrayPlayer then
		yqinfo("Player %d fail to pray reset, cannt get GuildPrayPlayer", pid)
		return conn:sendClientRespond(Command.C_GUILD_PRAY_RESET_RESPOND, pid, {sn, Command.RET_ERROR});
	end

	if type == 1 then
		local hasDrawReward = GuildPrayPlayer:getHasDrawReward()
		if hasDrawReward == 1 then
			yqinfo("Player %d fail to pray reset, reset type is 1 and already has draw reward", pid)
			return conn:sendClientRespond(Command.C_GUILD_PRAY_RESET_RESPOND, pid, {sn, Command.RET_ERROR});
		end
	end
	
	local consume = {}
	if type == 1 then
		consume = {{type = COST.type, id = COST.id, value= 100}}
	end
	local respond = cell.sendReward(pid, {}, consume, Command.REASON_CONSUME_TYPE_PRAY_RESET)
	if not respond or respond.result ~= Command.RET_SUCCESS then
		yqinfo("Player %d fail to pray reset, cell error", pid)
		return conn:sendClientRespond(Command.C_GUILD_PRAY_RESET_RESPOND, pid, {sn, Command.RET_ERROR});
	end

	if type == 0 then
		local lastResetTime = GuildPrayPlayer:getLastResetTime()
		if StableTime.get_begin_time_of_day(loop.now()) <= StableTime.get_begin_time_of_day(lastResetTime)  then
			yqinfo("Player %d fail to pray reset, cd", pid)
			return conn:sendClientRespond(Command.C_GUILD_PRAY_RESET_RESPOND, pid, {sn, Command.RET_ERROR});
		end
	end

	if (0 ~= GuildPrayPlayer:forceFresh(type)) then
		yqinfo("Player %d fail to pray reset, forceFresh error", pid)
		return conn:sendClientRespond(Command.C_GUILD_PRAY_RESET_RESPOND, pid, {sn, Command.RET_ERROR});
	end
	
	local GuildPrayList = GuildPrayList.Get(player.guild.id)
	local success, deleteTb = GuildPrayList:deletePlayerAllPrayList(pid)

	--for k, v in pairs(deleteTb) do
	--	EventManager.DispatchEvent("GUILD_PRAY_LIST_CHANGE", {guild = player.guild, list = {pid, v.id, v.index, getConsumeByIDAndIndex(v.id, v.index)}, type = 0});
	--end

	local playerInfo = GuildPrayPlayer:getPlayerInfo() 
	local todaySeekHelpCount = GuildPrayPlayer:getTodaySeekHelpCount()
	local todayHelpCount = GuildPrayPlayer:getTodayHelpCount()
	local amf_value = {
			playerInfo._id,
			playerInfo._progress,
			playerInfo._progress_flag,
			--playerInfo._last_seek_help_time,
			todaySeekHelpCount,
			--playerInfo._last_help_time,
			todayHelpCount,
			playerInfo._has_draw_reward,
			playerInfo._seek_help_flag,
			playerInfo._last_reset_time,
		}
	if playerInfo._id then
		local GuildPrayConfig = GuildPrayConfig.Get()
		local prayConfig = GuildPrayConfig:getConfigContent(playerInfo._id) 
		if prayConfig then
			table.insert(amf_value, prayConfig.product_type)
			table.insert(amf_value, prayConfig.product_id)
			table.insert(amf_value, prayConfig.product_value)
			local consume = {}
			for k, v in ipairs(prayConfig.consume or {}) do
				table.insert(consume, {v.type, v.id, v.value, v.cost})	
			end
			table.insert(amf_value, consume)
		end
	end

	return conn:sendClientRespond(Command.C_GUILD_PRAY_RESET_RESPOND, pid, {sn, Command.RET_SUCCESS, amf_value});
end

function process_guild_update_pray_progress(conn, pid , req)
	local sn = req[1]
	local type = req[2] or 0
	local id = req[3]
	local index = req[4]
	if  not id or not index then
		yqinfo("Player %d fail to update pray progress, param 3rd or 4th is nil", pid)
		return conn:sendClientRespond(Command.C_GUILD_PRAY_UPDATE_PROGRESS_RESPOND, pid, {sn, Command.RET_PARAM_ERROR});
	end
	yqinfo("Player %d begin to update pray progress type:%d id:%d index:%d", pid, req[2], req[3], req[4])
	
	local player = PlayerManager.Get(pid);
	-- 玩家不存在
	if player.name == nil then
		yqinfo("Player %d fail to update pray progress, player not exitst", pid)
		return conn:sendClientRespond(Command.C_GUILD_PRAY_UPDATE_PROGRESS_RESPOND, pid, {sn, Command.RET_CHARACTER_NOT_EXIST});
	end

	-- 玩家没有军团
	if player.guild == nil then --or player.level < 10 then
		yqinfo("Player %d fail to update pray progress, dont has guild", pid)
		return conn:sendClientRespond(Command.C_GUILD_PRAY_UPDATE_PROGRESS_RESPOND, pid, {sn, Command.RET_GUILD_NOT_EXIST});
	end

	local GuildPrayConfig = GuildPrayConfig.Get()
	local prayConfig = GuildPrayConfig:getConfigContent(id) 
	if not prayConfig then
		yqinfo("Player %d fail to update pray progress cannot get config for id:%d",pid, id)
		return conn:sendClientRespond(Command.C_GUILD_PRAY_UPDATE_PROGRESS_RESPOND, pid, {sn, Command.RET_ERROR});
	end
	if index > #prayConfig.consume then
		yqinfo("Player %d fail to update pray progress index:%d too big",pid, index)
		return conn:sendClientRespond(Command.C_GUILD_PRAY_UPDATE_PROGRESS_RESPOND, pid, {sn, Command.RET_ERROR});
	end

	local GuildPrayPlayer = GuildPrayPlayer.Get(pid)	
	local serverCfgID = GuildPrayPlayer:getCfgID()	
	if not serverCfgID then
		yqinfo("Player %d fail to update pray progress cannot get cfgID",pid)
		return conn:sendClientRespond(Command.C_GUILD_PRAY_UPDATE_PROGRESS_RESPOND, pid, {sn, Command.RET_ERROR});
	end
	if serverCfgID ~= id then
		yqinfo("Player %d fail to update pray progress , server cfgID donot fit with  cfgID",pid)
		return conn:sendClientRespond(Command.C_GUILD_PRAY_UPDATE_PROGRESS_RESPOND, pid, {sn, Command.RET_ERROR});
	end

	local progressFlag = GuildPrayPlayer:getProgressFlag()	
	local can, retFlag = canUpdate(progressFlag, index)
	if not can then
		yqinfo("Player %d fail to update pray progress index:%d ,already update",pid, index)
		return conn:sendClientRespond(Command.C_GUILD_PRAY_UPDATE_PROGRESS_RESPOND, pid, {sn, Command.RET_ERROR});
	end	
	
	--consume
	local consume = {}
	if type == 0 then
		table.insert(consume, {type = prayConfig.consume[index].type, id = prayConfig.consume[index].id, value = prayConfig.consume[index].value})
	else
		consume = {{type = COST.type, id = COST.id, value = prayConfig.consume[index].cost}}
	end
	local respond = cell.sendReward(pid, {}, consume, Command.REASON_CONSUME_TYPE_GUILD_UPDATE_PRAY_PROGRESS);
	if not respond or respond.result ~= Command.RET_SUCCESS then
		yqinfo("Player %d fail to update pray progress index:%d ,consume fail",pid, index)
		return conn:sendClientRespond(Command.C_GUILD_PRAY_UPDATE_PROGRESS_RESPOND, pid, {sn, Command.RET_ERROR});
	end
	if 0 ~= (GuildPrayPlayer:updateData(GuildPrayPlayer:getProgress()+1, retFlag, GuildPrayPlayer:getLastSeekHelpTime(), GuildPrayPlayer:getTodaySeekHelpCount(), GuildPrayPlayer:getLastHelpTime(), GuildPrayPlayer:getTodayHelpCount(), GuildPrayPlayer:getHasDrawReward(), GuildPrayPlayer:getSeekHelpFlag(), GuildPrayPlayer:getLastResetTime())) then
		yqinfo("Player %d fail to update pray progress index:%d ,updateData fail",pid, index)
		return conn:sendClientRespond(Command.C_GUILD_PRAY_UPDATE_PROGRESS_RESPOND, pid, {sn, Command.RET_ERROR});
	end
	yqinfo("Player %d success to update pray progress", pid)

	local GuildPrayList	 = GuildPrayList.Get(player.guild.id)
	if not GuildPrayList then
		yqinfo("Player %d fail to update pray progress, cannot get pray list", pid)
		return conn:sendClientRespond(Command.C_GUILD_PRAY_UPDATE_PROGRESS_RESPOND, pid, {sn, Command.RET_ERROR});
	end

	GuildPrayList:deletePlayerPrayList(pid, id, index)

	cell.NotifyQuestEvent(pid, { { type = 75, id = 1, count = 1 }, }) 

	return conn:sendClientRespond(Command.C_GUILD_PRAY_UPDATE_PROGRESS_RESPOND, pid, {sn, Command.RET_SUCCESS});
end

function process_guild_draw_pray_reward(conn, pid, req)
	local sn = req[1]
	local id = req[2]
	if not id  then
		yqinfo("Player %d fail to draw pray reward, param 2nd  is nil", pid)
		return conn:sendClientRespond(Command.C_GUILD_PRAY_DRAW_REWARD_RESPOND, pid, {sn, Command.RET_ERROR});
	end
	yqinfo("Player %d begin to draw pray reward for id:%d", pid, id)

	local player = PlayerManager.Get(pid);
	-- 玩家不存在
	if player.name == nil then
		yqinfo("Player %d fail to draw pray reward, player not exitst", pid)
		return conn:sendClientRespond(Command.C_GUILD_PRAY_DRAW_REWARD_RESPOND, pid, {sn, Command.RET_CHARACTER_NOT_EXIST});
	end

	-- 玩家没有军团
	if player.guild == nil then --or player.level < 10 then
		yqinfo("Player %d fail to draw pray reward, dont has guild", pid)
		return conn:sendClientRespond(Command.C_GUILD_PRAY_DRAW_REWARD_RESPOND, pid, {sn, Command.RET_GUILD_NOT_EXIST});
	end

	local GuildPrayPlayer = GuildPrayPlayer.Get(pid)	

	local serverCfgID = GuildPrayPlayer:getCfgID()	
	if  not serverCfgID then
		yqinfo("Player %d fail to draw pray reward cannot get  cfgID",pid)
		return conn:sendClientRespond(Command.C_GUILD_PRAY_DRAW_REWARD_RESPOND, pid, {sn, Command.RET_ERROR});
	end
	if  serverCfgID ~= id then
		yqinfo("Player %d fail to draw pray reward ,server cfgID donot fit with client cfgID",pid)
		return conn:sendClientRespond(Command.C_GUILD_PRAY_DRAW_REWARD_RESPOND, pid, {sn, Command.RET_ERROR});
	end

	local hasDrawReward = GuildPrayPlayer:getHasDrawReward()	
	if not hasDrawReward then
		yqinfo("Player %d fail to draw pray reward, param 2nd is nil", pid)
		return conn:sendClientRespond(Command.C_GUILD_PRAY_DRAW_REWARD_RESPOND, pid, {sn, Command.RET_ERROR});
	end
	if hasDrawReward == 1 then
		yqinfo("Player %d fail to draw pray reward, already has draw", pid)
		return conn:sendClientRespond(Command.C_GUILD_PRAY_DRAW_REWARD_RESPOND, pid, {sn, Command.RET_ERROR});
	end
	local progress = GuildPrayPlayer:getProgress()
	if not progress then
		yqinfo("Player %d fail to draw pray reward, cannot get progress", pid)
		return conn:sendClientRespond(Command.C_GUILD_PRAY_DRAW_REWARD_RESPOND, pid, {sn, Command.RET_ERROR});
	end
	local GuildPrayConfig = GuildPrayConfig.Get()
	local prayConfig = GuildPrayConfig:getConfigContent(id) 
	if not prayConfig then
		yqinfo("Player %d fail to draw pray reward, cannot get prayconfig for id:%d", pid, id)
		return conn:sendClientRespond(Command.C_GUILD_PRAY_DRAW_REWARD_RESPOND, pid, {sn, Command.RET_ERROR});
	end
	local progress_needed = prayConfig.progress_needed
	if progress < progress_needed then
		yqinfo("Player %d fail to draw pray reward, progress not enough", pid)
		return conn:sendClientRespond(Command.C_GUILD_PRAY_DRAW_REWARD_RESPOND, pid, {sn, Command.RET_ERROR});
	end
	-- send reward
	local reward = {{type = prayConfig.product_type, id = prayConfig.product_id, value = prayConfig.product_value}}	
	local respond = cell.sendReward(pid, reward, {}, Command.REASON_CONSUME_TYPE_GUILD_DRAW_PRAY_REWARD);
	if not respond or respond.result ~= Command.RET_SUCCESS then
		yqinfo("Player %d fail to draw pray reward, sendreward fail", pid)
		return conn:sendClientRespond(Command.C_GUILD_PRAY_DRAW_REWARD_RESPOND, pid, {sn, Command.RET_ERROR});
	end
	if 0 ~= GuildPrayPlayer:updateData(GuildPrayPlayer:getProgress(), GuildPrayPlayer:getProgressFlag(), GuildPrayPlayer:getLastSeekHelpTime(), GuildPrayPlayer:getTodaySeekHelpCount(), GuildPrayPlayer:getLastHelpTime(), GuildPrayPlayer:getTodayHelpCount(), 1,GuildPrayPlayer:getSeekHelpFlag(), GuildPrayPlayer:getLastResetTime()) then
		yqinfo("Player %d fail to draw pray reward, updateData fail", pid)
		return conn:sendClientRespond(Command.C_GUILD_PRAY_DRAW_REWARD_RESPOND, pid, {sn, Command.RET_ERROR});
	end

	cell.NotifyQuestEvent(pid, { { type = 76, id = 1, count = 1 }, }) 
	
	return conn:sendClientRespond(Command.C_GUILD_PRAY_DRAW_REWARD_RESPOND, pid, {sn, Command.RET_SUCCESS});
end

function process_guild_seek_pray_help(conn, pid, req)
	local sn = req[1]
	local id = req[2]
	local index = req[3]

	if not id  then
		yqinfo("Player %d fail to seek pray help, param 2nd  is nil", pid)
		return conn:sendClientRespond(Command.C_GUILD_PRAY_SEEK_HELP_RESPOND, pid, {sn, Command.RET_ERROR});
	end
	yqinfo("Player %d begin to seek pray help for id:%d index:%d", pid, id, index)

	local player = PlayerManager.Get(pid);
	-- 玩家不存在
	if player.name == nil then
		yqinfo("Player %d fail to seek pray help, player not exitst", pid)
		return conn:sendClientRespond(Command.C_GUILD_PRAY_SEEK_HELP_RESPOND, pid, {sn, Command.RET_CHARACTER_NOT_EXIST});
	end

	-- 玩家没有军团
	if player.guild == nil then --or player.level < 10 then
		yqinfo("Player %d fail to seek pray help, dont has guild", pid)
		return conn:sendClientRespond(Command.C_GUILD_PRAY_SEEK_HELP_RESPOND, pid, {sn, Command.RET_GUILD_NOT_EXIST});
	end

	local GuildPrayPlayer = GuildPrayPlayer.Get(pid)	

	local serverCfgID = GuildPrayPlayer:getCfgID()	
	if  not serverCfgID then
		yqinfo("Player %d fail to seek pray help cannot get cfgID",pid)
		return conn:sendClientRespond(Command.C_GUILD_PRAY_SEEK_HELP_RESPOND, pid, {sn, Command.RET_ERROR});
	end
	if  serverCfgID ~= id then
		yqinfo("Player %d fail to seek pray help , server cfgID donot fit with client cfgID",pid)
		return conn:sendClientRespond(Command.C_GUILD_PRAY_SEEK_HELP_RESPOND, pid, {sn, Command.RET_ERROR});
	end

	local GuildPrayConfig = GuildPrayConfig.Get()
	local prayConfig = GuildPrayConfig:getConfigContent(id) 
	if not prayConfig then
		yqinfo("Player %d fail to seek pray help, cannot get config for id:%d",pid, id)
		return conn:sendClientRespond(Command.C_GUILD_PRAY_UPDATE_PROGRESS_RESPOND, pid, {sn, Command.RET_ERROR});
	end
	if index > #prayConfig.consume then
		yqinfo("Player %d fail to seek pray help , index too big",pid)
		return conn:sendClientRespond(Command.C_GUILD_PRAY_SEEK_HELP_RESPOND, pid, {sn, Command.RET_ERROR});
	end
	
	local todaySeekHelpCount = GuildPrayPlayer:getTodaySeekHelpCount()
	if not todaySeekHelpCount then
		yqinfo("Player %d fail to seek pray help , cannot get helped_count",pid)
		return conn:sendClientRespond(Command.C_GUILD_PRAY_SEEK_HELP_RESPOND, pid, {sn, Command.RET_ERROR});
	end
	
	if todaySeekHelpCount >= MAX_HELPED_COUNT then
		yqinfo("Player %d fail to seek pray help , helped_count already max",pid)
		return conn:sendClientRespond(Command.C_GUILD_PRAY_SEEK_HELP_RESPOND, pid, {sn, Command.RET_MAX_HELPED});
	end

	local progressFlag = GuildPrayPlayer:getProgressFlag()	
	local notfinish, _ = canUpdate(progressFlag, index)
	if not notfinish then
		yqinfo("Player %d fail to seek pray help  ,already finished",pid)
		return conn:sendClientRespond(Command.C_GUILD_PRAY_SEEK_HELP_RESPOND, pid, {sn, Command.RET_ERROR});
	end

	local seekHelpFlag = GuildPrayPlayer:getSeekHelpFlag()
	if not seekHelpFlag then
		yqinfo("Player %d fail to seek pray help , cannot get seekHelpFlag",pid)
		return conn:sendClientRespond(Command.C_GUILD_PRAY_SEEK_HELP_RESPOND, pid, {sn, Command.RET_ERROR});
	end
	local can, retFlag = canUpdate(seekHelpFlag, index)
	if not can then
		yqinfo("Player %d fail to seek pray help  index:%d ,already release this help",pid, index)
		return conn:sendClientRespond(Command.C_GUILD_PRAY_SEEK_HELP_RESPOND, pid, {sn, Command.RET_ERROR});
	end	
	if (0 ~= GuildPrayPlayer:updateData(GuildPrayPlayer:getProgress(), GuildPrayPlayer:getProgressFlag(), loop.now(), GuildPrayPlayer:getTodaySeekHelpCount()+1, GuildPrayPlayer:getLastHelpTime(), GuildPrayPlayer:getTodayHelpCount(), GuildPrayPlayer:getHasDrawReward(), retFlag, GuildPrayPlayer:getLastResetTime())) then
		yqinfo("Player %d fail to seek pray help index:%d ,updateData fail",pid, index)
		return conn:sendClientRespond(Command.C_GUILD_PRAY_SEEK_HELP_RESPOND, pid, {sn, Command.RET_ERROR});
	end
	local gid = player.guild.id
	local GuildPrayList = GuildPrayList.Get(gid)
	if (0 ~= GuildPrayList:insertNewList(pid, id, index)) then
		yqinfo("Player %d fail to seek pray help index:%d ,insertNewList fail",pid, index)
		return conn:sendClientRespond(Command.C_GUILD_PRAY_SEEK_HELP_RESPOND, pid, {sn, Command.RET_ERROR});
	end

	EventManager.DispatchEvent("GUILD_PRAY_LIST_CHANGE", {guild = player.guild, list = {pid, id , index, getConsumeByIDAndIndex(id, index)}, type = 1});

	return conn:sendClientRespond(Command.C_GUILD_PRAY_SEEK_HELP_RESPOND, pid, {sn, Command.RET_SUCCESS});
end

function onServiceSeekPrayHelp(conn, channel, request)
	local pid = request.pid
	local sn = request.sn or 0

	log.debug(string.format("onServiceSeekPrayHelp: ai %d seek for help.", pid))

	local player = PlayerManager.Get(pid)

	-- 玩家不存在
	if player == nil then
		log.warning(string.format("onServiceSeekPrayHelp: player %d is not exist.", pid))
		return
	end

	-- 玩家没有军团
	if player.guild == nil then
		log.warning(string.format("onServiceSeekPrayHelp: player %d guild is not exist.", pid))
		return 
	end

	local GuildPrayPlayer = GuildPrayPlayer.Get(pid)	
	local serverCfgID = GuildPrayPlayer:getCfgID()	
	if not serverCfgID then
		log.warning(string.format("onServiceSeekPrayHelp: player %d fail to seek pray help cannot get cfgID", pid))
		return
	end

	local GuildPrayConfig = GuildPrayConfig.Get()
	local prayConfig = GuildPrayConfig:getConfigContent(serverCfgID) 
	if not prayConfig then
		log.warning(string.format("onServiceSeekPrayHelp: Player %d fail to seek pray help, cannot get config for id: %d", pid, serverCfgID))
		return
	end
	
	-- 找到还没进行完成的
	local progressFlag = GuildPrayPlayer:getProgressFlag()	
	local index = 0
	for i = 1, #prayConfig.consume do
		if canUpdate(progressFlag, i) then
			index = i
			break
		end 
	end

	if index > #prayConfig.consume or index == 0 then
		log.info(string.format("onServiceSeekPrayHelp: Player %d fail to seek pray help, index is %d", pid, index))
		return
	end
	
	local seekHelpFlag = GuildPrayPlayer:getSeekHelpFlag()
	if not seekHelpFlag then
		log.info(string.format("Player %d fail to seek pray help , cannot get seekHelpFlag", pid))
		return
	end

	local can, retFlag = canUpdate(seekHelpFlag, index)
	if not can then
		log.info(string.format("Player %d fail to seek pray help  index:%d, already release this help", pid, index))
		return
	end
		
	if (0 ~= GuildPrayPlayer:updateData(GuildPrayPlayer:getProgress(), GuildPrayPlayer:getProgressFlag(), loop.now(), GuildPrayPlayer:getTodaySeekHelpCount()+1, 
		GuildPrayPlayer:getLastHelpTime(), GuildPrayPlayer:getTodayHelpCount(), GuildPrayPlayer:getHasDrawReward(), retFlag, GuildPrayPlayer:getLastResetTime())) then
		log.info(string.format("Player %d fail to seek pray help index:%d ,updateData fail", pid, index))
		return
	end

	local gid = player.guild.id
	local GuildPrayList = GuildPrayList.Get(gid)
	if (0 ~= GuildPrayList:insertNewList(pid, id, index)) then
		log.info("Player %d fail to seek pray help index:%d ,insertNewList fail",pid, index)
		return
	end

	EventManager.DispatchEvent("GUILD_PRAY_LIST_CHANGE", { guild = player.guild, list = { pid, serverCfgID, index, getConsumeByIDAndIndex(serverCfgID, index) }, type = 1 })
end

function process_guild_query_pray_list(conn, pid, req)
	local sn = req[1]
	yqinfo("Player %d begin to query pray list ", pid)

	local player = PlayerManager.Get(pid);
	-- 玩家不存在
	if player.name == nil then
		yqinfo("Player %d fail to query pray list, player not exitst", pid)
		return conn:sendClientRespond(Command.C_GUILD_PRAY_QUERY_LIST_RESPOND, pid, {sn, Command.RET_CHARACTER_NOT_EXIST});
	end

	-- 玩家没有军团
	if player.guild == nil then --or player.level < 10 then
		yqinfo("Player %d fail to query pray list, dont has guild", pid)
		return conn:sendClientRespond(Command.C_GUILD_PRAY_QUERY_LIST_RESPOND, pid, {sn, Command.RET_GUILD_NOT_EXIST});
	end
	
	local guild = player.guild
	local GuildPrayList = GuildPrayList.Get(guild.id)		
	local prayList = GuildPrayList:getPrayList()
	return conn:sendClientRespond(Command.C_GUILD_PRAY_QUERY_LIST_RESPOND, pid, {sn, Command.RET_SUCCESS, getPrayList(prayList)});
end

function process_guild_pray_help_others(conn, pid, req)
	local sn = req[1]
	local type = req[2]
	local targetID = req[3]
	local id = req[4]
	local index = req[5]
	if not type or not targetID or not id or not index then
		yqinfo("Player %d fail to help others, 2nd or 3rd or 4th or 5th arg is nil", pid)
	end
	yqinfo("Player %d begin to help others", pid)

	if pid == targetID then
		yqinfo("Player %d fail to help others, same pid and targetID", pid)
		return conn:sendClientRespond(Command.C_GUILD_PRAY_HELP_OTHERS_RESPOND, pid, {sn, Command.RET_GUILD_SAME_PID});
	end

	local player = PlayerManager.Get(pid);
	-- 玩家不存在
	if player.name == nil then
		yqinfo("Player %d fail to help others, player not exist", pid)
		return conn:sendClientRespond(Command.C_GUILD_PRAY_HELP_OTHERS_RESPOND, pid, {sn, Command.RET_CHARACTER_NOT_EXIST});
	end

	-- 玩家没有军团
	if player.guild == nil then --or player.level < 10 then
		yqinfo("Player %d fail to help others, dont has guild", pid)
		return conn:sendClientRespond(Command.C_GUILD_PRAY_HELP_OTHERS_RESPOND, pid, {sn, Command.RET_GUILD_NOT_EXIST});
	end

	local guild = player.guild
	local target = PlayerManager.Get(targetID) 
	if target.name == nil then
		yqinfo("Player %d fail to help others, target not exist", pid)
		return conn:sendClientRespond(Command.C_GUILD_PRAY_HELP_OTHERS_RESPOND, pid, {sn, Command.RET_TARGET_NOT_EXIST});
	end

	-- 目标没有军团
	if target.guild == nil then --or player.level < 10 then
		yqinfo("Player %d fail to help others, dont has guild", pid)
		return conn:sendClientRespond(Command.C_GUILD_PRAY_HELP_OTHERS_RESPOND, pid, {sn, Command.RET_GUILD_TARGET_GUILD_NOT_EXIST});
	end
	
	if guild.id ~= target.guild.id then
		yqinfo("Player %d fail to help others, not in same guild with %d", pid, targetID)
		return conn:sendClientRespond(Command.C_GUILD_PRAY_HELP_OTHERS_RESPOND, pid, {sn, Command.RET_GUILD_TARGET_GUILD_NOT_SAME});
	end

	local PrayPlayer = GuildPrayPlayer.Get(pid)
	local TargetGuildPrayPlayer = GuildPrayPlayer.Get(targetID)	

	if PrayPlayer:getTodayHelpCount() > MAX_HELP_COUNT then
		yqinfo("Player %d fail to help others, help count max", pid)
		return conn:sendClientRespond(Command.C_GUILD_PRAY_HELP_OTHERS_RESPOND, pid, {sn, Command.RET_MAX_HELP});
	end

	local serverCfgID = TargetGuildPrayPlayer:getCfgID()	
	if  not serverCfgID then
		yqinfo("Player %d fail to help others get cfgID",pid)
		return conn:sendClientRespond(Command.C_GUILD_PRAY_HELP_OTHERS_RESPOND, pid, {sn, Command.RET_PARAM_ERROR});
	end
	if  serverCfgID ~= id then
		yqinfo("Player %d fail to help others , server cfgID donot fit with client cfgID",pid)
		return conn:sendClientRespond(Command.C_GUILD_PRAY_HELP_OTHERS_RESPOND, pid, {sn, Command.RET_PARAM_ERROR});
	end

	local seekHelpFlag = TargetGuildPrayPlayer:getSeekHelpFlag()
	local needntHelp = canUpdate(seekHelpFlag, index)
	if needntHelp then
		yqinfo("Player %d fail to help others  ,neednt help",pid)
		return conn:sendClientRespond(Command.C_GUILD_PRAY_HELP_OTHERS_RESPOND, pid, {sn, Command.RET_GUILD_NEEDNT_HELP});
	end
	
	local progressFlag = TargetGuildPrayPlayer:getProgressFlag()	
	local can, retFlag = canUpdate(progressFlag, index)
	if not can then
		yqinfo("Player %d fail to help others  ,already finished",pid)
		return conn:sendClientRespond(Command.C_GUILD_PRAY_HELP_OTHERS_RESPOND, pid, {sn, Command.RET_GUILD_PRAY_ALREADY_FINISHED});
	end
	
	local GuildPrayList	 = GuildPrayList.Get(guild.id)
	if not GuildPrayList then
		yqinfo("Player %d fail to help others, cannot get pray list", pid)
		return conn:sendClientRespond(Command.C_GUILD_PRAY_HELP_OTHERS_RESPOND, pid, {sn, Command.RET_ERROR});
	end
	if (0 ~= GuildPrayList:deletePlayerPrayList(targetID, id, index)) then
		yqinfo("Player %d fail to help others, delete pray list fail", pid)
		return conn:sendClientRespond(Command.C_GUILD_PRAY_HELP_OTHERS_RESPOND, pid, {sn, Command.RET_ERROR});
	end	

	if (0 ~= TargetGuildPrayPlayer:updateData(TargetGuildPrayPlayer:getProgress()+1, retFlag, TargetGuildPrayPlayer:getLastSeekHelpTime(), TargetGuildPrayPlayer:getTodaySeekHelpCount(), TargetGuildPrayPlayer:getLastHelpTime(), TargetGuildPrayPlayer:getTodayHelpCount(), TargetGuildPrayPlayer:getHasDrawReward(), TargetGuildPrayPlayer:getSeekHelpFlag(), TargetGuildPrayPlayer:getLastResetTime())) then
		yqinfo("Player %d fail to help others, update player data fail", pid)
		return conn:sendClientRespond(Command.C_GUILD_PRAY_HELP_OTHERS_RESPOND, pid, {sn, Command.RET_ERROR});
	end
	
	if (0 ~= PrayPlayer:updateData(PrayPlayer:getProgress(), PrayPlayer:getProgressFlag(), PrayPlayer:getLastSeekHelpTime(), PrayPlayer:getTodaySeekHelpCount(), loop.now(), PrayPlayer:getTodayHelpCount()+1, PrayPlayer:getHasDrawReward(), PrayPlayer:getSeekHelpFlag(), PrayPlayer:getLastResetTime())) then
		yqinfo("Player %d fail to help others, update player data fail", pid)
		return conn:sendClientRespond(Command.C_GUILD_PRAY_HELP_OTHERS_RESPOND, pid, {sn, Command.RET_ERROR});
	end

	local consume, cost, contributionValue = getConsumeByIDAndIndex(id, index, 1)
	if not consume then
		yqinfo("Player %d fail to help others, cannot get consume", pid)
		return conn:sendClientRespond(Command.C_GUILD_PRAY_HELP_OTHERS_RESPOND, pid, {sn, Command.RET_ERROR});
	end
	if type == 0 then
		consume = {consume}
	else
		consume = {{type = COST.type, id = COST.id, value = cost}}
	end

	local respond = cell.sendReward(pid, {{type = CONTRIBUTION.type, id = CONTRIBUTION.id, value = contributionValue}}, consume, Command.REASON_CONSUME_TYPE_GUILD_PRAY_HELP_OTHERS);
	if not respond or respond.result ~= Command.RET_SUCCESS then
		yqinfo("Player %d fail to help others, cell error", pid)
		if respond.result == Command.RET_NOT_ENOUGH then
			return conn:sendClientRespond(Command.C_GUILD_PRAY_HELP_OTHERS_RESPOND, pid, {sn, Command.RET_NOT_ENOUGH});
		else
			return conn:sendClientRespond(Command.C_GUILD_PRAY_HELP_OTHERS_RESPOND, pid, {sn, Command.RET_EXCHANGE_ERROR});
		end	
	end 

	cell.NotifyQuestEvent(pid, { { type = 77, id = 1, count = 1 }, }) 

	-- add log
	local guild_pray_log = GuildPrayLog.Get(guild.id)
	if guild_pray_log then
		guild_pray_log:AddLog(1, {pid, targetID})
	end

	EventManager.DispatchEvent("GUILD_PRAY_PROGRESS_CHANGE", {pid = targetID, id = id, index = index});
	--EventManager.DispatchEvent("GUILD_PRAY_LIST_CHANGE", {guild = target.guild, list = {targetID, id , index, getConsumeByIDAndIndex(id, index)}, type = 0});
	return conn:sendClientRespond(Command.C_GUILD_PRAY_HELP_OTHERS_RESPOND, pid, {sn, Command.RET_SUCCESS});
end

function onServiceHelpOtherPray(conn, channel, request)
	local pid = request.pid
	local sn = request.sn	

	local player = PlayerManager.Get(pid);
	-- 玩家不存在
	if player == nil then
		log.warning(string.format("onServiceHelpOtherPray: Player %d fail to help others, player not exist", pid))
		return
	end

	-- 玩家没有军团
	if player.guild == nil then
		log.warning(string.format("onServiceHelpOtherPray: Player %d fail to help others, has not guild", pid))
		return
	end

	local guild = player.guild
	local GuildPrayConfig = GuildPrayConfig.Get()
	-- 找到还没进行完成的
	local targetID = 0
	local index = 0
	local progressFlag = 0
	for id, _ in pairs(guild.members or {}) do 
		local guildPrayPlayer = GuildPrayPlayer.Get(id)	
		local serverCfgID = guildPrayPlayer:getCfgID() or 0	
		progressFlag = guildPrayPlayer:getProgressFlag()	
		local prayConfig = GuildPrayConfig:getConfigContent(serverCfgID) 
		if prayConfig then 
			for i = 1, #prayConfig.consume do
				local TargetGuildPrayPlayer = GuildPrayPlayer.Get(id)	
				local seekHelpFlag = TargetGuildPrayPlayer:getSeekHelpFlag()
				local needntHelp = canUpdate(seekHelpFlag, i)
				if canUpdate(progressFlag, i) and not needntHelp then
					targetID = id
					index = i
					break
				end 
			end
		end
		if targetID ~= 0 and targetID ~= pid then
			break
		end
	end 
	
	log.debug(string.format("onServiceHelpOtherPray: targetID = %d, index = %d", targetID, index))

	if targetID == 0 or targetID == pid or index == 0 then
		log.info(string.format("onServiceHelpOtherPray: can not find suitable target %d, index %d", targetID, index))
		return
	end	

	local target = PlayerManager.Get(targetID)
	if target == nil then
		log.info(string.format("onServiceHelpOtherPray: Player %d fail to help others, target not exist", pid))
		return
	end

	-- 目标没有军团
	if target.guild == nil then
		log.error(string.format("onServiceHelpOtherPray: Player %d fail to help others, dont has guild", pid))
		return
	end
	
	if guild.id ~= target.guild.id then
		log.error(string.format("onServiceHelpOtherPray: Player %d fail to help others, not in same guild with %d", pid, targetID))
		return
	end

	local PrayPlayer = GuildPrayPlayer.Get(pid)
	local TargetGuildPrayPlayer = GuildPrayPlayer.Get(targetID)	
	local seekHelpFlag = TargetGuildPrayPlayer:getSeekHelpFlag()
	local needntHelp = canUpdate(seekHelpFlag, index)
	if needntHelp then
		log.info(string.format("Player %d fail to help others, neednt help", pid))
		return
	end
		
	local GuildPrayList = GuildPrayList.Get(guild.id)
	if not GuildPrayList then
		log.warning(string.format("onServiceHelpOtherPray: Player %d fail to help others, cannot get pray list", pid))
		return
	end

	local GuildPrayPlayer = GuildPrayPlayer.Get(targetID)	
	local serverCfgID = GuildPrayPlayer:getCfgID() or 0	
	if (0 ~= GuildPrayList:deletePlayerPrayList(targetID, serverCfgID, index)) then
		log.info(string.format("onServiceHelpOtherPray: Player %d fail to help others, delete pray list fail", pid))
		return
	end	

	local _, retFlag = canUpdate(progressFlag, index)

	if (0 ~= TargetGuildPrayPlayer:updateData(TargetGuildPrayPlayer:getProgress()+1, retFlag, TargetGuildPrayPlayer:getLastSeekHelpTime(), TargetGuildPrayPlayer:getTodaySeekHelpCount(), TargetGuildPrayPlayer:getLastHelpTime(), TargetGuildPrayPlayer:getTodayHelpCount(), TargetGuildPrayPlayer:getHasDrawReward(), TargetGuildPrayPlayer:getSeekHelpFlag(), TargetGuildPrayPlayer:getLastResetTime())) then
		log.warning(string.format("onServiceHelpOtherPray: Player %d fail to help others, update player data fail", pid))
		return
	end
	
	if (0 ~= PrayPlayer:updateData(PrayPlayer:getProgress(), PrayPlayer:getProgressFlag(), PrayPlayer:getLastSeekHelpTime(), PrayPlayer:getTodaySeekHelpCount(), loop.now(), PrayPlayer:getTodayHelpCount()+1, PrayPlayer:getHasDrawReward(), PrayPlayer:getSeekHelpFlag(), PrayPlayer:getLastResetTime())) then
		log.warning(string.format("Player %d fail to help others, update player data fail", pid))
		return
	end
	
	-- add log
	local guild_pray_log = GuildPrayLog.Get(guild.id)
	if guild_pray_log then
		guild_pray_log:AddLog(1, {pid, targetID})
	end

	EventManager.DispatchEvent("GUILD_PRAY_PROGRESS_CHANGE", { pid = targetID, id = serverCfgID, index = index })
end



















