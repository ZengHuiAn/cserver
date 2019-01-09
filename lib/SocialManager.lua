local Command = require "Command"
local XMLConfig = require "XMLConfig"
local ServiceManager = require "ServiceManager"
local print = print;
local AMF = require "AMF"
local type = type;
local pairs = pairs;
local table = table;
local coroutine = coroutine
local log = log

module "SocialManager"

local socials = {};
local _sn = 1;

local function sn()
	_sn = _sn + 1;
	return _sn;
end

local function runningThread()
	local co = coroutine.running();
	if co == nil then
		return
	end


	if coroutine.isyieldable == nil or
		coroutine.isyieldable(co) then
		return co;
	end

	return;
end

function Connect(name)
	if socials[name] then
		-- already connected
		return socials[name];
	end

	if XMLConfig.Social[name] == nil then
		return nil;
	end

	local remote = XMLConfig.Social[name];
	local service = ServiceManager.New(name, remote);
	socials[name] = service;

	local co = runningThread();
	if co then
		-- service:onConn
		service.waiting_co = co;
		service.onClosed = function()
			-- print('<<<SocialManager>>>', name, 'closed');
			if service.waiting_co then
				service.waiting_co = nil
				coroutine.resume(co);
			end
		end

		service.onConnected = function()
			if service.waiting_co then
				service.waiting_co = nil
				-- print('<<<SocialManager>>>', name, 'connected');
				coroutine.resume(co, service);
			end
		end


		-- print('<<<SocialManager>>>', name, 'start connect');

		return coroutine.yield();
	end

	return service;
end


-- * interface
function sendMail(type, from, to, title, content)
	local service = Connect("Mail");
	if service == nil then
		return nil;
	end

	service:RegisterCommand(Command.C_MAIL_SEND_REQUEST);
	service:RegisterCommand(Command.C_MAIL_SEND_RESPOND);

	local msg = {0, to, type, title, content};
	if service:isConnected(from) then
		return service:Request(Command.C_MAIL_SEND_REQUEST, from, msg)
	else
		return nil;
	end
end

function getContact(id)
	local service = Connect("Mail");
	if service == nil then
		return nil;
	end

	service:RegisterCommand(Command.S_MAIL_CONTACT_GET_REQUEST, "MailContactGetRequest");
	service:RegisterCommand(Command.S_MAIL_CONTACT_GET_RESPOND, "MailContactGetRespond");

	if service:isConnected() then
		return service:Request(Command.S_MAIL_CONTACT_GET_REQUEST, 0, {id = id});
	else
		return nil;
	end
end


function sendMessageToChannel(channel, cmd, msg, flag)
	if channel == nil or cmd == nil or msg == nil then
		return nil;
	end

	local service = Connect("Chat");
	if service == nil then
		return nil;
	end

	service:RegisterCommand(Command.S_CHANNEL_MESSAGE_REQUEST, "ChannelMessageRequest");
	service:RegisterCommand(Command.S_CHANNEL_MESSAGE_RESPOND, "aGameRespond");

	return service:Request(Command.S_CHANNEL_MESSAGE_REQUEST, 0, {
			channel = channel,
			cmd = cmd,
			flag = flag,
			message = msg});
end

function changeChatChannel(pid, join, leave)
	local service = Connect("Chat");
	if service == nil then
		return nil;
	end

	service:RegisterCommand(Command.S_CHANGE_CHAT_CHANNEL_REQUEST, "ChangeChatChannelRequest");
	service:RegisterCommand(Command.S_CHANGE_CHAT_CHANNEL_RESPOND, "aGameRespond");

	return service:Request(Command.S_CHANGE_CHAT_CHANNEL_REQUEST, 0, {
				pid = pid,
				join = join,
				leave = leave
			});
end

function AddMembersFavor(members, beginIndex, source)
	if beginIndex == #members then
		return
	end

	for i = beginIndex + 1, #members do
		AddFavor(members[beginIndex].pid, members[i].pid, source)
	end

	AddMembersFavor(members, beginIndex + 1, source)
end

function AddFavor(pid1, pid2, source)
	local service = Connect("Chat")
	if service == nil then
		return nil
	end

	service:RegisterCommand(Command.S_ADD_FAVOR_NOTIFY, "AddFavorNotify");
	if service:isConnected() then
		service:Notify(Command.S_ADD_FAVOR_NOTIFY, 0, { pid1 = pid1, pid2 = pid2, source = source })
	end
end



function getArenaOrder(pid)
	local service = Connect("Arena");
	if service == nil then
		return nil;
	end

	service:RegisterCommand(Command.S_ARENA_QUERY_REQUEST, "PArenaQueryRequest");
	service:RegisterCommand(Command.S_ARENA_QUERY_RESPOND, "PArenaQueryRespond");

	local respond = service:Request(Command.S_ARENA_QUERY_REQUEST, 0, {pid = pid});
	if respond and respond.result == Command.RET_SUCCESS then
		return respond.order;
	end
	return nil;
end

function getGuild(id)
	local service = Connect("Guild");
	if service == nil then
		return nil;
	end

	service:RegisterCommand(Command.S_GUILD_QUERY_BY_PLAYER_REQUEST, "GuildQueryByPlayerRequest");
	service:RegisterCommand(Command.S_GUILD_QUERY_BY_PLAYER_RESPOND, "GuildQueryByPlayerRespond");

	if service:isConnected() then
		return service:Request(Command.S_GUILD_QUERY_BY_PLAYER_REQUEST, 0, {playerid = id});
	else
		return nil;
	end
