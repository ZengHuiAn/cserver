local Class = require "Class"
local cell = require "cell"
local database = require "database"
local loop = loop;
local log = log;
local string = string;
local tonumber = tonumber;
local pairs = pairs;
local rawset = rawset
local type = type
local math = math;
local coroutine = coroutine
local table = table;
local os = os;
local io = io;
local print = print;
local next = next;
local ipairs = ipairs;
local PlayerManager = require "PlayerManager"
local FootmanManager= require "FootmanManager"
local GuildManager  = require "GuildManager"
local Scheduler     = require "Scheduler"
local Config        = require "GuildWarConfig"
local Command       = require "Command"
-- local broadcast     = require "broadcast"
local EventManager = require "EventManager"
-- local YQSTR         = require "YQSTR"
local bit32         = require "bit32"
local RoomConfig    = Config.RoomConfig
local SocialManager = require "SocialManager"
----------------------------
require "yqlog_sys"
require "printtb"
require "Thread"
local Sleep = Sleep
local yqinfo  = yqinfo
local yqerror = yqerror
local yqwarn  = yqwarn 
local sprinttb = sprinttb
-----------------------------
module "RoomManager"

local All = {};
local Room = {};
local g_room_id  = 0;
--local g_test_flag = true
local g_fight_cache = {}
local g_reward_cache = {}

local function exchange(pid, consume, reward, reason)
	local ret =cell.sendReward(pid, reward, consume, reason)
	if type(ret)=='table' then
		if ret.result=='RET_SUCCESS' then
			return true
		else
			if ret.result=='RET_NOT_ENOUGH' then
				return false, Command.RET_NOT_ENOUGH
			else
				return false, Command.RET_ERROR
			end
		end
	else 
		return false, Command.RET_ERROR
	end
end

function GetNowWarTime(room_id)
    local now = loop.now();
    local ok, result = database.query("SELECT UNIX_TIMESTAMP(prepare_time) AS prepare_time, UNIX_TIMESTAMP(check_time) AS check_time, \
    UNIX_TIMESTAMP(begin_time) AS begin_time, UNIX_TIMESTAMP(end_time) AS end_time FROM guild_war_room_info WHERE room_id = %d", room_id);
    if ok then
        if #result >= 1 then
            local row = result[1];
            log.info(sprinttb(result))
            local prepare_time = tonumber(row.prepare_time);
            local check_time   = tonumber(row.check_time);
            local begin_time   = tonumber(row.begin_time);
            local end_time     = tonumber(row.end_time);
            if now < end_time then
                return prepare_time, check_time, begin_time, end_time;
            end
        end
    end
            
    local prepare_time = 0;
    if now < RoomConfig[room_id].WarPrepareTime then
        prepare_time = RoomConfig[room_id].WarPrepareTime
    else
        prepare_time = math.floor((now - RoomConfig[room_id].WarPrepareTime) / RoomConfig[room_id].FreshPeriod) * RoomConfig[room_id].FreshPeriod + RoomConfig[room_id].WarPrepareTime
    end
    local check_time   = prepare_time + RoomConfig[room_id].CheckDelta;
    local begin_time   = prepare_time + RoomConfig[room_id].BeginDelta;
    local end_time     = prepare_time + RoomConfig[room_id].EndDelta;
    if now > end_time then
        prepare_time = prepare_time + RoomConfig[room_id].FreshPeriod;
        check_time   = check_time + RoomConfig[room_id].FreshPeriod;
        begin_time   = begin_time + RoomConfig[room_id].FreshPeriod;
        end_time     = end_time   + RoomConfig[room_id].FreshPeriod;
    end
    local str = "REPLACE INTO guild_war_room_info(room_id, prepare_time, check_time, begin_time, end_time) \
    VALUES(%d, from_unixtime_s(%d), from_unixtime_s(%d), from_unixtime_s(%d), from_unixtime_s(%d))";
    database.update(str, room_id, prepare_time, check_time, begin_time, end_time);
    return prepare_time, check_time, begin_time, end_time;
end

local function havePermission(pid)
    local player = PlayerManager.Get(pid);
    if not player then
        log.info("[havePermission] fail, player is nil")
        return nil;
    end
    if player.title >= 1 and player.title <= 10 then
        return true;
    end
    return nil;
end

local function loadFootman(room)
    local room_id   = room._id
    local room_isbn = room._room_isbn
    local room_member = {};
    local room_member_order = {};
    local ok, result = database.query("SELECT gid, UNIX_TIMESTAMP(join_time) as join_time, exp, order1, order2, order3, order4\
                                       FROM guild_war_member WHERE room_id = %u", room_id, room_isbn);
    if ok then
        local t_member_report = {}
        for i = 1, #result do
            local row = result[i];
            local footman = FootmanManager.Get(room_id, row.gid, 0, {row.order1,row.order2, row.order3, row.order4})
            room_member[row.gid] = {join_time = tonumber(row.join_time), footman = footman};
            table.insert(room_member_order, {gid = row.gid, key = row.exp, join_time = loop.now()})
        end
        table.sort(room_member_order, function(A,B)
            if A.key ~= B.key then
                return A.key > B.key
            else
                return A.join_time < B.join_time;
            end 
        end)
        for k, v in pairs(room_member_order) do
            v.origin_order = k;
            table.insert(t_member_report, {v.gid, 0, 7});
        end
        room._member_report = t_member_report;
        room._member = room_member;
        room._member_order = room_member_order;
    else
        log.info("[loadFootman] error, couldn't load guild_war_member");
        return nil
    end
    return room;
end


local function recordReward(t)
    table.insert(g_reward_cache, t);
end

local function sendReward()
    while true do
        if next(g_reward_cache) then
            local cache = g_reward_cache[1];
            if not cache[5] or (loop.now() > cache[5]) then
                table.remove(g_reward_cache, 1);
                log.info("[Send Reward]", cache[1], cache[2])
                if cache[1] and cache[1] ~= 0 then
					-- TODO:
                    -- if not cell.boxReward(cache[1], cache[2], cache[3], cache[4]) then
                    --    log.info(string.format("[Send Reward Fail] %d %s", cache[1], cache[2]));
                    -- end
                end
            end
        end
        Sleep(2);
    end
end


function Room:_init_(room_id)
    if not room_id then
        log.info(string.format("no such room_id"));
        return nil;
    end
    if not RoomConfig[room_id] then
        log.info(string.format("no such room `%d` config", room_id));
        return nil;
    end
    local now = loop.now();
    self._id           = room_id;
    self._member       = {};
    self._member_order = {};
    self._pre_member_report = {};
    self._member_report = {};
    self._sub_room_status = {};
    self._sub_room_record = {};

    self._history_report = nil;
    self._history_fight_record = nil;
    self._history_time = 0;

    self._status       = 0;
    self._fight_status = Config.g_fight_wait;

    self.fight_round = -1;
    self._fight_record = {};

    self.visitor       = {};
    self.fight_visitor = {};
    self.fight_visitor_map = {};

    local prepare_time, check_time, begin_time, end_time = GetNowWarTime(room_id);
    self._prepare_time = prepare_time;
    self._check_time   = check_time;
    self._begin_time   = begin_time;
    self._end_time     = end_time;
    self._room_isbn    = prepare_time - Config.g_guild_war_start_time;

    self.fight_prepare_time   = self._begin_time; 
    self.fight_begin_time     = self.fight_prepare_time + RoomConfig[room_id].FightBeginDelta
    self.fight_end_time       = self.fight_prepare_time + RoomConfig[room_id].FightPeriod;
     
    if not loadFootman(self) then
        return;
    end
    local t_history_sub_room_status = {}
    for i = 1, 70 do
        t_history_sub_room_status[i] = 3;
    end
    self.history_sub_room_status = t_history_sub_room_status;
    All[room_id] = self;
