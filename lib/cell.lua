local network=network;
local ipairs=ipairs;
local pairs=pairs;
local log=log;
local string=string;
local table=table;
local protobuf=protobuf;
local coroutine=coroutine;
local os=os;
local io=io;
local assert=assert;
local print=print;
local error=error;
local unpack=unpack;
local math = math;
local type = type;
local debug = debug

local Command = require "Command"

local ServiceManager = require "ServiceManager"
local EventManager = require "EventManager"

local AMF=require "AMF"
local protobuf=require "protobuf"

local Property = require "Property"

local CellConfig = require "CellConfig"
require "printtb"
local sprinttb = sprinttb
module "cell"


local service = ServiceManager.New("cell", unpack(CellConfig.cells));
if service == nil then
	log.error("connect to cell service failed");
	loop.exit();
	return;
end

service:RegisterCommands({
	{Command.S_GET_PLAYER_INFO_REQUEST,           "PGetPlayerInfoRequest"},
	{Command.S_GET_PLAYER_INFO_RESPOND,           "PGetPlayerInfoRespond"},
	{Command.S_ADD_PLAYER_NOTIFICATION_REQUEST,   "PAddPlayerNotificationRequest"},
	{Command.S_ADD_PLAYER_NOTIFICATION_RESPOND,   "PAddPlayerNotificationRespond"},
	{Command.S_ADMIN_REWARD_REQUEST,              "PAdminRewardRequest"},
	{Command.S_ADMIN_REWARD_RESPOND,              "PAdminRewardRespond"},

	{Command.S_QUERY_PLAYER_FIGHT_INFO_REQUEST,   "QueryPlayerFightInfoRequest"},
	{Command.S_QUERY_PLAYER_FIGHT_INFO_RESPOND,   "QueryPlayerFightInfoRespond"},

	{Command.S_PLAYER_FIGHT_PREPARE_REQUEST,      "PlayerFightPrepareRequest"},
	{Command.S_PLAYER_FIGHT_PREPARE_RESPOND,      "PlayerFightPrepareRespond"},

	{Command.S_PLAYER_FIGHT_CONFIRM_REQUEST,      "PlayerFightConfirmRequest"},
	{Command.S_PLAYER_FIGHT_CONFIRM_RESPOND,      "PlayerFightConfirmRespond"};

	{Command.S_GET_PLAYER_HERO_INFO_REQUEST,       "PGetPlayerHeroInfoRequest"},
	{Command.S_GET_PLAYER_HERO_INFO_RESPOND,       "PGetPlayerHeroInfoRespond"},

	{Command.C_QUERY_QUEST_REQUEST,                "PGetPlayerQuestInfoRequest"},
	{Command.C_QUERY_QUEST_RESPOND,                "PGetPlayerQuestInfoRespond"},

	{Command.C_SET_QUEST_STATUS_REQUEST,           "PSetPlayerQuestRequest"},
	{Command.C_SET_QUEST_STATUS_RESPOND,           "PSetPlayerQuestRespond"},

	{Command.S_NOTIFY_QUSET_EVENT_REQUEST,         "PNotifyPlayerQuestEventRequest"},
	{Command.S_NOTIFY_QUSET_EVENT_RESPOND,         "aGameRespond"},

	{Command.S_QUERY_RECOMMEND_FIGHT_INFO_REQUEST,   "QueryRecommendFightInfoRequest"},
	{Command.S_QUERY_RECOMMEND_FIGHT_INFO_RESPOND,   "QueryPlayerFightInfoRespond"},
	{Command.S_SET_PLAYER_STATUS_REQUEST, "PSetPlayerStatusRequest"},
	{Command.S_SET_PLAYER_STATUS_RESPOND, "PSetPlayerStatusRespond"},

	{Command.S_QUERY_UNACTIVE_AI_REQUEST, "PQueryUnactiveAIRequest"},
	{Command.S_QUERY_UNACTIVE_AI_RESPOND, "PQueryUnactiveAIRespond"},

	{Command.S_UPDATE_AI_ACTIVE_TIME_REQUEST, "PUpdateAIActiveTimeRequest"},
	{Command.S_UPDATE_AI_ACTIVE_TIME_RESPOND, "aGameRespond"},

	{Command.S_CHANGE_AI_NICK_NAME_REQUEST, "PChangeAINickNameRequest"},
	{Command.S_CHANGE_AI_NICK_NAME_RESPOND, "aGameRespond"},
	
	{Command.S_ADMIN_PLAYER_KICK_REQUEST, "PAdminPlayerKickRequest"},
	{Command.S_ADMIN_PLAYER_KICK_RESPOND, "PAdminPlayerKickRespond"},

	{Command.S_CHANGE_BUFF_REQUEST, "PChangeBuffRequest"},
	{Command.S_CHANGE_BUFF_RESPOND, "aGameRespond"},

	{Command.S_GET_SERVER_INFO_REQUEST, "ServerInfoRequest"},
	{Command.S_GET_SERVER_INFO_RESPOND, "ServerInfoRespond"},

	{Command.S_TRADE_WITH_SYSTEM_REQUEST, "TradeWithSystemRequest"}, 
	{Command.S_TRADE_WITH_SYSTEM_RESPOND, "TradeWithSystemRespond"},
});