end

function getGuildByGuildId(gid)
	local service = Connect("Guild");
        if service == nil then
                return nil;
        end
	service:RegisterCommand(Command.S_GUILD_QUERY_BY_GUILDID_REQUEST, "GuildQueryByGuildIdRequest");
        service:RegisterCommand(Command.S_GUILD_QUERY_BY_GUILDID_RESPOND, "GuildQueryByGuildIdRespond");

        if service:isConnected() then
                return service:Request(Command.S_GUILD_QUERY_BY_GUILDID_REQUEST, 0, {gid = gid});
        else
                return nil;
        end

end

function sendGuildNotify(playerId, guildId, msg)
	local service = Connect("Chat");
	if service == nil then
		return nil;
	end
	if not playerId then
		playerId = 0;
	end
	if not guildId then
		if 0 == playerId then
			return nil;
		end
		local guildInfo = getGuild(playerId);
		if guildInfo and type(guildInfo) == "table" and guildInfo.guild.id then
			guildId = guildInfo.guild.id;
		else
			return nil;
		end
	end
	if 0 == guildId then
		return nil;
	end
	
	service:RegisterCommand(Command.S_CHAT_MESSAGE_REQUEST, "ChatMessageRequest");
	service:RegisterCommand(Command.S_CHAT_MESSAGE_RESPOND, "ChatMessageRespond");
	local rt = service:Request(
		Command.S_CHAT_MESSAGE_REQUEST, 0, {
				from = playerId, channel = guildId + 20, message = msg,
			});
	return rt;
end

getPlayerGuildID = getGuild;

function sendRecordNotify(id, cmd, msg)
	local service = Connect("Chat");
	if service == nil then
		return nil;
	end

	service:RegisterCommand(Command.S_RECORD_NOTIRY_MESSAGE_REQUEST, "RecordNotifyMessageRequest");
	service:RegisterCommand(Command.S_RECORD_NOTIRY_MESSAGE_RESPOND, "aGameRespond");
	
	if service:isConnected(id) then
		return service:Request(
			Command.S_RECORD_NOTIRY_MESSAGE_REQUEST, 0, {
				to = id, cmd = Command.C_PLAYER_DATA_CHANGE, data = AMF.encode({
					sn(), Command.RET_SUCCESS, {cmd, msg}})});
	else
		return nil;
	end
end

function createBoss(type, id, bossid, time)
	local service = Connect("Boss");
	if service == nil then
		return nil;
	end

	time = time or 0;

	service:RegisterCommand(Command.S_BOSS_CREATE_REQUEST, "PBossCreateRequest");
	service:RegisterCommand(Command.S_BOSS_CREATE_RESPOND, "PBossCreateRespond");

	if service:isConnected() then
		return service:Request(Command.S_BOSS_CREATE_REQUEST, 0, {type=type,id=id,boss=bossid,time=time});
	else
		return nil;
	end
end

function addGuildExp(gid, pid, exp)
	local service = Connect("Guild");
        if service == nil then
                return nil;
        end

        service:RegisterCommand(Command.S_GUILD_ADD_EXP_REQUEST, "PGuildAddExpRequest");
        service:RegisterCommand(Command.S_GUILD_ADD_EXP_RESPOND, "aGameRespond");

        local msg = {gid = gid, pid = pid, exp = exp};

        if service:isConnected(0) then
                return service:Notify(Command.S_GUILD_ADD_EXP_REQUEST, 0, msg)
        else
                return nil;
        end
end

--[[
--	gm_id是gm进行公告管理的id，非gm模块可忽略
--]]
function AddTimingNotify(start, duration, interval, type, msg, gm_id)
	local service = Connect("Chat");
	if service == nil then
		return nil;
	end
	
	service:RegisterCommand(Command.S_TIMING_NOTIFY_ADD_REQUEST, "TimingNotifyAddRequest");
	service:RegisterCommand(Command.S_TIMING_NOTIFY_ADD_RESPOND, "TimingNotifyAddRespond");

	if service:isConnected() then
		return service:Request(Command.S_TIMING_NOTIFY_ADD_REQUEST, 0, {
				start = start, duration = duration, interval = interval, type = type, message = msg, gm_id = gm_id
			});
	else
		return nil;
	end
end

function QueryTimingNotify()
	local service = Connect("Chat");
	if service == nil then
		return nil;
	end

	service:RegisterCommand(Command.S_TIMING_NOTIFY_QUERY_REQUEST, "TimingNotifyQueryRequest");
	service:RegisterCommand(Command.S_TIMING_NOTIFY_QUERY_RESPOND, "TimingNotifyQueryRespond");

	if service:isConnected() then
		return service:Request(Command.S_TIMING_NOTIFY_QUERY_REQUEST, 0, {});
	else
		return nil;
	end
end

