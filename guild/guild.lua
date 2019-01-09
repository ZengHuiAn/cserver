#!../bin/server

package.cpath=package.cpath .. ";../lib/?.so";
package.path =package.path  .. ";../lib/?.lua";

require "log"
require "XMLConfig"
if log.open then
	local l = log.open(
		XMLConfig.FileDir and XMLConfig.FileDir .. "/guild_%T.log" or
		"../log/guild_%T.log");
	log.debug    = function(...) l:debug   (...) end;
	log.info     = function(...) l:info   (...)  end;
	log.warning  = function(...) l:warning(...)  end;
	log.error    = function(...) l:error  (...)  end;
end

local math=math
require "cell"
--local aiserver =require "aiserver"
require "database"
require "printtb"

require "AMF"
require "protobuf"
require "GuildConfig"
require "GuildManager"
require "PlayerManager"
require "DonateManager"
require "ServiceManager"

require "Command"
require "MailReward"

require "GuildEvent"
require "EventManager"
require "Scheduler"

require "NetService"

require "Time"

require "Xing5"

--require "Roulette"
require "printtb"
--local broadcast =require "broadcast"
--local util =require "util"
--local make_player_rich_text =util.make_player_rich_text;
--local limit = require "limit";
-- DEBUG ==================
require "Debug"
--require "GuildActivity"
require "RoomManager"
require "DonateConfig"
require "InviteManager"
require "GuildPrayLogic"
require "GuildExplore"
require "GuildSummaryConfig"
require "GuildPermissionConfig"
local Boss = require "Boss"
require "GuildPrayPlayer"
local GuildBuilding = require "GuildBuilding"
local GuildPrayLog = require "GuildPrayLog"
local GuildEventLog = require "GuildEventLog"
local YQSTR = require "YQSTR"
local GuildQuest = require "GuildQuest"
local SharedQuest = require "SharedQuest"
local GuildItem = require "GuildItem"

local cool_down = GuildSummaryConfig.CoolDown
local create_consume = GuildSummaryConfig.CreateConsume
local create_consume2 = GuildSummaryConfig.CreateConsume2

--local GridGame = require "GridGame"

--local Bonus = require "Bonus"
local ps = ps;
local pe = pe;
local pm = pm;
local pr = pr;
local debugOn = debugOn;
local debugOff = debugOff;
local dumpObj = dumpObj;
debugOn(false);
--debugOff();
-- ================== DEBUG
local GUILD_GID_MIN =10000000

local DAY = Time.DAY;

math.randomseed(os.time());
math.random();

local g_id = 0;
local last_sec = 0;
local function newID()
	local now = loop.now();
	if not (last_sec == now) then
		g_id = 0;
		last_sec = now;
	end
	g_id = g_id + 1;
	local id = now % 0x1000000 * 256 + g_id;
	return  id;
end

local function sendClientRespond(conn, cmd, channel, msg)
	assert(conn, "conn == nil");
	assert(cmd,  "cmd  == nil");
	assert(channel, "channel == nil");
	assert(msg and (table.maxn(msg) >= 2), "table.max(msg) < 2");

	local code = AMF.encode(msg);
	--log.debug(string.format("send %d byte to conn %u", string.len(code), conn.fd));
	log.debug("sendClientRespond", cmd, string.len(code));

	local sid = tonumber(bit32.rshift_long(channel, 32))
	assert(sid > 0, "sid == 0")

	if code then conn:sends(1, cmd, channel, sid, code) end
end

local function encode(protocol, msg)
	local code = protobuf.encode("com.agame.protocol." .. protocol, msg);
	if code == nil then
		print(string.format(" * encode %s failed", protocol));		
		return nil;
	end
	return code;
end

function sendServiceRespond(conn, cmd, channel, protocol, msg)
	local code = encode(protocol, msg);
	local sid = tonumber(bit32.rshift_long(channel, 32))
	if code then
		return conn:sends(2, cmd, channel, sid, code);
	else
		return false;
	end
end

local function buildGuildArray(guild, detail)
	local msg;
	local player  = guild and PlayerManager.Get(guild.leader.id);
	if player then
		msg = {
			guild.id,
			guild.name,
			guild.leader.id,
			guild.leader.name or "",
			guild.rank,
			guild.mcount,      --
			guild.exp,
			guild.level,
			player.level or 0,
			detail and guild.notice or "",
			detail and guild.desc   or "",
			detail and guild.boss   or 0,
            guild.member_buy_count,
			guild.today_add_exp,
			guild.wealth,
			guild.auto_confirm,
			guild.highest_wealth
		};
	else
		msg = {
			0,  --guild.id,
			"", --guild.name,
			0,  --guild.leader.id,
			"", --guild.leader.name,
			0,  --guild.rank,
			0,  --guild.mcount,
			0,  --guild.exp,
			1,  --guild.level,
			1,  --player.level,
			"", --guild.notice
			"", --guild.desc
			0,  --guild.boss
            0,
			0,
		};
	end
	return msg;
end

local function onGuildQuery(conn, id, request)
	local sn  = request[1] or 0;
	local gid = request[2];
    local guild_name = request[3];

	local cmd = Command.C_GUILD_QUERY_RESPOND;
    log.info(string.format("send gid is %d, guild_name is %s", gid or -1, guild_name or "xxx"));
	if gid == nil and guild_name == nil then
		log.error(id .. "Fail to `C_GUILD_QUERY_REQUEST`, param error")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_PARAM_ERROR, "param error"});
	end

	local guild = {};
    if gid ~= 0 then
        guild = GuildManager.Get(gid);
	    log.debug(string.format("onGuildQuery, gid first %u", gid))
    else
        guild = GuildManager.GetByName(guild_name);
	    log.debug("onGuildQuery, guild_name second "..(guild_name))
    end

    if not guild or not next(guild) then
		log.error(id .. "Fail to `C_GUILD_QUERY_REQUEST`, guild not exist")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_GUILD_NOT_EXIST, "guild not exist"});
    end

	local ginfo = buildGuildArray(guild, true);
	local msg = {
		sn,
		Command.RET_SUCCESS,
		(guild and guild.requests[id]) and 1 or 0,
		unpack(ginfo),
	}
    --yqinfo(sprinttb(msg));
	log.info(id .. "Success `C_GUILD_QUERY_REQUEST`")
	return sendClientRespond(conn, cmd, id, msg);
end


local function trim(s)
	return string.match(s,'^()%s*$') and '' or string.match(s,'^%s*(.*%S)')
end


local function onGuildSearchName(conn, id, request)
	local sn  = request[1] or 0;
    local guild_name = request[2];

	local cmd = Command.C_GUILD_SEARCH_NAME_RESPOND
    log.info(string.format("[C_GUILD_SEARCH_NAME_REQUEST] player %d send guild_name is %s", id, guild_name or "xxx"));
	if guild_name == nil then
		log.error(id .. "Fail to `C_GUILD_SEARCH_NAME_REQUEST`, param error")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_PARAM_ERROR})
	end

	local guild_list = {};
    guild_list = GuildManager.SearchByName(trim(guild_name));

    if not guild_list or not next(guild_list) then
		log.info(id .. "Fail to `C_GUILD_SEARCH_NAME_REQUEST`, guild not exist")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_GUILD_NOT_EXIST})
    end

	local msg = {
		sn,
		Command.RET_SUCCESS,
		{}
	}
    local str = ",";
    for _, gid in pairs(guild_list) do
		if gid ~= GUILD_GID_MIN then
            local g = GuildManager.Get(gid)
			local ginfo = buildGuildArray(g, true);
			table.insert(ginfo, g.requests[id] and 1 or 0)
			table.insert(msg[3], ginfo);
            str = str .. (gid) ..","
		end
	end
    log.info(id .." Success to `C_GUILD_SEARCH_NAME_REQUEST`"..(str))
	return sendClientRespond(conn, cmd, id, msg);
end

local function onGuildSearchID(conn, id, request)
	local sn  = request[1] or 0;
    local gid = request[2];

	local cmd = Command.C_GUILD_SEARCH_ID_RESPOND
    log.info(string.format("[C_GUILD_SEARCH_ID_REQUEST] player %d send guild_id is %d", id, gid));
	if gid == nil then
		log.error(id .. "Fail to `C_GUILD_SEARCH_ID_REQUEST`, param error")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_PARAM_ERROR})
	end

	local guild_list = {};
    guild_list = GuildManager.SearchByID(gid);

    if not guild_list or not next(guild_list) then
		log.info(id .. "Fail to `C_GUILD_SEARCH_ID_REQUEST`, guild not exist")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_GUILD_NOT_EXIST})
    end

	local msg = {
		sn,
		Command.RET_SUCCESS,
		{}
	}

    for _, gid in pairs(guild_list) do
		if gid ~= GUILD_GID_MIN then
            local g = GuildManager.Get(gid)
			local ginfo = buildGuildArray(g, true);
			table.insert(ginfo, g.requests[id] and 1 or 0)
			table.insert(msg[3], ginfo);
		end
	end

    log.info(id .." Success to `C_GUILD_SEARCH_ID_REQUEST`")
	return sendClientRespond(conn, cmd, id, msg);
end

local function onGuildCreate(conn, id, request)
	local sn = request[1] or 0;
	local name = trim(request[2] or "");
	local consume_flag= request[3] or 0; -- 0 -> sliver; otherwise -> gold
	local camp = request[4] or 0;
	local enterTime = os.clock()

	log.debug(string.format("onGuildCreate sn %u, name %s, consume_flag %d", sn, name, consume_flag));

	local cmd = Command.C_GUILD_CREATE_RESPOND;

	local player = PlayerManager.Get(id);
    --if not limit.check(33, player.level, player.vip) then
	--	log.error(string.format("Fail to `C_GUILD_CREATE_REQUEST`, player level `%d` limit, pid `%d`", player.level, id))
	--	return sendClientRespond(conn, cmd, id, {sn, Command.RET_LEVEL_LIMIT, "player level limit"});
    --end

	-- 玩家不存在
	if player.name == nil then
		log.error(id .. "Fail to `C_GUILD_CREATE_REQUEST`, player not exists")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_CHARACTER_NOT_EXIST, "player not exists"});
	end

	-- 名字问题
	if name == "" then
		log.error(id .. "Fail to `C_GUILD_CREATE_REQUEST`, param error")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_PARAM_ERROR, "param error"});
	end

	-- 玩家已经有军团
	if player.guild then --or player.level < 10 then
		log.error(id .. "Fail to `C_GUILD_CREATE_REQUEST`, player already have guild")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_GUILD_EXIST, "player already have guild"});
	end

	-- 军团名重复
	if GuildManager.IsExist(name) then
		log.error(id .. "Fail to `C_GUILD_CREATE_REQUEST`, guild name exists")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_GUILD_NAME_EXIST, "guild exist"});
	end

	-- 扣10w铜币
	local errno
	local consume 
	if consume_flag == 0 then
		consume = create_consume-- { {type =41, id = 90002, value = 0} };
	else
		consume = create_consume2-- { {type =42, id = 90006, value = 0} };
	end
	local respond = cell.sendReward(id, nil, consume, Command.REASON_CONSUME_TYPE_GUILD_CREATE, 0, 0);
	if respond == nil or respond.result ~= Command.RET_SUCCESS then
		log.error(id .. "Fail to `C_GUILD_CREATE_REQUEST`, coin or gold not enough")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_NOT_ENOUGH})
	end
	guild = GuildManager.Create(player, name,camp);
	if guild == nil then
		-- 失败, 返还
		cell.sendReward(id, consume, nil, Command.REASON_CONSUME_TYPE_GUILD_CREATE);
		log.error(id .. "Fail to `C_GUILD_CREATE_REQUEST`, create guild failed")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_ERROR, "create guild failed"});
	end

	log.info("Begin to dispatch event")
	EventManager.DispatchEvent("GUILD_CRETE", {guild = guild, founder = player});
	log.info("Finish to dispatch event")

	-- 全服广播	
	NetService.NotifyClients(Command.NOTIFY_DISPLAY_MESSAGE, { 2, player.name, name })

	log.info(id .. "Success `C_GUILD_CREATE_REQUEST`")
	return sendClientRespond(conn, cmd, id, {sn, Command.RET_SUCCESS, guild.id});
end

