local log = log;
local table = table;
local pairs=pairs;
local string=string;
local cell = require "cell"
local Command = require "Command"
local EventManager = require "EventManager"
local print = print;
local NetService = require "NetService"
local SocialManager = require "SocialManager"
local loop = loop;
local string = string
require "printtb"
local sprinttb = sprinttb
require "GuildPrayLogic"
local deleteGuildPrayList = deleteGuildPrayList
local GuildExploreEvent = require "GuildExploreEvent"
require "GuildExplore"
local CleanPlayerExploreMapInfo = CleanPlayerExploreMapInfo

SocialManager.Connect("Chat");

module "GuildEvent"

local function sendNotifyToMembers(guild, cmd, msg, title, other)
	title = title or 0;
	local pids = {};
	for _, m in pairs(guild.members) do
		if title == 0 or (m.title > 0 and m.title <= title) then
			table.insert(pids, m.id);
		end
	end

	NetService.NotifyClients(cmd, msg, pids);
end

-- #define NOTIFY_GUILD_REQUEST            19      // 请求加入军团 [gid, [pid, name]]
local function onJoinRequest(guild, player)
	local cmd = Command.NOTIFY_GUILD_REQUEST;

	local msg = {
		guild.id,
		player.id,
		player.name,
		player.level,
		loop.now(),
		player.arena_order or 0,
		player.online	
	};
	sendNotifyToMembers(guild, cmd, msg, 10);
end

local function onGuildCreate(guild, founder)
	SocialManager.changeChatChannel(founder.id, {guild.id + 1000}, {});
end

local function onGuildActivityBoss(info)
    local msg = {
       info.fight_id,
       info.fight_record_id,
       info.hp,
 --      info.timestamp,
       info.winner,
       info.captain_pid,
    };
	local pids = {};
	for k, v in pairs(info.visitor) do
        table.insert(pids, k);
	end
	NetService.NotifyClients(Command.NOTIFY_GUILD_ACTIVITY_BOSS, msg, pids);
end

local function onGuildActivityBuy(info)
    local msg = {
       info.buy_pid,
    };
	local pids = {};
	for k, v in pairs(info.visitor) do
        table.insert(pids, k);
	end
	NetService.NotifyClients(Command.NOTIFY_GUILD_ACTIVITY_BUY, msg, pids);
end

local function onGuildWarOrder(info)
    local msg = info.member_order
    
    local pids = {};
    for k, v in pairs(info.visitor) do
        table.insert(pids, k);
    end
    NetService.NotifyClients(Command.NOTIFY_GUILD_WAR_ORDER, msg, pids);
end

local function onGuildWarReport(info)
    local msg = {
        info.fight_round,
        info.guild1,
        info.guild2,
        info.winner,
    }
    local pids = {};
    for k, v in pairs(info.visitor) do
        table.insert(pids, k);
    end
    --log.info(string.format("[GuildEvent]onGuildWarReport: \
    --        fight_round[%u], %u : %u, %u win", info.fight_round, info.guild1 or -1, info.guild2 or -1, info.winner or -1));
    NetService.NotifyClients(Command.NOTIFY_GUILD_WAR_REPORT, msg, pids);
end

local function onGuildWarStatus(info)
    local msg = {
        info.room_status,
        info.room_fight_status,
        info.room_stage_cd,
    }
    --[[
    local pids = {};
    for k, v in pairs(info.visitor) do
        table.insert(pids, k);
    end]]
    log.info(string.format("[GuildEvent] onGuildWarStatus %d %d %d", info.room_status, info.room_fight_status, info.room_stage_cd));
    NetService.NotifyClients(Command.NOTIFY_GUILD_WAR_STATUS, msg, nil);
end


local function onGuildWarInspire(info)
    local msg = {
        info.gid,
        info.inspire_sum,
    }
    local pids = {};
    for k, v in pairs(info.visitor) do
        table.insert(pids, k);
    end
    --log.info(string.format("[GuildEvent] onGuildWarInspire %d %d", info.gid, info.inspire_sum));
    NetService.NotifyClients(Command.NOTIFY_GUILD_WAR_INSPIRE, msg, pids);
end

local function onGuildWarFightRecord(info)
    local msg = {
        info.sub_room_id,
        info.msg
    }
    local pids = {};
    if not info.visitor_list then
        --log.info("[onGuildWarFightRecord] empty visitor_list")
        return
    end
    for k, v in pairs(info.visitor_list) do
        table.insert(pids, k);
    end
    NetService.NotifyClients(Command.NOTIFY_GUILD_WAR_FIGHT_RECORD, msg, pids);