end

local function getPlayerGuildId(playerid)
    local player  = PlayerManager.Get(playerid);
    if not player then
        log.error(playerid .." Fail to Get Player Gid, no such player");
        return nil;
    end
    local guild   = player.guild
    if not guild then
        log.error(playerid .." Fail to Get Player's Guild, play not in guild");
        return nil
    end
    local gid = guild.id;
    if not gid then
        log.error(playerid .." Fail to Get Player's Guild's Id, no guild id");
        return nil
    end
    return gid;
end

function Room:IsMember(gid)
    if not gid then
        log.info("the member gid is error");
        return nil;
    end
    return self._member[gid];
end

function Room:addMember(gid)
    if not gid then
        log.info("the member gid is error");
        return nil;
    end
    local guild = GuildManager.Get(gid);
    local footman = FootmanManager.Get(self.id, gid);
    if not footman then
        log.error("fail to get footman, why it happen?");
        return nil;
    end
    local ok, err = database.update("INSERT INTO guild_war_member(room_id, gid, join_time, exp) \
            VALUES(%u, %u, from_unixtime_s(%u), %u)", self._id, gid, loop.now(), guild.exp);
    if ok then
        local t_member_report = {};
        self._member[gid] = {footman = footman, join_time = loop.now()}
        table.insert(self._member_order, {gid = gid, key = guild.exp, join_time = loop.now()})
        table.sort(self._member_order, function(A,B)
            if A.key ~= B.key then
                return A.key > B.key
            else
                return A.join_time < B.join_time;
            end
        end)
        for k, v in pairs(self._member_order) do
            v.origin_order = k;
            table.insert(t_member_report, {v.gid, 0, 7});
        end
        self._member_report = t_member_report;
        EventManager.DispatchEvent("GUILD_WAR_MEMBER_JOIN", {
            gid = gid,
        });
        return true
    else
        log.info(string.format("addMember: database update error, %s", err));
        return nil;
    end
end

function Room:Join(pid)
    local room_id = self._id;
    if not pid then 
        log.info(string.format("no pid `%d`", pid or -1));
        return nil
    end
    if self.status ~= Config.g_prepare_status then
        log.info(string.format("not prepare status"));
        return nil
    end
    local gid = getPlayerGuildId(pid)
    if not gid then
        log.error(string.format("player `%d` is do not have guild", pid or -1));
        return nil;
    end

    if self:IsMember(gid) then
        log.info(string.format("player `%d` already join the war", pid or -1));
        return Command.RET_GUILD_WAR_ALREADY_JOIN;
    end

    -- is captain
    if not havePermission(pid) then
        log.error(string.format("player `%d` is not captain", pid));
        return nil
    end

    local guild = GuildManager.Get(gid)

    --level
    if guild.level < RoomConfig[room_id].GuildLevelLimit then
        log.info(string.format("guild `%d` level is too low", gid));
        return nil
    end

    --member count
    if guild.mcount < RoomConfig[room_id].GuildMemberLimit then
        log.info(string.format("guild `%d` member count is too few", gid));
        return nil
    end

    -- money
    if RoomConfig[room_id].JoinConsume.value > 0 then
		if not exchange(pid, {RoomConfig[room_id].JoinConsume}, {}, Command.REASON_GUILD_WAR_JOIN_CONSUME) then
		   log.info(string.format("pid `%d` add guild `%d` join fail, no money", pid, gid));
		   return nil; 
		end
	end
    
    -- add guild into room
    if not self:addMember(gid) then
       exchange(pid, {}, {RoomConfig[room_id].JoinConsume}, Command.REASON_GUILD_WAR_JOIN_CONSUME);
       log.error(string.format("fail to add member in room"));
       return nil;
    end
    log.info(string.format("[addMember] %u add %u to GuildWar", pid, gid));
    return true
end

function Room:loadHistory()
    local room_id = self._id;
    local f_room_id = (room_id - 1 > 0) and (room_id - 1) or (Config.g_max_room_id);
    local f_room = Get(f_room_id)
    local f_room_isbn = f_room.prepare_time - RoomConfig[f_room_id].FreshPeriod - Config.g_guild_war_start_time;
    local ok, result = database.query("SELECT gid, origin_order, room_rank, room_rank_status, UNIX_TIMESTAMP(room_rank_time) \
    AS room_rank_time FROM guild_war_report WHERE room_id = %d AND room_isbn = %d", f_room_id, f_room_isbn);
    local t_history_report = {};
    if ok then
        if #result >= 1 then
            for i = 1, #result do
                local row = result[i];
                t_history_report[row.origin_order] = {row.gid, row.room_rank, tonumber(row.room_rank_time), row.room_rank_status}
            end
        end
        self._history_report = t_history_report;
    else
        return nil;
    end
    local str = "SELECT sub_room_id, gid, g_type, %s, inspire_sum FROM guild_war_sub_room_record WHERE room_id = %d AND room_isbn = %d";
    local sub_str = ""
    local t_max = RoomConfig[f_room_id].MaxExpertCount +  RoomConfig[f_room_id].MaxMasterCount;
    for i = 1,  t_max do
        if i == t_max then
            sub_str = sub_str .. "pid"..(i);
        else
            sub_str = sub_str .. ("pid"..(i)..",")
        end
    end
    ok, result = database.query(str, sub_str, f_room_id, f_room_isbn);
    local t_sub_room_record = {};
    if ok then 
        if #result >= 1 then
            for i = 1, #result do
                local row = result[i];
                local sub_room_id = row.sub_room_id;
                local gid = row.gid;
                local inspire_sum = row.inspire_sum;
                local g_type = row.g_type;
                if not t_sub_room_record[sub_room_id] then
                    t_sub_room_record[sub_room_id] = { {},{{},{}}, {{},{},} };
                end
                t_sub_room_record[sub_room_id][1][g_type]     = gid;
                t_sub_room_record[sub_room_id][1][g_type + 2] = inspire_sum;
                for i = 1, t_max do
					local pid = row["pid"..i];
					if pid and pid > 0 then
						if i <= RoomConfig[room_id].MaxMasterCount then
							table.insert(t_sub_room_record[sub_room_id][2][g_type], row["pid"..i]);
						else
							table.insert(t_sub_room_record[sub_room_id][3][g_type], row["pid"..i]);
						end
					end
                end
            end
        end
        self._history_sub_room_record = t_sub_room_record
    end
    ok, result = database.query("SELECT sub_room_id, fight_round, fight_type, gid1, pid1, gid2, pid2, fight_result, fight_record_id, \
    UNIX_TIMESTAMP(fight_record_time) AS fight_record_time  FROM guild_war_fight_record WHERE room_id = %d AND room_isbn = %d", f_room_id, f_room_isbn);
    local t_history_fight_record = {}
    if ok then
        if #result >= 1 then
            for i = 1, #result do
                local row = result[i];
                local sub_room_id = row.sub_room_id
                if t_history_fight_record[sub_room_id] == nil then 
                   t_history_fight_record[sub_room_id] = {} 
                end
                table.insert(t_history_fight_record[sub_room_id],{
                    row.fight_result,
                    tonumber(row.fight_record_id),
                    nil,
                    row.fight_type,
                    row.gid1,
                    row.pid1,
                    row.gid2,
                    row.pid2,
                    row.fight_record_time,
                    row.fight_round
                })
            end
        end
        self._history_fight_record = t_history_fight_record;
        self._history_time = loop.now();
        return true
    else
        return nil;
    end
