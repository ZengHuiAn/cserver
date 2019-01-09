package.cpath=package.cpath .. ";../lib/?.so";
package.path =package.path  .. ";../lib/?.lua";

local database = require "database"
local Thread = require "utils/Thread"
local TeamProxy = require "TeamProxy"
local TeamActivityConfig = require "TeamActivityConfig"
local TeamFightVM = require "TeamFightVM"
local bit32 = require "bit32"
local WELLRNG512a_ = require "WELLRNG512a"

local function SendDropReward(pid, consume, reason, drops, heros)
	local ret = cell.sendReward(pid, consume, nil, reason, false, nil, "", drops, heros)
	if type(ret)=='table' then
		if ret.result== Command.RET_SUCCESS then
			local content = {}
			for k, v in ipairs(ret.rewards) do
				table.insert(content, {v.type, v.id, v.value})
			end

			return true, Command.RET_SUCCESS, content 
		else
			if ret.result== Command.RET_NOT_ENOUGH then
				return false, Command.RET_NOT_ENOUGH
			else
				return false, Command.RET_ERROR
			end
		end
	else 
		return false, Command.RET_ERROR
	end
end

local function DOReward(pid, reward, consume, reason, manual, limit, name)
	assert(reason and reason ~= 0)

	if isEmptyOrNull(reward) and isEmptyOrNull(consume) then
		return true
	end

	local respond = cell.sendReward(pid, reward, consume, reason, manual, limit, name)
	if respond == nil or respond.result ~= 0 then
		return false;
	end

	return true;
end

ERROR_LOG = ERROR_LOG or function(...)
	log.error(...)
end


local update_list = {}
Scheduler.Register(function(t)
	for teamid, v in pairs(update_list) do
		for battle_id, info in pairs(v) do
			info.thread:send_message('UPDATE', t);
		end
	end
end)

local TeamBattle = {}
function TeamBattle:LoadScript(fileName)
	--load script
	local this = self;
	local log_key = string.format('TeamBattle[%d]', self.battle);
	local env = setmetatable({
		table = table,
		math  = math,
		string = string,
		ipairs = ipairs,
		pairs = pairs,
		tonumber = tonumber,
		tostring = tostring,
		type = type,
		unpack = table.unpack or unpack,
		select = select,
		next = next,
		assert = assert,
		bit32 = bit32,
		print = function(...) print(log_key, ...) end,
	}, {__index=function(t, k)
		if this["API_"..k] then
			return function(...)
				return this["API_" .. k](this, ...)
			end
		end
	end})

	local chunk, info = loadfile(fileName, "bt", env)
	if chunk == nil then
		log.error('TeamBattle loadfile', fileName, "failed", info);
		return false
	end

	local success, info = pcall(chunk);
	if not success then
		log.error('TeamBattle dofile', fileName, "failed", info);
		return false
	end

	self.script = env

	if env.Update or self.end_time > 0 then 
		update_list[self.teamid] = update_list[self.teamid] or {}
		update_list[self.teamid][self.battle] = self
	end

	return true;
end

local function LoadPlayers(teamid, battle_id)
	local t = {}
	local success, result = database.query("select pid, data1, data2, data3, data4, data5 from team_battle_player where teamid = %d and battle_id = %d", teamid, battle_id)
	if success then
		for _, row in ipairs(result) do
			t[row.pid] = {
				pid = row.pid,
				data = {row.data1, row.data2, row.data3, row.data4, row.data5}
			}
		end
	end

	return t
end

local function LoadNpcs(teamid, battle_id)
	local t = {}
	local next_npc_uuid = 0
	local success, result = database.query("select npc_uuid, npc_id, data1, data2, data3, data4, data5, dead from team_battle_npc where teamid = %d and battle_id = %d", teamid, battle_id)
	if success then
		for _, row in ipairs(result) do
			t[row.npc_uuid] = {
				uuid = row.npc_uuid, 
				id = row.npc_id,
				dead = row.dead,
				data = {row.data1, row.data2, row.data3, row.data4, row.data5}, 
			}
		end
	end
	return t;