--[[
--	gm_id是gm进行公告管理的id，非gm模块可忽略
--]]
function DelTimingNotify(id, gm_id)
	local service = Connect("Chat");
	if service == nil then
		return nil;
	end

	service:RegisterCommand(Command.S_TIMING_NOTIFY_DEL_REQUEST, "TimingNotifyDelRequest");
	service:RegisterCommand(Command.S_TIMING_NOTIFY_DEL_RESPOND, "aGameRespond");

	if service:isConnected() then
		return service:Request(Command.S_TIMING_NOTIFY_DEL_REQUEST, 0, {id = id, gm_id = gm_id});
	else
		return nil;
	end
end

function SendPlayerRecordChangeNotify(pid, type, key, value)
	local service = Connect("ADSupport");
	if service == nil then
		return nil;
	end

	service:RegisterCommand(Command.S_PLAYER_CHANGE_NOTIFY, "SPlayerChangeNotify");
	if service:isConnected() then
		return service:Notify(Command.S_PLAYER_CHANGE_NOTIFY, 0, {player={{pid=pid,records={{type=type,key=key,value=value}}}}});
	else
		return nil;
	end
end

-----------------------------------
function RoomCheck(roomType, roomId)
	local service = Connect("Room");
	if service == nil then
		return nil;
	end

	service:RegisterCommand(Command.S_ROOM_CHECK_REQUEST, "S_ROOM_CHECK_REQUEST");
	service:RegisterCommand(Command.S_ROOM_CHECK_RESPOND, "aGameRespond");

	if service:isConnected() then
		return service:Request(Command.S_ROOM_CHECK_REQUEST, 0, {roomType = roomType, roomId = roomId});
	else
		return nil;
	end
end

function RoomClean(roomType, roomId)
	local service = Connect("Room");
	if service == nil then
		return nil;
	end

	service:RegisterCommand(Command.S_ROOM_CLEAN_REQUEST, "S_ROOM_CLEAN_REQUEST");
	service:RegisterCommand(Command.S_ROOM_CLEAN_RESPOND, "aGameRespond");

	if service:isConnected() then
		return service:Request(Command.S_ROOM_CLEAN_REQUEST, 0, {roomType = roomType, roomId = roomId});
	else
		return nil;
	end
end

function RoomClose(roomType, roomId)
	local service = Connect("Room");
	if service == nil then
		return nil;
	end

	service:RegisterCommand(Command.S_ROOM_CLOSE_REQUEST, "S_ROOM_CLOSE_REQUEST");
	service:RegisterCommand(Command.S_ROOM_CLOSE_RESPOND, "aGameRespond");

	if service:isConnected() then
		return service:Request(Command.S_ROOM_CLOSE_REQUEST, 0, {roomType = roomType, roomId = roomId});
	else
		return nil;
	end
end

function RoomCreate(roomType, roomId, maximum)
	local service = Connect("Room");
	if service == nil then
		return nil;
	end

	service:RegisterCommand(Command.S_ROOM_CREATE_REQUEST, "S_ROOM_CREATE_REQUEST");
	service:RegisterCommand(Command.S_ROOM_CREATE_RESPOND, "aGameRespond");

	if service:isConnected() then
		return service:Request(Command.S_ROOM_CREATE_REQUEST, 0, {
				roomType = roomType, roomId = roomId, maximum = maximum});
	else
		return nil;
	end
end

function RoomRecreate(roomType, roomId, maximum, players)
	local service = Connect("Room");
	if service == nil then
		return nil;
	end

	service:RegisterCommand(Command.S_ROOM_RECREATE_REQUEST, "S_ROOM_RECREATE_REQUEST");
	service:RegisterCommand(Command.S_ROOM_RECREATE_RESPOND, "aGameRespond");

	if service:isConnected() then
		return service:Request(Command.S_ROOM_RECREATE_REQUEST, 0, {
				roomType = roomType, roomId = roomId, maximum = maximum, players = players});
	else
		return nil;
	end
end

function RoomGetPos(playerId)
	local service = Connect("Room");
	if service == nil then
		return nil;
	end

	service:RegisterCommand(Command.S_ROOM_GETPOS_REQUEST, "S_ROOM_GETPOS_REQUEST");
	service:RegisterCommand(Command.S_ROOM_GETPOS_RESPOND, "S_ROOM_GETPOS_RESPOND");

	if service:isConnected() then
		return service:Request(Command.S_ROOM_GETPOS_REQUEST, 0, {playerId = playerId});
	else
		return nil;
	end
end

function RoomMove(playerId, x, y)
	local service = Connect("Room");
	if service == nil then
		return nil;
	end

	service:RegisterCommand(Command.S_ROOM_MOVE_REQUEST, "S_ROOM_MOVE_REQUEST");
	service:RegisterCommand(Command.S_ROOM_MOVE_RESPOND, "aGameRespond");

	if service:isConnected() then
		return service:Request(Command.S_ROOM_MOVE_REQUEST, 0, {playerId = playerId, x = x, y = y});
	else
		return nil;
	end
end

function RoomEnter(roomType, roomId, playerId, startX, startY, speed)
	local service = Connect("Room");
	if service == nil then
		return nil;
	end

	service:RegisterCommand(Command.S_ROOM_ENTER_REQUEST, "S_ROOM_ENTER_REQUEST");
	service:RegisterCommand(Command.S_ROOM_ENTER_RESPOND, "aGameRespond");

	if service:isConnected() then
		return service:Request(Command.S_ROOM_ENTER_REQUEST, 0, {
			roomType = roomType, roomId = roomId, playerId = playerId,
			startX = startX, startY = startY, speed = speed});
	else
		return nil;
	end
