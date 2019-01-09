require "ArenaPlayerPool"
require "ArenaFightRecord"
require "ArenaEnemyConfigManager"
require "ArenaConfigManager"
require "printtb"
local Property = require "Property"
local protobuf = require "protobuf"
local sprinttb = sprinttb
local cell = require "cell"
local getPlayerFightData = ArenaPlayerPool.GetPlayerFightData
local getAIFightData = ArenaPlayerPool.GetAIFightData
local addPlayerFightData = ArenaPlayerPool.AddPlayerFightData
local ArenaPlayerPool = ArenaPlayerPool.Get()
local bit32 = require "bit32"
local base64 = require "base64"
local CHALLENGE_TICKET = {type = 41, id = 90007, value = 1}

local ArenaPlayerBoxReward = require "ArenaPlayerBoxReward"
local GetPlayerBoxReward = ArenaPlayerBoxReward.GetPlayerBoxReward
require "ArenaRewardConfig"
require "ArenaBuffConfig"
require "MailReward"

local OpenlevConfig = require "OpenlevConfig" 

local AI_ENABLE = true 
local AI_RANGE = 110000

local function encode(protocol, msg)
    local code = protobuf.encode("com.agame.protocol." .. protocol, msg);
    if code == nil then
        print(string.format(" * encode %s failed", protocol));
        loop.exit();
        return nil;
    end
    return code;
end

local function decode(code, protocol)
    return protobuf.decode("com.agame.protocol." .. protocol, code);
end

local function have_ticket(pid)
	local respond = cell.sendReward(pid, nil, { { type = 41, id = 90007, value = 0 }, }) 
	if respond and respond.result == 0 then
		return true
	else
		return false
	end
end

local ARENA_REWARD = {
	{type = 1, condition = 1, reward_type = 41, reward_id = 90002, reward_value = 300,  reward_type2 = 41, reward_id2 = 90401, reward_value2 = 2},
	{type = 1, condition = 2, reward_type = 41, reward_id = 90002, reward_value = 500,  reward_type2 = 41, reward_id2 = 90401, reward_value2 = 4},
	{type = 1, condition = 3, reward_type = 41, reward_id = 90002, reward_value = 800,  reward_type2 = 41, reward_id2 = 90401, reward_value2 = 6},
	{type = 3, condition = 2, reward_type = 41, reward_id = 90002, reward_value = 300,  reward_type2 = 41, reward_id2 = 90401, reward_value2 = 1},
	{type = 2, condition = 1, reward_type = 41, reward_id = 90002, reward_value = 3000, reward_type2 = 41, reward_id2 = 90401, reward_value2 = 10},
	{type = 2, condition = 2, reward_type = 41, reward_id = 90002, reward_value = 5000, reward_type2 = 41, reward_id2 = 90402, reward_value2 = 12},
	{type = 2, condition = 3, reward_type = 41, reward_id = 90002, reward_value = 8000, reward_type2 = 41, reward_id2 = 90403, reward_value2 = 15},
}

local function getRewardList(type, condition, isAmf)   --1胜利奖励   2宝箱奖励
	if type == 1 then
		local reward 
		if isAmf then
			reward = {
				{ARENA_REWARD[condition].reward_type, ARENA_REWARD[condition].reward_id, ARENA_REWARD[condition].reward_value},
				{ARENA_REWARD[condition].reward_type2, ARENA_REWARD[condition].reward_id2, ARENA_REWARD[condition].reward_value2},
			}
		else
			reward = {
				{type = ARENA_REWARD[condition].reward_type, id = ARENA_REWARD[condition].reward_id, value = ARENA_REWARD[condition].reward_value},
				{type = ARENA_REWARD[condition].reward_type2, id = ARENA_REWARD[condition].reward_id2, value = ARENA_REWARD[condition].reward_value2},
			}
		end
		return reward 
	else
		for k, v in ipairs(ARENA_REWARD) do
			if v.type == type and v.condition == condition then
				local reward
				if isAmf then
					reward = {
						{ARENA_REWARD[k].reward_type, ARENA_REWARD[k].reward_id, ARENA_REWARD[k].reward_value},
						{ARENA_REWARD[k].reward_type2,ARENA_REWARD[k].reward_id2,ARENA_REWARD[k].reward_value2},
					}
				else
					reward = {
						{type = ARENA_REWARD[k].reward_type, id = ARENA_REWARD[k].reward_id, value = ARENA_REWARD[k].reward_value},
						{type = ARENA_REWARD[k].reward_type2, id = ARENA_REWARD[k].reward_id2, value = ARENA_REWARD[k].reward_value2},
					}
				end
				return reward
			end
		end
	end	
end

local function getWinReward(enemyPower, playerPower, isAmf)
	--local difficult = ArenaConfigManager.GetDifficult(enemyPower, playerPower)
	--return getRewardList(1, difficult, isAmf)
end

local playerPower = {}
function getPlayerPower(pid)
	return playerPower[pid] and playerPower[pid] or 0
end

function resetPlayerPower(pid)
	if playerPower[pid] then
		playerPower[pid] = nil
	end
end