end

Room.id = {
    get = '_id'
}

Room.status = {
    get = '_status',
    set = function(self, v)
       self._status = v;
    end
}

Room.fight_status = {
    get = '_fight_status',
}

Room.history_report = {
    get = function(self)
        if not self._history_report then
            if self:loadHistory() then
                return self._history_report;
            else
                return {};
            end
        end
        if self._history_time < self._prepare_time then
            self:loadHistory();
            return self._history_report;
        end
        return self._history_report;
    end
}

Room.history_fight_record = {
    get = function(self)
        if not self._history_fight_record then
            if self:loadHistory() then
                return self._history_fight_record;
            else
                return {};
            end
        end
        if self._history_time < self._prepare_time then
            self:loadHistory();
            return self._history_fight_record;
        end
        return self._history_fight_record;
    end
}

Room.history_sub_room_record = {
    get = function(self)
        if not self._history_sub_room_record then
            if self:loadHistory() then
                return self._history_sub_room_record;
            else
                return {};
            end
        end
        if self._history_time < self._prepare_time then
            self:loadHistory();
            return self._history_sub_room_record;
        end
        return self._history_sub_room_record;
    end
}

Room.prepare_time = {
    get = '_prepare_time'
}

Room.check_time = {
    get = '_check_time'
}

Room.end_time = {
    get = '_end_time'
}
Room.begin_time = {
    get = '_begin_time'
}

Room.stage_cd = {
    get = function(self)
        if self.status == Config.g_prepare_status then
            return self.check_time - loop.now();
        elseif self.status == Config.g_check_status then
            return self.begin_time - loop.now();
        elseif self.status == Config.g_run_status then
            if self.fight_status == Config.g_fight_prepare then
                return self.fight_begin_time - loop.now(); 
            else
                return self.fight_end_time - loop.now();
            end
        else
            return self.end_time - loop.now();
        end
    end
}

Room.member_report = {
    get = function(self)
        if self._status ~= Config.g_run_status then
            return self._member_report;
        else
            return self._pre_member_report;
        end
    end
}

Room.fight_record = {
    get = function(self)
        if self._status == Config.g_prepare_status then
            return self.history_fight_record
        else
            return self._fight_record
        end
    end
}

Room.sub_room_status= {
    get = function(self)
        if self._status == Config.g_prepare_status then
            return self.history_sub_room_status
        else
            return self._sub_room_status
        end
    end
}

Room.sub_room_record = {
    get = function(self)
        if self._status == Config.g_prepare_status then
            return self.history_sub_room_record
        else
            return self._sub_room_record
        end
    end
}


function Room:check()
    local room_id = self._id;
    self.status = Config.g_check_status;
    local check_fail_list = {}
    local unsort_member_order = {};
    local t_member_order = {}
    local t_member = {}
    local fresh_pid = {};

    -- 人数限制
    for k, v in pairs(self._member) do
        local guild = GuildManager.Get(k);
        if not guild or guild.mcount < RoomConfig[room_id].GuildMemberLimit then
            log.info(string.format("guild war check gid = %d fail, count %s", k, guild and guild.mcount or 0))
            check_fail_list[k] = true;
        else
            t_member[k] = v;
            local key = GuildManager.Get(k).exp;
            table.insert(unsort_member_order, {gid = k, key = key, join_time = v.join_time})
        end
    end

    table.sort(unsort_member_order, function(A,B)
        if A.key ~= B.key then
            return A.key > B.key
        else
            return A.join_time < B.join_time;
        end 
    end)

    local maxn = RoomConfig[room_id].MaxMemberCount;
    for k, v in pairs(unsort_member_order) do
        if #t_member_order >= maxn then
            break
        end
        table.insert(t_member_order, v)
        log.info(string.format("%d [GuildWarCheck] guild[%d]=%d", maxn, v.gid, v.key))
    end
    
    --记录下check后的顺序
    local t_member_report = {}
    for k, v in pairs(t_member_order) do
        v.origin_order = k;
        table.insert(t_member_report, {v.gid, 0, 7});
        database.update("INSERT INTO guild_war_report(room_id, room_isbn, gid, origin_order)\
        VALUES(%d, %d, %d, %d)", room_id, self._room_isbn, v.gid, k);
        local guild = GuildManager.Get(v.gid);
        if guild then
            for pid,_ in pairs(guild.members or {}) do 
                table.insert(fresh_pid, pid);
            end
        end
    end
    --Sleep(20);

    self._member = t_member;
    self._member_order = t_member_order;
    self._member_report = t_member_report;
    self._pre_member_report = t_member_report;
    EventManager.DispatchEvent("GUILD_WAR_ORDER", {
        visitor = self.visitor or {}, 
        member_order = t_member_report
    });
    EventManager.DispatchEvent("GUILD_WAR_STATUS",{
        visitor = self.visitor or {},
        room_status = self.status,
        room_fight_status = self._fight_status,
        room_stage_cd = self.stage_cd
    })

    while loop.now() + Config.g_guild_load_player_delta < self.begin_time do
        Sleep(1);
    end
    
    for k = 1, #fresh_pid, 2 do
        -- ret = cell.freshPlayerInfo({fresh_pid[k], fresh_pid[k+1]});
        Sleep(1);
		if loop.now() + 3 >= self.begin_time then
			break;
		end
    end

    for k, v in pairs(t_member_order) do
        local guild   = GuildManager.Get(v.gid);
        local footman = self._member[v.gid].footman;
        if guild and footman then
            local used_pid = {}
            local t_order = {}
            for k, v in pairs(footman.master_order) do
                for pid, _ in pairs(guild.members or {}) do 
                    if v == pid and not used_pid[v] then
                        table.insert(t_order, v);
                        used_pid[v] = true;
                    end
                end
            end
            if #t_order ~= RoomConfig[room_id].MaxMasterCount then
                footman:SetMasterOrder(0, t_order);
            end
        end
    end
end

function Room:GetClientFightRound()
    local now = loop.now();
    if now < self.begin_time then
        return 0;
    else
        --[[第x轮]]
        return self.fight_round + 1;
    end
end

function Room:CanInspire(pid)
    local now     = loop.now();
    local room_id = self._id;
    log.info("[CanInspire] check status");
    if not (self.status == Config.g_run_status) or not (self.fight_status == Config.g_fight_prepare) then
        log.info("[CanInspire] status unmatch  "..(self.status).."   "..(self.fight_status));
        return false;
    end
    local gid = getPlayerGuildId(pid)
    if not gid then
        log.info("[CanInspire] gid error");
        return false;
    end
    local footman = self:GetFootman(pid);
    if not footman then
        log.info("[CanInspire] could not get footman");
        return false;
    end
    if (footman.inspire_count[pid]or 0) + 1 > RoomConfig[room_id].MaxInspireCount then
        log.info("[CanInspire] footman inspire_count ".. (footman.inspire_count[pid] or 0));
        return false;
    end
    for k, v in pairs(self._member_order) do
        if v.gid == gid then
            return true;
        end
    end
    log.info("[CanInspire] error, no pvp guild");
    return false;
end

function Room:GetFootman(pid)
    local room_id = self._id
    local gid     = getPlayerGuildId(pid);
    if not gid then 
        return nil;
    end
    if not self._member[gid] then
        return nil
    end
    local footman = self._member[gid].footman;
    return footman;