local function onGuildJoin(conn, id, request)
	local sn = request[1] or 0;
	local gid = request[2] or 0;
	--local pid = request[3] or 0;

	log.debug(string.format("onGuildJoin"));

	local cmd = Command.C_GUILD_JOIN_RESPOND;

	local player = PlayerManager.Get(id);
	local guild = GuildManager.Get(gid);

	-- 角色不存在
	if player.name == nil then
		log.error(id .. "Fail to `C_GUILD_JOIN_REQUEST`, player not exists")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_CHARACTER_NOT_EXIST, "player not exist"});
	end
	
    --if not limit.check(33, player.level, player.vip) then
	--	log.error(id .. "Fail to `C_GUILD_JOIN_REQUEST`, player level limit")
	--	return sendClientRespond(conn, cmd, id, {sn, Command.RET_LEVEL_LIMIT, "player level limit"});
    --end

	-- 玩家已经有军团
	if player.guild then
		log.error(id .. "Fail to `C_GUILD_JOIN_REQUEST`, player s already in guild")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_GUILD_EXIST, "player is in guild"});
	end

	-- 军团不存在
	if guild == nil then
		log.error(id .. "Fail to `C_GUILD_JOIN_REQUEST`, guild not exist")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_GUILD_NOT_EXIST, "guild not exist"});
	end

	-- 军团战已经开始
	--[[if RoomManager.IsRunning() then
		log.error(id .. "Fail to `C_GUILD_JOIN_REQUEST`, guild war running")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_GUILD_UNABLE_COP, "guild war running"});
	end--]]

	--[[ 不属于同一个国家
	if not (player.country == guild.leader.country) then
		log.error(id .. "Fail to `C_GUILD_JOIN_REQUEST`, guild is not from one country")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_COUNTRY_MATCH, "guild is not same country"});
	end
	]]

	-- 已经请求
	if guild.requests[player.id] then
		log.error(id .. "Fail to `C_GUILD_JOIN_REQUEST`, request is in progressing")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_GUILD_REQUEST_INPROGRESS, "request is in progress"});
	end
	
	if player.leaveTime and player.leaveTime + cool_down >= loop.now() then
		log.error(id .. "Fail to `C_GUILD_JOIN_REQUEST`, cd")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_GUILD_UNABLE_JOIN, "退出军团2小时内不能再加入军团"});
	end

	if guild.auto_confirm == 1 then
		guild:Join(player)
		EventManager.DispatchEvent("GUILD_JOIN", {guild = guild, player = player});
		log.info(id .. "Success `C_GUILD_JOIN_REQUEST`")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_SUCCESS, guild.id});
	end

	if guild:JoinRequest(player) then
		-- 给团长发送通知
		--GuildEvent.onJoinRequest(guild, player);

		EventManager.DispatchEvent("GUILD_REQUEST_JOIN", {guild = guild, player = player, time = loop.now()});

		log.info(id .. "Success `C_GUILD_JOIN_REQUEST`")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_SUCCESS, guild.id});
	else
		log.error(id .. "Fail to `C_GUILD_JOIN_REQUEST`, failed")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_ERROR, "failed"});
	end
end

local function onGuildAutoJoin(conn, id, request)
	local sn = request[1] or 0;
	local auto_join = request[2] or 0;

	log.debug(string.format("onGuildAutoJoin"));

	local cmd = Command.C_GUILD_AUTO_JOIN_RESPOND;

	local player = PlayerManager.Get(id);

	-- 角色不存在
	if player.name == nil then
		log.error(id .. "Fail to `C_GUILD_AUTO_JOIN_REQUEST`, player not exists")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_CHARACTER_NOT_EXIST, "player not exist"});
	end
	
	-- 玩家已经有军团
	if player.guild then
		log.error(id .. "Fail to `C_GUILD_AUTO_JOIN_REQUEST`, player s already in guild")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_GUILD_EXIST, "player is in guild"});
	end
	
	if player.auto_join and player.auto_join == auto_join then
		log.error(id .. "Fail to `C_GUILD_AUTO_JOIN_REQUEST`, player.auto_join == auto_join")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_ERROR});
	end

	if player.leaveTime and player.leaveTime + cool_down >= loop.now() then
		log.error(id .. "Fail to `C_GUILD_AUTO_JOIN_REQUEST`, cd")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_GUILD_UNABLE_JOIN, "退出军团2小时内不能再加入军团"});
	end

	if auto_join == 0 then
        GuildManager.CancelAutoJoin(player)
        log.info(id .. "Success `C_GUILD_AUTO_JOIN_REQUEST`")
        return sendClientRespond(conn, cmd, id, {sn, Command.RET_SUCCESS});
    end

	local success, guild = GuildManager.AutoJoinRequest(player)
	if success and guild then
		EventManager.DispatchEvent("GUILD_JOIN", {guild = guild, player = player});
	end

	log.info(id .. "Success `C_GUILD_AUTO_JOIN_REQUEST`")
	return sendClientRespond(conn, cmd, id, {sn, Command.RET_SUCCESS});
end

local function onGuildQueryPlayerAutoJoin(conn, id, request)
	local sn = request[1] or 0;
	log.debug(string.format("onGuildQueryPlayerAutoJoin"));

	local cmd = Command.C_GUILD_QUERY_PLAYER_AUTO_JOIN_RESPOND;

	local player = PlayerManager.Get(id);

	return sendClientRespond(conn, cmd, id, {sn, Command.RET_SUCCESS, player.auto_join and player.auto_join or 0});
end

local function onGuildLeave(conn, id, request)
	local sn = request[1] or 0;

	log.debug(string.format("onGuildLeave"));

	local cmd = Command.C_GUILD_LEAVE_RESPOND;

	local player = PlayerManager.Get(id);

	-- 没有军团
	if player.guild == nil then
		log.error(id .. "Fail to `C_GUILD_LEAVE_REQUEST`, player is not in guild")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_GUILD_NOT_EXIST, "player is not in guild"});
	end

	local guild = player.guild;

	-- 军团团长
	if guild.leader.id == player.id then
		if (guild.mcount > 1) then
			log.error(id .. "Fail to `C_GUILD_LEAVE_REQUEST`, player is leader")
			return sendClientRespond(conn, cmd, id, {sn, Command.RET_GUILD_LEADER, "player is leader"});
		end
	end
	
	-- 军团战已经开始
	--if RoomManager.IsRunning() then
	--	log.error(id .. "Fail to `C_GUILD_LEAVE_REQUEST`, guild war running")
	--	return sendClientRespond(conn, cmd, id, {sn, Command.RET_GUILD_UNABLE_COP, "guild war running"});
	--end

	-- patch 军团战报名阶段，退出军团，触发事件
	--RoomManager.ResetOrder(id)

	if player.guild:Leave(player) then
		player.leaveTime = loop.now();
		-- 发送通知给现有
		--GuildEvent.onLeave(guild, player);
        --delActJoinQueue(id,guild.id);
		EventManager.DispatchEvent("GUILD_LEAVE", {guild = guild, player = player, opt = player});
		log.info(id .. "Success `C_GUILD_LEAVE_REQUEST`")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_SUCCESS, player.leaveTime + cool_down});
	else
		log.error(id .. "Fail to `C_GUILD_LEAVE_REQUEST`, failed")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_ERROR, "failed"});
	end
end

local function onGuildQueryApply(conn, id, request)
	local sn = request[1] or 0;

	log.debug(string.format("onGuildQueryApply"));

	local cmd = Command.C_GUILD_QUERY_APPLY_RESPOND;

	local player = PlayerManager.Get(id);
	local guild = player.guild;

	-- 玩家没有军团
	if player == nil or player.name == nil then
		log.error(id .. "Fail to `C_GUILD_QUERY_APPLY_REQUEST`, player is not in guild")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_CHARACTER_NOT_EXIST, "player is not in guild"});
	end

	if player.guild == nil then
		log.error(id .. "Fail to `C_GUILD_QUERY_APPLY_REQUEST`, player is not in guild")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_GUILD_NOT_EXIST, "player is not in guild"});
	end

	-- 没有权限
	if not HasPermission(player.title, "audit") then--player.title == 0 or player.title > 10 then
		log.error(id .. "Fail to `C_GUILD_QUERY_APPLY_REQUEST`, player is not leader")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_GUILD_PREMISSIONS, "player is not leader"});
	end

	local msg = {
		sn,
		Command.RET_SUCCESS,
		{}
	}

	for pid, info in pairs(guild.requests) do
		local rp = PlayerManager.Get(pid);
		assert(rp.name);
		if rp.guild == nil then
			local info = {rp.id, rp.name, rp.level, info.time, rp.arena_order or 0, rp.online};
			table.insert(msg[3], info)
		else
			-- 移除已经加入军团的玩家的请求
			guild:RemoveRequest(pid);
		end
	end

	log.info(id .. "Success `C_GUILD_QUERY_APPLY_REQUEST`")
	return sendClientRespond(conn, cmd, id, msg);
end

local function onGuildAudit(conn, id, request)
	local sn = request[1] or 0;
	local rid = request[2];
	local atype = request[3];

	local cmd = Command.C_GUILD_AUDIT_RESPOND;

	-- 参数错误
	if rid == nil or atype == nil then
		log.error(id .. "Fail to `C_GUILD_AUDIT_REQUEST`, param error")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_PARAM_ERROR, "param error"});
	end
	
	local player = PlayerManager.Get(id);

	-- 玩家没有军团
	if player == nil or player.name == nil then
		log.error(id .. "Fail to `C_GUILD_AUDIT_REQUEST`, player is not in guild")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_CHARACTER_NOT_EXIST, "player is not in guild"});
	end

	if player.guild == nil then
		log.error(id .. "Fail to `C_GUILD_AUDIT_REQUEST`, player is not in guild")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_GUILD_NOT_EXIST, "player is not in guild"});
	end

	-- 没有权限
	if not HasPermission(player.title, "audit") then
		log.error(id .. "Fail to `C_GUILD_AUDIT_REQUEST`, player is not leader")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_GUILD_PREMISSIONS, "player is not leader"});
	end

	--[[-- 军团战已经开始
	if RoomManager.IsRunning() then
		log.error(id .. "Fail to `C_GUILD_AUDIT_REQUEST`, guild war running")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_GUILD_UNABLE_COP, "guild war running"});
	end--]]

--[[
	-- 玩家没有军团
	if player == nil or player.guild == nil then
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_NOT_EXIST, "player is not in guild"});
	end


	-- 没有权限
	if player.title == 0 or player.title > 10 then
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_ERROR, "player is not leader"});
	end
--]]

	local guild = player.guild;
	-- 请求不存在
	if guild.requests[rid] == nil then
		log.error(id .. "Fail to `C_GUILD_AUDIT_REQUEST`, request is not exists")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_GUILD_REQUEST_NOT_EXIST, "request is not exist"});
	end

	local rp = PlayerManager.Get(rid);
	-- 玩家不存在
	if rp.name == nil then
		guild:RemoveRequest(rid);
		log.error(id .. "Fail to `C_GUILD_AUDIT_REQUEST`, player is not exists")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_GUILD_REQUEST_NOT_EXIST, "player not exist"});
	end

	-- 玩家已经加入军团
	if rp.guild then
		guild:RemoveRequest(rid);
		log.error(id .. "Fail to `C_GUILD_AUDIT_REQUEST`, player is already in guild")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_GUILD_EXIST, "player already have guild"});
	end

	--[[ 不能进行人事变动的时间段
	if JTYW.IsFighting() then
		log.error(id .. "Fail to `C_GUILD_AUDIT_REQUEST`, can't change human resource when fighting")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_GUILD_UNABLE_COP, "unable to change the personnel now"});
	end
	]]

	--加入CD
	if rp.leaveTime and rp.leaveTime + cool_down >= loop.now() then
		log.error(id .. "Fail to `C_GUILD_AUDIT_REQUEST`, player cd")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_COOLDOWN})
	end

	if atype == 1 then
		-- 同意
        if (guild.mcount >= guild.max_mcount) then
                log.error(id .. "Fail to `C_GUILD_AUDIT_REQUEST`, guild is full")
                return sendClientRespond(conn, cmd, id, {sn, Command.RET_GUILD_FULL});
        end
		if guild:Join(rp) then
			guild:RemoveRequest(rid);

			--GuildEvent.onAudit(guild, rp, player, atype);
			--GuildEvent.onJoin(guild, rp);

			EventManager.DispatchEvent("GUILD_AUDIT", {guild = guild, player = player, target = rp, atype = atype});
			EventManager.DispatchEvent("GUILD_JOIN", {guild = guild, player = rp});

			log.info(id .. "Success `C_GUILD_AUDIT_REQUEST`")
			return sendClientRespond(conn, cmd, id, {sn, Command.RET_SUCCESS, rp.id, atype});
		else
			log.error(id .. "Fail to `C_GUILD_AUDIT_REQUEST`, failed")
			return sendClientRespond(conn, cmd, id, {sn, Command.RET_ERROR, "failed"});
		end
	else
		-- 拒绝
		guild:RemoveRequest(rid);

		-- 发送拒绝通知给申请者
		--GuildEvent.onAudit(guild, rp, player, atype);

		EventManager.DispatchEvent("GUILD_AUDIT", {guild = guild, player = player, target = rp, atype = atype});

		log.info(id .. "Success `C_GUILD_AUDIT_REQUEST`")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_SUCCESS, rp.id, atype});
	end
end

local function onGuildAutoConfirm(conn, id, request)
	local sn = request[1] or 0;
	local auto_confirm = request[2] 

	local cmd = Command.C_GUILD_AUTO_CONFIRM_RESPOND;

	-- 参数错误
	if auto_confirm == nil then
		log.error(id .. "Fail to `C_GUILD_AUTO_CONFIRM_REQUEST`, param error")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_PARAM_ERROR, "param error"});
	end

	log.debug(string.format("player %d begin to set guild auto confirm: %d", id, auto_confirm))
	
	local player = PlayerManager.Get(id);

	-- 玩家没有军团
	if player == nil or player.name == nil then
		log.error(id .. "Fail to `C_GUILD_AUTO_CONFIRM_REQUEST`, player is not in guild")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_CHARACTER_NOT_EXIST, "player is not in guild"});
	end

	if player.guild == nil then
		log.error(id .. "Fail to `C_GUILD_AUTO_CONFIRM_REQUEST`, player is not in guild")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_GUILD_NOT_EXIST, "player is not in guild"});
	end

	-- 没有权限
	if not HasPermission(player.title, "auto_confirm") then
		log.error(id .. "Fail to `C_GUILD_AUTO_CONFIRM_REQUEST`, player is not leader")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_GUILD_PREMISSIONS, "player is not leader"});
	end

	--[[-- 军团战已经开始
	if RoomManager.IsRunning() then
		log.error(id .. "Fail to `C_GUILD_AUDIT_REQUEST`, guild war running")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_GUILD_UNABLE_COP, "guild war running"});
	end--]]

--[[
	-- 玩家没有军团
	if player == nil or player.guild == nil then
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_NOT_EXIST, "player is not in guild"});
	end


	-- 没有权限
	if player.title == 0 or player.title > 10 then
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_ERROR, "player is not leader"});
	end