function isConnected(playerid)
	if service:isConnected(playerid) then
		return true;
	else
		return false;
	end
end

function getPlayer(playerid, name)
	if service:isConnected(playerid) then
		local result =service:Request(Command.S_GET_PLAYER_INFO_REQUEST, playerid or 0, {playerid = playerid, name = name});
		if not result or not result.player then
			log.warning("fail to call getPlayer `%d`, player not exist", playerid)
		end
		return result;
	else
		log.warning("fail to call getPlayer `%d`, not connecting", playerid)
		return nil;
	end
end

function getPlayerInfo(playerid, name)
	local result =getPlayer(playerid, name)
	return result and result.player or nil
end

function sendNotification(playerid, type, notify)
	 code = AMF.encode(notify);
	return service:Notify(Command.S_ADD_PLAYER_NOTIFICATION_REQUEST, playerid, {type = type, playerid = playerid, data = code});
end


local function convertDrops(drops)
	local drops_s = nil;
	if drops then
		drops_s = {}
		for _, v in ipairs(drops) do
			if type(v) == "number" then
				table.insert(drops_s, {id=v});
			else
				table.insert(drops_s, {id=v.id,level=v.level});
			end
		end
	end
	return drops_s
end


function sendReward(playerid, reward, consume, reason, manual, limit, name, drops, heros, first_time)
	local drops_s = convertDrops(drops);
	return service:Request(Command.S_ADMIN_REWARD_REQUEST, playerid, {playerid = playerid, reward = reward, consume = consume, reason = reason, manual = manual and 1 or 0, limit = limit, name=name, drops = drops_s, heros = heros, first_time = first_time or 0, send_reward = 1});
end

function getDropsReward(drops, first_time)
	local drops_s = convertDrops(drops);
	local ret = service:Request(Command.S_ADMIN_REWARD_REQUEST, 0, {playerid = 0, reward = nil, consume = nil, reason = 0, manual =  0, limit = nil, name = "", drops = drops_s, heros = nil, first_time = first_time or 0, send_reward = 0})--sendReward(0, nil, nil, 0, false, nil, "", drops, nil, first_time, 0)
	if ret and ret.result == Command.RET_SUCCESS then
		return ret.rewards, Command.RET_SUCCESS 
	else
		return nil, ret and ret.result or "not connected" 
	end
end

function sendDropReward(pid, drops, reason, first_time)
	local drops_s = convertDrops(drops);
	local ret = service:Request(Command.S_ADMIN_REWARD_REQUEST, 0, {
			playerid = pid,
			reason = reason,
			manual = 0,
			name = "",
			drops = drops_s,
			first_time = first_time or 0,
			send_reward = 1
	})

	if ret and ret.result == Command.RET_SUCCESS then
		return ret.rewards, Command.RET_SUCCESS 
	else
		return nil, ret and ret.result or "not connected" 
	end
end

function sendRewardWithCondition(playerid, reward, consume, reason, manual, limit, name, condition)
	return service:Request(Command.S_ADMIN_REWARD_REQUEST, playerid, {playerid = playerid, reward = reward, consume = consume, reason = reason, manual = manual and 1 or 0, limit = limit, name=name, condition=condition});
end


function CheckOpenLev(playerid, id) 
	if not id or id == 0 then
		return true;
	end

	local respond = service:Request(Command.S_ADMIN_REWARD_REQUEST, playerid, {playerid = playerid, consume = {{type=57,id=id,count=1}}, manual = 0});
	if respond and respond.result == Command.RET_SUCCESS then
		return true;
	else
		return false;
	end
end