end

local function onGuildWarMemberJoin(info)
    local msg = info.gid;
    NetService.NotifyClients(Command.NOTIFY_GUILD_WAR_MEMBER_JOIN, msg, nil);
end

local function onGuildBuyMemberCount(info)
    local msg = {
        info.pid,
        info.gid,
        info.member_buy_count,
    }
    NetService.NotifyClients(Command.NOTIFY_GUILD_BUY_MEMBER_COUNT, msg, nil);
end

local function onGuildInvite(info)
    local msg = {
        info.host,
        info.gid,
        info.invite_id,
    }
    if info.guest and info.guest ~= 0 then
        NetService.NotifyClients(Command.NOTIFY_GUILD_INVITE, msg, {info.guest});
    end
end


local function onGuildActivityJoin(info)
    local v = info.person_info;
    local msg = {
         v.pid,
         v.attack,
         v.defend,
         v.hp,
         v.crit_ratio,
         v.crit_immune_ratio,
         v.crit_hurt,
         v.disparry_ratio,
         v.parry_ratio,
         v.init_power,
         v.incr_power,
         v.attack_speed,
         v.true_blood_ratio,
         v.weapon_skin_id,
         v.weapon_body_type,
         v.hero_skin_id,
         v.hero_body_type,
         v.mount_skin_id,
         v.mount_body_type,
         v.scale,
         info.gid,
         v.pos,
         v.quality,
         v.timestamp,
         v.name,
         v.hero_id,
         v.weapon_id,
    };
	local pids = {};
	for k, v in pairs(info.visitor) do
        table.insert(pids, k);
        --log.info("person_info : id = "..k)
	end
	NetService.NotifyClients(Command.NOTIFY_GUILD_ACTIVITY_JOIN, msg, pids);
end



local function onGuildDonate(guild, donate)
	local msg ={
		guild.id,
		donate.type,
		donate.pid,
		donate.exp_current,
		donate.exp_change
	}
    if not donate.dispatch_all then
        sendNotifyToMembers(guild, Command.NOTIFY_GUILD_DONATE, msg);
    else
        NetService.NotifyClients(Command.NOTIFY_GUILD_DONATE, msg, nil);
    end
end
-- #define NOTIFY_GUILD_JOIN               20      // 加入军团     [gid, [pid, pname]]
local function onJoin(guild, player)
	local cmd = Command.NOTIFY_GUILD_JOIN;

	local msg = {
		guild.id,
		player.id,
		player.name,
		player.level,
		player.arena_order or 0,
		player.online,
		player.today_donate_count,
	};

	sendNotifyToMembers(guild, cmd, msg);
	SocialManager.changeChatChannel(player.id, {guild.id + 1000}, {});
end

-- #define NOTIFY_GUILD_LEAVE              21      // 离开军团     [gid, [pid, pname], [oid, oname]]
local function onLeave(guild, player, opt)
	opt = opt or player;

	local cmd = Command.NOTIFY_GUILD_LEAVE;

	local msg = {
		guild.id,
		player.id, 
		player.name,
		opt.id,
		opt.name,
	}

	cell.sendNotification(player.id, cmd, msg);
	sendNotifyToMembers(guild, cmd, msg);
	SocialManager.changeChatChannel(player.id, {}, {guild.id + 1000});

	--delete event
	local player_event = GuildExploreEvent.Get(player.id)
	if player_event then
   		player_event:DeleteEvent()	
	end
end

-- #define NOTICE_GUILD_NOTICE             22      // 军团公告     [gid, notice]
local function onNoticeChange(guild)
	local cmd = Command.NOTIFY_GUILD_NOTIFY;

	local msg = {
		guild.id,
		guild.notice or "",
		guild.desc or "",
	};
	sendNotifyToMembers(guild, cmd, msg);
end

local function onBossSettingChange(guild)
	local cmd = Command.NOTIFY_GUILD_BOSS_SETTING;

	local msg = {
		guild.id,
		guild.boss,
	};
	sendNotifyToMembers(guild, cmd, msg);
end

-- #define NOTIFY_GUILD_LEADER             23      // 团长变更     [gid, [leaderid, leadername], [oid, oname]]
local function onLeaderChange(guild, opt)
	local cmd = Command.NOTIFY_GUILD_LEADER;

	local msg = {
		guild.id,
		guild.leader.id,
		guild.leader.name,
		opt.id,
		opt.name
	}

	sendNotifyToMembers(guild, cmd, msg);