--]]

	local guild = player.guild;

	if auto_confirm == guild.auto_confirm then
		log.error(id .. "Fail to `C_GUILD_AUTO_CONFIRM_REQUEST`, auto_confirm == guild.auto_confirm")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_ERROR});
	end

	local success , join_players = guild:SetAutoConfirm(auto_confirm)
	
	if auto_confirm == 1 then
		for _, join_player in ipairs(join_players) do
			EventManager.DispatchEvent("GUILD_JOIN", {guild = guild, player = join_player});
		end

		for pid, v in pairs(guild.requests) do
			local rp = PlayerManager.Get(pid)
			if rp.name and (not rp.guild) and ((not player.leaveTime) or (player.leaveTime + cool_down < loop.now())) and guild:Join(rp) then
				EventManager.DispatchEvent("GUILD_AUDIT", {guild = guild, player = player, target = rp, atype = 1});
				EventManager.DispatchEvent("GUILD_JOIN", {guild = guild, player = rp});
			end
		end
		guild:RemoveAllRequest()
		log.info(id .. "Success `C_GUILD_AUTO_CONFIRM_REQUEST`")
	end

	return sendClientRespond(conn, cmd, id, {sn, Command.RET_SUCCESS});
end

local function onGuildSetting(conn, id, request)	-- 此含有修改军团公告
	local sn = request[1] or 0;
	local notice = nil
	local desc   = nil

	if type(request[2])=='string' and type(request[3])=='string' then
		-- 兼容老版本
		notice =request[2]
		desc =request[3]
		log.info(string.format("onGuildSetting:notice =%s, desc =%s", notice or "", desc or ""))
	else
		-- 新版本
		local flag = request[2] or 1
		if flag==1 then
			notice =request[3] or nil
		elseif flag==2 then
			desc =request[3] or nil
		elseif flag==3 then
			notice =request[3] or nil
			desc =request[4] or nil
		end
		log.info(string.format("onGuildSetting:flag =%d, notice =%s, desc =%s", flag, notice or "", desc or ""))
	end
	-- prepare
	local cmd = Command.C_GUILD_SETTING_RESPOND;
	local player = PlayerManager.Get(id);

	-- 玩家没有军团
	if player == nil or player.name == nil then
		log.error(id .. "Fail to `C_GUILD_SETTING_REQUEST`, player is not guild")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_CHARACTER_NOT_EXIST, "player is not in guild"});
	end

	if player.guild == nil then
		log.error(id .. "Fail to `C_GUILD_SETTING_REQUEST`, player is not guild")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_GUILD_NOT_EXIST, "player is not in guild"});
	end

	-- 没有权限
	if not HasPermission(player.title, "set_slogan") then
		log.error(id .. "Fail to `C_GUILD_SETTING_REQUEST`, player is not leader")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_GUILD_PREMISSIONS, "player is not leader"});
	end

	-- set state
	local need_notify =false
	local guild = player.guild;
	if desc and type(desc)=='string' then
		guild.desc = desc;
		need_notify =true
	end
	if notice and type(notice)=='string' then
		guild.notice = notice;
		need_notify =true
		local ModifyNotice = 104
		local event_log = GuildEventLog.Get(player.guild.id)
	        if event_log then
        	        event_log:AddLog(ModifyNotice,{ player.id, notice })
	        end
	end
	
	-- notify
	if need_notify then
		EventManager.DispatchEvent("GUILD_SETTING", {guild = guild, opt = player});
	end

	log.info(id .. "Success `C_GUILD_SETTING_REQUEST`")
	return sendClientRespond(conn, cmd, id, {sn, Command.RET_SUCCESS, "success"});
end

local function onGuildBossSetting(conn, id, request)
	local sn = request[1] or 0;
	local boss = request[2];

	local cmd = Command.C_GUILD_BOSS_SETTING_RESPOND;

	local player = PlayerManager.Get(id);

	-- 玩家没有军团
	if player == nil or player.name == nil then
		log.error(id .. "Fail to `C_BOSS_GUILD_SETTING_REQUEST`, player is not in guild")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_CHARACTER_NOT_EXIST, "player is not in guild"});
	end

	if player.guild == nil then
		log.error(id .. "Fail to `C_BOSS_GUILD_SETTING_REQUEST`, player is not in guild")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_GUILD_NOT_EXIST, "player is not in guild"});
	end

	-- 没有权限
	if player.title == 0 or player.title > 10 then
		log.error(id .. "Fail to `C_BOSS_GUILD_SETTING_REQUEST`, player is not leader")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_GUILD_PREMISSIONS, "player is not leader"});
	end

	local guild = player.guild;

	if boss then
		guild.boss = boss;
		EventManager.DispatchEvent("GUILD_BOSS_SETTING", {guild = guild, opt = player});
	end
	log.info(id .. "Success `C_BOSS_GUILD_SETTING_REQUEST`")
	return sendClientRespond(conn, cmd, id, {sn, Command.RET_SUCCESS, "success"});
end

local function onGuildQueryGuildList(conn, id, request)
	log.debug(id .. "onGuildQueryGuildList " .. id);

	local sn = request[1] or 0;
	--protobuf.close_decoder(request);

	local cmd = Command.C_GUILD_QUERY_GUILD_LIST_RESPOND;

	local msg = {
		sn,
		Command.RET_SUCCESS,
		{}
	}

	local guild_list = GuildManager.GetTopKGuild() or {};
    for _, gid in pairs(guild_list) do
		if gid ~= GUILD_GID_MIN then
            local g = GuildManager.Get(gid);
			local ginfo = buildGuildArray(g, true);
			table.insert(ginfo, g.requests[id] and 1 or 0)
			table.insert(msg[3], ginfo);
		end
	end
	log.info(id .. "Success `C_GUILD_QUERY_GUILD_LIST_REQUEST`")
	--log.info(sprinttb(msg))
	return sendClientRespond(conn, cmd, id, msg);
end

local function onGuildQueryMembers(conn, id, request)
	local sn = request[1] or 0;

	--protobuf.close_decoder(request);

	local cmd = Command.C_GUILD_QUERY_MEMBERS_RESPOND;

	local player = PlayerManager.Get(id);

	-- 玩家没有军团
	if player == nil or player.name == nil then
		log.error(id .. "Fail to `C_GUILD_QUERY_MEMBERS_REQUEST`, player is not in guild")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_CHARACTER_NOT_EXIST, "player is not in guild"});
	end

	if player.guild == nil then
		log.error(id .. "Fail to `C_GUILD_QUERY_MEMBERS_REQUEST`, player is not in guild")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_GUILD_NOT_EXIST, "player is not in guild"});
	end

	local guild = player.guild;

	local msg = {
		sn,
		Command.RET_SUCCESS,
		{}
	}

	local members = guild.members;
	for _, m in pairs(members) do
		local cont = m.cont;
		local minfo = {
			m.id,
			m.name or "",
			m.level or 0,
			(guild.leader.id == m.id) and 1 or m.title,
			cont.today, -- today contribution
			cont.total, -- contribution
			m.online and true or false, -- online flag
			m.login or 0,
			m.arena_order,
			m.reward_flag,
			m.today_donate_count,
		}
		table.insert(msg[3], minfo);
	end
	log.info(id .. "Success `C_GUILD_QUERY_MEMBERS_REQUEST`")
	return sendClientRespond(conn, cmd, id, msg);
end

local function onGuildQueryByPlayer(conn, id, request)
	local sn = request[1] or 0;
	local pid = request[2] or id;

	--protobuf.close_decoder(request);
	
	log.debug(id .. "onGuildQueryByPlayer");

	local cmd = Command.C_GUILD_QUEYR_BY_PLAYER_RESPOND;
	
	local player = PlayerManager.Get(pid);
	local guild = player.guild;
	local ginfo = buildGuildArray(player.guild, true);

	local msg = {
		sn,
		Command.RET_SUCCESS,
		player.id,
		(guild and (guild.leader.id == player.id)) and 1 or player.title,
		player.leaveTime and player.leaveTime + cool_down or 0,
		unpack(ginfo),
	};
	log.info(id .. "Success `C_GUILD_QUERY_BY_PLAYER_REQUEST`")
	return sendClientRespond(conn, cmd, id, msg);
end

local function onGuildDissolve(conn, id, request)
	local sn = request[1] or 0;
	local auth = request[2] or "";

	log.debug(string.format("onGuildDissolve"));

	local cmd = Command.C_GUILD_DISSOLVE_RESPOND;

	local player = PlayerManager.Get(id);

	-- 玩家没有军团
	if player == nil or player.name == nil then
		log.error(id .. "Fail to `C_GUILD_DISSOLVE_REQUEST`, player is not in guild")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_CHARACTER_NOT_EXIST, "player is not in guild"});
	end

	if player.guild == nil then
		log.error(id .. "Fail to `C_GUILD_DISSOLVE_REQUEST`, player is not in guild")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_GUILD_NOT_EXIST, "player is not in guild"});
	end

	local guild = player.guild;

	-- 军团团长
	if guild.leader.id == player.id then
		if (guild.mcount > 1) then
			log.error(id .. "Fail to `C_GUILD_DISSOLVE_REQUEST`, more than one members")
			return sendClientRespond(conn, cmd, id, {sn, Command.RET_GUILD_MEMBER, "more than one members"});
		end
	else
		log.error(id .. "Fail to `C_GUILD_DISSOLVE_REQUEST`, player is not leader")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_GUILD_PREMISSIONS, "player is not leader"});
	end

--[[
	if auth ~= "123" then
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_GUILD_PREMISSIONS, "auth error"});
	end
--]]

	if player.guild:Leave(player) then
		player.leaveTime = loop.now();
		-- 发送通知给玩家
		EventManager.DispatchEvent("GUILD_LEAVE", {guild = guild, player = player, opt = player});
		log.info(id .. "Success `C_GUILD_DISSOLVE_REQUEST`")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_SUCCESS, player.leaveTime + cool_down});
	else
		log.error(id .. "Fail to `C_GUILD_DISSOLVE_REQUEST`, failed")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_ERROR, "failed"});
	end
end


local function onGuildQueryExpLog(conn, id, request)
	local cmd = Command.C_QUERY_GUILD_EXP_LOG_RESPOND;
	-- [sn, result, [time, [pid,name] exp], ...]
	
	local player = PlayerManager.Get(id);

	log.debug(string.format("onGuildQueryExpLog player %u", id));

	-- 玩家没有军团
	if player == nil or player.name == nil then
		log.error(id .. "Fail to `C_QUERY_GUILD_EXP_LOG_REQUEST`, player is not exist")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_CHARACTER_NOT_EXIST, "player is not exist"});
	end

	if player.guild == nil then
		log.error(id .. "Fail to `C_QUERY_GUILD_EXP_LOG_REQUEST`, player is not in guild")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_GUILD_NOT_EXIST, "player is not in guild"});
	end

	local guild = player.guild;

	local respond = {
		request[1] or 0,
		Command.RET_SUCCESS,
		{}
	};

	for idx = 1, guild.log.length do
		if idx > 18 then
			break;
		end

		local log = guild.log[idx];
		if log then
			local p = (log.pid == 0) and {id=0,name="-"} or PlayerManager.Get(log.pid);
			table.insert(respond[3], {
				log.time,
				p.id,
				p.name or "",
				log.exp,
				log.reason
			});
		end
	end

	log.info(id .. "Success `C_QUERY_GUILD_EXP_LOG_REQUEST`")
	sendClientRespond(conn, cmd, id, respond);
end


local function morePower(t1, t2)
	if t1 == 0 then
		return false;
	end

	if t2 == 0 then
		return true;
	end

	if t1 < t2 then
		return true;
	end
	return false;
end

local function titleDiff(t1, t2)
	local title1 = t1
	local title2 = t2
	if title1 == 0 then
		title1 = GetSecondMinTitle() + 1	
	end
	if title2 == 0 then
		title2 = GetSecondMinTitle() + 1	
	end

	return title2 - title1
end

local function numToTitleStr(title)
	if title == 1 then
		return YQSTR.GUILD_TITLE_LEADER
	elseif title == 2 then
		return YQSTR.GUILD_TITLE_ASSISTANT_LEADER
	elseif title == 3 then
		return YQSTR.GUILD_TITLE_CORE_MEMBER
	elseif title == 0 then
		return YQSTR.GUILD_TITLE_MEMBER
	else 
		return ""
	end	
end

local function onGuildSetTitle(conn, id, request)
	local sn = request[1] or 0;
	local tid = request[2] or 0;
	local title = request[3] or 0;

	--protobuf.close_decoder(request);

	local cmd = Command.C_GUILD_SET_TITLE_RESPOND;

	local player = PlayerManager.Get(id);

	-- 玩家没有军团
	if player == nil or player.name == nil then
		log.error(id .. "Fail to `C_GUILD_SET_TITLE_REQUEST`, player is not in guild")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_CHARACTER_NOT_EXIST, "player is not in guild"});
	end

	if player.guild == nil then
		log.error(id .. "Fail to `C_GUILD_SET_TITLE_REQUEST`, player is not in guild")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_GUILD_NOT_EXIST, "player is not in guild"});
	end

	local guild = player.guild;

	local target = guild.members[tid];
	if target == nil then
		log.error(id .. "Fail to `C_GUILD_SET_TITLE_REQUEST`, target not exists")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_TARGET_NOT_EXIST, "target not exists"});
	end

	if not HasPermission(player.title, "set_title") or not morePower(player.title, target.title) then
		log.error(id .. "Fail to `C_GUILD_SET_TITLE_REQUEST`, no permissions")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_GUILD_PREMISSIONS, "no permissions"});
	end

	--[[if math.abs(target.title - title) > 1 then
		log.error(id .. "Fail to `C_GUILD_SET_TITLE_REQUEST`,math.abs(target.title - title) > 1 ")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_ERROR});
	end-]]

	if titleDiff(title, target.title) >= 1 and titleDiff(player.title, title) < 1 then
		log.error(id .. "Fail to `C_GUILD_SET_TITLE_REQUEST`, increase title, titleDiff(player.title, title) < 1")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_ERROR});
	end

	--[[if guild.leader.id ~= player.id and not morePower(player.title, title) then
		log.error(id .. "Fail to `C_GUILD_SET_TITLE_REQUEST`, no permissions")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_GUILD_PREMISSIONS, "no permissions"});
	end--]]

	local ot = target.title;

	target.title = title;

	--GuildEvent.onTitleChange(guild, target, player, ot);
	EventManager.DispatchEvent("GUILD_SET_TITLE", {guild = guild, opt = player, player = target, ot = ot});
	send_system_mail(target.id, YQSTR.GUILD_APPOINT_MAIL_TITLE, string.format(YQSTR.GUILD_APPOINT_MAIL_CONTENT, player.name, numToTitleStr(title)), {})
	log.info(id .. "Success `C_GUILD_SET_TITLE_REQUEST`")
	return sendClientRespond(conn, cmd, id, {sn, Command.RET_SUCCESS, target.id, title});