function QueryPlayerFightInfo(pid, npc, ref, heros, assists, opt)
	opt = opt or {}

	local respond = service:Request(Command.S_QUERY_PLAYER_FIGHT_INFO_REQUEST, pid, {pid = pid, npc = npc, ref = ref, heros = heros, assists = assists, level = opt.level, target_fight = opt.target_fight});

	if respond and respond.result == Command.RET_SUCCESS then
		local player = respond.player;
		if not player.roles then
			log.error("QueryPlayerFightInfo fail player roles is nil", sprinttb(player))
		end

		for k, role in pairs(player.roles) do
			local property = {}
			for _, v in ipairs(role.propertys) do
				property[v.type] = (property[v.type] or 0) + v.value
			end
			role.Property = Property(property);
		end

		for k, role in ipairs(player.assists) do
			local property = {}
			for _, v in ipairs(role.propertys) do
				property[v.type] = (property[v.type] or 0) + v.value
			end
			role.Property = Property(property);

			for _, v in ipairs(role.assist_skills) do
				print(v.id, v.weight);
			end
		end
	
		return player;
	else
		return nil, respond and respond.result or "not connected";
	end
end

function PlayerFightPrepare(pid, fightid, heros, assists, opt)
	opt = opt or {}
	local respond = service:Request(Command.S_PLAYER_FIGHT_PREPARE_REQUEST, pid, {pid = pid, fightid = fightid, heros = heros, assists = assists, level = opt.level});
	if respond and respond.result == Command.RET_SUCCESS then
		for k, role in ipairs(respond.fight_data.attacker.roles) do
			local property = {}
			for _, v in ipairs(role.propertys) do
				property[v.type] = (property[v.type] or 0) + v.value
			end
			role.Property = Property(property);
		end

		for k, role in ipairs(respond.fight_data.defender.roles) do
			local property = {}
			for _, v in ipairs(role.propertys) do
				property[v.type] = (property[v.type] or 0) + v.value
			end
			role.Property = Property(property);
		end

		for k, role in ipairs(respond.fight_data.attacker.assists) do
			local property = {}
			for _, v in ipairs(role.propertys) do
				property[v.type] = (property[v.type] or 0) + v.value
			end
			role.Property = Property(property);

			for _, v in ipairs(role.assist_skills) do
				print(v.id, v.weight);
			end
		end
	

		for k, v in ipairs(respond.fight_data.star) do
			print(v.type, v.v1, v.v2);
		end

		return respond.fight_data;
	else
		return nil, respond and respond.result or "not connected";
	end
end

function PlayerFightConfirm(pid, fightid, star, heros)
	local respond = service:Request(Command.S_PLAYER_FIGHT_CONFIRM_REQUEST, pid, {pid = pid, fightid = fightid, star = star, heros = heros});
	if respond and respond.result == Command.RET_SUCCESS then
		return respond.rewards;
	else
		return nil, respond and respond.result or "not connected";
	end
end

function getPlayerHeroInfo(playerid, gid, uuid)
	log.info("Begin to getPlayerHeroInfo")
	local respond =service:Request(Command.S_GET_PLAYER_HERO_INFO_REQUEST, playerid or 0, {playerid = playerid, gid = gid, uuid = uuid});
	if respond and respond.result == Command.RET_SUCCESS then
		return respond.hero, respond.heros;
	else
		return nil, respond and respond.result or "not connected";
	end
end


function QueryPlayerQuestList(pid, types, include_finished_and_canceled)
	local respond =service:Request(Command.C_QUERY_QUEST_REQUEST, pid or 0, {pid = pid, types=types,  include_finished_and_canceled = include_finished_and_canceled});
	print('!!!', respond, respond and respond.result or "--");
	if respond and respond.result == Command.RET_SUCCESS then
		return respond.quests;
	else
		return nil, respond and respond.result or "not connected";
	end
end

function SetPlayerQuestInfo(pid, info) 
	local records = {};
	for k, v in ipairs(info.records or {}) do
		records[k] = v;
	end

	local respond =service:Request(Command.C_SET_QUEST_STATUS_REQUEST, pid or 0, {
			pid  = pid, 
			uuid = info.uuid,
			id   = info.id,
			status = info.status,
			records = records,
			expired_time = info.expired_time,
			rich_reward = info.rich_reward,
			pool = info.pool,
		});
	if respond and respond.result == Command.RET_SUCCESS then
		return respond.uuid;
	else
		return nil, respond and respond.result or "not connected";
	end
end

function NotifyQuestEvent(pid, eventList) 
	return service:Notify(Command.S_NOTIFY_QUSET_EVENT_REQUEST, pid, {pid = pid, events = eventList});
end