local player_last_join_time = {}
function process_arena_join_arena(conn, pid , req)
	yqinfo("%d begin to join arena", pid)
	-- refresh player data
	if not player_last_join_time[pid] or loop.now() - player_last_join_time[pid] > 30 * 3600 then
		getPlayerFightData(pid, true)		
	end
	
	local sn = req[1]
	local power = req[2]
	if not power or (power < 100)then
		yqinfo("%d fail to join arena , arg 2nd is nil", pid)
		conn:sendClientRespond(Command.S_ARENA_JOIN_ARENA, pid, {sn, Command.RET_SUCCESS})
		return 
	end
	playerPower[pid] = power
	if ArenaPlayerPool:playerInPool(pid) then
		yqinfo("%d fail to join arena , player has already in arena", pid)
		conn:sendClientRespond(Command.S_ARENA_JOIN_ARENA, pid, {sn, Command.RET_SUCCESS})
		return 
	else
		if (0 ~= ArenaPlayerPool:insertNewPlayer(pid)) then
			yqinfo("%d fail to join arena , insert new player fail", pid)
			conn:sendClientRespond(Command.S_ARENA_JOIN_ARENA, pid, {sn, Command.RET_ERROR})
		else
			conn:sendClientRespond(Command.S_ARENA_JOIN_ARENA, pid, {sn, Command.RET_SUCCESS})
			return
		end
	end		
end

local function canDraw(pid, index) 
	local canDraw = false
	local mask = 2^(index-1)
	local arenaFightRecord = ArenaFightRecord.Get(pid)
	if not arenaFightRecord then
		yqinfo("%d fail to canDraw , cannot get fight record", pid)
		return false 
	end
	local winCount = arenaFightRecord:getThisRoundWinCount()
	if not winCount then
		yqinfo("%d fail to canDraw , cannot get winCount or inspireCount", pid)
		return false
	end
	local nowFlag = ArenaPlayerPool:getRewardFlag(pid)	
	local maxDrawIndex = math.floor(winCount/3)
	if bit32.band(nowFlag, mask) == 0 and maxDrawIndex >= index then
		return true,bit32.bor(nowFlag, mask)
	else
		return false
	end
end

local reward_config = {
	[1] = {type = 41, id = 90002, value = 10},
	[2] = {type = 41, id = 90002, value = 20},
	[3] = {type = 41, id = 90002, value = 30},
}

local function getCanDrawIndex(rewardFlag, maxDrawIndex)
	local indexTb = {}
	for i=1,maxDrawIndex,1 do
		local mask = 2^(i-1)
		if (bit32.band(rewardFlag, mask) == 0) then
			table.insert(indexTb, i)
			bit32.bor(rewardFlag, mask)
		end
	end	
	return indexTb, rewardFlag
end

local function GetDropReward(drops, first_time)
	local ret = cell.getDropsReward(drops, first_time)--cell.sendReward(0, nil, nil, 0, false, nil, "", drops, nil, first_time, 0)
	if ret then
		local content = {}
		for k, v in ipairs(ret) do
			table.insert(content, {type = v.type, id = v.id, value = v.value})
		end
		return true, Command.RET_SUCCESS, content
	else
		return false
	end
end

local function addItemToList(list, item, n)
    for _, v in ipairs(list) do
        if v.type == item.type and v.id == item.id then
            v.value = v.value + item.value * n
            return
        end
    end
    table.insert(list, {type = item.type, id = item.id, value = item.value * n});

    return list
end

local function mergeItem(list1, list2, n)
    n = n or 1

    for _, v in ipairs(list2) do
        addItemToList(list1, v, n, need_mark);
    end
    return list1
end

local function checkAndSendReward(pid)
	print("check and send reward >>>>>>>>>>")
	if not ArenaPlayerPool:playerInPool(pid) then
		yqinfo("%d fail to checkAndSendReward, player not in arena", pid)
		return
	end
	local rewardFlag = ArenaPlayerPool:getRewardFlag(pid)
	if not rewardFlag then
		yqinfo("%d fail to checkAndSendReward, cannot get rewad flag", pid)
		return
	end	
	local arenaFightRecord = ArenaFightRecord.Get(pid)
	if not arenaFightRecord then
		yqinfo("%d fail to checkAndSendReward , cannot get fight record", pid)
		return nil
	end
	local winCount = arenaFightRecord:getThisRoundWinCount()
	if not winCount then
		yqinfo("%d fail to checkAndSendReward , cannot get winCount or inspireCount", pid)
		return 
	end
	local maxDrawIndex = math.floor(winCount/3)
	local indexTb, flag = getCanDrawIndex(rewardFlag, maxDrawIndex)
	
	local player_box_reward = GetPlayerBoxReward(pid) 

	for _, idx in ipairs(indexTb) do
		local rewards, drops = player_box_reward:GetRewardList(idx)
		if not rewards then
			yqinfo("%d fail to checkAndSendReward, reward for %d is nil", pid, idx)
		else
			-- send mail
			local final_rewards = {}
			mergeItem(final_rewards, rewards)
			if #drops ~= 0 then
				local success, err, drop_rewards = GetDropReward(drops, 0)
				if success and #rewards > 0 then
					mergeItem(final_rewards, drop_rewards)
				end	
			end

			print("final reward >>>>>>>>>>", sprinttb(final_rewards))
			if not send_arena_mail(pid, "英雄比拼" .. idx * 3 .. "胜奖励", "恭喜您获得英雄比拼" .. idx * 3 .. "胜宝箱", final_rewards) then
				yqinfo("send arena mail failed.")
			end
		end
	end
	ArenaPlayerPool:updateRewardFlag(pid, flag)	
	return