end

function RoomGetRoomIds(roomType)
	local service = Connect("Room");
	if service == nil then
		return nil;
	end

	service:RegisterCommand(Command.S_ROOM_GET_ROOMIDS_REQUEST, "S_ROOM_GET_ROOMIDS_REQUEST");
	service:RegisterCommand(Command.S_ROOM_GET_ROOMIDS_RESPOND, "S_ROOM_GET_ROOMIDS_RESPOND");

	if service:isConnected() then
		return service:Request(Command.S_ROOM_GET_ROOMIDS_REQUEST, 0, {roomType = roomType});
	else
		return nil;
	end
end


function NotifyADSupportEvent(pid, eventid, value)
	local service = Connect("ADSupport");
	
	if service == nil then
		return nil;
	end
	service:RegisterCommand(Command.S_ADSUPPORT_EVENT_INSERT_EVENT_NUM_REQUEST, "NotifyADSupportEventRequest");
	service:RegisterCommand(Command.S_ADSUPPORT_EVENT_INSERT_EVENT_NUM_RESPOND, "aGameRespond");
	if service:isConnected() then
		return service:Notify(Command.S_ADSUPPORT_EVENT_INSERT_EVENT_NUM_REQUEST, 0, {pid= pid,eventid= eventid,value= value});
	else
		return nil;
	end
end

function GetArenaList()
	local service = Connect("Arena");
	
	if service == nil then
		return nil;
	end

	service:RegisterCommand(Command.S_ARENA_QUERY_LIST_REQUEST, "PArenaQueryListRequest");
	service:RegisterCommand(Command.S_ARENA_QUERY_LIST_RESPOND, "PArenaQueryListRespond");
	if service:isConnected() then
		local respond = service:Request(Command.S_ARENA_QUERY_LIST_REQUEST, 0, {});
		if respond.result == Command.RET_SUCCESS then
			return respond.list;
		end
	else
		return nil;
	end
end

function AddWealth(pid, wealth)
	local service = Connect("Arena");
	
	if service == nil then
		return nil
	end

	service:RegisterCommand(Command.S_ARENA_ADD_WEALTH_REQUEST, "ArenaAddWealthRequest")
	service:RegisterCommand(Command.S_ARENA_ADD_WEALTH_RESPOND, "aGameRespond")
	if service:isConnected() then
		local respond = service:Request(Command.S_ARENA_ADD_WEALTH_REQUEST, 0, { sn = 0, pid = pid, wealth = wealth })	
		return respond
	else
		return nil
	end	
end

function PVPFightPrepare(attacker, defender, opt)
	local service = Connect("Fight");
	
	if service == nil then
		return nil;
	end

	opt = opt or  {}

	service:RegisterCommand(Command.S_PVP_FIGHT_PREPARE_REQUEST, "PVPFightPrepareRequest");
	service:RegisterCommand(Command.S_PVP_FIGHT_PREPARE_RESPOND, "PVPFightPrepareRespond");
	if service:isConnected() then
		local respond = service:Request(Command.S_PVP_FIGHT_PREPARE_REQUEST, 0, {
					sn = sn,
					attacker = attacker,
					defender = defender,
					scene = opt.scene,
					auto = opt.auto,
					attacker_data = opt.attacker_data,
					defender_data = opt.defender_data,
				});
		if respond and respond.result == Command.RET_SUCCESS then
			return respond.winner, respond.id, respond.seed, respond.roles
		end
	else
		return nil;
	end
end

function TeamFightStart(pids, fight_id, fight_level, attacker_data, defender_data)
	local service = Connect("Fight");
	
	if service == nil then
		return nil;
	end

	service:RegisterCommand(Command.S_TEAM_FIGHT_START_REQUEST, "TeamFightStartRequest");
	service:RegisterCommand(Command.S_TEAM_FIGHT_START_RESPOND, "TeamFightStartRespond");
	if service:isConnected() then
		local respond = service:Request(Command.S_TEAM_FIGHT_START_REQUEST, 0, {
					sn = sn,
					pids = pids,
					fight_id = fight_id,
					fight_level = fight_level,
					attacker_data = attacker_data,
					defender_data = defender_data,
				});
		if respond and respond.result == Command.RET_SUCCESS then
			return respond.winner;
		end
	else
		return nil;
	end
end

function TeamStartActivityFight(pid, fight_id, fight_level)
	local service = Connect("Fight");
	
	if service == nil then
		return nil;
	end

	service:RegisterCommand(Command.S_TEAM_START_ACTIVITY_FIGHT_REQUEST, "TeamStartActivityFightRequest");
	service:RegisterCommand(Command.S_TEAM_START_ACTIVITY_FIGHT_RESPOND, "aGameRespond");

	if not service:isConnected() then
		return
	end

	local respond = service:Request(Command.S_TEAM_START_ACTIVITY_FIGHT_REQUEST, 0, {
				sn = sn,
				pid = pid,
				fight_id = fight_id,
				fight_level = fight_level,
			});
	if respond and respond.result == Command.RET_SUCCESS then
		return true;
	end
end