end

function Room:Inspire(pid)
    local room_id = self._id
    if self:CanInspire(pid) then
        local footman = self:GetFootman(pid);
        local t_sum = footman.inspire_sum
        footman.inspire_sum = t_sum + RoomConfig[room_id].GoldInspireFactor;
        footman.inspire_count[pid] = (footman.inspire_count[pid] or 0) + 1;
        log.info(string.format("Player[%u] Add Guild[%u], %u -> %u", pid, footman.id, t_sum, footman.inspire_sum));
		local mm = Config.g_dz_map[self.fight_round + 1];
		for _, v in pairs(mm) do
			local idx1 = v[1];
			local idx2 = v[2];
			if self._member_order[idx1] and self._member_order[idx2] then
				local gid1 = self._member_order[idx1].gid;
				local gid2 = self._member_order[idx2].gid;
				if gid1 == footman.id or gid2 == footman.id then
					local sub_room_id = self.fight_round * 16 + idx1;
					if self._sub_room_record[sub_room_id] and self._sub_room_record[sub_room_id][1] then
						if self._sub_room_record[sub_room_id][1][1] == footman.id then
							self._sub_room_record[sub_room_id][1][3] = math.floor(footman.inspire_sum/50);
						else
							self._sub_room_record[sub_room_id][1][4] = math.floor(footman.inspire_sum/50);
						end
					end
					EventManager.DispatchEvent("GUILD_WAR_INSPIRE",{
						visitor = self.fight_visitor[sub_room_id] or {}, 
						inspire_sum = (footman.inspire_sum/50), 
						gid = footman.id
					});
					break;
				end
            end
        end
        return true;
    end
end

function Room:getRank()
    if self.fight_round == 0 then
        return 7;
    elseif self.fight_round == 1 then
        return 6;
    elseif self.fight_round == 2 then
        return 5;
    else
        return 8;
    end
end


function Room:saveFightRecord(sub_room_id, t)
    local fight_result = t[1]
    local fight_record_id = t[2];
    -- t[3] == nil
    local fight_type = t[4];
    local gid1 = t[5];
    local pid1 = t[6];
    local gid2 = t[7];
    local pid2 = t[8];
    local fight_record_time = t[9];
    local fight_round = t[10]
    if self._fight_record[sub_room_id] == nil then
        self._fight_record[sub_room_id] = {}
    end
    table.insert(self._fight_record[sub_room_id], t);
    database.update("INSERT INTO guild_war_fight_record(room_id, room_isbn, sub_room_id, fight_round, \
    fight_type, gid1, pid1, gid2, pid2, \
    fight_result, fight_record_id,fight_record_time) VALUES(%u, %u, %u, %u,\
    %u, %u, %u, %u, %u, \
    %u, %u, from_unixtime_s(%u))",
    self._id, self._room_isbn, sub_room_id, fight_round, fight_type, gid1, pid1, gid2, pid2, fight_result, fight_record_id, fight_record_time);

    local pid = (t[1] == t[5]) and t[6] or t[8]
    local reward_flag = true;
    local reward_str = "";
    if t[4] == 1 then
        log.info("第", t[10] + 1, "轮奖励主将奖励 FOR", pid)
        -- reward_str = string.format(YQSTR.GUILD_WAR_MASTER_ORDER_REWARD,YQSTR.NUMBER2FOREIGN[t[10] + 1] or '');
        reward_str = "第" .. t[10] + 1 .. "轮主将奖励"
    elseif t[4] <= 4 then
        log.info("第", t[10] + 1, "轮先锋奖励 FOR", pid)
        -- reward_str = string.format(YQSTR.GUILD_WAR_EXPERT_ORDER_REWARD,YQSTR.NUMBER2FOREIGN[t[10] + 1] or '');
        reward_str = "第" .. t[10] + 1 .. "轮先锋奖励"
    else
        reward_flag = false;
    end
    if reward_flag then
        recordReward({pid, reward_str, RoomConfig[self._id].OrderReward[t[4]], Command.REASON_GUILD_WAR_ORDER_REWARD, self.fight_end_time});
    end

    EventManager.DispatchEvent("GUILD_WAR_FIGHT_RECORD", {
        visitor_list = self.fight_visitor[sub_room_id], 
        msg = t, 
        sub_room_id = sub_room_id
    })
end

function Room:fight()
    local now = loop.now()
    local room_id = self.id;
    if self._fight_status == Config.g_fight_wait then 
        -- 战斗状态等待开始
        -- 设置战斗开始
        -- 载入战斗时间配置
        -- 调整战斗状态 未开启 -》 战斗准备(0213将由时间确定改为每一场战斗结束递增)
        --self.fight_round         = math.floor((now - self.begin_time) / RoomConfig[room_id].FightPeriod);

        self.fight_round          = self.fight_round + 1;
        self.fight_prepare_time   = now;
        self.fight_begin_time     = self.fight_prepare_time + RoomConfig[room_id].FightBeginDelta
        self.fight_end_time       = self.fight_prepare_time + RoomConfig[room_id].FightPeriod;
        self._fight_status         = Config.g_fight_prepare

        local t = {};
        for k, v in pairs(self._member_report) do 
            table.insert(t, v);
        end
        self._pre_member_report = t;

        for k, v in pairs(self._member_order) do
            local sub_room_id = self.fight_round * 16 + k;
            self._sub_room_status[sub_room_id] = 1;
        end
        local ok, result = database.query("SELECT from_unixtime_s(%u) as fight_prepare_time, from_unixtime_s(%u) as fight_begin_time, from_unixtime_s(%u) as fight_end_time",
				self.fight_prepare_time, self.fight_begin_time, self.fight_end_time);

        log.info(result[1].fight_prepare_time, result[1].fight_begin_time, result[1].fight_end_time);
        self:subRoomPrepare();
        EventManager.DispatchEvent("GUILD_WAR_STATUS",{
            visitor = self.visitor or {}, 
            room_status = self.status, 
            room_fight_status = self._fight_status, 
            room_stage_cd = self.stage_cd
        })
    end

    if self._fight_status == Config.g_fight_prepare and now > self.fight_begin_time then
        -- 战斗处于准备阶段，时间到，开始战斗
        self._fight_status = Config.g_fight_run;
        self:startBattle();
    end
    if self._fight_status == Config.g_fight_end and now > self.fight_end_time then
        self._fight_status = Config.g_fight_wait
        EventManager.DispatchEvent("GUILD_WAR_ORDER", {
            visitor = self.visitor or {}, 
            member_order = self._member_report,
        });
        Sleep(2);
    end
    if self._fight_status == Config.g_fight_over and now > self.fight_end_time then
        self.status = Config.g_reward_status
        EventManager.DispatchEvent("GUILD_WAR_ORDER", {
            visitor = self.visitor or {}, 
            member_order = self._member_report,
        });
        EventManager.DispatchEvent("GUILD_WAR_STATUS",{
            visitor = self.visitor or {}, 
            room_status = self.status, 
            room_fight_status = self._fight_status, 
            room_stage_cd = self.stage_cd
        })
    end
end