end

local function onGuildInvite(conn, id, request)
    local sn = request[1] or 0;
    local target_id = request[2] or 0;
    local cmd = Command.C_GUILD_INVITE_RESPOND
    if type(target_id) ~= 'number' then
		log.error(id .. "Fail to `C_GUILD_INVITE_RESPOND`, target_id is not number")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_PARAM_ERROR})
    end
	local host = PlayerManager.Get(id);
	if host == nil or host.name == nil then
		log.error(id .. "Fail to `C_GUILD_INVITE_RESPOND`, host is not exist")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_CHARACTER_NOT_EXIST});
	end

    --邀请人是否有军团
	if host.guild == nil then
		log.error(id .. "Fail to `C_GUILD_INVITE_RESPOND`, host is not in guild")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_GUILD_NOT_EXIST})
	end
	local guild = host.guild;
    
    --邀请人是否有权限
	if host.title == 0 or host.title > 10 then
		log.error(id .. " Fail to `C_GUILD_INVITE_RESPOND`, host do not have permission")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_PREMISSIONS});
	end

    --军团是否满员
    if guild:IsFull() then
		log.error(id .. " Fail to `C_GUILD_INVITE_RESPOND`, guild is full")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_FULL});
    end

    --被邀请人
    local guest = PlayerManager.Get(target_id)
	
    --是否存在
    if guest == nil or guest.name == nil then
		log.error(id .. "Fail to `C_GUILD_INVITE_RESPOND`, guest not exists")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_CHARACTER_NOT_EXIST})
	end

    --等级	
    --if not limit.check(33, guest.level, guest.vip) then
	--	log.error(id .. "Fail to `C_GUILD_INVITE_RESPOND`, guest level limit")
	--	return sendClientRespond(conn, cmd, id, {sn, Command.RET_LEVEL_LIMIT});
    --end

	-- 玩家已经有军团
	if guest.guild then
		log.error(id .. "Fail to `C_GUILD_INVITE_RESPOND`, guest is already in guild")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_GUILD_EXIST});
	end
    
    --加入CD
	if guest.leaveTime and guest.leaveTime + cool_down >= loop.now() then
		log.error(id .. "Fail to `C_GUILD_INVITE_RESPOND`, guest cd")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_COOLDOWN})
	end

    --生成队列
    local idx = InviteManager.Add(id, target_id, guild.id)
    sendClientRespond(conn, cmd, id, {sn, Command.RET_SUCCESS}) 
    EventManager.DispatchEvent("GUILD_INVITE", {host =  id, gid = guild.id, invite_id = idx, guest = target_id})
    log.info(string.format("player %d Success to `C_GUILD_INVITE_RESPOND`, gid = %d, guest = %d, invite_id = %d", id or -1, guild.id or -1, target_id or -1, idx or -1 ))
end

local function onGuildAccpetInvite(conn, id, request)
    local sn = request[1] or 0;
    local invite_id = request[2] or 0;
    local gid = request[3] or 0;
    local cmd = Command.C_GUILD_ACCEPT_INVITE_RESPOND

    if type(invite_id ) ~= 'number' or type(gid) ~= 'number' then
		log.error(id .. "Fail to `C_GUILD_ACCEPT_INVITE`, invite_id or gid is string")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_PARAM_ERROR})
    end

    local data= InviteManager.Get(invite_id)
    log.info(string.format("player %d BEGIN C_GUILD_ACCEPT_INVITE_RESPOND, invite_id %d, gid %d", id or -1, invite_id or -1, gid or -1))
    if not data then
		log.error(id .. "Fail to `C_GUILD_ACCEPT_INVITE`, err invite_id "..(invite_id))
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_PARAM_ERROR})
    end

    --[[1.use 2.host 3.guest 4.gid 5.time]]
    if data[1] then
        log.error(id .. "Fail to `C_GUILD_ACCEPT_INVITE`, invitation have been used")
        return sendClientRespond(conn, cmd, id, {sn, Command.RET_GUILD_INVITE_USED})
    end
    if data[3] ~= id then
        --不行，不是你的 
        log.error(id .." Fail to `C_GUILD_ACCEPT_INVITE`, not your invitation "..(data[3] or -1))
        return sendClientRespond(conn, cmd, id, {sn, Command.RET_DEPEND})
    end
    if data[4] ~= gid then
        --不行，军团id不对应
        log.error(string.format("%d Fail to `C_GUILD_ACCEPT_INVITE`, invite gid %d, cli gid %d", id, data[4], gid))
        return sendClientRespond(conn, cmd, id, {sn, Command.RET_PARAM_ERROR})
    end
    if loop.now() - data[5] > (5 * 60) then
        log.error(string.format("%d Fail to `C_GUILD_ACCEPT_INVITE`, invite time out %d", id, data[5]))
        return sendClientRespond(conn, cmd, id, {sn, Command.RET_ESCORT_TIME_OUT})
    end
    --用掉
    InviteManager.Use(invite_id)
    
    --检查用户状态
    local guest = PlayerManager.Get(id)
    --是否存在
    if guest == nil or guest.name == nil then
		log.error(id .. "Fail to `C_GUILD_ACCPET_INVITE_RESPOND`, guest not exists")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_CHARACTER_NOT_EXIST})
	end
    --等级	
    --if not limit.check(33, guest.level, guest.vip) then
	--	log.error(id .. "Fail to `C_GUILD_ACCEPT_INVITE_RESPOND`, guest level limit")
	--	return sendClientRespond(conn, cmd, id, {sn, Command.RET_LEVEL_LIMIT});
    --end
	-- 玩家已经有军团
	if guest.guild then
		log.error(id .. "Fail to `C_GUILD_ACCEPT_INVITE_RESPOND`, guest is already in guild")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_GUILD_EXIST});
	end
    --加入CD
	if guest.leaveTime and guest.leaveTime + cool_down >= loop.now() then
		log.error(id .. "Fail to `C_GUILD_ACCEPT_INVITE_RESPOND`, guest cd")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_COOLDOWN})
	end
    
    --检查军团状态
    local guild = GuildManager.Get(gid)
    if guild:IsFull() then
		log.error(id .. "Fail to `C_GUILD_ACCEPT_INVITE_RESPOND`, guild full")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_FULL})
    end
    if guild:Join(guest) then
        log.info(id .. " Success to `C_GUILD_ACCEPT_INVITE_RESPOND`")
        EventManager.DispatchEvent("GUILD_JOIN", {guild = guild, player = guest});
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_SUCCESS})
    else
        log.error(id .. " Fail to `C_GUILD_ACCEPT_INVITE_RESPOND`, guild join err");
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_ERROR})
    end
end

local function server_leader_work(conn, channel, request)
	log.debug(string.format("server_leader_work: ai %d donate. ", request.pid))	
	if channel ~= 0 then
		log.error("server_leader_work: channel ~= 0")
		return
	end
	local sn = request.sn or 1
	local pid = request.pid

	local player = PlayerManager.Get(pid)
	if player == nil then
		log.warning(string.format("server_leader_work: player %d is not exists.", pid))
		return
	end
	if player.guild == nil then
		log.warning(string.format("server_leader_work: player %d has no guild.", pid))
		return
	end
	local guild = player.guild
		
	if guild.leader.id ~= pid then
		log.warning(string.format("server_leader_work: player %d is not leader, leader is %d", pid, guild.leader.id))
		return
	end

	-- 找到一个非ai的成员
	local peer = nil
	for id, _ in pairs(guild.members) do
		if id > 110000 then
			peer = id
			break
		end
	end

	if peer then		-- 转让队长
		local target = PlayerManager.Get(peer)
		local ot1 = player.title;
		local ot2 = target.title;
		guild.leader = target
		EventManager.DispatchEvent("GUILD_SET_LEADER", {guild = guild, opt = player, leader = target});
		EventManager.DispatchEvent("GUILD_SET_TITLE", {guild = guild, opt = player, player = player, ot = ot1});
		EventManager.DispatchEvent("GUILD_SET_TITLE", {guild = guild, opt = player, player = target, ot = ot2});
	else			-- 解散军团
		for _, member in pairs(guild.members) do
			guild:Leave(member)
		end
	end
end

local function onGuildSetLeader(conn, id, request)
	local sn = request[1] or 0;
	local tid = request[2];

	--protobuf.close_decoder(request);

	log.debug("onGuildSetLeader " .. tid);

	local cmd = Command.C_GUILD_SET_LEADER_RESPOND;

	local player = PlayerManager.Get(id);
	-- 玩家没有军团
	if player == nil or player.name == nil then
		log.error(id .. "Fail to `C_GUILD_SET_LEADER_REQUEST`, player is not in guild")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_CHARACTER_NOT_EXIST, "player is not in guild"});
	end

	if player.guild == nil then
		log.error(id .. "Fail to `C_GUILD_SET_LEADER_REQUEST`, player is not in guild")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_GUILD_NOT_EXIST, "player is not in guild"});
	end

	local guild = player.guild;

	if tid == nil or tid == playerid then
		log.error(id .. "Fail to `C_GUILD_SET_LEADER_REQUEST`, param error")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_PARAM_ERROR, "param error"});
	end

	-- 目标不存在
	if guild.members[tid] == nil then
		log.error(id .. "Fail to `C_GUILD_SET_LEADER_REQUEST`, target no exist")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_TARGET_NOT_EXIST, "target no exists"}); 
	end

	local target = guild.members[tid];

	if not (guild.leader.id == player.id) then
		log.error(id .. "Fail to `C_GUILD_SET_LEADER_REQUEST`, permissions")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_GUILD_PREMISSIONS, "premissions"});
	end

	local ot1 = player.title;
	local ot2 = target.title;

	guild.leader = target;

	--GuildEvent.onLeaderChange(guild, player);
	--GuildEvent.onTitleChange(guild, player, player, ot1);
	--GuildEvent.onTitleChange(guild, target, player, ot2);

	EventManager.DispatchEvent("GUILD_SET_LEADER", {guild = guild, opt = player, leader = target});

	EventManager.DispatchEvent("GUILD_SET_TITLE", {guild = guild, opt = player, player = player, ot = ot1});
	EventManager.DispatchEvent("GUILD_SET_TITLE", {guild = guild, opt = player, player = target, ot = ot2});
	
	log.info(id .. "Success `C_GUILD_SET_LEADER_REQUEST`")
	sendClientRespond(conn, cmd, id, {sn, Command.RET_SUCCESS, target.id});
end

local function onGuildQueryByTitle(conn, id, request)
	log.debug(id .. "onGuildQueryByTitle");
	local sn = request[1] or 0;
	local title = request[2];

	--protobuf.close_decoder(request);

	local cmd = Command.C_GUILD_QUERY_BY_TITLE_RESPOND;

	if title == nil then
		log.error(id .. "Fail to `C_GUILD_QUERY_BY_TITLE_REQUEST`, param error")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_PARAM_ERROR, "param error"});
	end


	local player = PlayerManager.Get(id);
	-- 玩家没有军团
	if player == nil or player.name == nil then
		log.error(id .. "Fail to `C_GUILD_QUERY_BY_TITLE_REQUEST`, player is not in guild")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_CHARACTER_NOT_EXIST, "player is not in guild"});
	end

	if player.guild == nil then
		log.error(id .. "Fail to `C_GUILD_QUERY_BY_TITLE_REQUEST`, player is not in guild")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_GUILD_NOT_EXIST, "player is not in guild"});
	end

	local guild = player.guild;

	local msg = {
		sn,
		Command.RET_SUCCESS,
		{}
	}

	if title == 1 then
		local minfo = {
			guild.leader.id,
			guild.leader.name,
			guild.leader.level,
		};
		table.insert(msg[3], minfo)
	else
		local members = guild.members;
		for _, m in pairs(members) do
			if m.title == title and guild.leader.id ~= m.id then
				local minfo = {
					m.id,
					m.name,
					m.level,
				}
				table.insert(msg[3], minfo)
			end
		end
	end
	log.info(id .. "Success `C_GUILD_QUERY_BY_TITLE_REQUEST`")
	return sendClientRespond(conn, cmd, id, msg);
end