end

function TeamBattle.Resume(info, observer) -- uuid, teamid, battle, stage, begin_time, end_time, stage_begin_time, data1, data2, data3, data4, data5, next_npc_uuid, players, npcs, observer)
	local t = {
		--uuid    = info.uuid,
		battle  = info.battle_id,
		teamid  = info.teamid,

		next_npc_uuid = 0,

		-- stage = stage,
		-- stage_begin_time = stage_begin_time,
		rng = WELLRNG512a_.new(info.seed),

		begin_time = info.begin_time,
		end_time   = info.end_time,

		observer = observer,
		thread = Thread.Create(TeamBattle.Loop), 

		changes = { npcs = {}, players = {} }
	}

	t.players = LoadPlayers(t.teamid, t.battle);
	t.npcs = LoadNpcs(t.teamid, t.battle);

	for _, v in pairs(t.npcs) do
		if v.uuid >= t.next_npc_uuid then
			t.next_npc_uuid = v.uuid;
		end
	end


	t = setmetatable(t, {__index = TeamBattle} )

	if t:Start() then
		return t
	end
end


function TeamBattle.New(teamid, battle_id, begin_time, end_time, observer)
	local seed = math.random(1, 0xffffffff);

	local t = {
		battle = battle_id,
		teamid = teamid,
		next_npc_uuid = 0,

		-- stage = 0,
		-- stage_begin_time = 0,
	
		begin_time = begin_time,
		end_time = end_time,
	
		data = {0, 0, 0, 0, 0}, 

		players = {},
		npcs = {},	

		observer = observer,

		thread = Thread.Create(TeamBattle.Loop), 

		rng = WELLRNG512a_.new(seed),

		changes = { npcs = {}, players = {} }
	}	

	t = setmetatable(t, {__index = TeamBattle} )

	if t:Start(true) then
		database.update("insert into team_battle(teamid, battle_id, seed, begin_time, end_time) values(%d, %d, %d, from_unixtime_s(%d), from_unixtime_s(%d))", teamid, battle_id, seed, begin_time, end_time);
		return t;
	end
end

function TeamBattle:Start(...)
	local cfg = TeamActivityConfig.GetTeamActivityConfig(self.battle)
	if not self:LoadScript(cfg.server_script) then
		return 
	end

	self.thread:Start(self, ...);

	return true
end

--[[
function TeamBattle:ChangeBattleStage(stage, t)
	local old_stage = self.stage	
	if old_stage == 0 and stage ~= 1 then
		log.debug("fail to change stage, battle %d(%d) not start", self.uuid, self.battle_id)
		return false
	end

	t = t or loop.now()
	self.stage = stage	
	database.update("update team_battle set stage = %d, stage_begin_time = from_unixtime_s(%d) where uuid = %d", self.uuid, t)
	self:Command("CHANGESTAGE", old_stage, stage)
	self:Notify()
	return true
end

function TeamBattle:API_ChangeStage(stage)
	return self:ChangeBattleStage(stage)
end

function TeamBattle:API_GetStage()
	return self.stage
end

function TeamBattle:API_GetStageBeginTime()
	return self.stage_begin_time
end
--]]

function TeamBattle:API_IsLeader(pid)
    if not self.team or loop.now() > self.team_update_time then
        self.team = getTeam(self.teamid)
        self.team_update_time = loop.now()
    end

    if not self.team then
        ERROR_LOG(string.format("team %d not exist", self.teamid))
        return false
    end

    return self.team.leader.pid == pid
end


function TeamBattle:API_GetActivityConfig()
	return TeamActivityConfig.GetTeamActivityConfig(self.battle)
end