function Room:settle()
    local room_id = self.id
    local report_map = {}
    local fight_record = self._fight_record
    local report = self._member_report

    local t_prepare_time = self._prepare_time + RoomConfig[room_id].FreshPeriod
    local t_check_time   = self._check_time   + RoomConfig[room_id].FreshPeriod
    local t_begin_time   = self._begin_time   + RoomConfig[room_id].FreshPeriod
    local t_end_time     = self._end_time     + RoomConfig[room_id].FreshPeriod

    local str = "UPDATE guild_war_room_info SET prepare_time = from_unixtime_s(%d), check_time = from_unixtime_s(%d), begin_time = from_unixtime_s(%d), \
                end_time = from_unixtime_s(%d) WHERE room_id = %d";
    database.update(str, t_prepare_time, t_check_time, t_begin_time, t_end_time, room_id);

    for _, rank in pairs(report) do
        local t_rank = rank[3]
        if t_rank then
            local guild = GuildManager.Get(rank[1])
            --log.info("军团战第",t_rank,"名军团长奖励",guild.leader.id);
            --local reward_str = string.format(YQSTR.GUILD_WAR_LEADER_REWARD, t_rank)
            --recordReward({guild.leader.id, reward_str, RoomConfig[room_id].LeaderReward[t_rank], Command.REASON_GUILD_WAR_LEADER_REWARD})
            for pid, _ in pairs(guild.members) do
                log.info("军团战第",t_rank,"名军团成员奖励 FOR",pid);
                -- local reward_str = string.format(YQSTR.GUILD_WAR_MEMBER_REWARD, YQSTR.NUMBER2RANK[t_rank] or '')
                local reward_str = "军团战第" .. t_rank .. "名军团成员奖励";
                recordReward({pid, reward_str, RoomConfig[room_id].MemberReward[t_rank], Command.REASON_GUILD_WAR_MEMBER_REWARD})
            end
            if t_rank == 1 and guild.name then
                -- TODO: broadcast.SystemBroadcastEasy(Command.SYS_BROADCAST_TYPE_FULL_SCREEN, string.format(YQSTR.GUILD_WAR_RANK_MESSAGE, guild.name));
                -- TODO: broadcast.SystemBroadcastEasy(Command.SYS_BROADCAST_TYPE_TOP_CENTER,  string.format(YQSTR.GUILD_WAR_RANK_MESSAGE, guild.name));
            end
        end

    end
    self.status = Config.g_end_status
end

function Room:renew()
    local room_id = self._id;
    self.status = Config.g_prepare_status;
    self._fight_status = Config.g_fight_wait;
    self._history_report = nil;
    self._history_sub_room_record = nil;
    self._history_fight_record = nil;
    self.fight_round = -1;
    self._fight_record = {};
    self._pre_member_report = {}
    self._sub_room_record = {};
    self._sub_room_status = {};
    self.visitor       = {};
    self.fight_visitor = {};
    self.fight_visitor_map = {};
    self._member = {}
    self._member_order = {};
    self._member_report = {}
    self._prepare_time = self._prepare_time + RoomConfig[room_id].FreshPeriod
    self._check_time   = self._check_time   + RoomConfig[room_id].FreshPeriod
    self._begin_time   = self._begin_time   + RoomConfig[room_id].FreshPeriod
    self._end_time     = self._end_time     + RoomConfig[room_id].FreshPeriod
    self._room_isbn    = self._prepare_time - Config.g_guild_war_start_time;

    self.fight_prepare_time   = self._begin_time;
    self.fight_begin_time     = self.fight_prepare_time + RoomConfig[room_id].FightBeginDelta
    self.fight_end_time       = self.fight_prepare_time + RoomConfig[room_id].FightPeriod;

    FootmanManager.Unload(room_id)
    g_room_id = (room_id + 1 > Config.g_max_room_id) and (1) or (room_id + 1) ;

    local file, err = io.open("../log/DEBUG");
    if file then
        file:close();
        loadFootman(Get(g_room_id));
    else
        database.update("DELETE FROM guild_war_member WHERE room_id = %d", room_id);
    end
end

local function recordFightMessage(room_id, sub_room_id, fight_record)
    if not g_fight_cache[sub_room_id] then
        g_fight_cache[sub_room_id] = {};
    end
    table.insert(g_fight_cache[sub_room_id], {room_id = room_id, fight_record = fight_record})
end

local function sendFightMessage()
    local time_table = {};
    while true do
        if next(g_fight_cache) then 
            for k , v in pairs(g_fight_cache) do
                local v = g_fight_cache[k]
                if v[1] then 
                    if (not time_table[k]) or (loop.now() - time_table[k] > Config.g_guild_fight_record_delta) then
                        local room = Get(v[1].room_id)
                        room:saveFightRecord(k, v[1].fight_record);
                        table.remove(g_fight_cache[k], 1);
                        time_table[k] = loop.now();
                        if not next(g_fight_cache[k]) then
                            g_fight_cache[k] = nil
                        end
                    end
                end
            end
        end
        Sleep(1);
    end
end

function Room:masterFightH(sub_room_id, gid1, idx1, gid2, idx2)
    local footman1 = self._member[gid1].footman;
    local footman2 = self._member[gid2].footman;
    local fight_round = self.fight_round;

    local winner, fight_id = SocialManager.PVPFightPrepare(footman1.master_order[idx1], footman2.master_order[idx2], {auto=true});

	log.debug('Room:masterFightH', footman1.master_order[idx1], footman2.master_order[idx2], winner);

	if winner== 1 then
		winner = gid1;
	elseif winner == 0 then
		local tie_value = cell.getGuildTopKList(0, {footman1.master_order[idx1], footman2.master_order[idx2]});
		if tie_value.military_powers[1] == tie_value.military_powers[2] then
			winner = gid1;
			log.info(string.format("[masterFightH](%d)%d == (%d)%d, same power, %d win", gid1,footman1.master_order[idx1], gid2,footman2.master_order[idx2], winner or -1))
		else
			winner = (tie_value.pids[1] == footman1.master_order[idx1]) and gid1 or gid2;
			log.info(string.format("[masterFightH](%d)%d == (%d)%d, %d win", gid1,footman1.master_order[idx1], gid2,footman2.master_order[idx2],winner));
		end
	else
		winner = gid2;
	end

	local msg = {
		winner, 
		fight_id or 0, 
		nil,
		idx1, 
		gid1, footman1.master_order[idx1], 
		gid2, footman2.master_order[idx2],
		loop.now(),
		self.fight_round,
	};
	recordFightMessage(self._id, sub_room_id, msg);
	return winner;
end

function Room:masterFight()
    local room_id = self.id;
    local fight_round  = self.fight_round
    local t_point = {}
    --get master_order
    --
    local mm = Config.g_dz_map[self.fight_round + 1]
    for i = 1, RoomConfig[room_id].MaxMasterCount do
        for k, v in pairs(mm) do
            local idx1 = v[1];
            local idx2 = v[2];
            if self._member_order[idx1] and self._member_order[idx2] then
                local gid1 = self._member_order[idx1].gid;
                local gid2 = self._member_order[idx2].gid;
                local footman1 = self._member[gid1].footman;
                local footman2 = self._member[gid2].footman;
                self._sub_room_status[idx1 + 16*self.fight_round] = 2;
                local winner = self:masterFightH(idx1 + 16*self.fight_round, gid1, i, gid2, i);
                local point1 = t_point[gid1] or 0;
                local point2 = t_point[gid2] or 0;
                if winner == gid1 then
                    point1 = point1 + RoomConfig[room_id].OrderPoint[i];
                    footman1.inspire_sum = footman1.inspire_sum + RoomConfig[room_id].WarInspireFactor[i]
                elseif winner == gid2 then
                    point2 = point2 + RoomConfig[room_id].OrderPoint[i];
                    footman2.inspire_sum = footman2.inspire_sum + RoomConfig[room_id].WarInspireFactor[i]
                end
                t_point[gid1] = point1
                t_point[gid2] = point2
            end
        end
    end
    return t_point;