local function onGuildKick(conn, id, request)
	local sn = request[1] or 0;
	local tid = request[2];

	--protobuf.close_decoder(request);

	log.debug("onGuildKick", id, tid);

	local cmd = Command.C_GUILD_KICK_RESPOND;

	if tid == nil or tid == playerid then
		log.error(id .. "Fail to `C_GUILD_KICK_REQUEST`, param error")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_PARAM_ERROR, "param error"});
	end

	local player = PlayerManager.Get(id);
	-- 玩家没有军团
	if player == nil or player.name == nil then
		log.error(id .. "Fail to `C_GUILD_KICK_REQUEST`, player is not guild")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_CHARACTER_NOT_EXIST, "player is not in guild"});
	end

	if player.guild == nil then
		log.error(id .. "Fail to `C_GUILD_KICK_REQUEST`, player is not guild")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_GUILD_NOT_EXIST, "player is not in guild"});
	end

	local guild = player.guild;

	if guild.members[tid] == nil then
		log.error(id .. "Fail to `C_GUILD_KICK_REQUEST`, target no exists")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_TARGET_NOT_EXIST, "target no exists"}); 
	end

	local target = guild.members[tid];

	if not HasPermission(player.title, "kick") or not morePower(player.title, target.title) then
		log.error(id .. "Fail to `C_GUILD_KICK_REQUEST`, permissions")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_GUILD_PREMISSIONS, "premissions"});
	end

	-- 军团战已经开始
	--if RoomManager.IsRunning() then
	--	log.error(id .. "Fail to `C_GUILD_KICK_REQUEST`, guild war running")
	--	return sendClientRespond(conn, cmd, id, {sn, Command.RET_GUILD_UNABLE_COP, "guild war running"});
	--end

	if guild:Leave(target) then
		--GuildEvent.onLeave(guild, target, player);
		EventManager.DispatchEvent("GUILD_LEAVE", {guild = guild, opt = player, player = target});
		log.info(id .. "Success `C_GUILD_KICK_REQUEST`")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_SUCCESS, target.id});
	else
		log.error(id .. "Fail to `C_GUILD_KICK_REQUEST`, failed")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_ERROR, "failed"});
	end
end


local function onGuildBuyMemberCount(conn, id, request)
	local sn = request[1] or 0;
    local value = request[2] or 0;
	log.debug("onGuildBuyMemberCount", id);

	local cmd = Command.C_GUILD_BUY_MEMBER_COUNT_RESPOND;

	local player = PlayerManager.Get(id);
	-- 玩家没有军团
	if player == nil or player.name == nil then
		log.error(id .. "Fail to `C_GUILD_BUY_MEMBER_COUNT_REQUEST`, player is not guild")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_CHARACTER_NOT_EXIST});
	end

	if player.guild == nil then
		log.error(id .. "Fail to `C_GUILD_BUY_MEMBER_COUNT_REQUEST`, player is not guild")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_GUILD_NOT_EXIST});
	end

	local guild = player.guild;
	if guild.member_buy_count + 1 > GuildConfig.GUILD_MAX_MEMBER_BUY_COUNT then
		log.error(id .. "Fail to `C_GUILD_BUY_MEMBER_COUNT_REQUEST`, buy count max")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_MAX_LEVEL});
	end

    local target_count = guild.member_buy_count + 1;
    local Config = GuildConfig.GuildMemberAddConfig[target_count];
    if player.vip < Config.vip_limit then
		log.error(id .. "Fail to `C_GUILD_BUY_MEMBER_COUNT_REQUEST`, player vip limit")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_VIP_LEVEL_LIMIT});
    end
    local consume = {type = Config.type, id = Config.id, value = Config.value}
    if consume.value ~= value then
		log.error(id .. "Fail to `C_GUILD_BUY_MEMBER_COUNT_REQUEST`, client send value not match ")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_DEPEND, guild.member_buy_count});
    end
	local respond = cell.sendReward(id, {}, {consume}, Command.REASON_CONSUME_TYPE_GUILD_BUY_MEMBER_COUNT);
	if respond and respond.result == Command.RET_SUCCESS then
        if guild:AddMemberBuyCount(player) then
            EventManager.DispatchEvent("GUILD_BUY_MEMBER_COUNT", {gid = guild.id, pid = id, member_buy_count = guild.member_buy_count});
            log.info(id .. "Success `C_GUILD_BUY_MEMBER_COUNT_REQUEST`")
            return sendClientRespond(conn, cmd, id, {sn, Command.RET_SUCCESS, target_count});
        else
           --pay back
           cell.sendReward(id, {consume}, {}, Command.REASON_CONSUME_TYPE_GUILD_BUY_MEMBER_COUNT);  
           log.error(id .. "Fail to `C_GUILD_BUY_MEMBER_COUNT_REQUEST`, failed")
           return sendClientRespond(conn, cmd, id, {sn, Command.RET_ERROR});
        end
    else
		log.error(id .. "Fail to `C_GUILD_BUY_MEMBER_COUNT_REQUEST`, failed")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_ERROR});
    end
end


local function onGuildCleanAllRequest(conn, id, request)
	local cmd = Command.C_GUILD_CLEAN_ALL_RESPOND;

	local sn = request[1] or 0;

	local player = PlayerManager.Get(id);
	-- 玩家没有军团
	if player == nil or player.name == nil then
		log.error(id .. "Fail to `C_GUILD_CLEAN_ALL_REQUEST`, player is not in guild")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_CHARACTER_NOT_EXIST, "player is not in guild"});
	end

	if player.guild == nil then
		log.error(id .. "Fail to `C_GUILD_CLEAN_ALL_REQUEST`, player is not in guild")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_GUILD_NOT_EXIST, "player is not in guild"});
	end

	-- 没有权限
	if player.title == 0 or player.title > 10 then
		log.error(id .. "Fail to `C_GUILD_CLEAN_ALL_REQUEST`, player is not leader")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_GUILD_PREMISSIONS, "player is not leader"});
	end

	local guild = player.guild;

	for rid, _ in pairs(guild.requests) do
		--GuildEvent.onAudit(guild, {id = rid}, player, 2);
		EventManager.DispatchEvent("GUILD_AUDIT", {guild = guild, player = player, target = {id = rid},  atype = 2});
	end

	guild:RemoveAllRequest();
	log.info(id .. "Success `C_GUILD_CLEAN_ALL_REQUEST`")
	return sendClientRespond(conn, cmd, id, {sn, Command.RET_SUCCESS, "success"});
end


local function onServiceQueryGuildByPlayer(conn, channel, request)
	local cmd = Command.S_GUILD_QUERY_BY_PLAYER_RESPOND;
	local proto = "GuildQueryByPlayerRespond";

	if channel ~= 0 then
		log.error(id .. "Fail to `S_GUILD_QUEYR_BY_PLAYER_REQUEST`, channel ~= 0")
		sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_PREMISSIONS});
		return;
	end

	local player = PlayerManager.Get(request.playerid);
	local guild = player.guild;
	local ginfo = buildGuildArray(player.guild, true);

	local respond = {
		sn = request.sn or 0,
		result = Command.RET_SUCCESS,
		id = request.playerid,
		title = guild and ((guild.leader.id == player.id) and 1 or player.titla) or 0,
		guild = { id = 0 },
		jointime = player.join_time
	}

	if guild then
		respond.guild = {
			id = guild.id,
			name = guild.name,
			leader = {
				id = guild.leader.id,
				name = guild.leader.name,
			},
			rank = guild.rank,
			member = guild.mcount,
			members_id = {},
			exp = guild.exp,
			level = guild.level,
		};

		for _, player in pairs(guild.members) do
			table.insert(respond.guild.members_id, player.id)
		end
	end

	log.info("Success `S_GUILD_QUEYR_BY_PLAYER_REQUEST`")
	sendServiceRespond(conn, cmd, channel, proto, respond);
end

local function onServiceQueryGuildByGuildId(conn, channel, request)
	local cmd = Command.S_GUILD_QUERY_BY_GUILDID_RESPOND
	local proto = "GuildQueryByGuildIdRespond"
	if channel ~= 0 then
                log.error(id .. "Fail to `S_GUILD_QUEYR_BY_GUILDID_REQUEST`, channel ~= 0")
                sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_PREMISSIONS});
                return;
        end
	local guild = GuildManager.Get(request.gid)
	local respond = {sn = request.sn,result = Command.RET_SUCCESS, members_id = {} }
	if guild then
		for _, player in pairs(guild.members) do
                        table.insert(respond.members_id, player.id)
                end	
	end

	log.info("Success `S_GUILD_QUEYR_BY_GUILDID_REQUEST`")
        sendServiceRespond(conn, cmd, channel, proto, respond)
end

local function onAddExp(conn, channel, request)
	local cmd = Command.S_GUILD_ADD_EXP_RESPOND;
	local proto = "aGameRespond";

	local sn  = request.sn or 0;
        local gid = request.gid or 0;
	local exp = request.exp or 0;
	local pid = request.pid or 0;

	log.debug("onAddExp", gid, pid, exp);

	if channel ~= 0 then
		return sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_PREMISSIONS});
	end

	local guild, player;
	if gid > 0 then
		guild = GuildManager.Get(gid);
	elseif pid > 0 then
		player = PlayerManager.Get(pid);
		guild = player and player.guild or nil;
	end

	if guild == nil then
		return sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_NOT_EXIST});
	end

	if guild:AddExp(exp, player) then
		sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_SUCCESS});
	else
		sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_ERROR});
	end
end

local function onServiceQueryGuildBuildingLevel(conn, channel, request)
	local cmd = Command.S_GUILD_QUERY_BUILDING_LEVEL_RESPOND;
	local proto = "GuildQueryBuildingLevelRespond";

	if channel ~= 0 then
		log.error(id .. "Fail to `S_GUILD_QUEYR_GUILD_BUILDING_LEVEL_REQUEST`, channel ~= 0")
		sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_PREMISSIONS});
		return;
	end

	local player = PlayerManager.Get(request.playerid);
	local building_type = request.building_type;
	local guild = player.guild;

	local level = 0 
	local gid = 0

	local respond = {
		sn = request.sn,
		result = Command.RET_ERROR,
		gid = gid,
		level = level
	}

	if not guild then
		log.info("Success `S_GUILD_QUERY_BUILDING_LEVEL_REQUEST`")
		sendServiceRespond(conn, cmd, channel, proto, respond);
	end

	local guild_building = GuildBuilding.Get(guild.id)
	local level = guild_building:GetLevel(request.playerid, building_type)

	respond.gid = guild.id
	respond.level = level
	respond.result = Command.RET_SUCCESS
	
	log.info("Success `S_GUILD_QUEYR_BUILDING_LEVEL_REQUEST`")
	sendServiceRespond(conn, cmd, channel, proto, respond);
end

function onServiceGuildQuery(conn, channel, request)
	local cmd = Command.S_GUILD_QUERY_RESPOND 
	local proto = "QueryGuildByPidRespond"
	local pid = request.pid

	log.debug("onServiceGuildQuery: query guild id, pid = ", pid)

	if channel ~= 0 then
		log.error("onServiceGuildQuery: channel ~= 0")
		return sendServiceRespond(conn, cmd, channel, proto, { sn = request.sn or 0, result = Command.RET_PREMISSIONS })
	end
	local player = PlayerManager.Get(request.pid)

	local help_count = 0
	local PrayPlayer	
	if player and player.guild then
		PrayPlayer = GuildPrayPlayer.Get(pid)
	end
	if PrayPlayer then
		help_count = PrayPlayer:getTodayHelpCount()
	end

	if not player or not player.guild then
		sendServiceRespond(conn, cmd, channel, proto, { sn = request.sn or 0, result = Command.RET_SUCCESS, gid = 0, leader = 0,  help_count = 0 })
	else
		sendServiceRespond(conn, cmd, channel, proto, { sn = request.sn or 0, result = Command.RET_SUCCESS, gid = player.guild.id, leader = player.guild.leader.id, 
			help_count = help_count, join_time = player.join_time or 0 })
	end
end

function onServiceApplyGuild(conn, channel, request)
	local cmd = Command.S_GUILD_Apply_RESPOND 
	if channel ~= 0 then
		log.error("onServiceApplyGuild: channel ~= 0")
		return
	end	
	
	log.debug(string.format("onServiceApplyGuild: %d apply guild.", request.pid))

	-- 角色不存在
	local player = PlayerManager.Get(request.pid)
	if player == nil then
		log.info(string.format("onServiceApplyGuild: player %d not exist.", request.pid))
		return
	end
	
	-- 不存在可以加入的军团
	local guild_list = GuildManager.GetJoinGuild()		
	for i = 1, 5 do
		local guild = guild_list[i]	
		-- 玩家已经有军团
		if guild and player.guild == nil and not guild.requests[player.id] then
			-- 自动加入军团，不需要确认
			if guild.auto_confirm == 1 then
				log.info("onServiceApplyGuild: success to join guild.")
				guild:Join(player)
				EventManager.DispatchEvent("GUILD_JOIN", { guild = guild, player = player })
				return
			end

			-- 加入申请加入军团的请求	
			if guild:JoinRequest(player) then
				-- 给团长发送通知
				EventManager.DispatchEvent("GUILD_REQUEST_JOIN", { guild = guild, player = player, time = loop.now() })
				log.info(string.format("onServiceApplyGuild: apply success."))
			else
				log.error(string.format("onServiceApplyGuild: join guild failed, pid is %d, guild id is %d", request.pid, guild.id))
			end	
		end		
	end	
end

function onUnload()
	--GridGame.Unload();
end

local function onAILogin(conn, channel, request)
	local pid = request.pid	
	if pid then
		PlayerManager.Login(pid, conn);
	end
end

local function onLogin(conn, playerid, request)
	PlayerManager.Login(playerid, conn);

	-- ai patch
	local player = PlayerManager.Get(playerid);
	if player and player.name and player.guild then
		--aiserver.NotifyAIAction(playerid, Command.ACTION_GUILD_APPLY)
	end	
end

local function onServiceRegister(conn, channel, request)
	if request.type == "GATEWAY" then
		for k, v in pairs(request.players) do
			-- print(k, v);
			onLogin(conn, v, {})
		end
	end