function TeamBattle:API_GetNpcConfig(id)
	return TeamActivityConfig.GetTeamActivityNpcConfig(id)
end

function TeamBattle:API_GetConfig(ConfigName, key)
	return TeamActivityConfig.GetConfigByName(ConfigName, key)
end

function TeamBattle:API_Exit()
	self:Command("STOP")
end

function TeamBattle:API_RAND(...)
	-- local v = WELLRNG512a_.value(self.rng);
    -- self.rng = self.rng or WELLRNG512a(self.seed);
 
    local a, b = select(1, ...);

    local o = WELLRNG512a_.value(self.rng);

    if not a then
        local f = math.floor(o / 0xffffffff * 100) / 100;
        return f
    end

    if a <= 0 then
        -- assert(a > 0, 'interval is empty' .. debug.traceback());
		return a;
    end

    local v = 0;
    if not b then
        v = 1 + o % a;
    elseif b >= a then
        v = a + (o % (b-a+1))
    else
        v = a;
    end

    return v;
end

function TeamBattle:API_NPC_List()
	local t = {}
	for k, v in pairs(self.npcs) do
		if v.dead ~= 1 then
			table.insert(t, k);
		end
	end

	return t;
end

function TeamBattle:API_NPC_Info_List()
	local t = {}
	for k, v in pairs(self.npcs) do
		table.insert(t, {uuid = v.npc_uuid, id = v.npc_id, dead = v.dead, data = {v.data[1], v.data[2], v.data[3], v.data[4], v.data[5]}})
	end

	return t	
end

function TeamBattle:API_NPC_GetDeadNum(npc_id)
	local sum = 0
	for k, v in pairs(self.npcs) do
		if v.dead == 1 and v.id == npc_id then
			sum = sum + 1
		end
	end

	return sum
end

function TeamBattle:API_NPC_GetAliveNum(npc_id)
	local sum = 0
	for k, v in pairs(self.npcs) do
		if v.dead == 0 and v.id == npc_id then
			sum = sum + 1
		end
	end

	return sum
end

function TeamBattle:API_NPC_Add(id)
	self.next_npc_uuid = self.next_npc_uuid + 1;
	local uuid = self.next_npc_uuid;

	self.npcs[uuid] = {uuid = uuid, id = id, dead = 0, data = {0, 0, 0, 0, 0}}

	database.update("insert into team_battle_npc (teamid, battle_id, npc_uuid, npc_id) values(%d, %d, %d, %d)", self.teamid, self.battle, uuid, id);

	self.changes.npcs[uuid] = {};

	return uuid;
end

function TeamBattle:API_NPC_Remove(uuid)
	if not self.npcs[uuid] then	
		log.error(string.format("fail to remove npc %d, not exist", npc_uuid))
		return false
	end

	if self.npcs[uuid].dead == 1 then
		log.error(string.format("fail to remove npc %d, already dead", npc_uuid))
		return false
	end

	self.npcs[uuid].dead = 1	

	database.update("update team_battle_npc set dead = 1 where teamid = %d and battle_id = %d and npc_uuid = %d", self.teamid, self.battle, uuid)
	
	self.changes.npcs[uuid] = {};

	return true
end

function TeamBattle:API_NPC_GetID(uuid)
	if self.npcs[uuid] then
		return self.npcs[uuid].id
	end
end

function TeamBattle:API_NPC_GetValue(npc_uuid, key)
	if self.npcs[npc_uuid] then
		return self.npcs[npc_uuid].data[key]
	end
end

function TeamBattle:API_NPC_SetValue(npc_uuid, key, value)
	if not self.npcs[npc_uuid] then
		log.error(string.format("fail to update npc data, npc %d not exist", npc_uuid))
		return false
	end

	if self.npcs[npc_uuid].data[key] == value then
		return 
	end

	self.npcs[npc_uuid].data[key] = value

	database.update("update team_battle_npc set data%d = %d where teamid = %d and battle_id = %d and npc_uuid = %d", key, value, self.teamid, self.battle, npc_uuid)

	self.changes.npcs[npc_uuid] = self.changes.npcs[npc_uuid] or {}
	self.changes.npcs[npc_uuid][key] = value;

	-- self:Notify()
	return true