end
local function onLeaderChangeBySystem(guild)
	local cmd = Command.NOTIFY_GUILD_LEADER;

	local msg = {
		guild.id,
		guild.leader.id,
		guild.leader.name,
		0,
		""
	}

	sendNotifyToMembers(guild, cmd, msg);
	log.debug(string.format("onLeaderChangeBySystem guild %d, leader %s %d", guild.id, guild.leader.name, guild.leader.id));
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


-- #define NOTIFY_GUILD_TITLE              24      // 职位变更     [gid, [pid, pname], [oid, oname], changetype, title]
local function onTitleChange(guild, player, opt, ot)
	local ct = 0
	if morePower(player.title, ot) then
		ct = 1;
	else
		ct = 2;
	end

	local cmd = Command.NOTIFY_GUILD_TITLE;

	local msg = {
		guild.id,
		player.id,
		player.name,
		opt.id,
		opt.name,
		ct;
		player.title,
	}

	sendNotifyToMembers(guild, cmd, msg);
	print("onTitleChange", player.id, opt.id, ot);
end
local function onTitleChangeBySystem(guild, player)
	local msg = {
		guild.id,
		player.id,
		player.name,
		0,
		"",
		2,
		player.title,
	}
	local cmd = Command.NOTIFY_GUILD_TITLE;
	sendNotifyToMembers(guild, cmd, msg);
	log.debug(string.format("onTitleChangeBySystem guild %d, player %s %d, title is %d", guild.id, player.name, player.id, player.title));
end


-- #define NOTIFY_GUILD_AUDIT	        25	// 同意加入变更 [[gid, gname], [oid, oname], type];
local function onAudit(guild, player, opt, atype)
	local cmd = Command.NOTIFY_GUILD_AUDIT;

	local msg = {
		guild.id,
		"", -- guild.name,
		opt.id,
		"", -- opt.name,
		atype,
		player.id,
	}
	cell.sendNotification(player.id, cmd, msg);
	sendNotifyToMembers(guild, cmd, msg, 10);
end

--[[
-- #define NOTICE_GUILD_DESC               26      // 军团公告     [gid, notice]
function onDescChange(guild)
	local cmd = Command.NOTIFY_GUILD_DESC;

	local msg = {
		guild.id,
		guild.desc,
	};

	sendNotifyToMembers(guild, cmd, msg);
end
--]]

-- notify 27  //军团祈愿进度变化
local function onGuildPrayProgressChange(info)
	local cmd = Command.NOTIFY_GUILD_PRAY_PROGRESS_CHANGE;
	cell.sendNotification(info.pid, cmd, {info.id, info.index});
end

-- notify 28 军团祈愿求助列表发生变化
local function onGuildPrayListChange(info)
	local cmd = Command.NOTIFY_GUILD_PRAY_LIST_CHANGE;
	local msg = {
		info.list,
	}
	sendNotifyToMembers(info.guild, cmd, msg)
end

local function onGuildExploreMapChange(info)
	local cmd = Command.NOTIFY_GUILD_EXPLORE_MAP_CHANGE;
	sendNotifyToMembers(info.guild, cmd, info.messsage)
end

local function onGuildExploreEventLogChange(info)
	local cmd = Command.NOTIFY_GUILD_EXPLORE_EVENT_LOG_CHANGE;
	sendNotifyToMembers(info.guild, cmd, info.message)
end

local function onGuildPrayLogChange(info)
	local cmd = Command.NOTIFY_GUILD_PRAY_LOG_CHANGE;
	sendNotifyToMembers(info.guild, cmd, info.message)
end

local function onGuildBossOpen(info)
        local cmd = Command.NOTIFY_GUILD_BOSS_OPEND  --49
        sendNotifyToMembers(info.guild, cmd, info.message)
end

local function onGuildQuestChange(guild, quest, pid)
    local cmd = Command.NOTIFY_GUILD_QUEST_CHANGE
	local attenders = {}
	for id, v in pairs(quest.attender_list) do
		table.insert(attenders, {id, v.attender_reward_flag, v.contribution})	
	end
    local msg = {
  	    pid,
	    quest.id,
	    quest.status,
	    quest.count,
	    quest.record1,
	    quest.record2,
	    quest.record3,
	    quest.consume_item_save1,
	    quest.consume_item_save2,
	    quest.accept_time,
	    quest.submit_time,
	    quest.next_time_to_accept,
		attenders,
    }

    sendNotifyToMembers(guild, cmd, msg);