end
local function onDonate(conn, playerid, request)
	-- prepare
	local cmd = Command.C_GUILD_DONATE_RESPOND;
	local sn = request[1] or 0;
	local donate_type = request[2] or 0;
	local consume =DonateConfig[donate_type].Consume
	local guild_add_exp =DonateConfig[donate_type].GuildAddExpValue
	local guild_add_wealth = DonateConfig[donate_type].GuildAddWealth
	--local self_add_exp  =DonateConfig[donate_type].SelfAddExpValue
	local reward = DonateConfig[donate_type].Reward
	local self_add_exp = reward[1] and reward[1].value or 0
	local error_no      =DonateConfig[donate_type].ErrorNo
    local vip_limit   =DonateConfig[donate_type].VipLimit
	if not consume then
		log.error(string.format("unknown donate type `%d`", donate_type))
		return
	end

	-- check
	local player = PlayerManager.Get(playerid);
	if player == nil or player.name == nil then
		log.error(string.format("%dplayer is not in guild", playerid))
		return sendClientRespond(conn, cmd, playerid, {sn, Command.RET_CHARACTER_NOT_EXIST, "player is not in guild"});
	end
	if player.guild == nil then
		log.error(string.format("%dplayer is not in guild", playerid))
		return sendClientRespond(conn, cmd, playerid, {sn, Command.RET_GUILD_NOT_EXIST, "player is not in guild"});
	end
	local can_donate, last_t =DonateManager.CanDonate(player, donate_type)
	log.info(string.format("%dlast donate time is %d", playerid, last_t))
	if not can_donate then
		log.error(string.format("%dplayer can not donate, last time is %d", playerid, last_t))
		return sendClientRespond(conn, cmd, playerid, {sn, Command.RET_ERROR});
	end

   	if player.vip < vip_limit then
		log.error(string.format("%d player can not donate, vip level is %d , vip_level is %d", playerid, player.vip or -1, vip_limit or -1))
		return sendClientRespond(conn, cmd, playerid, {sn, Command.RET_ERROR});
   	end
	
	-- trade
	--[[local reward ={
		type = 41,--Command.REWARD_TYPE_RESOURCE,
		id = 90021,--Command.RESOURCES_GERENGONGXIAN,
		value =self_add_exp
	}--]]
	local respond = cell.sendReward(playerid, reward, consume, Command.REASON_CONSUME_TYPE_GUILD_DONATE);
	if respond == nil or respond.result ~= Command.RET_SUCCESS then
		log.error(string.format("%dfail to sendReward", playerid))
		return sendClientRespond(conn, cmd, playerid, {sn, error_no});
	end

	--quest
	if reward[1].value > 0 then
		cell.NotifyQuestEvent(playerid, {{type = 35, id = 1, count = reward[1].value}})
	end

	-- ai patch
	--aiserver.NotifyAIAction(playerid, Command.ACTION_GUILD_DONATE, {donate_type})

	--[[ broadcast
	if donate_type == GUILD_DONATE_TYPE_ADVANCE then
		local msg =string.format(YQSTR.GUILD_DONATE_MESSAGE, make_player_rich_text(playerid, player.name))
		broadcast.SystemBroadcastEasy(Command.SYS_BROADCAST_TYPE_GUILD, msg);
	end]]

	-- process and respond
	local guild_exp_old =player.guild.exp
	player.guild:Donate(player, donate_type, guild_add_exp, self_add_exp, guild_add_wealth)
	local guild_exp_current =player.guild.exp

	log.info(string.format("%dsuccess C_GUILD_DONATE_REQUEST", playerid))
	EventManager.DispatchEvent("GUILD_DONATE", {guild = player.guild, donate= { type =donate_type, pid =playerid, exp_current =guild_exp_current, exp_change =self_add_exp, dispatch_all = (donate_type == GUILD_DONATE_TYPE_HIGH)}});

	--cell.addActivityPoint(playerid, Command.ACTIVITY_GUILD_DONATE, 1);
	--cell.disPatchQuestEvent(playerid,34,1);

	return sendClientRespond(conn, cmd, playerid, {sn, Command.RET_SUCCESS, guild_exp_current, self_add_exp});
end

local function onServiceDonate(conn, channel, request)	
	log.debug(string.format("onServiceDonate: ai %d donate. ", request.pid))	

	if channel ~= 0 then
		log.error("onServiceDonate: channel ~= 0")
		return
	end
	
	local donate_type = request.donateType
	local guild_add_exp = DonateConfig[donate_type].GuildAddExpValue
	local guild_add_wealth = DonateConfig[donate_type].GuildAddWealth
	local reward = DonateConfig[donate_type].Reward
	local self_add_exp = reward[1] and reward[1].value or 0

	local player = PlayerManager.Get(request.pid);
	if player == nil then
		log.info(string.format("onServiceDonate: player %d is not exist. ", request.pid))
		return
	end
	
	if player.guild == nil then
		log.warning(string.format("onServiceDonate: guild is not exist."))
		return
	end

	local can_donate, last_t = DonateManager.CanDonate(player, donate_type)
	if not can_donate then
		log.info(string.format("onServiceDonate: player %d can not donate, last time is %d", request.pid, last_t))
		return
	end

	-- process and respond
	local guild_exp_old = player.guild.exp
	player.guild:Donate(player, donate_type, guild_add_exp, self_add_exp, guild_add_wealth)
	local guild_exp_current = player.guild.exp

	EventManager.DispatchEvent("GUILD_DONATE", {guild = player.guild, donate = { type = donate_type, pid = request.pid, exp_current = guild_exp_current, exp_change = self_add_exp, 
			dispatch_all = (donate_type == GUILD_DONATE_TYPE_HIGH) } })
end

local function onQueryDonate(conn, playerid, request)
	-- prepare
	local cmd = Command.C_GUILD_QUERY_DONATE_RESPOND;
	local sn = request[1] or 0;
	local max_count = request[2] or 0;

	-- check
	local player = PlayerManager.Get(playerid);
	if player == nil or player.name == nil then
		return sendClientRespond(conn, cmd, playerid, {sn, Command.RET_CHARACTER_NOT_EXIST, "player is not in guild"});
	end
	if player.guild == nil then
		return sendClientRespond(conn, cmd, playerid, {sn, Command.RET_GUILD_NOT_EXIST, "player is not in guild"});
	end

	-- process and respond
	local result =player.guild:QueryDonate(player, max_count)
	local has    =player.guild:HasDonatedToday(player)
	if result then
		return sendClientRespond(conn, cmd, playerid, {sn, Command.RET_SUCCESS, has, result});
	else
		return sendClientRespond(conn, cmd, playerid, {sn, Command.RET_ERROR});
	end
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

local function buyAttackCount(conn, playerid, request)
    local cmd     = Command.C_GUILD_ADD_ACTIVITY_COUNT_RESPOND
    local sn      = request[1] or 0;
    local consume = {
        Type  = request[2];
        Id    = request[3];
        Value = request[4];
    }
    local gid     = getPlayerGuildId(playerid); 
    if not consume or not consume.Type or not consume.Id or not consume.Value then
        log.info(string.format("%d %d %d", consume.Type or -1, consume.Id or -1, consume.Value or -1))
        log.error(playerid .."Fail to C_GUILD_ADD_ACTIVITY_COUNT_REQUEST")
        sendClientRespond(conn, cmd, playerid,{sn, Command.RET_PARAM_ERROR});
--    elseif type(gid) ~= 'number' then
--        log.error(playerid .."Fail to C_GUILD_ADD_ACTIVITY_COUNT_REQUEST, error gid");
--        sendClientRespond(conn, cmd, playerid,{sn, Command.RET_PARAM_ERROR});
    else
        local ok,errno  = onBuyAttackCount(playerid, gid, consume);
        if ok then
            log.info(string.format("%d success C_GUILD_ADD_ACTIVITY_COUNT_REQUEST", playerid))
        else
            log.error(playerid .."Fail to C_GUILD_ADD_ACTIVITY_COUNT_REQUEST")
        end
        sendClientRespond(conn, cmd, playerid, {sn, errno});
    end
end

local function queryGuildActivityInfo(conn, playerid, request)
    local cmd = Command.C_GUILD_QUERY_ACTIVITY_INFO_RESPOND;
    local sn      = request[1] or 0;
    local gid     = getPlayerGuildId(playerid);
    if type(gid) ~= 'number' then
        log.error(playerid .."Fail to C_GUILD_QUERY_ACTIVITY_INFO_REQUEST, error gid");
        sendClientRespond(conn, cmd, playerid,{sn, Command.RET_PARAM_ERROR});
    else
        local ret = onQueryGuildActivityInfo(playerid, gid);
        sendClientRespond(conn, cmd, playerid,{sn, Command.RET_SUCCESS, unpack(ret)});
        log.info(string.format("%d success C_GUILD_QUERY_ACTIVITY_INFO_REQUEST", playerid))
    end
end

local function queryJoinActivityInfo(conn, playerid, request)
    local cmd = Command.C_GUILD_QUERY_JOIN_ACTIVITY_INFO_RESPOND
    local sn  = request[1] or 0;
    local gid = getPlayerGuildId(playerid);
    if type(gid) ~= 'number' then
        log.error(playerid .."Fail to C_GUILD_QUERY_JOIN_ACTIVITY_INFO_REQUEST, error gid");
        sendClientRespond(conn, cmd, playerid,{sn, Command.RET_PARAM_ERROR});
    else
        local ret,errno = onQueryJoinActInfo(gid);
        --yqinfo("here we got ret"..sprinttb(ret))
        if ret then
            sendClientRespond(conn, cmd, playerid,{sn, Command.RET_SUCCESS, ret});
            log.info(string.format("%d success C_GUILD_QUERY_JOIN_ACTIVITY_INFO_REQUEST", playerid))
        else
            log.error(playerid .."Fail to  C_GUILD_QUERY_JOIN_ACTIVITY_INFO_REQUEST, error ");
            sendClientRespond(conn, cmd, playerid,{sn, Command.RET_PARAM_ERROR});
        end
    end
end


local function enterGuildActivity(conn, playerid, request)
    local cmd = Command.C_GUILD_ENTER_ACTIVITY_RESPOND;
    local sn  = request[1] or 0;
    local gid = getPlayerGuildId(playerid);
    if type(gid) ~= 'number' then
        log.error(playerid .."Fail to C_GUILD_ENTER_ACTIVITY_REQUEST, error gid");
        sendClientRespond(conn, cmd, playerid,{sn, Command.RET_PARAM_ERROR});
    else
        local ret = onEnterGuildActivity(playerid, gid);
        sendClientRespond(conn, cmd, playerid,{sn, ret and Command.RET_SUCCESS or Command.RET_ERROR});
        log.info(string.format("%d success C_GUILD_ENTER_ACTIVITY_RESQUEST", playerid))
    end
end

local function leaveGuildActivity(conn, playerid, request)
    local cmd = Command.C_GUILD_LEAVE_ACTIVITY_RESPOND;
    local sn  = request[1] or 0;
    local gid = getPlayerGuildId(playerid);
    if type(gid) ~= 'number' then
        log.error(playerid .."Fail to C_GUILD_LEAVE_ACTIVITY_REQUEST, error gid");
        sendClientRespond(conn, cmd, playerid,{sn, Command.RET_PARAM_ERROR});
    else
        local ret = onLeaveGuildActivity(playerid, gid);
        sendClientRespond(conn, cmd, playerid,{sn, ret and Command.RET_SUCCESS or Command.RET_ERROR});
        log.info(string.format("%d success C_GUILD_LEAVE_ACTIVITY_REQUEST", playerid))
    end
end



local function queryGuildActivityBossInfo(conn, playerid, request)
    local cmd = Command.C_GUILD_QUERY_ACTIVITY_BOSS_RESPOND;
    local sn  = request[1] or 0;
    local gid = getPlayerGuildId(playerid);
    if type(gid) ~= 'number' then
        log.error(playerid .."Fail to C_GUILD_QUERY_ACTIVITY_BOSS_REQUEST, error gid");
        sendClientRespond(conn, cmd, playerid,{sn, Command.RET_PARAM_ERROR});
    else
        local ret = onGetAllBossInfo(gid);
        sendClientRespond(conn, cmd, playerid,{sn, Command.RET_SUCCESS, ret});
        log.info(string.format("%d success C_GUILD_QUERY_ACTIVITY_BOSS_REQUEST", playerid))
    end
end

local function joinGuildActivity(conn, playerid, request)
    local cmd = Command.C_GUILD_JOIN_ACTIVITY_RESPOND;
    local sn  = request[1] or 0;
    local placeholder = request[2];
    local gid = getPlayerGuildId(playerid)
    if type(gid) ~= 'number' then
        log.error(playerid .."Fail to C_GUILD_JOIN_ACTIVITY_REQUEST, error gid");
        sendClientRespond(conn, cmd, playerid,{sn, Command.RET_PARAM_ERROR});
    else
        local ret,errno = onJoinAct(playerid,gid,placeholder);
        if ret then
            sendClientRespond(conn, cmd, playerid,{sn, Command.RET_SUCCESS});
            log.info(string.format("%d success C_GUILD_JOIN_ACTIVITY_REQUEST", playerid))
        else
            log.error(playerid .."Fail to C_GUILD_JOIN_ACTIVITY_REQUEST, error gid");
            sendClientRespond(conn, cmd, playerid,{sn, Command.RET_PARAM_ERROR});
        end
    end
end