function QueryRecommendFightInfo(pid, fight_id, ref, heros, assists)
	local respond = service:Request(Command.S_QUERY_RECOMMEND_FIGHT_INFO_REQUEST, pid, {pid = pid, fight_id = fight_id, ref = ref, heros = heros, assists = assists});
	if respond and respond.result == Command.RET_SUCCESS then
		local player = respond.player;
		for k, role in pairs(player.roles) do
			local property = {}
			for _, v in ipairs(role.propertys) do
				property[v.type] = (property[v.type] or 0) + v.value
			end
			role.Property = Property(property);
		end

		for k, role in ipairs(player.assists) do
			local property = {}
			for _, v in ipairs(role.propertys) do
				property[v.type] = (property[v.type] or 0) + v.value
			end
			role.Property = Property(property);

			for _, v in ipairs(role.assist_skills) do
				print(v.id, v.weight);
			end
		end
	
		return player;
	else
		return nil, respond and respond.result or "not connected";
	end
end

-- status:
-- 0 is normal, 1 is ban, 2 is mute
function setPlayerStatus(pid, status)
	local respond = service:Request(Command.S_SET_PLAYER_STATUS_REQUEST, pid, { playerid = pid, status = status })
	if respond and respond.result == 0 then	
		return true, nil
	else
		if not respond then
			return false, "respond is nil"
		end
		local err = ""
		if respond.result == 11 then
			err = "permmison deny"	
		elseif respond.result == 3 then
			err = "player not exist"
		else
			err = "other reason"
		end		
		return false, err
	end	
end

function QueryUnactiveAI(ref_level)
	local respond = service:Request(Command.S_QUERY_UNACTIVE_AI_REQUEST, 0, {ref_level = ref_level})
	if type(respond) == 'number' then
		print(string.format("respond error %d", respond), debug.traceback())
	end
	if respond and respond.result == 0 then	
		return respond.pid, respond.level 
	else
		if not respond then
			print("query unactive ai fail respond is nil")
			return false, "respond is nil"
		end
		print("query unactive ai fail result", respond.result)
		return false, respond.result 
	end	
end

function UpdateAIActiveTime(id, time)
	local respond = service:Request(Command.S_UPDATE_AI_ACTIVE_TIME_REQUEST, 0, {pid = id, time = time})
	if respond and respond.result == 0 then	
		return respond.pid, nil
	else
		if not respond then
			return false, "respond is nil"
		end
		return false, respond.result 
	end
end


function getGuildTopKList(_, list)
	local power= {}
	for k, v in ipairs(list) do
		power[k] = 0;
	end

	return  {pids = list, military_powers = power};
end

function ChangeAINickName(id, name, head)
	local respond = service:Request(Command.S_CHANGE_AI_NICK_NAME_REQUEST, 0, {pid = id, name = name, head = head or 0})
	if respond and respond.result == 0 then	
		return true
	else
		if not respond then
			return false, "respond is nil"
		end
		return false, respond.result 
	end
end

function KickPlayer(pid)
	local respond = service:Request(Command.S_ADMIN_PLAYER_KICK_REQUEST, 0, { playerid = pid })
	if respond then
		return respond.result
	end
end

function ChangeBuff(playerid, buff_id, add)
	if service:isConnected(playerid) then
		local respond =service:Request(Command.S_CHANGE_BUFF_REQUEST, playerid or 0, {pid = playerid, buff_id = buff_id, add = add});
		if not respond or respond.result ~= Command.RET_SUCCESS then
			log.warning("fail to call ChangeBUff for Player `%d`", playerid)
			return false
		end
		return true;
	else
		log.warning("fail to call ChangeBuff for Player `%d`, not connecting", playerid)
		return false;
	end
end

function getServerInfo()
	local respond = service:Request(Command.S_GET_SERVER_INFO_REQUEST, 0, { sn = 1 })
	if respond and respond.result == 0 then
		return respond
	else
		log.warning("fail to query max level.")
		return nil
	end
end

function TradeEquipWithSystem(playerid, equip_gid, equip_uuid, sell, consume)
	if service:isConnected(playerid) then
		local respond =service:Request(Command.S_TRADE_WITH_SYSTEM_REQUEST, 0, {pid = playerid, equip_gid = equip_gid, equip_uuid = equip_uuid, sell = sell and 1 or 0, consume = consume});
		if not respond or respond.result ~= Command.RET_SUCCESS then
			log.warning("fail to call TradeEquipWithSystem for Player `%d`", playerid)
			return false
		end
		return true, respond.level, respond.quality, respond.uuid
	else
		log.warning("fail to call TradeEquipWithSystem for Player `%d`, not connecting", playerid)
		return false
	end
end