function PVEFightPrepare(attacker, target, npc, heros, assists)
	local service = Connect("Fight");
	
	if service == nil then
		return nil;
	end

	service:RegisterCommand(Command.S_FIGHT_PREPARE_REQUEST, "PVEFightPrepareRequest");
	service:RegisterCommand(Command.S_FIGHT_PREPARE_RESPOND, "PVEFightPrepareRespond");

	if service:isConnected() then
		local respond = service:Request(Command.S_FIGHT_PREPARE_REQUEST, 0, {
					attacker = attacker,
					target = target,
					npc = npc,
					heros = heros,
					assists = assists,
				});
		if respond and respond.result == Command.RET_SUCCESS then
			print("pve fight prepare success")
			return respond.fightID, respond.fightData;
		else
			return nil
		end	
	else
		return nil;
	end	
end

function PVEFightCheck(pid, fightid, starValue, code)
	local service = Connect("Fight");
	
	if service == nil then
		return nil;
	end

	service:RegisterCommand(Command.S_FIGHT_CHECK_REQUEST, "PVEFightCheckRequest");
	service:RegisterCommand(Command.S_FIGHT_CHECK_RESPOND, "PVEFightCheckRespond");

	if service:isConnected() then
		local respond = service:Request(Command.S_FIGHT_CHECK_REQUEST, 0, {
					pid = pid,
					fightid = fightid,
					starValue = starValue,
					code = code,
				});
		if respond and respond.result == Command.RET_SUCCESS then
			return respond.winner, respond.rewards;
		else	
			return nil
		end
	else
		return nil;
	end	
end

function AddRewardRecord(pid, quest_id, rewards)
	local service = Connect("Fight")

	service:RegisterCommand(Command.S_ADD_ACTIVITY_REWARD_NOTIFY, "AddActivityRewardNotify")

	if service:isConnected() then
		return service:Notify(Command.S_ADD_ACTIVITY_REWARD_NOTIFY, 0, { sn = 1, pid = pid, quest_id = quest_id, rewards = rewards });
	else
		return nil;
	end
end

--[[
function PVPFightCheck(id)
	local service = Connect("Fight");
	
	if service == nil then
		return nil;
	end

	service:RegisterCommand(Command.S_PVP_FIGHT_CHECK_REQUEST, "PVPFightCheckRequest");
	service:RegisterCommand(Command.S_PVP_FIGHT_CHECK_RESPOND, "PVPFightCheckRespond");
	if service:isConnected() then
		local respond = service:Request(Command.S_PVP_FIGHT_PREPARE_REQUEST, 0, {sn = sn, attacker = attacker, defender = defender});
		if respond.result == Command.RET_SUCCESS then
			return respond.winner;
		end
	else
		return nil;
	end
end
--]]

function RoomGetPlayerIds(roomType, roomId)
	local service = Connect("Room");
	if service == nil then
		return nil;
	end

	service:RegisterCommand(Command.S_ROOM_GET_PLAYERIDS_REQUEST, "S_ROOM_GET_PLAYERIDS_REQUEST");
	service:RegisterCommand(Command.S_ROOM_GET_PLAYERIDS_RESPOND, "S_ROOM_GET_PLAYERIDS_RESPOND");

	if service:isConnected() then
		return service:Request(Command.S_ROOM_GET_PLAYERIDS_REQUEST, 0, {roomType = roomType, roomId = roomId});
	else
		return nil;
	end
end

function NotifyAITeamPlayerEnter(id, teamid, pid, level)
	local service = Connect("AI");
	if service == nil then
		return nil;
	end

	service:RegisterCommand(Command.S_NOTIFY_AI_TEAM_PLAYER_ENTER_REQUEST, "NotifyAITeamPlayerEnterRequest");
	service:RegisterCommand(Command.S_NOTIFY_AI_TEAM_PLAYER_ENTER_RESPOND, "aGameRespond");

	if service:isConnected(0) then
		return service:Notify(Command.S_NOTIFY_AI_TEAM_PLAYER_ENTER_REQUEST, 0, {id = id, teamid = teamid, pid = pid, level = level, name = name});
	else
		return nil;
	end
end


function NotifyAITeamPlayerAFK(id, pid)
	local service = Connect("AI");
	if service == nil then
		return nil;
	end

	service:RegisterCommand(Command.S_NOTIFY_AI_TEAM_PLAYER_AFK, "NotifyAITeamPlayerAFK");

	if service:isConnected(0) then
		return service:Notify(Command.S_NOTIFY_AI_TEAM_PLAYER_AFK, 0, {id = id, pid = pid});
	else
		return nil;
	end
end

function NotifyAITeamPlayerBackToTeam(id, pid)
	local service = Connect("AI");
	if service == nil then
		return nil;
	end

	service:RegisterCommand(Command.S_NOTIFY_AI_TEAM_PLAYER_BACK_TO_TEAM, "NotifyAITeamPlayerBackToTeam");

	if service:isConnected(0) then
		return service:Notify(Command.S_NOTIFY_AI_TEAM_PLAYER_BACK_TO_TEAM, 0, {id = id, pid = pid});
	else
		return nil;
	end
end

function GetTeamInfo(tid, pid)
	local service = Connect("Map");
	if service == nil then
		return nil;
	end

	service:RegisterCommand(Command.S_TEAM_QUERY_INFO_REQUEST, "TeamQueryInfoRequest");
	service:RegisterCommand(Command.S_TEAM_QUERY_INFO_RESPOND, "TeamQueryInfoRespond");

	if not service:isConnected() then
		return nil
	end

	local respond = service:Request(Command.S_TEAM_QUERY_INFO_REQUEST, 0, {tid = tid, pid = pid});
	if respond and respond.result == Command.RET_SUCCESS then
		return respond;
	end