local function guildActivityPkBoss(conn, playerid, request)
    local cmd = Command.C_GUILD_ACTIVITY_PK_BOSS_RESPOND
    local sn  = request[1] or 0;
    local boss_id = request[2]
    local gid = getPlayerGuildId(playerid);
    if type(gid) ~= 'number' or type(boss_id) ~= 'number' then
        log.error(playerid .."Fail to C_GUILD_ACTIVITY_PK_BOSS_REQUEST, error gid");
        sendClientRespond(conn, cmd, playerid,{sn, Command.RET_PARAM_ERROR});
    else
        local ret,errno = onPkBoss(playerid, gid, boss_id);
        if ret then
            sendClientRespond(conn, cmd, playerid,{sn, Command.RET_SUCCESS, ret});
            log.info(string.format("%d success C_GUILD_ACTIVITY_PK_BOSS_REQUEST", playerid))
        else
            log.error(playerid .."Fail to  C_GUILD_ACTIVITY_PK_BOSS_REQUEST, error ");
            sendClientRespond(conn, cmd, playerid,{sn, errno or Command.RET_PARAM_ERROR});
        end
    end
end


local function guildActivitySelectTeam(conn, playerid, request)
    local cmd = Command.C_GUILD_ACTIVITY_SELECT_TEAM_RESPOND
    local sn  = request[1] or 0;
    local c_send_pid = request[2];
    local gid = getPlayerGuildId(playerid);
    if type(gid) ~= 'number' or not c_send_pid then
        log.error(playerid .."Fail to C_GUILD_ACTIVITY_SELECT_TEAM_REQUEST, error gid or team is nil");
        sendClientRespond(conn, cmd, playerid,{sn, Command.RET_PARAM_ERROR});
    else
        local ret = onSelectTeam(playerid, c_send_pid, gid); 
        if ret then
            sendClientRespond(conn, cmd, playerid,{sn, Command.RET_SUCCESS});
            log.info(string.format("%d success C_GUILD_ACTIVITY_SELECT_TEAM_REQUEST", playerid))
        else
            log.error(playerid .."Fail to  C_GUILD_ACTIVITY_SELECT_TEAM_REQUEST, error ");
            sendClientRespond(conn, cmd, playerid,{sn, Command.RET_PARAM_ERROR});
        end
    end
end


local function guildActivityGetFightRecord(conn, playerid, request)
    local cmd = Command.C_GUILD_ACTIVITY_GET_FIGHT_RECORD_RESPOND
    local sn  = request[1] or 0;
    local boss_id= request[2];
    local gid = getPlayerGuildId(playerid);
    if type(gid) ~= 'number' or type(boss_id)~='number'  then
        log.error(playerid .."Fail to  C_GUILD_ACTIVITY_GET_FIGHT_RECORD_REQUEST, error gid");
        sendClientRespond(conn, cmd, playerid,{sn, Command.RET_PARAM_ERROR});
    else
        local ret = onGetFightRecord(gid, boss_id);
        if ret then
            sendClientRespond(conn, cmd, playerid,{sn, Command.RET_SUCCESS, ret});
            log.info(string.format("%d success C_GUILD_ACTIVITY_GET_FIGHT_RECORD_REQUEST", playerid))
        else
            log.error(playerid .."Fail to  C_GUILD_ACTIVITY_GET_FIGHT_RECORD_REQUEST, error ");
            sendClientRespond(conn, cmd, playerid,{sn, Command.RET_PARAM_ERROR});
        end
    end
end

local function enterGuildWar(conn, pid, request)
    local cmd = Command.C_GUILD_WAR_ENTER_RESPOND;
    local sn  = request[1] or 0;
    local ok = RoomManager.Enter(pid); 
    local errno = ok and Command.RET_SUCCESS or Command.RET_ERROR;
    sendClientRespond(conn, cmd, pid,{sn, errno});
    if errno == Command.RET_SUCCESS then
        log.info(string.format("%d SUCCESS TO C_GUILD_WAR_ENTER_RESQUEST", pid ))
    else
        log.info(string.format("%d FAIL TO C_GUILD_WAR_ENTER_RESQUEST", pid))
    end
end

local function leaveGuildWar(conn, pid, request)
    local cmd = Command.C_GUILD_WAR_LEAVE_RESPOND;
    local sn  = request[1] or 0;
    local ret = RoomManager.Leave(pid); 
    local errno = ret and Command.RET_SUCCESS or Command.RET_ERROR;
    sendClientRespond(conn, cmd, pid,{sn, errno});
    if errno == Command.RET_SUCCESS then
        log.info(string.format("%d SUCCESS TO C_GUILD_WAR_LEAVE_RESQUEST", pid))
    else
        log.info(string.format("%d FAIL TO C_GUILD_WAR_LEAVE_RESQUEST", pid))
    end
end

local function joinGuildWar(conn, pid, request)
    local cmd = Command.C_GUILD_WAR_JOIN_RESPOND;
    local sn  = request[1] or 0;
    local gid = getPlayerGuildId(pid);
    if type(gid) ~= 'number' then
        log.error(pid .."Fail to C_GUILD_WAR_JOIN_REQUEST, error gid");
        sendClientRespond(conn, cmd, pid,{sn, Command.RET_PARAM_ERROR});
    else 
        local ret = RoomManager.Join(pid); 
        local errno = ret and Command.RET_SUCCESS or Command.RET_ERROR
        sendClientRespond(conn, cmd, pid,{sn, errno})
        if errno == Command.RET_SUCCESS then
            log.info(string.format("%d SUCCESS TO C_GUILD_WAR_JOIN_REQUEST,ERRNO", pid))
        else
            log.info(string.format("%d FAIL TO C_GUILD_WAR_JOIN_REQUEST,ERRNO:%d", pid, errno))
        end
    end
end

local function inspireGuildWar(conn, pid, request)
    local cmd = Command.C_GUILD_WAR_INSPIRE_RESPOND;
    local sn  = request[1] or 0;
    local gid = getPlayerGuildId(pid);
    if type(gid) ~= 'number' then
        log.error(pid .."Fail to C_GUILD_WAR_INSPIRE_REQUEST, error gid");
        sendClientRespond(conn, cmd, pid,{sn, Command.RET_PARAM_ERROR});
    else 
        local ret = RoomManager.Inspire(pid); 
        local errno = ret and Command.RET_SUCCESS or Command.RET_ERROR
        sendClientRespond(conn, cmd, pid,{sn, errno})
        if errno == Command.RET_SUCCESS then
            log.info(string.format("%d SUCCESS TO C_GUILD_WAR_INSPIRE_RESQUEST", pid))
        else
            log.info(string.format("%d FAIL TO C_GUILD_WAR_INSPIRE_RESQUEST  ERRNO:%d", pid, errno))
        end
    end
end

local function enterGuildWarSubRoom(conn, pid, request)
    log.info(string.format("BEGIN %d C_GUILD_WAR_ENTER_SUB_ROOM_REQUEST", pid))
    local cmd = Command.C_GUILD_WAR_ENTER_SUB_ROOM_RESPOND
    local sn  = request[1] or 0;
    local sub_room_id = request[2] or 0;
    if type(sub_room_id) ~= 'number' then
        log.error(pid.."Fail to C_GUILD_WAR_ENTER_SUB_ROOM_REQUEST, error sub_room_id");
        sendClientRespond(conn, cmd, pid,{sn, Command.RET_PARAM_ERROR});
        return 
    end
    local ok, room_status, room_record, room_fight_record, player_inspire_count = RoomManager.EnterSubRoom(pid, sub_room_id);
    if ok then
        sendClientRespond(conn, cmd, pid,{sn, Command.RET_SUCCESS, room_status, room_record and room_record[1] or {}, room_record and room_record[2] or {}, room_record and room_record[3] or {}, room_fight_record or {}, player_inspire_count} );
        log.info(string.format("%d SUCCESS TO C_GUILD_WAR_ENTER_SUB_ROOM_REQUEST", pid))
    else
        sendClientRespond(conn, cmd, pid, {sn, Command.RET_ERROR});
        log.info(string.format("%d FAIL TO C_GUILD_WAR_ENTER_SUB_ROOM_REQUEST", pid))
    end
end

local function leaveGuildWarSubRoom(conn, pid, request)
    log.info(string.format("BEGIN %d C_GUILD_WAR_LEAVE_SUB_ROOM_REQUEST", pid))
    local cmd = Command.C_GUILD_WAR_LEAVE_SUB_ROOM_RESPOND
    local sn  = request[1] or 0;
    local ok = RoomManager.LeaveSubRoom(pid);
    if ok then
        sendClientRespond(conn, cmd, pid, {sn, Command.RET_SUCCESS});
        log.info(pid .. "Success to C_GUILD_WAR_LEAVE_SUB_ROOM_REQUEST, Success");
    else
        sendClientRespond(conn, cmd, pid, {sn, Command.RET_ERROR});
        log.error(pid .. "Fail to C_GUILD_WAR_LEAVE_SUB_ROOM_REQUEST, result error");
    end
end

local function queryGuildWarReport(conn, pid, request)
    log.info(string.format("BEGIN %d C_GUILD_WAR_QUERY_REPORT_REQUEST", pid))
    local cmd = Command.C_GUILD_WAR_QUERY_REPORT_RESPOND
    local sn  = request[1] or 0;
    local ok, ret = RoomManager.GetCurrentReport(pid);
    if ok then
        sendClientRespond(conn, cmd, pid, {sn, Command.RET_SUCCESS, ret});
        log.info(string.format("%d SUCCESS TO C_GUILD_WAR_QUERY_REPORT_RESPOND", pid))
    else
        sendClientRespond(conn, cmd, pid, {sn, Command.RET_ERROR});
        log.info(string.format("%d FAIL TO C_GUILD_WAR_QUERY_REPORT_RESPOND", pid))
    end
end

local function queryGuildWarHistoryReport(conn, pid, request)
    log.info(string.format("BEGIN %d C_GUILD_WAR_QUERY_HISTORY_REPORT_REQUEST", pid))
    local cmd = Command.C_GUILD_WAR_QUERY_HISTORY_REPORT_RESPOND
    local sn  = request[1] or 0;
    local ok,ret = RoomManager.GetHistoryReport();
    if ok then
        sendClientRespond(conn, cmd, pid, {sn, Command.RET_SUCCESS, ret});
        log.info(string.format("%d SUCCESS TO C_GUILD_WAR_QUERY_HISTORY_REPORT_RESPOND", pid))
    else
        sendClientRespond(conn, cmd, pid, {sn, Command.RET_ERROR});
        log.info(string.format("%d FAIL TO C_GUILD_WAR_QUERY_HISTORY_REPORT_RESPOND", pid))
    end
end

local function queryGuildWarHistoryFightRecord(conn, pid, request)
    log.info(string.format("BEGIN %d C_GUILD_WAR_QUERY_HISTORY_FIGHT_RECORD_REQUEST", pid))
    local cmd = Command.C_GUILD_WAR_QUERY_HISTORY_FIGHT_RECORD_RESPOND
    local sn  = request[1] or 0;
    local sub_room_id = request[2] or 0;
    if type(sub_room_id) ~= 'number' then
        log.error(pid.."Fail to C_GUILD_WAR_QUERY_HISTORY_FIGHT_RECORD_REQUEST, error sub_room_id");
        sendClientRespond(conn, cmd, pid, {sn, Command.RET_PARAM_ERROR});
        return 
    end
    local ok, ret = RoomManager.GetHistoryFightRecord(sub_room_id);
    if ok then
        --yqinfo(sprinttb(ret))
        sendClientRespond(conn, cmd, pid, {sn, Command.RET_SUCCESS, ret});
        log.info(string.format("%d SUCCESS TO C_GUILD_WAR_QUERY_HISTORY_FIGHT_RECORD_REQUEST", pid))
    else
        sendClientRespond(conn, cmd, pid, {sn, Command.RET_ERROR});
        log.info(string.format("%d FAIL TO C_GUILD_WAR_QUERY_HISTORY_FIGHT_RECORD_REQUEST", pid))
    end
end


local function setGuildWarOrder(conn, pid, request)
    log.info(string.format("BEGIN %d C_GUILD_WAR_SET_ORDER_REQUEST", pid))
    local cmd = Command.C_GUILD_WAR_SET_ORDER_RESPOND
    local sn  = request[1] or 0;
    local requst_order_table = request[2] or {};
    local ret, server_order_table = RoomManager.SetOrder(pid, requst_order_table)
    if ret then
        sendClientRespond(conn, cmd, pid, {sn, Command.RET_SUCCESS, server_order_table});
        local log_str1 = "";
        local log_str2 = "";
        for k, v in pairs(requst_order_table) do
            log_str1 = log_str1 .." <" .. v .. "> ";
        end
        for k, v in pairs(server_order_table) do
            log_str2 = log_str2 .." <" .. v .. "> ";
        end
        log.info(string.format("C_GUILD_WAR_SET_ORDER_REQUEST SUCCESS, %d send table -> %s, system set order -> %s", pid, log_str1, log_str2));
    else
        sendClientRespond(conn, cmd, pid, {sn, server_order_table or Command.RET_ERROR});
        log.info(string.format("%d FAIL TO C_GUILD_WAR_SET_ORDER_RESQUEST", pid))
    end
end

local function queryGuildWarOrder(conn, pid, request)
    log.info(string.format("BEGIN %d C_GUILD_WAR_QUERY_ORDER_REQUEST", pid))
    local cmd = Command.C_GUILD_WAR_QUERY_ORDER_RESPOND
    local sn  = request[1] or 0;
    local ok, ret = RoomManager.QueryOrder(pid)
    if ok then
        sendClientRespond(conn, cmd, pid, {sn, Command.RET_SUCCESS, ret});
        local log_str = "";
        for k, v in pairs(ret) do
            log_str = log_str .." <" .. v .. "> ";
        end
        log.info(string.format("C_GUILD_WAR_QUERY_ORDER_REQUEST SUCCESS `%d` %s", pid, log_str));
    else
        sendClientRespond(conn, cmd, pid, {sn, ret or Command.RET_ERROR});
        log.info(string.format("%d FAIL TO C_GUILD_WAR_QUERY_ORDER_REQUEST", pid))
    end