end

function Room:expertFightH(sub_room_id, gid1, idx1, gid2, idx2)
    local footman1 = self._member[gid1].footman;
    local footman2 = self._member[gid2].footman;
    local expert_order1  = footman1.expert_order;
    local expert_order2  = footman2.expert_order;
    local fight_round   = self.fight_round
    local winflag1 = true;
    local winflag2 = true;
    local winner, fight_id;
    if idx1 > #expert_order1 then
        winflag1 = false
    end
    if idx2 > #expert_order2 then
        winflag2 = false
    end
    if winflag1 and not winflag2 then
        return gid1;
    elseif winflag2 and not winflag1 then
        return gid2
    elseif not winflag1 and not winflag2 then
        return gid1;
    else
        local pid1 = expert_order1[idx1];
        local pid2 = expert_order2[idx2];


		winner, fight_id = SocialManager.PVPFightPrepare(expert_order1[idx1], expert_order2[idx2], {inspire = {footman1.inspire_sum, footman2.inspire_sum}, auto=true});

		log.debug('Room:expertFightH', pid1, pid2, winner);
		
		if winner == 1 then
			winner = gid1;
		elseif winner == 0 or winner == nil then
			local tie_value = cell.getGuildTopKList(0, {pid1, pid2});
			if tie_value.military_powers[1] == tie_value.military_powers[2] then
				winner = gid1;
			else
				if tie_value.pids[1] == pid1 then
					winner = gid1;
				else
					winner = gid2;
				end
			end
		else
			winner = gid2
		end
		footman1.expert_attack_count[pid1] = (footman1.expert_attack_count[pid1] or 0) + 1;
		footman2.expert_attack_count[pid2] = (footman2.expert_attack_count[pid2] or 0) + 1;
		if winner == gid1 then 
			if footman1.expert_attack_count[pid1] >= 3 then
				idx1 = idx1 +1;
			end
			idx2 = idx2 + 1;
		else
			if footman2.expert_attack_count[pid2] >= 3 then
				idx2 = idx2 +1;
			end
			idx1 = idx1 + 1;
		end
		local msg = {winner, fight_id, nil, 5, gid1, pid1, gid2, pid2, loop.now(), self.fight_round};
		recordFightMessage(self._id, sub_room_id, msg)
    end
    if idx1 > #expert_order1 and idx2 > #expert_order2 then
        return winner, idx1, idx2;
    end
    return false, idx1, idx2;
end

function Room:expertFight()
    local room_id = self.id;
    local t_point = {};
    local expert_idx  = {}
    local mm = Config.g_dz_map[self.fight_round + 1];
    for round_idx = 1, 40 do
        for _, v in pairs(mm) do
            local it1 = v[1];
            local it2 = v[2];
            if self._member_order[it1] and self._member_order[it2] then
                local gid1 = self._member_order[it1].gid;
                local gid2 = self._member_order[it2].gid;
                if not t_point[gid1] then
                    local idx1 = expert_idx[gid1] or 1;
                    local idx2 = expert_idx[gid2] or 1;
                    local winner, n_idx1, n_idx2 = self:expertFightH(it1 + 16*self.fight_round, gid1, idx1, gid2, idx2);
                    if not winner then
                        expert_idx[gid1] = n_idx1 or (idx1 + 1);
                        expert_idx[gid2] = n_idx2 or (idx2 + 1);
                    else
                        t_point[winner] = RoomConfig[room_id].TeamPoint;
                        t_point[((winner == gid1) and gid2 or gid1)] = 0;
                    end
                end
            end
        end
    end
    while next(g_fight_cache) do
        Sleep(1);
    end
    for k, v in pairs(self._sub_room_status) do
        self._sub_room_status[k] = 3;
    end
    return t_point;
end

function Room:subRoomPrepare()
    local room_id = self.id;
    local t_sub_room_record = self._sub_room_record
    local mm = Config.g_dz_map[self.fight_round + 1];
    for _, v in pairs(mm) do
        local idx1 = v[1];
        local idx2 = v[2];
        if self._member_order[idx1] and self._member_order[idx2] then
            local gid1 = self._member_order[idx1].gid;
            local gid2 = self._member_order[idx2].gid;
            local sub_room_id = idx1 + 16*self.fight_round;
            local t = {};
            table.insert(t, {gid1, gid2});
            t_sub_room_record[sub_room_id] = t;
        end
    end
    self._sub_room_record = t_sub_room_record;
    return true;
end

function Room:subRoomSubmit()
    local room_id = self.id;
    local mm = Config.g_dz_map[self.fight_round + 1]
    for _, v in pairs(mm) do
        local idx1 = v[1];
        local idx2 = v[2];
        if self._member_order[idx1] and self._member_order[idx2] then
            local gid1 = self._member_order[idx1].gid;
            local gid2 = self._member_order[idx2].gid;
            local footman1 = self._member[gid1].footman;
            local footman2 = self._member[gid2].footman;
            local sub_room_id = idx1 + 16*self.fight_round;
            local t = {};
            table.insert(t, {gid1, gid2, math.floor(footman1.inspire_sum/50), math.floor(footman2.inspire_sum/50)});
            table.insert(t, {footman1.master_order, footman2.master_order})
            table.insert(t, {footman1.expert_order, footman2.expert_order})
            self._sub_room_record[sub_room_id] = t;
            for sub_type = 1, 2 do
                local log_str = string.format("INSERT INTO guild_war_sub_room_record(room_id, room_isbn, sub_room_id, \
                gid, %%s g_type, inspire_sum) VALUES(%d, %d, %d, %d, %%s %d, %d)",self._id, self._room_isbn, sub_room_id, t[1][sub_type],sub_type, t[1][sub_type + 2]);
                local str1 = "";
                local str2 = "";
                local str_count = 1;
                for order_idx, pid in pairs(t[2][sub_type]) do
                    str1 = str1 .. "pid"..(str_count)..","
                    str2 = str2 .. pid .."," 
                    str_count = str_count + 1;
                end
                for order_idx, pid in pairs(t[3][sub_type]) do
                    str1 = str1 .. "pid"..(str_count)..","
                    str2 = str2 .. pid .."," 
                    str_count = str_count + 1;
                end
                database.update(string.format(log_str, str1, str2));
            end
        end
    end
    return true;
    --print(sprinttb(self._sub_room_record))
    --Sleep(3600);
end