end


local listener = EventManager.CreateListener("guild_event_listener");

--EventManager.RegisterEvent("GUILD_CRETE", function(event, info) end);
listener:RegisterEvent("GUILD_REQUEST_JOIN", function (event, info)
		return onJoinRequest(info.guild, info.player);
	end);

listener:RegisterEvent("GUILD_LEAVE", function(event, info)
		deleteGuildPrayList(info.guild.id, info.player.id)
		CleanPlayerExploreMapInfo(info.guild.id, info.player.id)
		return onLeave(info.guild, info.player, info.opt)
	end);

listener:RegisterEvent("GUILD_AUDIT", function(event, info)
		return onAudit(info.guild, info.target, info.player, info.atype)
	end);

listener:RegisterEvent("GUILD_JOIN", function(event, info)
		onJoin(info.guild, info.player)
	end);

listener:RegisterEvent("GUILD_SETTING", function(event, info)
		return onNoticeChange(info.guild)
	end);

listener:RegisterEvent("GUILD_BOSS_SETTING", function(event, info)
		return onBossSettingChange(info.guild)
	end);

listener:RegisterEvent("GUILD_SET_TITLE", function(event, info)
		if info.by_system then
			return onTitleChangeBySystem(info.guild, info.player);
		else
			return onTitleChange(info.guild, info.player, info.opt, info.ot);
		end
	end);

listener:RegisterEvent("GUILD_SET_LEADER", function(event, info)
		if info.by_system then
			return onLeaderChangeBySystem(info.guild)
		else
			return onLeaderChange(info.guild, info.opt)
		end
	end);

listener:RegisterEvent("GUILD_CRETE", function(event, info)
		return onGuildCreate(info.guild, info.founder);
	end);
listener:RegisterEvent("GUILD_DONATE", function(event, info)
		return onGuildDonate(info.guild, info.donate);
	end);
listener:RegisterEvent("GUILD_ACTIVITY_BOSS", function(event, info)
		return onGuildActivityBoss(info);
	end);
listener:RegisterEvent("GUILD_ACTIVITY_BUY", function(event, info)
		return onGuildActivityBuy(info);
	end);
listener:RegisterEvent("GUILD_ACTIVITY_JOIN", function(event, info)
		return onGuildActivityJoin(info);
	end);
listener:RegisterEvent("GUILD_WAR_ORDER", function(event, info)
		return onGuildWarOrder(info);
	end);

listener:RegisterEvent("GUILD_WAR_REPORT", function(event, info)
		return onGuildWarReport(info);
	end);

listener:RegisterEvent("GUILD_WAR_STATUS", function(event, info)
        return onGuildWarStatus(info)
end);

listener:RegisterEvent("GUILD_WAR_INSPIRE", function(event, info)
        return onGuildWarInspire(info)
end);

listener:RegisterEvent("GUILD_WAR_FIGHT_RECORD", function(event, info)
		return onGuildWarFightRecord(info);
	end);
listener:RegisterEvent("GUILD_WAR_MEMBER_JOIN", function(event, info)
		return onGuildWarMemberJoin(info);
end);
listener:RegisterEvent("GUILD_BUY_MEMBER_COUNT", function(event, info)
		return onGuildBuyMemberCount(info);
end);

listener:RegisterEvent("GUILD_INVITE", function(event, info)
		return onGuildInvite(info);
end);

listener:RegisterEvent("GUILD_PRAY_PROGRESS_CHANGE", function(event, info)
		return onGuildPrayProgressChange(info);
end);

listener:RegisterEvent("GUILD_PRAY_LIST_CHANGE", function(event, info)
		return onGuildPrayListChange(info)
end); 

listener:RegisterEvent("GUILD_EXPLORE_MAP_CHANGE", function(event, info)
		return onGuildExploreMapChange(info)
end); 

listener:RegisterEvent("GUILD_EXPLORE_EVENT_LOG_CHANGE", function(event, info)
		return onGuildExploreEventLogChange(info)
end); 

listener:RegisterEvent("GUILD_PRAY_LOG_CHANGE", function(event, info)
		return onGuildPrayLogChange(info)
end);

listener:RegisterEvent("GUILD_BOSS_OPEN", function(event, info)
                return onGuildBossOpen(info)
end);

listener:RegisterEvent("GUILD_QUEST_CHANGE", function(event, info)
               return onGuildQuestChange(info.guild, info.quest, info.pid)
end);