end

function NotifyTeamDissolve(team_id, service)
	local service = Connect(service or "Fight");
	if service == nil then
		return nil;
	end

	service:RegisterCommand(Command.S_TEAM_QUERY_INFO_REQUEST, "TeamQueryInfoRequest");
	service:RegisterCommand(Command.S_TEAM_QUERY_INFO_RESPOND, "TeamQueryInfoRespond");

	if not service:isConnected() then
		return nil
	end

	service:Notify(Command.S_TEAM_QUERY_INFO_REQUEST, 0, {sn = 0, tid = team_id});
end

function NotifyAITeamPlayerLeave(id, teamid, pid, opt_pid, x, y, z, mapid, channel, room)
	local service = Connect("AI");
	if service == nil then
		return nil;
	end

	service:RegisterCommand(Command.S_NOTIFY_AI_TEAM_PLAYER_LEAVE_REQUEST, "NotifyAITeamPlayerLeaveRequest");
	service:RegisterCommand(Command.S_NOTIFY_AI_TEAM_PLAYER_LEAVE_RESPOND, "aGameRespond");

	if service:isConnected(0) then
		return service:Notify(Command.S_NOTIFY_AI_TEAM_PLAYER_LEAVE_REQUEST, 0, {id = id, teamid = teamid, pid = pid, opt_pid = opt_pid, level = level, name = name, x = x, y = y, z = z, mapid = mapid, channel = channel, room = room});
	else
		return nil;
	end
end

function NotifyAITeamPlayerReady(id, teamid, pid, ready)
	local service = Connect("AI");
	if service == nil then
		return nil;
	end

	service:RegisterCommand(Command.S_NOTIFY_AI_TEAM_PLAYER_READY_REQUEST, "NotifyAITeamPlayerReadyRequest");
	service:RegisterCommand(Command.S_NOTIFY_AI_TEAM_PLAYER_READY_RESPOND, "aGameRespond");

	if service:isConnected(0) then
		return service:Notify(Command.S_NOTIFY_AI_TEAM_PLAYER_READY_REQUEST, 0, {id = id, teamid = teamid, pid = pid, ready = ready});
	else
		return nil;
	end
end

function NotifyAITeamFightFinish(id, winner, fight_id)
	local service = Connect("AI");
	if service == nil then
		return nil;
	end

	service:RegisterCommand(Command.S_NOTIFY_AI_TEAM_FIGHT_FINISH_REQUEST, "NotifyAITeamFightFinishRequest");
	service:RegisterCommand(Command.S_NOTIFY_AI_TEAM_FIGHT_FINISH_RESPOND, "aGameRespond");

	if service:isConnected(0) then
		return service:Notify(Command.S_NOTIFY_AI_TEAM_FIGHT_FINISH_REQUEST, 0, {id = id, winner = winner, fight_id = fight_id});
	else
		return nil;
	end
end

function NotifyAIRollGameCreate(id, game_id, reward_count)
	local service = Connect("AI");
	if service == nil then
		return nil;
	end

	service:RegisterCommand(Command.S_NOTIFY_ROLL_GAME_CREATE, "NotifyAIRollGameCreate");
	--service:RegisterCommand(Command.S_NOTIFY_AI_TEAM_FIGHT_FINISH_RESPOND, "aGameRespond");

	if service:isConnected(0) then
		return service:Notify(Command.S_NOTIFY_ROLL_GAME_CREATE, 0, {id = id, game_id = game_id, reward_count = reward_count});
	else
		return nil;
	end
end

function NotifyAIRollGameFinish(id, game_id)
	local service = Connect("AI");
	if service == nil then
		return nil;
	end

	service:RegisterCommand(Command.S_NOTIFY_ROLL_GAME_FINISH, "NotifyAIRollGameFinish");
	--service:RegisterCommand(Command.S_NOTIFY_AI_TEAM_FIGHT_FINISH_RESPOND, "aGameRespond");

	if service:isConnected(0) then
		return service:Notify(Command.S_NOTIFY_ROLL_GAME_FINISH, 0, {id = id, game_id = game_id});
	else
		return nil;
	end
end

function NotifyAITeamFightStart(id)
	local service = Connect("AI");
	if service == nil then
		return nil;
	end

	service:RegisterCommand(Command.S_NOTIFY_AI_TEAM_FIGHT_START, "NotifyAITeamFightStart");

	if service:isConnected(0) then
		return service:Notify(Command.S_NOTIFY_AI_TEAM_FIGHT_START, 0, {id = id});
	else
		return nil;
	end	
end

-- 通知AI，好友赠送了一次体力
function NotifyAiPresentEnergy(src, dest)
	local service = Connect("AI")
	if service == nil then
		return nil
	end

	service:RegisterCommand(Command.NOTIFY_PRESENT, "NotifyEnergyPresent")
		
	if service:isConnected(0) then
		return service:Notify(Command.NOTIFY_PRESENT, 0, { src = src, dest = dest });
	else
		return nil;
	end	
end