function Room:startBattle()
    local room_id      = self.id
    local ok = self:subRoomSubmit();
    EventManager.DispatchEvent("GUILD_WAR_STATUS",{
        visitor = self.visitor or {}, 
        room_status = self.status, 
        room_fight_status = self._fight_status, 
        room_stage_cd = self.stage_cd
    })
    local t_master_point = self:masterFight();
    local t_expert_point = self:expertFight();
    for k, v in pairs(self._member_order) do
        local gid = v.gid;
        local footman = self._member[v.gid].footman;
        local guild   = GuildManager.Get(gid) or {};
        local t_point = ( (t_master_point[gid] or 0) +  (t_expert_point[gid] or 0)) ;
        if t_point >= 100 then
            for pid, _ in pairs(guild.members or {}) do
               -- recordReward({pid, string.format(YQSTR.GUILD_WAR_VICTORY_REWARD, YQSTR.NUMBER2FOREIGN[self.fight_round + 1] or ''), RoomConfig[room_id].TeamReward,Command.REASON_GUILD_WAR_TEAM_REWARD + (self.fight_round or 0), self.fight_end_time})
               recordReward({pid, "军团战奖励", RoomConfig[room_id].TeamReward,Command.REASON_GUILD_WAR_TEAM_REWARD + (self.fight_round or 0), self.fight_end_time})
               log.info(string.format("[EXPERT REWARD] gid = %d, pid = %d", gid, pid));
            end
        end
        footman.inspire_sum  = 0;
        footman.expert_order = nil;
        footman.expert_attack_count = {};
        footman.inspire_count = {};
    end
    local mm = Config.g_dz_map[self.fight_round + 1]
    for _, v in pairs(mm) do
        local rank     = self:getRank();
        local idx1     = v[1];
        local idx2     = v[2];
        if self._member_order[idx1] and self._member_order[idx2] then
            local gid1     = self._member_order[idx1].gid;
            local gid2     = self._member_order[idx2].gid;
            local point1 = ( (t_master_point[gid1] or 0) +  (t_expert_point[gid1] or 0)) ;
            local point2 = ( (t_master_point[gid2] or 0) +  (t_expert_point[gid2] or 0)) ;
            -- fight record 
            local mask1 = self._member_report[self._member_order[idx1].origin_order][2];
            local mask2 = self._member_report[self._member_order[idx2].origin_order][2];

            mask1 = bit32.bor(mask1, 2^(2*self.fight_round+1));
            mask2 = bit32.bor(mask2, 2^(2*self.fight_round+1));
            if point1 > point2 then
                mask1 = bit32.bor(mask1,2^(2*self.fight_round));
            else
                mask2 = bit32.bor(mask2,2^(2*self.fight_round));
            end
            self._member_report[self._member_order[idx1].origin_order][2] = mask1;
            self._member_report[self._member_order[idx2].origin_order][2] = mask2;
            if point1 < point2 then
                self._member_order[idx1], self._member_order[idx2] = self._member_order[idx2], self._member_order[idx1];
            end
            if self.fight_round <= 3 then 
                if self.fight_round ~= 3 then
                    self._member_report[self._member_order[idx2].origin_order][3] = rank;
                    self._member_report[self._member_order[idx1].origin_order][3] = rank - 1;
                    database.update("UPDATE guild_war_report SET room_rank = %d, room_rank_status = %d, room_rank_time = from_unixtime_s(%d) WHERE room_id = %d AND gid = %d AND room_isbn = %d",
							self._member_report[self._member_order[idx2].origin_order][3],
							self._member_report[self._member_order[idx2].origin_order][2],
							loop.now(), self._id, (point1 < point2) and gid1 or gid2, self._room_isbn)
                    self._member_order[idx2] = nil;
                else
                    self._member_report[self._member_order[idx1].origin_order][3] = 2;
                    self._member_report[self._member_order[idx2].origin_order][3] = 4;
                end
            else
                self._member_report[self._member_order[idx1].origin_order][3] = self._member_report[self._member_order[idx1].origin_order][3] - 1;
                database.update("UPDATE guild_war_report SET room_rank = %d, room_rank_status = %d, room_rank_time = from_unixtime_s(%d) WHERE room_id = %d AND gid = %d AND room_isbn = %d",
						self._member_report[self._member_order[idx1].origin_order][3],
						self._member_report[self._member_order[idx1].origin_order][2],
						loop.now(), self._id, self._member_report[self._member_order[idx1].origin_order][1], self._room_isbn)

                database.update("UPDATE guild_war_report SET room_rank = %d, room_rank_status = %d, room_rank_time = from_unixtime_s(%d) WHERE room_id = %d AND gid = %d AND room_isbn = %d",
						self._member_report[self._member_order[idx2].origin_order][3],
						self._member_report[self._member_order[idx2].origin_order][2],
						loop.now(), self._id, self._member_report[self._member_order[idx2].origin_order][1], self._room_isbn)
            end
        elseif self._member_order[idx1] then
            local mask1   = self._member_report[self._member_order[idx1].origin_order][2];
            local gid1    = self._member_order[idx1].gid;
            local log_str = "[FakeFightRecord] Gid["..(gid1).."] Round["..(self.fight_round).."]";
            mask1 = bit32.bor(mask1, 2^(2*self.fight_round+1));
            mask1 = bit32.bor(mask1,2^(2*self.fight_round));
            self._member_report[self._member_order[idx1].origin_order][2] = mask1;
            if self.fight_round ~= 4 then
                if self.fight_round ~= 3 then
                    self._member_report[self._member_order[idx1].origin_order][3] = rank - 1;
                else
                    self._member_report[self._member_order[idx1].origin_order][3] = 2;
                end
            else
                self._member_report[self._member_order[idx1].origin_order][3] = idx1;
            end
            local footman1 = self._member[gid1].footman;
            for k, v in pairs(footman1.master_order) do
                if k == 1 then
                    log.info(string.format("第%d轮奖励主将奖励 -- 轮空", self.fight_round + 1));
                    -- recordReward({v, string.format(YQSTR.GUILD_WAR_MASTER_ORDER_REWARD,YQSTR.NUMBER2FOREIGN[self.fight_round+1] or ''), RoomConfig[room_id].OrderReward[k], Command.REASON_GUILD_WAR_ORDER_REWARD})
                    recordReward({v, string.format("第%d轮奖励主将奖励 -- 轮空", self.fight_round + 1), RoomConfig[room_id].OrderReward[k], Command.REASON_GUILD_WAR_ORDER_REWARD})
                else
                    log.info(string.format("第%d轮奖励先锋奖励 -- 轮空", self.fight_round + 1))
                    -- recordReward({v, string.format(YQSTR.GUILD_WAR_EXPERT_ORDER_REWARD,YQSTR.NUMBER2FOREIGN[self.fight_round+1] or ''), RoomConfig[room_id].OrderReward[k], Command.REASON_GUILD_WAR_ORDER_REWARD})
                    recordReward({v, string.format("第%d轮奖励先锋奖励 -- 轮空", self.fight_round + 1), RoomConfig[room_id].OrderReward[k], Command.REASON_GUILD_WAR_ORDER_REWARD})
                end
                log_str = log_str .. ("<"..(v)..">,")
            end
            local guild = GuildManager.Get(gid1) or {};
            for pid, _ in pairs(guild.members or {}) do
                log_str = log_str .. ("<"..(pid)..">,")
                -- recordReward({pid, string.format(YQSTR.GUILD_WAR_VICTORY_REWARD, YQSTR.NUMBER2FOREIGN[self.fight_round + 1] or ''), RoomConfig[room_id].TeamReward,Command.REASON_GUILD_WAR_TEAM_REWARD + (self.fight_round or 0), self.fight_end_time})
                recordReward({pid, string.format("第%d轮奖励参战奖励 -- 轮空", self.fight_round + 1), RoomConfig[room_id].TeamReward,Command.REASON_GUILD_WAR_TEAM_REWARD + (self.fight_round or 0), self.fight_end_time})
            end
            log.info(log_str)
        end
    end
    if self.fight_round ~= 4 then
        self._fight_status = Config.g_fight_end
    else
        self._fight_status = Config.g_fight_over
    end
end

function Get(room_id)
    local room = All[room_id]
    if not room then
		room = Class.New(Room, room_id); 
        if not room then
            log.info(string.format("FUNCTION Get: no such room %d",room_id))
            return nil;
        end
    end
    return room
end

local workCo = nil;
local msgCo = nil;