end

local function onGuildDrawReward(conn, id, request)
	local sn = request[1] or 0;
	local index = request[2]

	log.debug(string.format("onGuildDrawReward, reward index:%d", index));

	local cmd = Command.C_GUILD_DRAW_DONATE_REWARD_RESPOND;

	local player = PlayerManager.Get(id);

	-- 没有军团
	if player.guild == nil then
		log.error(id .. "Fail to `C_GUILD_DRAW_DONATE_REWARD_REQUEST`, player is not in guild")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_GUILD_NOT_EXIST, "player is not in guild"});
	end

	local guild = player.guild;

	if player.guild:DrawDonateReward(player, index) then
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_SUCCESS});
	else
		log.error(id .. "Fail to `C_GUILD_DRAW_DONATE_REWARD_REQUEST`, failed")
		return sendClientRespond(conn, cmd, id, {sn, Command.RET_ERROR});
	end

end

local function onAILogout(conn, channel, request)
	local pid = request.pid	
	if pid then
		PlayerManager.Logout(pid);
	end
end

local function onLogout(conn, playerid, request)
	PlayerManager.Logout(playerid);
    --leaveGuildWar(conn, playerid, request);
    --leaveGuildWarSubRoom(conn, playerid, request);
	-- DonateManager.Logout(playerid)
end

-- listen
for _, cfg in ipairs(GuildConfig.listen) do
	service = NetService.New(cfg.port, cfg.host, cfg.name or "guild");
	assert(service, "listen on " .. cfg.host .. ":" .. cfg.port .. " failed");

	service:on("accept", function (client)
		client.sendClientRespond = sendClientRespond;
		log.debug(string.format("Service: client %d connected", client.fd));
	end);

	service:on("close", function(client)
		log.debug(string.format("Service: client %d closed", client.fd));
	end);

	service:on(Command.C_GUILD_QUERY_REQUEST,		onGuildQuery);  --请求具体军团信息  3000(客户端未用到)
	service:on(Command.C_GUILD_SEARCH_NAME_REQUEST,		onGuildSearchName); --3144
	service:on(Command.C_GUILD_SEARCH_ID_REQUEST,		onGuildSearchID); --3126
	service:on(Command.C_GUILD_CREATE_REQUEST,		onGuildCreate); --创建军团 3002
	service:on(Command.C_GUILD_JOIN_REQUEST,		onGuildJoin); --申请加入军团 3004
	service:on(Command.C_GUILD_LEAVE_REQUEST,		onGuildLeave); --离开军团 3006
	service:on(Command.C_GUILD_QUERY_GUILD_LIST_REQUEST,	onGuildQueryGuildList); --请求军团列表 3008
	service:on(Command.C_GUILD_QUERY_MEMBERS_REQUEST,	onGuildQueryMembers); --查询军团成员列 3010
	service:on(Command.C_GUILD_QUERY_APPLY_REQUEST,		onGuildQueryApply); --查询军团申请列表 3016
	service:on(Command.C_GUILD_AUDIT_REQUEST,		onGuildAudit);   --军团审核（批准玩家是否可以加入军团）3018
	service:on(Command.C_GUILD_SETTING_REQUEST,		onGuildSetting); --设置军团宣言 军团通知 3020
	service:on(Command.C_GUILD_QUEYR_BY_PLAYER_REQUEST,	onGuildQueryByPlayer); --查询玩家所属军团 3028
	service:on(Command.C_GUILD_SET_TITLE_REQUEST,		onGuildSetTitle); --设置头衔 3030
	service:on(Command.C_GUILD_INVITE_REQUEST,		onGuildInvite);  --邀请加入军团
	service:on(Command.C_GUILD_ACCEPT_INVITE_REQUEST,		onGuildAccpetInvite); --同意加入军
	service:on(Command.C_GUILD_SET_LEADER_REQUEST,		onGuildSetLeader);  --设置军团长(转让) 3036
	service:on(Command.C_GUILD_QUERY_BY_TITLE_REQUEST,	onGuildQueryByTitle); --通过职位查询角色请求
	service:on(Command.C_GUILD_KICK_REQUEST,		onGuildKick);  --踢出军团 3040
	service:on(Command.C_GUILD_BUY_MEMBER_COUNT_REQUEST,		onGuildBuyMemberCount); --购买军团人数上限 3142
	service:on(Command.C_GUILD_CLEAN_ALL_REQUEST,		onGuildCleanAllRequest); --清除所有申请列表 3042
	service:on(Command.C_GUILD_DISSOLVE_REQUEST,		onGuildDissolve); --解散军团 3026
	service:on(Command.C_QUERY_GUILD_EXP_LOG_REQUEST,	onGuildQueryExpLog); --查询军团贡献log 3046

	service:on(Command.C_GUILD_BOSS_SETTING_REQUEST,	onGuildBossSetting)

	service:on(Command.S_GUILD_QUERY_BY_PLAYER_REQUEST,	"GuildQueryByPlayerRequest", onServiceQueryGuildByPlayer);
	service:on(Command.S_GUILD_QUERY_BY_GUILDID_REQUEST,     "GuildQueryByGuildIdRequest", onServiceQueryGuildByGuildId);
	service:on(Command.S_GUILD_ADD_EXP_REQUEST,		"PGuildAddExpRequest",       onAddExp);

	service:on(Command.S_GUILD_QUERY_REQUEST, "QueryGuildByPidRequest", onServiceGuildQuery)
	
	service:on(Command.S_GUILD_APPLY_NOTIFY, "ApplyGuildNotify", onServiceApplyGuild)


	service:on(Command.C_LOGIN_REQUEST, 		onLogin);
	service:on(Command.C_LOGOUT_REQUEST, 		onLogout);
	service:on(Command.S_SERVICE_REGISTER_REQUEST,	onServiceRegister);

	service:on(Command.C_GUILD_DONATE_REQUEST,	onDonate); --军团捐献请求  3094

	service:on(Command.S_GUILD_DONATE_NOTIFY, "DonateExpNotify", onServiceDonate)

	service:on(Command.C_GUILD_QUERY_DONATE_REQUEST,	onQueryDonate); --军团捐献列表 3096

	service:on(Command.C_GUILD_DRAW_DONATE_REWARD_REQUEST,		onGuildDrawReward); --领取每日军团贡献奖励 

	service:on(Command.C_GUILD_AUTO_CONFIRM_REQUEST,		onGuildAutoConfirm); --设置军团自动审核  3128
	service:on(Command.C_GUILD_AUTO_JOIN_REQUEST,		onGuildAutoJoin); --一键申请（自动加入开启自动审核的军团）  3130
	service:on(Command.C_GUILD_QUERY_PLAYER_AUTO_JOIN_REQUEST, onGuildQueryPlayerAutoJoin) -- 3138
	--[[service:on(Command.C_GUILD_ADD_ACTIVITY_COUNT_REQUEST,	buyAttackCount);
	service:on(Command.C_GUILD_QUERY_ACTIVITY_INFO_REQUEST,queryGuildActivityInfo);
	service:on(Command.C_GUILD_JOIN_ACTIVITY_REQUEST, joinGuildActivity);
	service:on(Command.C_GUILD_ACTIVITY_PK_BOSS_REQUEST, guildActivityPkBoss);
	service:on(Command.C_GUILD_ACTIVITY_SELECT_TEAM_REQUEST,guildActivitySelectTeam );
	service:on(Command.C_GUILD_ACTIVITY_GET_FIGHT_RECORD_REQUEST,guildActivityGetFightRecord);
    service:on(Command.C_GUILD_QUERY_JOIN_ACTIVITY_INFO_REQUEST, queryJoinActivityInfo);
    service:on(Command.C_GUILD_QUERY_ACTIVITY_BOSS_REQUEST, queryGuildActivityBossInfo);
    service:on(Command.C_GUILD_ENTER_ACTIVITY_REQUEST, enterGuildActivity);
    service:on(Command.C_GUILD_LEAVE_ACTIVITY_REQUEST, leaveGuildActivity);--]]

    service:on(Command.C_GUILD_WAR_ENTER_REQUEST, enterGuildWar);
    service:on(Command.C_GUILD_WAR_LEAVE_REQUEST, leaveGuildWar);
    service:on(Command.C_GUILD_WAR_JOIN_REQUEST, joinGuildWar);
    service:on(Command.C_GUILD_WAR_INSPIRE_REQUEST, inspireGuildWar);
    service:on(Command.C_GUILD_WAR_ENTER_SUB_ROOM_REQUEST, enterGuildWarSubRoom);
    service:on(Command.C_GUILD_WAR_LEAVE_SUB_ROOM_REQUEST, leaveGuildWarSubRoom);
    service:on(Command.C_GUILD_WAR_QUERY_REPORT_REQUEST, queryGuildWarReport);
    service:on(Command.C_GUILD_WAR_QUERY_HISTORY_REPORT_REQUEST, queryGuildWarHistoryReport);
    service:on(Command.C_GUILD_WAR_QUERY_HISTORY_FIGHT_RECORD_REQUEST, queryGuildWarHistoryFightRecord);
    service:on(Command.C_GUILD_WAR_SET_ORDER_REQUEST, setGuildWarOrder);
    service:on(Command.C_GUILD_WAR_QUERY_ORDER_REQUEST, queryGuildWarOrder);

	--[[for k, v in pairs(GridGame.interface) do
		service:on(k, v);
	end]]

    --service:on(Command.S_GM_HOT_UPDATE_BONUS_REQUEST,   "GmHotUpdateBonusRequest", Bonus.OnGmHotUpdateBonus);

	local route = Xing5.GetMessageRoute();
	if route then 
		for cmd, func in pairs(route) do
			assert(cmd, func);
			service:on(cmd, func);
		end
	end

	service:on(Command.C_GUILD_PRAY_QUERY_PLAYER_INFO_REQUEST, process_guild_query_pray_player_info)	
	service:on(Command.C_GUILD_PRAY_RESET_REQUEST, process_guild_pray_reset)
	service:on(Command.C_GUILD_PRAY_UPDATE_PROGRESS_REQUEST, process_guild_update_pray_progress)
	service:on(Command.C_GUILD_PRAY_DRAW_REWARD_REQUEST, process_guild_draw_pray_reward)
	service:on(Command.C_GUILD_PRAY_SEEK_HELP_REQUEST, process_guild_seek_pray_help)
	service:on(Command.C_GUILD_PRAY_QUERY_LIST_REQUEST, process_guild_query_pray_list)
	service:on(Command.C_GUILD_PRAY_HELP_OTHERS_REQUEST, process_guild_pray_help_others)

	service:on(Command.S_SEEK_PRAY_HELP_NOTIFY, "SeekPrayHelpNotify", onServiceSeekPrayHelp)
	service:on(Command.S_HELP_PRAY_NOTIFY, "HelpPrayNotify", onServiceHelpOtherPray)
	
	service:on(Command.C_GUILD_EXPLORE_QUERY_MAP_INFO_REQUEST, process_guild_explore_query_map_info)
	service:on(Command.C_GUILD_EXPLORE_QUERY_PLAYER_TEAM_INFO_REQUEST, process_guild_explore_query_player_team_info)
	service:on(Command.C_GUILD_EXPLORE_ATTEND_REQUEST, process_guild_explore_attend)
	service:on(Command.C_GUILD_EXPLORE_STOP_REQUEST, process_guild_explore_stop)
	service:on(Command.C_GUILD_EXPLORE_RESET_REQUEST, process_guild_explore_reset)
	service:on(Command.C_GUILD_EXPLORE_DRAW_REWARD_REQUEST, process_guild_explore_draw_reward)
	service:on(Command.C_GUILD_EXPLORE_QUERY_EVENT_REQUEST, process_guild_query_explore_event)
	service:on(Command.C_GUILD_EXPLORE_FINISH_EVENT_REQUEST, process_guild_finish_explore_event)
	service:on(Command.C_GUILD_EXPLORE_QUERY_EVENT_LOG_REQUEST, process_guild_query_explore_event_log)
	service:on(Command.C_GUILD_EXPLORE_FIGHT_PREPARE_REQUEST, process_guild_explore_fight_prepare)
	service:on(Command.C_GUILD_EXPLORE_FIGHT_CHECK_REQUEST, process_guild_explore_fight_check)

	-- building
	service:on(Command.C_GUILD_QUERY_BUILDING_INFO_REQUEST, process_guild_query_building_info) --3132
	service:on(Command.C_GUILD_LEVEL_UP_BUILDING_REQUEST, process_guild_level_up_building)  --3134
	service:on(Command.S_GUILD_QUERY_BUILDING_LEVEL_REQUEST,	"GuildQueryBuildingLevelRequest", onServiceQueryGuildBuildingLevel);  --3136

	service:on(Command.C_GUILD_QUERY_PRAY_LOG_REQUEST, process_query_pray_log)

	service:on(Command.S_GUILD_EXPLORE_NOTIFY, "GuildExploreNotify", server_finish_explore_event)
	service:on(Command.S_NOTIFY_AI_LEADER_WORK, "DoLeaderWorkNotify", server_leader_work)

	service:on(Command.S_NOTIFY_AI_LOGIN_GUILD, "AILoginNotify", onAILogin)
	service:on(Command.S_NOTIFY_AI_LOGOUT_GUILD, "AILogoutNotify", onAILogout)
	--[[local routeRlt = Roulette.GetMessageRoute();
	if routeRlt then 
		for cmd, func in pairs(routeRlt) do
			assert(cmd, func);
			service:on(cmd, func);
		end
	end]]

	Boss.RegisterCommand(service)
	GuildQuest.RegisterCommand(service)
	SharedQuest.RegisterCommand(service)
	GuildItem.RegisterCommand(service)
end