function NotifyAITeamInplaceCheck(id)
	local service = Connect("AI");
	if service == nil then
		return nil;
	end

	service:RegisterCommand(Command.S_NOTIFY_AI_TEAM_INPLACE_CHECK, "NotifyAITeamInplaceCheck");

	if service:isConnected(0) then
		return service:Notify(Command.S_NOTIFY_AI_TEAM_INPLACE_CHECK, 0, {id = id});
	else
		return nil;
	end	
end

function NotifyAITeamLeaderChange(id, leader, x, y, z, mapid, channel, room)
	local service = Connect("AI");
	if service == nil then
		return nil;
	end

	service:RegisterCommand(Command.S_NOTIFY_AI_TEAM_LEADER_CHANGE, "NotifyAITeamLeaderChange");

	if service:isConnected(0) then
		return service:Notify(Command.S_NOTIFY_AI_TEAM_LEADER_CHANGE, 0, {id = id, leader = leader, x = x, y = y, z = z, mapid = mapid, channel = channel, room = room});
	else
		return nil;
	end	
end

function NotifyAITeamGroupChange(id, group)
	local service = Connect("AI");
	if service == nil then
		return nil;
	end

	service:RegisterCommand(Command.S_NOTIFY_AI_TEAM_GROUP_CHANGE, "NotifyAITeamGroupChange");

	if service:isConnected(0) then
		return service:Notify(Command.S_NOTIFY_AI_TEAM_GROUP_CHANGE, 0, {id = id, grup = group});
	else
		return nil;
	end	
end

function NotifyAITeamAutoMatchChange(id, auto_match) 
	local service = Connect("AI");
	if service == nil then
		return nil;
	end

	service:RegisterCommand(Command.S_NOTIFY_AI_TEAM_AUTO_MATCH_CHANGE, "NotifyAITeamAutoMatchChange");

	if service:isConnected(0) then
		return service:Notify(Command.S_NOTIFY_AI_TEAM_AUTO_MATCH_CHANGE, 0, {id = id, auto_match = auto_match});
	else
		return nil;
	end
end

-- 通知AI，军团申请回复
function NotifyAiGuildApply(gid)
	local service = Connect("AI")
	if service == nil then
		return nil
	end
	
	service:RegisterCommand(Command.S_GUILD_APPLY_NOTIFY, "NotifyGuildApply")
	if service:isConnected(0) then
		return service:Notify(Command.S_GUILD_APPLY_NOTIFY, 0, { gid = gid })
	else
		return nil
	end	
end

-- 通知AI，军团解散或者被踢出
function NotifyAiLeaveGuild(pid, gid)	
	local service = Connect("AI")
	if service == nil then
		return nil
	end

	service:RegisterCommand(Command.S_GUILD_DISPEAR_NOTIFY, "NotifyGuildDispear")
	if service:isConnected(0) then
		return service:Notify(Command.S_GUILD_DISPEAR_NOTIFY, 0, { pid = pid, gid = gid })
	else
		return nil
	end	
end

function NotifyAIBountyChange(id, quest_id, record, next_fight_time, activity_id, finish, winner)
	local service = Connect("AI");
	if service == nil then
		return nil;
	end

	service:RegisterCommand(Command.S_NOTIFY_AI_BOUNTY_CHANGE, "NotifyAIBountyChange");

	if service:isConnected(0) then
		return service:Notify(Command.S_NOTIFY_AI_BOUNTY_CHANGE, 0, {id = id, quest = quest_id, record = record, next_fight_time = next_fight_time, activity_id = activity_id, finish = finish, winner = winner});
	else
		return nil;
	end	
end

function NotifyToActiveAI(level, first_target)
	local service = Connect("AI");
	if service == nil then
		return nil;
	end

	service:RegisterCommand(Command.S_NOTIFY_ACTIVE_AI, "NotifyActiveAI");

	if service:isConnected(0) then
		return service:Notify(Command.S_NOTIFY_ACTIVE_AI, 0, {level = level, first_target = first_target});
	else
		return nil;
	end	

end

function NotifyAIPlayerApplyToBeLeader(id, candidate)
	local service = Connect("AI");
	if service == nil then
		return nil;
	end

	service:RegisterCommand(Command.S_NOTIFY_AI_PLAYER_APPLY_TO_BE_LEADER, "NotifyAIPlayerApplyToBeLeader");

	if service:isConnected(0) then
		return service:Notify(Command.S_NOTIFY_AI_PLAYER_APPLY_TO_BE_LEADER, 0, {id = id, candidate = candidate});
	else
		return nil;
	end	

end

function NotifyAINewJoinRequest(id, pid, level)
	local service = Connect("AI");
	if service == nil then
		return nil;
	end

	service:RegisterCommand(Command.S_NOTIFY_AI_NEW_JOIN_REQUEST, "NotifyAINewJoinRequest");

	if service:isConnected(0) then
		return service:Notify(Command.S_NOTIFY_AI_NEW_JOIN_REQUEST, 0, {id = id, pid = pid, level = level});
	else
		return nil;
	end
end

function NotifyAIBattleTimeChange(id, battle_id, begin_time, end_time) 
	local service = Connect("AI");
	if service == nil then
		return nil;
	end

	service:RegisterCommand(Command.S_NOTIFY_AI_BATTLE_TIME_CHANGE, "NotifyAIBattleTimeChange");

	if service:isConnected(0) then
		return service:Notify(Command.S_NOTIFY_AI_BATTLE_TIME_CHANGE, 0, {id = id, battle_begin_time = begin_time, battle_end_time = end_time});
	else
		return nil;
	end