end

local ENEMY_LIST_MAX_SIZE = 9
local RESET_CD = 2*3600
local function checkAndLoadEnemyList(pid, force, ignore_cd)
	local arenaFightRecord = ArenaFightRecord.Get(pid)
	if not arenaFightRecord then
		yqinfo("%d fail to check and load enemyList , cannot get fight record", pid)
		return nil, nil
	end
	local fightRecord = arenaFightRecord:getAllFightRecord()
	if #fightRecord > 0 and not force then
		local enemyList = {}
		for _, fight_record in ipairs(fightRecord) do
			local power, name
			local enemy_id = fight_record.enemy_id
			if enemy_id < AI_RANGE then
				name = ArenaEnemyConfigManager.getEnemyInfoByPid(enemy_id).name and ArenaEnemyConfigManager.getEnemyInfoByPid(enemy_id).name or ""
				power = ArenaEnemyConfigManager.getEnemyInfoByPid(enemy_id).power and ArenaEnemyConfigManager.getEnemyInfoByPid(enemy_id).power or 0
			else
				_, _, name = getPlayerFightData(enemy_id) 
				power = fight_record.capacity
			end

			table.insert(enemyList, { fight_record.enemy_id, name, fight_record.has_win, fight_record.buff_increase_percent, fight_record.fight_count, power, fight_record.reward_id })
		end
		return enemyList, nil  
	else	
		if force then
			local now = loop.now()
			local lastResetTime = ArenaPlayerPool:getLastResetTime(pid)
			if not ignore_cd and ((not lastResetTime) or (now - lastResetTime < RESET_CD)) then
				return nil, 1
			end
		
			if not ignore_cd then
				ArenaPlayerPool:updateLastResetTime(pid, now)		
			end
		end
		local cell_res = cell.getPlayer(pid)	
		local _, power = getPlayerFightData(pid)
		if not power then
			yqinfo("%d fail to check and load enemyList, can not get power", pid)
			return nil, nil
		end
		local averagePower = ArenaPlayerPool:getEnemyAveragePower(pid) 	
		if averagePower == 0 then
			yqinfo("%d just join arena and first get enemy list, his power is:%d", pid, power)
			averagePower = power
		end

		--build enemyList
		local enemyList = {}
		local winRate = ArenaPlayerPool:getWinRate(pid)
		local powerRange = ArenaConfigManager.getPowerRange(averagePower, winRate)
		local mask = {}
		mask[pid] = 1
		for k,v in ipairs(powerRange) do
			if v.range then
				local list = ArenaEnemyConfigManager.getEnemyList(v.powerLower, v.powerUpper, v.range, mask)
				for _, pid in ipairs(list) do
					local _, power, name = getPlayerFightData(pid) 
					table.insert(enemyList, { pid, name, 0, 0, 0, power, RandomEnemyRewardConfig(k) })
					mask[pid] = 1
				end
				local balance = v.range - #list

				--ai enemy
				if balance ~= 0 and AI_ENABLE then
					local ai_list = ArenaEnemyConfigManager.getAIEnemyList(v.powerLower, v.powerUpper, balance, mask)
					for _, pid in ipairs(ai_list) do
						local name = ArenaEnemyConfigManager.getEnemyInfoByPid(pid).name and ArenaEnemyConfigManager.getEnemyInfoByPid(pid).name or ""
                    				local power = ArenaEnemyConfigManager.getEnemyInfoByPid(pid).power and ArenaEnemyConfigManager.getEnemyInfoByPid(pid).power or 0
						table.insert(enemyList, { pid, name, 0, 0, 0, power, RandomEnemyRewardConfig(k) })
						mask[pid] = 1
					end
					balance = balance - #ai_list
				end

				for i = k-1, 1, -1 do
					if balance == 0 then
						break	
					end
					local difflist  = ArenaEnemyConfigManager.getEnemyList(powerRange[i].powerLower, powerRange[i].powerUpper, balance, mask)
					for _,pid in ipairs(difflist) do
						local _, power, name = getPlayerFightData(pid) 
						table.insert(enemyList, { pid, name, 0, powerRange[k].powerRateBegin - powerRange[i].powerRateBegin, 0, power, RandomEnemyRewardConfig(k) })
						mask[pid] = 1
					end	
					balance = balance - #difflist

					--ai enemy
					if balance ~= 0 and AI_ENABLE then
						local ai_difflist  = ArenaEnemyConfigManager.getAIEnemyList(powerRange[i].powerLower, powerRange[i].powerUpper, balance, mask)
						for _,pid in ipairs(ai_difflist) do
							local name = ArenaEnemyConfigManager.getEnemyInfoByPid(pid).name and ArenaEnemyConfigManager.getEnemyInfoByPid(pid).name or ""
							local power = ArenaEnemyConfigManager.getEnemyInfoByPid(pid).power and ArenaEnemyConfigManager.getEnemyInfoByPid(pid).power or 0
							table.insert(enemyList, { pid, name, 0, powerRange[k].powerRateBegin - powerRange[i].powerRateBegin, 0, power, RandomEnemyRewardConfig(k) })
							mask[pid] = 1
						end	
						balance = balance - #difflist
					end
				end
			else				-- 随机范围中随机
				local powerLower, powerUpper = v.powerLower, v.powerUpper
				local loop_count = 0
				while #enemyList < ENEMY_LIST_MAX_SIZE do
					local n = ENEMY_LIST_MAX_SIZE - #enemyList
					local list = ArenaEnemyConfigManager.getEnemyList(powerLower, powerUpper, n, mask)
					for _, pid in ipairs(list) do
						local _, power, name = getPlayerFightData(pid) 
						local difficulty = ArenaConfigManager.getDifficulty(power, averagePower)
						table.insert(enemyList, { pid, name, 0, 0, 0, power, RandomEnemyRewardConfig(difficulty) })
						mask[pid] = 1
					end
					n = n - #list

					--ai enemy
					if AI_ENABLE and n > 0 then
						local ai_list = ArenaEnemyConfigManager.getAIEnemyList(powerLower, powerUpper, n, mask)
						for _,pid in ipairs(ai_list) do
							local name = ArenaEnemyConfigManager.getEnemyInfoByPid(pid).name and ArenaEnemyConfigManager.getEnemyInfoByPid(pid).name or ""
							local power = ArenaEnemyConfigManager.getEnemyInfoByPid(pid).power and ArenaEnemyConfigManager.getEnemyInfoByPid(pid).power or 0
							
							local difficulty = ArenaConfigManager.getDifficulty(power, averagePower)
							table.insert(enemyList, { pid, name, 0, 0, 0, power, RandomEnemyRewardConfig(difficulty) })
						end
					end

					if loop_count >= 10 then
						break
					end

					loop_count = loop_count + 1
					powerLower = (powerLower - math.floor(averagePower * 0.1)) > 0 and (powerLower - math.floor(averagePower * 0.1)) or 0
					powerUpper = powerUpper + math.floor(averagePower * 0.1)  
				end
			end	
		end

		
		if #enemyList < ENEMY_LIST_MAX_SIZE then
			log.warning("checkAndLoadEnemyList: load enemyList not enough, load size is ", #enemyList)
		end

		checkAndSendReward(pid)
		arenaFightRecord:deleteAllFightRecord()
		for  _,enemy in ipairs(enemyList) do
			local code, _ 
			-- ai
			if enemy[1] <= AI_RANGE then
				code = getAIFightData(enemy[1], false, enemy[4]) 
			else	
				code, _ = getPlayerFightData(enemy[1], false, enemy[4])
			end
			arenaFightRecord:addNewFightRecord(enemy[1], enemy[4], base64.encode(code), enemy[7])
		end	
		ArenaPlayerPool:updateInspireCount(pid, 0)
		ArenaPlayerPool:updateBuff(pid, "")
		ArenaPlayerPool:updateRewardFlag(pid, 0)

		--update box reward 
		local level = OpenlevConfig.get_level(pid)
		local player_box_reward = GetPlayerBoxReward(pid) 
		local reward_id1 = GetBoxRewardID(3, level)
		local reward_id2 = GetBoxRewardID(6, level)
		local reward_id3 = GetBoxRewardID(9, level)
		player_box_reward:UpdatePlayerBoxReward(reward_id1, reward_id2, reward_id3, level)

		return enemyList, nil
	end
end

local function queryBoxReward(pid)
	local reward_amf = {}
	local player_box_reward = GetPlayerBoxReward(pid) 

	for i = 1, 3, 1 do
		local reward = player_box_reward:GetRewardList(i) 	
		local amf_value = {}
		for k, v in ipairs(reward or {}) do
			table.insert(amf_value, {v.type, v.id, v.value})
		end
		table.insert(reward_amf, amf_value)		
	end

	return reward_amf
end

function process_arena_get_enemy_list(conn, pid, req)
	yqinfo("%d begin to get arena enemy list", pid)
	local sn = req[1]
	if not ArenaPlayerPool:playerInPool(pid) then
		yqinfo("%d fail to get arena enemy list , player not in arena", pid)
		conn:sendClientRespond(Command.S_ARENA_GET_ENEMY_LIST, pid, {sn, Command.RET_ERROR})
		return 
	end
	local enemyList = checkAndLoadEnemyList(pid)
	local rewardAmf = queryBoxReward(pid)
	if not enemyList then
		yqinfo("%d fail to get arena enemy list , check and load fail", pid)	
		conn:sendClientRespond(Command.S_ARENA_GET_ENEMY_LIST, pid, {sn, Command.RET_ERROR})
		return
		
	else
		conn:sendClientRespond(Command.S_ARENA_GET_ENEMY_LIST, pid, {sn, Command.RET_SUCCESS, enemyList, rewardAmf})
		return
	end
end

local function str_split(str, pattern)
	local arr ={}
	while true do
		if #str==0 then
			return arr
		end
		local pos,last =string.find(str, pattern)
		if not pos then
			table.insert(arr, str)
			return arr
		end
		if pos>1 then
			table.insert(arr, string.sub(str, 1, pos-1))
		end
		if last<#str then
			str =string.sub(str, last+1, -1)
		else
			return arr
		end
	end
end

local ENEMY_POWER_HISTORY_SIZE = 5
local function getNewEnemyPowerHistory(history, new)
	local ret = str_split(history, "[| ]")
	local a = {}
	if #ret == 0 then
		return tostring(new)
	end
	if #ret < ENEMY_POWER_HISTORY_SIZE then
		return history.."|"..tostring(new)
	end
	local pos = string.find(history,'|')
	local subStr = string.sub(history, pos+1)
	return subStr.."|"..tostring(new)
end

-- 返回匹配战力
local function getAvgValue(history, pid)	
	local arr = str_split(history, "|")
	local total = 0
	if #arr == 0 then	
		local _, power, name = getPlayerFightData(pid) 
		return power
	end
	for _, v in ipairs(arr) do
		total = total + tonumber(v)
	end
	return math.floor(total / #arr) 
end

function process_arena_update_fight_result(conn, pid, req)
	local sn = req[1]
	local enemyID = req[2]
	local fightResult = req[3]	
	yqinfo("player %d begin to update fight result for arena  enemy:%d fight_result:%d", pid, enemyID, fightResult)
	if not ArenaPlayerPool:playerInPool(pid) then
		yqinfo("%d fail to update fight result , player not in arena", pid)
		conn:sendClientRespond(Command.S_ARENA_UPDATE_FIGHT_RESULT, pid, {sn, Command.RET_ERROR})
		return 
	end
	checkAndLoadEnemyList(pid)
	local arenaFightRecord = ArenaFightRecord.Get(pid)
	if not arenaFightRecord then
		yqinfo("%d fail to update fight result , cannot get fight record", pid)
		conn:sendClientRespond(Command.S_ARENA_UPDATE_FIGHT_RESULT, pid, {sn, Command.RET_ERROR})
		return 
	end
	local hasWin = arenaFightRecord:getHasWin(enemyID)
	if hasWin == nil then
		yqinfo("%d fail to update fight result , cannot get fight record for enemy:%d", pid, enemyID)
		conn:sendClientRespond(Command.S_ARENA_UPDATE_FIGHT_RESULT, pid, {sn, Command.RET_ERROR})
		return 
	end
	if hasWin == 1 then
		yqinfo("%d fail to update fight result , already win", pid)
		conn:sendClientRespond(Command.S_ARENA_UPDATE_FIGHT_RESULT, pid, {sn, Command.RET_ERROR})
		return 
	end

	local rewardID = arenaFightRecord:getRewardID(enemyID)
	log.debug("rewardID = ", rewardID)
	local rewards = GetArenaEnemyRewardConfig(rewardID)
	if not rewards then
		yqinfo("enemy dont has reward")
	end

	local real_reward_list = {}
	
	if fightResult == 1 then
		--胜利奖励
		if rewards.drop_id then
			-- cell.sendReward(pid, rewards.reward, nil, Command.REASON_ARENA_WIN)
			local drop_reward = cell.sendDropReward(pid, { rewards.drop_id }, Command.REASON_ARENA_WIN)
			for _, v in ipairs(drop_reward or {}) do
				table.insert(real_reward_list, {v.type, v.id, v.value, v.uuid})
			end
		end
	end
	
	--consume
	if fightResult == 1 then
		local respond = cell.sendReward(pid, nil, {CHALLENGE_TICKET}, Command.REASON_ARENA_CHALLENGE)
		if not respond or respond.result ~= Command.RET_SUCCESS then
			yqinfo("%d fail to process fight, consume fail", pid)
			return conn:sendClientRespond(Command.S_ARENA_UPDATE_FIGHT_RESULT, pid, {sn, Command.RET_ERROR})
		end
		cell.NotifyQuestEvent(pid, {{type = 33,id = 2,  count = 1}})
	else	
		cell.NotifyQuestEvent(pid, {{type = 33,id = 3,  count = 1}})
	end

	--quest
	cell.NotifyQuestEvent(pid, {{type = 4, id = 16, count = 1}})
	cell.NotifyQuestEvent(pid, {{type = 33,id = 1,  count = 1}})

	local now = loop.now()
    arenaFightRecord:updateFightRecord(enemyID, fightResult, arenaFightRecord:getFightCount(enemyID)+1, now, arenaFightRecord:getBuffIncreasePercent(enemyID))
	if fightResult == 1 then
		local enemyPower
		if pid <= AI_RANGE then
			enemyPower = ArenaEnemyConfigManager.getPowerByEnemyID(enemyID)
		else
			local arenaFightRecord = ArenaFightRecord.Get(pid)
			enemyPower = arenaFightRecord:getCapacity(enemyID)
		end
		
		local _, power, name = getPlayerFightData(pid) 
		-- local enemyPowerHistory = getNewEnemyPowerHistory(ArenaPlayerPool:getEnemyPowerHistory(pid), enemyPower)
		local enemyPowerHistory = getNewEnemyPowerHistory(ArenaPlayerPool:getEnemyPowerHistory(pid), power)
		log.debug("============================ power, enemyPowerHistory: ", power, enemyPowerHistory)
		ArenaPlayerPool:updatePlayerPoolData(pid,enemyPowerHistory, ArenaPlayerPool:getWinCount(pid) + 1, now, ArenaPlayerPool:getFightTotalCount(pid) + 1, now, ArenaPlayerPool:getLastResetTime(pid), ArenaPlayerPool:getRewardFlag(pid), ArenaPlayerPool:getBuff(pid), ArenaPlayerPool:getInspireCount(pid), ArenaPlayerPool:getConstWinCount(pid) + 1)
		conn:sendClientRespond(Command.S_ARENA_UPDATE_FIGHT_RESULT, pid, {sn, Command.RET_SUCCESS, ArenaPlayerPool:getWinRate(pid), getAvgValue(enemyPowerHistory or "", pid), real_reward_list })
	else
		ArenaPlayerPool:updatePlayerPoolData(pid,ArenaPlayerPool:getEnemyPowerHistory(pid), ArenaPlayerPool:getWinCount(pid), ArenaPlayerPool:getLastWinTime(pid), ArenaPlayerPool:getFightTotalCount(pid) + 1, now, ArenaPlayerPool:getLastResetTime(pid), ArenaPlayerPool:getRewardFlag(pid), ArenaPlayerPool:getBuff(pid), ArenaPlayerPool:getInspireCount(pid), 0)
		conn:sendClientRespond(Command.S_ARENA_UPDATE_FIGHT_RESULT, pid, {sn, Command.RET_SUCCESS, ArenaPlayerPool:getWinRate(pid), getAvgValue(enemyPowerHistory or "", pid), real_reward_list })
	end

	cell.NotifyQuestEvent(pid, { {type = 33, id = 4, count = ArenaPlayerPool:getConstWinCount(pid) }})
end

function process_arena_reset_enemy_list(conn, pid, req)
	local sn = req[1]
	local ignore_cd = req[2] or false
	yqinfo("player %d begin to reset enemy list ignore_cd", pid)	
	if not ArenaPlayerPool:playerInPool(pid) then
		yqinfo("%d fail to reset enemy list, player not in arena", pid)
		conn:sendClientRespond(Command.C_ARENA_RESET_ENEMY_LIST_RESPOND, pid, {sn, Command.RET_ERROR})
		return 
	end
	if ignore_cd then
		local respond = cell.sendReward(pid, nil, {{type = 41, id = 90006, value = 10}}, Command.REASON_ARENA_RESET_ENEMY_LIST) 
		if not respond or respond.result ~= Command.RET_SUCCESS then
			return conn:sendClientRespond(Command.C_ARENA_RESET_ENEMY_LIST_RESPOND, pid, {sn, Command.RET_NOT_ENOUGH})
		end
	end

	local enemyList, error = checkAndLoadEnemyList(pid, true, ignore_cd)

	local rewardAmf = {}
	table.insert(rewardAmf, getRewardList(2,1,1))
	table.insert(rewardAmf, getRewardList(2,2,1))
	table.insert(rewardAmf, getRewardList(2,3,1))

	if enemyList then
		conn:sendClientRespond(Command.C_ARENA_RESET_ENEMY_LIST_RESPOND, pid, {sn, Command.RET_SUCCESS, enemyList, rewardAmf})
		return
	else
		if error and error == 1 then
			yqinfo("%d fail to reset enemy list, cd", pid)
			conn:sendClientRespond(Command.C_ARENA_RESET_ENEMY_LIST_RESPOND, pid, {sn, Command.RET_ERROR})
			return
		else
			yqinfo("%d fail to reset enemy list, reload enemy list fail", pid)
			conn:sendClientRespond(Command.C_ARENA_RESET_ENEMY_LIST_RESPOND, pid, {sn, Command.RET_ERROR})
			return
		end
	end	
end

local function buildBuffTable(buffStr)
    local ret = str_split(buffStr, "|")
    local ret_tb = {}
    for k,v in ipairs(ret) do
        local kv_pair = str_split(v, ":")
        ret_tb[tonumber(kv_pair[1])] = tonumber(kv_pair[2])
    end
    return ret_tb
end

local function buildBuffStr(buffTb)
    local ret
    for k,v in pairs(buffTb) do
        local str = k..":"..v
        ret = ret and ret.."|"..str or str
    end
    return ret
end

local function getNewBuff(oldBuff, buffType, value)
    local buffTable = buildBuffTable(oldBuff)
    buffTable[buffType] = buffTable[buffType] or 0
    buffTable[buffType] = buffTable[buffType] + value 
    local buffStr = buildBuffStr(buffTable)
    return buffStr
end

local MAX_INSPIRE_COUNT = 2
function process_arena_inspire_player(conn, pid, req)
	local sn = req[1]
	yqinfo("player %d begin to inspire player", pid)
	if not ArenaPlayerPool:playerInPool(pid) then
		yqinfo("%d fail to inspire player, player not in arena", pid)
		conn:sendClientRespond(Command.C_ARENA_INSPIRE_PLAYER_RESPOND, pid, {sn, Command.RET_ERROR})
		return
	end
	local buff_gid = req[2]
	if not buff_gid then
		yqinfo("%d fail to inspire player, arg 2nd buff_gid is nil", pid)
		conn:sendClientRespond(Command.C_ARENA_INSPIRE_PLAYER_RESPOND, pid, {sn, Command.RET_PARAM_ERROR})
		return
	end
	--check
	local arenaFightRecord = ArenaFightRecord.Get(pid)
	if not arenaFightRecord then
		yqinfo("%d fail to inspire player , cannot get fight record", pid)
		conn:sendClientRespond(Command.C_ARENA_INSPIRE_PLAYER_RESPOND, pid, {sn, Command.RET_ERROR})
		return 
	end
	local winCount = arenaFightRecord:getThisRoundWinCount()
	local inspireCount = ArenaPlayerPool:getInspireCount(pid)	
	if (not winCount) or (not inspireCount) then
		yqinfo("%d fail to inspire player , cannot get winCount or inspireCount", pid)
		conn:sendClientRespond(Command.C_ARENA_INSPIRE_PLAYER_RESPOND, pid, {sn, Command.RET_ERROR})
		return
	end	
	if math.floor(winCount/2) <= inspireCount then --((winCount < 8 and math.floor(winCount/3) <= inspireCount) or (winCount >= 8 and inspireCount >= 3)) and inspireCount <= MAX_INSPIRE_COUNT then
		yqinfo("%d fail to inspire player , no more chance to inspire  winCount %d  inspireCount %d", pid, winCount, inspireCount)
		conn:sendClientRespond(Command.C_ARENA_INSPIRE_PLAYER_RESPOND, pid, {sn, Command.RET_ERROR})
		return
	end	

	local buff = ArenaPlayerPool:getBuff(pid) 
	local buff_cfg = GetArenaBuffConfig(buff_gid)
	if not buff_cfg then
		yqinfo("%d fail to inspire player , cannt get buff config", pid)
		conn:sendClientRespond(Command.C_ARENA_INSPIRE_PLAYER_RESPOND, pid, {sn, Command.RET_ERROR})
	end

	for k, v in ipairs(buff_cfg.buff) do
		buff = getNewBuff(buff, v.buff_type, v.buff_value)
	end
	
	log.debug("buff>>>>>>>>>>>>>>>>>>>>>",buff)

	--local buff = getNewBuff(ArenaPlayerPool:getBuff(pid), buffType, 5)
	if (0 ~= ArenaPlayerPool:updatePlayerPoolData(pid,ArenaPlayerPool:getEnemyPowerHistory(pid), ArenaPlayerPool:getWinCount(pid), ArenaPlayerPool:getLastWinTime(pid), ArenaPlayerPool:getFightTotalCount(pid), ArenaPlayerPool:getLastFightTime(pid), ArenaPlayerPool:getLastResetTime(pid), ArenaPlayerPool:getRewardFlag(pid), buff, ArenaPlayerPool:getInspireCount(pid) + 1, ArenaPlayerPool:getConstWinCount(pid))) then
		conn:sendClientRespond(Command.C_ARENA_INSPIRE_PLAYRE_RESPOND, pid, {sn, Command.RET_ERROR})
		return
	end
		conn:sendClientRespond(Command.C_ARENA_INSPIRE_PLAYER_RESPOND, pid, {sn, Command.RET_SUCCESS})
		return
end

function process_arena_draw_reward(conn, pid, req)
	local sn = req[1]
	yqinfo("player %d begin to draw reward", pid)	
	if not ArenaPlayerPool:playerInPool(pid) then
		yqinfo("%d fail to draw reward, player not in arena", pid)
		conn:sendClientRespond(Command.C_ARENA_DRAW_REWARD_RESPOND, pid, {sn, Command.RET_ERROR})
		return
	end
	local index = req[2]
	if not index then
		yqinfo("%d fail to draw reward, arg 2nd is nil", pid)
		conn:sendClientRespond(Command.C_ARENA_DRAW_REWARD_RESPOND, pid, {sn, Command.RET_PARAM_ERROR})
		return
	end
	local rewardFlag = ArenaPlayerPool:getRewardFlag(pid)
	if not rewardFlag then
		yqinfo("%d fail to draw reward, cannot get rewad flag", pid)
		conn:sendClientRespond(Command.C_ARENA_DRAW_REWARD_RESPOND, pid, {sn, Command.RET_ERROR})
		return
	end	
	local canDraw, flag = canDraw(pid, index)
	
	local player_box_reward = GetPlayerBoxReward(pid) 
	local rewards, drops = player_box_reward:GetRewardList(index)	

	if canDraw then
		if not rewards then
			yqinfo("%d fail to draw reward, reward is nil", pid)
			return 
		end

		cell.sendReward(pid, rewards, nil, Command.REASON_ARENA_REWARD)
		if #drops ~= 0 then
			if not cell.sendDropReward(pid, drops, Command.REASON_ARENA_REWARD, loop.now()) then
				return conn:sendClientRespond(Command.C_ARENA_DRAW_REWARD_RESPOND, pid, { sn, Command.RET_ERROR })
			end
		end

		ArenaPlayerPool:updateRewardFlag(pid, flag)
		conn:sendClientRespond(Command.C_ARENA_DRAW_REWARD_RESPOND, pid, {sn, Command.RET_SUCCESS})
		return
	end 	
	conn:sendClientRespond(Command.C_ARENA_DRAW_REWARD_RESPOND, pid, {sn, Command.RET_ERROR})
	return 
end

function process_arena_query_player_info(conn, pid, req)
	local sn = req[1]
	yqinfo("player %d begin to query player info in arena", pid)
	if not ArenaPlayerPool:playerInPool(pid) then
		yqinfo("%d fail to get player info, player not in arena", pid)
		conn:sendClientRespond(Command.C_ARENA_QUERY_PLAYER_INFO_RESPOND, pid, {sn, Command.RET_ERROR})
		return
	end
	local enemyPowerStr = ArenaPlayerPool:getEnemyPowerHistory(pid) or ""
	local num = getAvgValue(enemyPowerStr, pid)	
	local _, power, name = getPlayerFightData(pid) 

	local player_info = {
		ArenaPlayerPool:getLastResetTime(pid),
		ArenaPlayerPool:getRewardFlag(pid),
		ArenaPlayerPool:getBuff(pid),
		ArenaPlayerPool:getInspireCount(pid),
		ArenaPlayerPool:getWinRate(pid),
		num
	}

	log.debug("enemyPowerStr = ", enemyPowerStr)	
	log.debug("player_info: ", sprinttb(player_info))
	log.debug("power: ", power)

	conn:sendClientRespond(Command.C_ARENA_QUERY_PLAYER_INFO_RESPOND, pid, {sn, Command.RET_SUCCESS, player_info})
end

local function tableIncludeKey(tb, key)
	for k, v in pairs(tb) do
		if key == k then
			return true
		end
	end
	return false
end

function process_arena_fight_prepare(conn, pid, req)
	local sn = req[1]
	local target = req[2]
	if not target then
		yqinfo("Player %d fail to prepare fight in arena , param 2nd is nil", pid)
		return conn:sendClientRespond(Command.C_ARENA_FIGHT_PREPARE_RESPOND, pid, {sn, Command.RET_ERROR})
	end
	yqinfo("player %d begin to prepare fight in arena , target:%d", pid, target)

	-- 检查是否有挑战券
	if not have_ticket(pid) then
		log.warning(string.format("player %d has not challenge ticket.", pid))
		return conn:sendClientRespond(Command.C_ARENA_FIGHT_PREPARE_RESPOND, pid, { sn, Command.RET_ERROR })
	end
	
	attacker, err = cell.QueryPlayerFightInfo(pid, false, 0)
	if err then
		log.debug(string.format('load fight data of player %d error %s', pid, err))
		return conn:sendClientRespond(Command.C_ARENA_FIGHT_PREPARE_RESPOND, pid, {sn, Command.RET_ERROR});
	end

	--add buff
	local buff_tb = buildBuffTable(ArenaPlayerPool:getBuff(pid))
	for k, role in pairs(attacker.roles) do
		for _, v in ipairs(role.propertys) do
			if tableIncludeKey(buff_tb, v.type) then
				v.value = v.value + buff_tb[v.type]
				buff_tb[v.type] = nil
			end
		end
		for type, value in pairs(buff_tb) do
			table.insert(role.propertys, {type = type, value = value})
		end 
	end

	local arenaFightRecord = ArenaFightRecord.Get(pid)
	def_code = arenaFightRecord:getFightData(target);
	if not def_code then
		log.debug(string.format('load target fight data of player %d error', target))
		return conn:sendClientRespond(Command.C_ARENA_FIGHT_PREPARE_RESPOND, pid, {sn, Command.RET_ERROR});
	end

	local defender = decode(def_code, 'FightPlayer') 	

	for k, role in ipairs(defender.roles) do
		local property = {}
		for _, v in ipairs(role.propertys) do
			property[v.type] = (property[v.type] or 0) + v.value
		end
		--role.Property = Property(property);
	end
	scene = "18hao"

	local fightData = {
		attacker = attacker,
		defender = defender,
		seed = math.random(1, 0x7fffffff),
		scene = scene,
	}

	local code = encode('FightData', fightData);
	if code == nil then
		log.debug(string.format('encode fight data failed'));
		return conn:sendClientRespond(Command.C_ARENA_FIGHT_PREPARE_RESPOND, pid, {sn, Command.RET_ERROR});
	end
	
	-- fresh player fight data
	getPlayerFightData(pid, true)

	return conn:sendClientRespond(Command.C_ARENA_FIGHT_PREPARE_RESPOND, pid, {sn, Command.RET_SUCCESS, code})

end