function Crontab()
    local room = Get(g_room_id);
    --stage prepare
    while loop.now() < room.check_time do
        Sleep(1);
    end
    --stage time to check guild list
    --room:loadHistory();
    room:check();
    while loop.now() < room.begin_time do
        Sleep(1);
    end

    -- time to start
    while room.status ~= Config.g_end_status do
        if room.status == Config.g_check_status then
            room.status = Config.g_run_status
        elseif room.status == Config.g_run_status then 
            room:fight();
        elseif room.status == Config.g_reward_status then
            room:settle();
        end
        Sleep(1);
    end
    while loop.now() < room.end_time do
        Sleep(1);
    end
    room:renew();
    --g_test_flag = nil -- test
    workCo = nil;
end

(function()
    workCo = true
    local file, err = io.open("../log/DEBUG");
    if file then
        database.update("DELETE FROM guild_war_room_info");
        file:close();
    else
        if loop.now() < 1426176000 then
            g_room_id = 2;
        end
    end
    local now = loop.now()
    for i = 1, Config.g_max_room_id do
        Get(i)
    end
    
    local ok, result = database.query("SELECT room_id from guild_war_room_info ORDER BY prepare_time");
    if ok then
        if #result >= 1 then
            g_room_id = result[1].room_id;
        end
    end
    msgCo = coroutine.create(function()
        sendFightMessage();
    end)
    local ok, status = coroutine.resume(msgCo);
    if not ok then 
        log.info(status)
    end

    rewardCo= coroutine.create(function()
        sendReward();
    end);
    local ok, status = coroutine.resume(rewardCo);
    if not ok then 
        log.info(status)
    end
    workCo = nil
end)()

function Enter(pid)
    if not pid then
        return nil;
    end
    local room = Get(g_room_id)
    if not room then
        log.info("[Enter] no room start")
    end
    if true then --[[ level limit]]
        if not room.visitor[pid] then
            room.visitor[pid] = true;
        end
        --g_test_flag = true;
        return true
    end
end

function Leave(pid)
    if not pid then
        return nil;
    end
    local room = Get(g_room_id)
    if not room then
        log.info("[Leave] no room start")
    end
    if true then 
        if room.visitor[pid] then
            room.visitor[pid] = nil;
        end
        return true
    end
end

function Join(pid)
    if not pid then
        return nil;
    end
    local room = Get(g_room_id);
    if not room then
        log.info("[Join] no room start")
        return nil
    end
    local ret  = room:Join(pid);
    return ret;
end

function Inspire(pid)
    if not pid then
        return nil;
    end
    local room = Get(g_room_id);
    local ret  = room:Inspire(pid);
    return ret;
end

function SetOrder(pid, order)
    if not pid then
        return nil;
    end
    local room = Get(g_room_id);
    if room.status == Config.g_run_status and room.fight_status == Config.g_fight_run then
        log.info("guild war is fight, cound not set order!!!");
        return nil, Command.RET_INPROGRESS;
    end 
    local player = PlayerManager.Get(pid);
    if not player then 
        log.info("[SetOrder] fail, player is nil")
        return nil;
    end
    if not player.guild then
        return nil;
    end
    if player.guild.leader.id ~= pid then
        return nil;
    end
    local footman = room:GetFootman(pid);
    if not footman then 
        return nil;
    end
    return footman:SetMasterOrder(pid, order);
end

function QueryOrder(pid)
    if not pid then
        return nil, Command.RET_ERROR;
    end
    local player = PlayerManager.Get(pid);
    if not player then 
        log.info("[QueryOrder] fail, player is nil")
        return nil;
    end
    if not player.guild then
        return nil, Command.RET_NOT_EXIST;
    end
    local room = Get(g_room_id)
    local footman = room:GetFootman(pid);
    if not footman then
        return nil, Command.RET_GUILD_JTYW_APP_TIME;
    end
    return true, footman.master_order;
end

function GetCurrentReport(pid)
    local room = Get(g_room_id);
    if not room then
        log.info(string.format("no room to get history_report `%d`", g_room_id or -1))
        return nil, Command.RET_ERROR;
    end
    return true, {{room.prepare_time, room.check_time, room.begin_time}, {room.status, room.fight_status, room.stage_cd}, room.member_report}
end

function GetHistoryReport()
    local room = Get(g_room_id);
    if not room then
        log.info(string.format("no room to get history_report `%d`", g_room_id or -1))
        return nil, Command.RET_ERROR;
    end
   return true, room.history_report;
end

function GetHistoryFightRecord(sub_room_id)
    local room = Get(g_room_id);
    if not room then
        log.info(string.format("no room to get history_report `%d`", g_room_id or -1))
        return nil, Command.RET_ERROR;
    end
    return true, room.history_fight_record[sub_room_id] or {};
end

function EnterSubRoom(pid, sub_room_id)
    local room = Get(g_room_id);
    if not room then
        return nil, Command.RET_ERROR;
    end
    if not sub_room_id or sub_room_id < 0 or sub_room_id > 500 then
        return nil, Command.RET_PARAM_ERROR;
    end
    if not room.fight_visitor[sub_room_id] then
        room.fight_visitor[sub_room_id] = {};
    end
    if not room.fight_visitor[sub_room_id][pid] then
        room.fight_visitor[sub_room_id][pid] = true;
        room.fight_visitor_map[pid] = sub_room_id;
    end
    local footman = room:GetFootman(pid)
    local t_count = footman and footman.inspire_count[pid] or 0;
    return true, (room.sub_room_status[sub_room_id] or 0), (room.sub_room_record[sub_room_id] or {}), room.fight_record[sub_room_id], t_count;
end

function LeaveSubRoom(pid)
    local room = Get(g_room_id);
    if not room then
        return nil, Command.RET_ERROR;
    end
    if not room.fight_visitor_map[pid] then
        return true;
    end
    local sub_room_id = room.fight_visitor_map[pid]
    if  not room.fight_visitor[sub_room_id] then
        room.fight_visitor_map[pid] = nil;
        return true;
    end
    if room.fight_visitor[sub_room_id][pid] then
        room.fight_visitor[sub_room_id][pid] = nil;
        room.fight_visitor_map[pid] = nil;
        return true;
    end
    return true;
end

function IsRunning()
    local room = Get(g_room_id);
    if Config.g_run_status == room.status then
        return true;
    else
        return false;
    end
end

function ResetOrder(pid)
    if type(pid) ~= 'number' then
        return false;
    end
    local room = Get(g_room_id);
    if not room then
        return true;
    end
    local footman = room:GetFootman(pid);
    if not footman then
        return true;
    end
    return footman:ResetMasterOrder(pid);
end
    
local _debug_join = fale;
Scheduler.Register(function(now)
    _now = now;
    if workCo then
        return;
    end


    if not _debug_join then
        _debug_join = true;
		Join(463856567970);
		Join(463856568281);
		Join(463856567976);
		Join(463856568276);
		Join(463856568135);

		local room = Get(g_room_id);
		for i = 1, 32 do
			print('- ----', i);
			if room._member_order[i] then
				local gid1 = room._member_order[i].gid;
				local footman1 = room._member[gid1].footman;
				local expert_order1  = footman1.expert_order;
			end
		end
    end

    --[[if not g_test_flag then
        return;
    end]]
    if g_room_id ~= 0 then
        workCo = coroutine.create(function()
            Crontab();
        end)
        local ok, status = coroutine.resume(workCo);
        if not ok then 
            log.info(status)
        end
    end
end);