end

function SetRankDatum(pid,rankid,score,sociaty)		-- 玩家id 排行榜id 分数 公会id
	local service = Connect("Quiz")
	if service == nil then
                return nil;
        end
	service:RegisterCommand(Command.S_RANKLIST_UPDATE_DATUM_REQUEST, "RankListUpdateDatumRequest")
	service:RegisterCommand(Command.S_RANKLIST_UPDATE_DATUM_RESPOND, "aGameRespond")	

	if service:isConnected(0) then
                return service:Notify(Command.S_RANKLIST_UPDATE_DATUM_REQUEST, 0, {pid = pid,rankid = rankid,score = score,sociaty = sociaty});
        else
                return nil;
        end

end

--[[function TeamNotify(teamid, cmd, msg, pids, include_afk_mem)
	local service = Connect("Map")
	if service == nil then
		return nil
	end

	service:RegisterCommand(Command.S_NOTIFY_TEAM_MEMBERS, "NotifyTeamMembers");

	if service:isConnected(0) then
		return service:Notify(Command.S_NOTIFY_TEAM_MEMBERS, 0, {teamid = teamid, cmd = cmd, msg = msg, pids = pids, include_afk_mem = include_afk_mem})
	else 
		return nil
	end
end--]]

-----------------------------------
function translateCellRewardToClientInfo(reward)
        if reward == nil or type(reward) ~= "table" then
                return {};
        end

	local rr = {};
	for _, v in pairs(reward) do
		if v.type == "REWARD_PLAYER_EXP" or v.type == 1 then
			table.insert(rr, {1,1000,v.value});
		elseif v.type == "REWARD_PLAYER_PRESTIGE" or v.type == 2 then table.insert(rr, {1,1001,v.value});
		elseif v.type == "REWARD_RESOURCES_VALUE" or v.type == 3 then
			table.insert(rr, {90,v.key,v.value});
		elseif v.type == "REWARD_HERO_EXP" or v.type == 4 then
			table.insert(rr, {2,2000, v.value});
		elseif v.type == "REWARD_HERO_ID"  then
			table.insert(rr, {10,v.key,v.value});
		elseif v.type == "REWARD_ITEM" or v.type == 5 then
			table.insert(rr, {41,v.key,v.value});
		elseif v.type == "REWARD_GEM" or v.type == 6 then
			table.insert(rr, {22,v.key,v.value});
		elseif v.type == "REWARD_EQUIP" or v.type == 7 then
			table.insert(rr, {21,v.key,v.value});
		end end return rr;
end

function translateCellRewardToServerInfo(reward)
        if reward == nil or type(reward) ~= "table" then
                return {};
        end

	local rr = {};
	for _, v in pairs(reward) do
		if v.type == 1 and v.key == 1000 then
			table.insert(rr, {type = "REWARD_PLAYER_EXP", key = v.key, value = v.value});
		elseif v.type == 1 and v.key == 1001 then
			table.insert(rr, {type = "REWARD_PLAYER_PRESTIGE", key = v.key, value = v.value});
		elseif v.type == 90 then
			table.insert(rr, {type = "REWARD_RESOURCES_VALUE", key = v.key, value = v.value});
		elseif v.type == 2 and v.key == 2000 then
			table.insert(rr, {type = "REWARD_HERO_EXP", key = v.key, value = v.value});
		elseif v.type == 10 then
			table.insert(rr, {type = "REWARD_HERO_ID", key = v.key, value = v.value});
		elseif v.type == 41 then
			table.insert(rr, {type = "REWARD_ITEM", key = v.key, value = v.value});
		elseif v.type == 22 then
			table.insert(rr, {type = "REWARD_GEM", key = v.key, value = v.value});
		elseif v.type == 21 then
			table.insert(rr, {type = "REWARD_EQUIP", key = v.key, value = v.value});
		end
	end
	return rr;
end

function translateCellRewardToServerInfo2(reward)
        if reward == nil or type(reward) ~= "table" then
                return {};
        end

	for _, v in pairs(reward) do
		if v.type == 1 and v.key == 1000 then
			v.type = "REWARD_PLAYER_EXP";
			v.key = v.key;
			v.value = v.value;
		elseif v.type == 1 and v.key == 1001 then
			v.type = "REWARD_PLAYER_PRESTIGE";
			v.key = v.key;
			v.value = v.value;
		elseif v.type == 90 then
			v.type = "REWARD_RESOURCES_VALUE";
			v.key = v.key;
			v.value = v.value;
		elseif v.type == 2 and v.key == 2000 then
			v.type = "REWARD_HERO_EXP";
			v.key = v.key;
			v.value = v.value;
		elseif v.type == 10 then
			v.type = "REWARD_HERO_ID";
			v.key = v.key;
			v.value = v.value;
		elseif v.type == 41 then
			v.type = "REWARD_ITEM";
			v.key = v.key;
			v.value = v.value;
		elseif v.type == 22 then
			v.type = "REWARD_GEM";
			v.key = v.key;
			v.value = v.value;
		elseif v.type == 21 then
			v.type = "REWARD_EQUIP";
			v.key = v.key;
			v.value = v.value;
		end
	end
end