end

--[[
function TeamBattle:API_GetBattleData(key)
	return self.data[key]
end

function TeamBattle:API_SetBattleData(key, value)
	self.data[key] = value;

	self.changes.data[key] = value;

	-- database.update("update team_battle set data%d = %d where uuid = %d", key, value, self.uuid)
	-- self:Notify()
end
--]]

function TeamBattle:API_PLAYER_GetValue(pid, key)
	if self.players[pid] then
		return self.players[pid].data[key]
	end
end

function TeamBattle:API_PLAYER_SetValue(pid, key, value)
	local player_exists = true;
	if not self.players[pid] then
		player_exists = false;
		self.players[pid] = {pid = pid, data = {0, 0, 0, 0, 0} };
	end

	if self.players[pid].data[key] == value then
		return
	end

	self.players[pid].data[key] = value
	self.changes.players[pid] = self.changes.players[pid] or {}

	if player_exists then
		self.changes.players[pid][key] = value;
		database.update("update team_battle_player set data%d = %d where teamid = %d and battle_id = %d and pid = %d", key, value, self.teamid, self.battle, pid)
	else
		database.update("insert into team_battle_player(teamid, battle_id, pid) values(%d, %d)", self.teamid, self.battle, pid);
	end

	return true
end

function TeamBattle:API_StartFight(pids, fight_id, buffs, call_back)
	local vm = TeamFightVM.New(pids, 
				{
					OnFightFinished = function(_, winner)	
						if loop.now() >= self.begin_time and loop.now() <= self.end_time then
							call_back(winner)	
						end
					end
				}, fight_id)
	if buffs then
		vm:AddBuff(buffs)
	end

	if not vm:Start() then
		log.error("fail to start fight, fail to start fight vm")
		return false	
	end

	return true
end

function TeamBattle:API_SendDropReward(pids, consume, drops)
	for _, pid in ipairs(pids) do
		SendDropReward(pid, consume, Command.REASON_TEAM_ACTIVITY, drops)
	end
end

function TeamBattle:API_SendReward(pids, reward, consume, manual, limit, name)
	for _, pid in ipairs(pids) do
		DOReward(pid, reward, consume, Command.REASON_TEAM_ACTIVITY, manual, limit, name)	
	end	
end

function TeamBattle:API_GetTeamMembers()
	if not self.team or loop.now() > self.team_update_time then
		self.team = getTeam(self.teamid)	
		self.team_update_time = loop.now()
	end

	if not self.team then
		ERROR_LOG(string.format("team %d not exist", self.teamid))
		return {}
	end

	local list = {}
	for k, v in ipairs(self.team.members) do	
		table.insert(list, v.pid)	
	end

	return list
end

function TeamBattle:CallScriptFunc(funcName, ...)
	assert(self.script)

	local func = rawget(self.script, funcName) 
	if func then
		local success, info = pcall(func, ...);
		if not success then
			log.error(info);
			return 
		end

		return info
	end
end

function TeamBattle:Info()
	local info = {
		{self.teamid, self.battle},
	}

	local players = {}
	for k, v in pairs(self.players) do
		table.insert(players, {v.pid, {v.data[1], v.data[2], v.data[3], v.data[4], v.data[5]}});
	end
	table.insert(info, players)

	local npcs = {}
	for k, v in pairs(self.npcs) do
		table.insert(npcs, {v.uuid, v.id, {v.data[1], v.data[2], v.data[3], v.data[4], v.data[5]}, v.dead});
	end
	table.insert(info, npcs)
	table.insert(info, {self.begin_time, self.end_time})

	return info;
end

function TeamBattle:Loop(is_new_battle)
	if is_new_battle then
		self:CallScriptFunc("Start")

		self:Notify(self:Info());
	end

	while true do 
		local cmd, pid, data1, data2, conn, sn = self.thread:read_message();
		if cmd == "INTERACT" then
			if not self.npcs[data1] or self.npcs[data1].dead == 1 then
				if conn then
					conn:sendClientRespond(Command.C_TEAM_BATTLE_INTERACT_RESPOND, pid, {sn, Command.RET_NOT_EXIST});
				end
			else	
				local ret = self:CallScriptFunc("Interact", pid, data1, data2)
				if ret then
					ret = ret + 100	
				end

				if conn and sn then
					conn:sendClientRespond(Command.C_TEAM_BATTLE_INTERACT_RESPOND, pid, {sn, ret or Command.RET_SUCCESS});
				end	
			end
		elseif cmd == "UPDATE" then
			if self.end_time > 0 and loop.now() > self.end_time then
				log.debug("battle end because time out")
				break
			end
			self:CallScriptFunc("Update", loop.now())
		elseif cmd == "ONTEAMDISSOLVE" then
			--self:CallScriptFunc("TeamDissolve")
			break;
		elseif cmd == "STOP" then
			break;
		end	

		self:CleanNotify()
	end

	if update_list[self.teamid] then
		update_list[self.teamid][self.battle] = nil
	end

	self:CallScriptFunc("End")
	self:Notify({{self.teamid, self.battle, 4}})

	self:Cleanup();
end

function TeamBattle:OnTeamDissolve()
	self.thread:send_message("ONTEAMDISSOLVE")
end

function TeamBattle:CleanNotify()
	local notify = {
		{self.teamid, self.battle},
	}

	
	local npcs = {}
	for npc_uuid, c in pairs(self.changes.npcs) do
		local v = self.npcs[npc_uuid]
		if v then
			table.insert(npcs, {v.uuid, v.id, {v.data[1], v.data[2], v.data[3], v.data[4], v.data[5]}, v.dead});
		else
			table.insert(npcs, {npc_uuid, 0})
		end
	end

	local players =  {}
	for pid, _ in pairs(self.changes.players) do
		local v = self.players[pid]
		if v then
			table.insert(players, {v.pid, {v.data[1], v.data[2], v.data[3], v.data[4], v.data[5]}});
		end
	end

	table.insert(notify, players)
	table.insert(notify, npcs)

	self.changes = {players = {}, npcs = {} }

	if #players > 0 or #npcs > 0 then
		self:Notify(notify);
	end
end

function TeamBattle:Cleanup()
	database.update("delete from team_battle where teamid = %d and battle_id = %d", self.teamid, self.battle)
	database.update("delete from team_battle_player where teamid = %d and battle_id = %d", self.teamid, self.battle)
	database.update("delete from team_battle_npc where teamid = %d and battle_id = %d", self.teamid, self.battle)
	if self.observer and self.observer.OnRemove then
		self.observer.OnRemove(self)
	end
end

function TeamBattle:Command(cmd, ...)
	self.thread:send_message(cmd, ...)
end

function TeamBattle:Notify(msg)
	self.changes = {players = {}, npcs = {} }

	if not self.team or loop.now() > self.team_update_time then
		self.team = getTeam(self.teamid);
		self.team_update_time = loop.now()
	end
	self.team:Notify(Command.NOTIFY_TEAM_BATTLE_INFO, msg);

	
	--SocialManager.TeamNotify(self.teamid, Command.NOTIFY_TEAM_BATTLE_INFO, msg, nil, true)
end


--[[
database.update('truncate team_battle');
database.update('truncate team_battle_player');
database.update('truncate team_battle_npc');
--]]

--[[local battle = TeamBattle.New(0, 1, 0, 9999999999999999)
--]]

return TeamBattle
