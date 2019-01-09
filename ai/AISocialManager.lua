package.cpath=package.cpath .. ";../lib/?.so";
package.path =package.path  .. ";../lib/?.lua";

local Command = require "Command"
local XMLConfig = require "XMLConfig"
local ServiceManager = require "ServiceManager"
local AIData = require "AIData"
--local BattleConfig = require "BattleConfig"
require "ConditionConfig"
require "log"
require "Scheduler"
require "printtb"
require "Thread"
local DataThread = require "DataThread"
local cell = require "cell"

--local acting_list = {}

local services = {}
local remote_cfg = {
	["Map"] = {
		{Command.S_MAP_QUERY_POS_REQUEST, "MapQueryPosRequest"},
		{Command.S_MAP_QUERY_POS_RESPOND, "MapQueryPosRespond"},
		{Command.S_MAP_MOVE_REQUEST, "MapMoveRequest"},
		{Command.S_MAP_MOVE_RESPOND, "aGameRespond"},
		{Command.S_MAP_LOGIN_REQUEST, "MapLoginRequest"},
		{Command.S_MAP_LOGIN_RESPOND, "aGameRespond"},
		{Command.S_MAP_LOGOUT_REQUEST, "MapLogoutRequest"},
		{Command.S_MAP_LOGOUT_RESPOND, "aGameRespond"},
		{Command.S_TEAM_QUERY_INFO_REQUEST, "TeamQueryInfoRequest"},
		{Command.S_TEAM_QUERY_INFO_RESPOND, "TeamQueryInfoRespond"},
		{Command.S_TEAM_CREATE_REQUEST, "TeamCreateRequest"},
		{Command.S_TEAM_CREATE_RESPOND, "TeamCreateRespond"},
		{Command.S_TEAM_LEAVE_REQUEST, "TeamLeaveRequest"},
		{Command.S_TEAM_LEAVE_RESPOND, "aGameRespond"},
		{Command.S_TEAM_SET_AUTO_CONFIRM_REQUEST, "TeamSetAutoConfirmRequest"},
		{Command.S_TEAM_SET_AUTO_CONFIRM_RESPOND, "aGameRespond"},
		{Command.S_TEAM_INPLACE_CHECK_REQUEST, "TeamInplaceCheckRequest"},
		{Command.S_TEAM_INPLACE_CHECK_RESPOND, "aGameRespond"},
		{Command.S_TEAM_INPLACE_READY_REQUEST, "TeamInplaceReadyRequest"},
		{Command.S_TEAM_INPLACE_READY_RESPOND, "aGameRespond"},
		{Command.S_TEAM_SYNC_REQUEST, "TeamSyncRequest"},
		{Command.S_TEAM_SYNC_RESPOND, "aGameRespond"},
		{Command.S_TEAM_DISSOLVE_REQUEST, "TeamDissolveRequest"},
		{Command.S_TEAM_DISSOLVE_RESPOND, "aGameRespond"},
		{Command.S_QUERY_AUTOMATCH_TEAM_REQUEST, "QueryAutoMatchTeamRequest"},
		{Command.S_QUERY_AUTOMATCH_TEAM_RESPOND, "QueryAutoMatchTeamRespond"},
		{Command.S_NOTIFY_AI_SERVICE_RESTART, "aGameRequest"},
		{Command.S_AI_TEAM_AUTOMATCH_REQUEST, "AITeamAutomatchRequest"},
		{Command.S_AI_TEAM_AUTOMATCH_RESPOND, "aGameRespond"},
		{Command.S_AI_AUTOMATCH_REQUEST, "AIAutomatchRequest"},
		{Command.S_AI_AUTOMATCH_RESPOND, "aGameRespond"},
		{Command.S_GET_AUTOMATCH_TEAM_COUNT_REQUEST, "GetAutomatchTeamCountRequest"},
		{Command.S_GET_AUTOMATCH_TEAM_COUNT_RESPOND, "GetAutomatchTeamCountRespond"},
		{Command.S_TEAM_CHANGE_LEADER_REQUEST, "TeamChangeLeaderRequest"},
		{Command.S_TEAM_CHANGE_LEADER_RESPOND, "aGameRespond"},
		{Command.S_TEAM_GET_PLAYER_AI_RATIO_REQUEST, "GetPlayerAIRatioRequest"},
		{Command.S_TEAM_GET_PLAYER_AI_RATIO_RESPOND, "GetPlayerAIRatioRespond"},
		{Command.S_TEAM_VOTE_REQUEST, "TeamVoteRequest"},
		{Command.S_TEAM_JOIN_CONFIRM_REQUEST, "TeamJoinConfirmRequest"}
	},
	["Fight"] = {
		{Command.S_TEAM_START_ACTIVITY_FIGHT_REQUEST, "TeamStartActivityFightRequest"},
		{Command.S_TEAM_START_ACTIVITY_FIGHT_RESPOND, "aGameRespond"},
		--{Command.S_TEAM_FIGHT_READY_REQUEST, "TeamFightReadyRequest"},
		--{Command.S_TEAM_FIGHT_READY_RESPOND, "aGameRespond"},
		{Command.S_TEAM_ROLL_REWARD_REQUEST, "TeamRollRewardRequest"},
		{Command.S_TEAM_ROLL_REWARD_RESPOND, "aGameRespond"},
		{Command.S_TEAM_GET_TEAM_PROGRESS_REQUEST, "TeamGetTeamProgressRequest"},
		{Command.S_TEAM_GET_TEAM_PROGRESS_RESPOND, "TeamGetTeamProgressRespond"},
		{Command.S_TEAM_FIND_NPC_REQUEST, "TeamFindNpcRequest"},
		{Command.S_TEAM_FIND_NPC_RESPOND, "aGameRespond"},
		{Command.S_BOUNTY_QUERY_REQUEST, "BountyQueryRequest"},
		{Command.S_BOUNTY_QUERY_RESPOND, "BountyQueryRespond"},
		{Command.S_BOUNTY_START_REQUEST, "BountyStartRequest"},
		{Command.S_BOUNTY_START_RESPOND, "BountyStartRespond"},
		{Command.S_BOUNTY_FIGHT_REQUEST, "BountyFightRequest"},
		{Command.S_BOUNTY_FIGHT_RESPOND, "BountyFightRespond"},
		{Command.S_TEAM_QUERY_BATTLE_TIME_REQUEST, "QueryTeamBattleTimeRequest"},
		{Command.S_TEAM_QUERY_BATTLE_TIME_RESPOND, "QueryTeamBattleTimeRespond"},
		{Command.S_TEAM_ENTER_BATTLE_REQUEST, "TeamEnterBattleRequest"},
	},	
	["Chat"] = {
		{ Command.S_MAIL_ENERGE_PRESENT_NOTIFY, "PresentEnergyNotify"},
		{ Command.S_MAIL_ADD_FRIEND_NOTIFY, "AddFriendNotify"},
		
		{ Command.S_QUERY_RESENT_RECORD_REQUEST, "QueryResentRecordRequest" },	
		{ Command.S_QUERY_RESENT_RECORD_RESPOND, "QueryResentRecordRespond" },

		{ Command.S_CHAT_MESSAGE_REQUEST, "ChatMessageRequest"},
		{ Command.S_CHAT_MESSAGE_RESPOND, "ChatMessageRespond"},
		{ Command.S_NOTIFY_AI_LOGIN_CHAT, "AILoginNotify"},
		{ Command.S_NOTIFY_AI_LOGOUT_CHAT, "AILogoutNotify"},
	},
	["Guild"] = {
		{ Command.S_GUILD_QUERY_REQUEST, "QueryGuildByPidRequest" },
		{ Command.S_GUILD_QUERY_RESPOND, "QueryGuildByPidRespond" },

		{ Command.S_GUILD_APPLY_NOTIFY, "ApplyGuildNotify" },
		{ Command.S_GUILD_DONATE_NOTIFY, "DonateExpNotify" },	
		{ Command.S_SEEK_PRAY_HELP_NOTIFY, "SeekPrayHelpNotify" },
		{ Command.S_HELP_PRAY_NOTIFY, "HelpPrayNotify" },
		{ Command.S_GUILD_EXPLORE_NOTIFY, "GuildExploreNotify" },
		{ Command.S_NOTIFY_AI_LEADER_WORK, "DoLeaderWorkNotify" },
		{ Command.S_NOTIFY_AI_LOGIN_GUILD, "AILoginNotify"},
		{ Command.S_NOTIFY_AI_LOGOUT_GUILD, "AILogoutNotify"},
	},
	["Arena"] = {
		{ Command.NOTIFY_ARENA_AI_ENTER, "ArenaAIEnterNotify" }
	},
	["Quiz"] = {
		{ Command.S_PLAYERPROPERTY_QUERY_REQUEST, "QueryPlayerPropertyRequest"},
		{ Command.S_PLAYERPROPERTY_QUERY_RESPOND, "QueryPlayerPropertyRespond"},
		{ Command.S_PLAYERPROPERTY_MODIFY_REQUEST, "ModifyPlayerPropertyRequest"},
		{ Command.S_PLAYERPROPERTY_MODIFY_RESPOND, "aGameRespond"},
	},
}

for name, v in pairs (remote_cfg) do
	-- connect
	local remote = XMLConfig.Social[name]	
	if not services[name] then
		services[name] = ServiceManager.New(name, remote)
	end

	-- register command
	for _, v2 in ipairs(v) do
		services[name]:RegisterCommand(v2[1], v2[2])
	end

	services[name]:RegisterCallBack(function(cmd, channel, respond)
		DataThread.getInstance():SendMessage(cmd, channel, respond)
	end, "*")
end

local function GetService(name)
	return services[name]
end

function GetAndCheckService(name)
	local service = GetService(name)

	if not service then
		AI_DEBUG_LOG("donnt register service %s", name)
		return false 
	end

	local t = 0
	local thread = RunThread(function ()
		while (true) do
			if t >= 5 then
				AI_DEBUG_LOG(string.format("connect service %s overtime", name))
				return false	
			end

			if not service:isConnected(0) then
				AI_DEBUG_LOG(string.format("service %s not connected", name))
				t = t + 1
				Sleep(1)
			else
				break
			end	
		end
	end)

	return service
end

function NotifyAIServiceRestart()
	local service = GetAndCheckService("Map")

	if not service then
		log.error("Fight service not exists.")
		return false
	end

	local respond = service:Notify(Command.S_NOTIFY_AI_SERVICE_RESTART, 0, {})
	return respond
end

function LoginMap(id)
	local service = GetAndCheckService("Map")

	if not service then
		return false
	end

	service:Notify(Command.S_MAP_LOGIN_REQUEST, id, {pid = id})
end

function LogoutMap(id)
	local service = GetAndCheckService("Map")

	if not service then
		return false
	end

	service:Notify(Command.S_MAP_LOGOUT_REQUEST, id, {pid = id})
end

function GetPos(id)
	local service = GetAndCheckService("Map")

	if not service then
		return false
	end

	return service:Notify(Command.S_MAP_QUERY_POS_REQUEST, id, {pid = id})
end

function MapMove(id, x, y, z, mapid, channel, room) 
	local service = GetAndCheckService("Map")

	if not service then
		return false
	end

	return service:Notify(Command.S_MAP_MOVE_REQUEST, id, {pid = id, x = x, y = y, z = z, mapid = mapid, channel = channel, room = room})
end

function LoadTeam(id) 
	local service = GetAndCheckService("Map")

	if not service then
		return false
	end

	return service:Notify(Command.S_TEAM_QUERY_INFO_REQUEST, id, {pid = id})
end

function CreateTeam(id, group, lower_limit, upper_limit)
	local service = GetAndCheckService("Map")

	if not service then
		return false
	end

	return service:Notify(Command.S_TEAM_CREATE_REQUEST, id, {pid = id, grup = group, lower_limit = lower_limit, upper_limit = upper_limit})
end

function LeaveTeam(opt_id, id)
	local service = GetAndCheckService("Map")

	if not service then
		return false
	end

	return service:Notify(Command.S_TEAM_LEAVE_REQUEST, opt_id, {opt_id = opt_id, pid = id or opt_id})
end

function DissolveTeam(id)
	local service = GetAndCheckService("Map")

	if not service then
		return false
	end

	return service:Notify(Command.S_TEAM_DISSOLVE_REQUEST, id, {pid = id})
end

function SetAutoConfirm(id, teamid)
	local service = GetAndCheckService("Map")

	if not service then
		return false
	end

	return service:Notify(Command.S_TEAM_SET_AUTO_CONFIRM_REQUEST, id, {pid = id, teamid = teamid})
end

function InplaceCheck(id, teamid, type)
	local service = GetAndCheckService("Map")

	if not service then
		return false
	end

	return service:Notify(Command.S_TEAM_INPLACE_CHECK_REQUEST, id, {pid = id, teamid = teamid, type = type})
end

function InplaceReady(id, teamid, ready, type)
	local service = GetAndCheckService("Map")

	if not service then
		return false
	end

	return service:Request(Command.S_TEAM_INPLACE_READY_REQUEST, id, {pid = id, teamid = teamid, ready = ready, type = type})
end

function StartFight(id, fight_id)
	local service = GetAndCheckService("Fight")

	if not service then
		return false
	end

	return service:Notify(Command.S_TEAM_START_ACTIVITY_FIGHT_REQUEST, id, {pid = id, fight_id = fight_id})
end

function PlayerFightReady(id)
	local service = GetAndCheckService("Fight")

	if not service then
		return false
	end

	return service:Notify(Command.S_TEAM_FIGHT_READY_REQUEST, id, {pid = id})
end

function TeamSync(id, cmd, data)
	local service = GetAndCheckService("Map")

	if not service then
		return false
	end

	service:Notify(Command.S_TEAM_SYNC_REQUEST, id, {pid = id, cmd = cmd, data = data})
end

function Roll(id, game_id, idx, want)
	local service = GetAndCheckService("Fight")

	if not service then
		return false
	end

	return service:Notify(Command.S_TEAM_ROLL_REWARD_REQUEST, id, {pid = id, game_id = game_id, idx = idx, want = want})
end

function GetTeamProgress(id, teamid, fights)
	local service = GetAndCheckService("Fight")

	if not service then
		return false
	end

	local respond = service:Request(Command.S_TEAM_GET_TEAM_PROGRESS_REQUEST, id, {pid = id, teamid = teamid, fights = fights})
	return respond
end

function FindNpc(id, fight_id)
	local service = GetAndCheckService("Fight")

	if not service then
		return false
	end

	return service:Notify(Command.S_TEAM_FIND_NPC_REQUEST, id, {pid = id, fight_id = fight_id})
end

function AITeamAutoMatch(id, auto_match)
	local service = GetAndCheckService("Map")

	if not service then
		return false
	end

	return service:Notify(Command.S_AI_TEAM_AUTOMATCH_REQUEST, id, {pid = id, auto_match = auto_match})
end

function AIAutoMatch(id, group, teamid)
	local service = GetAndCheckService("Map")

	if not service then
		return false
	end

	return service:Notify(Command.S_AI_AUTOMATCH_REQUEST, id, {pid = id, grup = group, teamid = teamid})
end

function GetAutoMatchTeamCount(id, group, level)
	local service = GetAndCheckService("Map")

	if not service then
		return false
	end

	return service:Notify(Command.S_GET_AUTOMATCH_TEAM_COUNT_REQUEST, id, {grup = group, level = level})
end

function QueryAutoMatchTeam()
	local service = GetAndCheckService("Map")

	if not service then
		return false
	end

	local respond = service:Request(Command.S_QUERY_AUTOMATCH_TEAM_REQUEST, 0, {})
	return respond
end

function AddFriend(pid, friends)
	local service = GetAndCheckService("Chat")

	if not service then
		log.error("Chat service not exists.")
		return
	end

	service:Notify(Command.S_MAIL_ADD_FRIEND_NOTIFY, pid, { pid = pid, friends = friends })
end

function PresentEnergy(id)
	local service = GetAndCheckService("Chat")

	if not service then
		log.error("Chat service not exists.")
		return
	end
	service:Notify(Command.S_MAIL_ENERGE_PRESENT_NOTIFY, id, { pid = id })
end

function GetPresentRecord(id)	
	local service = GetAndCheckService("Chat")
		
	if not service then
		log.error("Chat service not exists.")
		return false
	end
	local respond = service:Request(Command.S_QUERY_RESENT_RECORD_REQUEST, id, { pid = id })
	return respond	
end

function AILoginChat(id)
	local service = GetAndCheckService("Chat")

	if not service then
		log.error("Chat service not exists.")
		return
	end
	service:Notify(Command.S_NOTIFY_AI_LOGIN_CHAT, id, { pid = id })
end

function AILogoutChat(id)
	local service = GetAndCheckService("Chat")

	if not service then
		log.error("Chat service not exists.")
		return
	end
	service:Notify(Command.S_NOTIFY_AI_LOGOUT_CHAT, id, { pid = id })
end

function GetGuildInfo(id)
	local service = GetAndCheckService("Guild")

	if not service then
		log.error("Guild service not exists.")
		return false
	end
	local respond = service:Request(Command.S_GUILD_QUERY_REQUEST, id, { pid = id })
	return respond	
end

function ApplyGuild(id)
	local service = GetAndCheckService("Guild")

	if not service then
		log.error("Guild service not exists.")
		return
	end
	service:Notify(Command.S_GUILD_APPLY_NOTIFY, id, { pid = id })	
end

function DonateExp(id, type)
	local service = GetAndCheckService("Guild")

	if not service then
		log.error("Guild service not exists.")
		return
	end
	service:Notify(Command.S_GUILD_DONATE_NOTIFY, id, { pid = id, donateType = type })
end

function SeekPrayHelp(id)
	local service = GetAndCheckService("Guild")

	if not service then
		log.error("Guild service not exists.")
		return
	end
	service:Notify(Command.S_SEEK_PRAY_HELP_NOTIFY, id, { pid = id })	
end

function HelpPray(id)
	local service = GetAndCheckService("Guild")

	if not service then
		log.error("Guild service not exists.")
		return
	end

	service:Notify(Command.S_HELP_PRAY_NOTIFY, id, { pid = id })
end

function FinishExplore(id)
	local service = GetAndCheckService("Guild")

	if not service then
		log.error("Guild service not exist.")
		return
	end

	service:Notify(Command.S_GUILD_EXPLORE_NOTIFY, id, { pid = id })
end

function DoLeaderWork(id)
	local service = GetAndCheckService("Guild")

	if not service then
		log.error("Guild service not exist.")
		return
	end

	service:Notify(Command.S_NOTIFY_AI_LEADER_WORK, id, { pid = id } )
end

function AILoginGuild(id)
	local service = GetAndCheckService("Guild")

	if not service then
		log.error("Guild service not exist.")
		return
	end

	service:Notify(Command.S_NOTIFY_AI_LOGIN_GUILD, id, { pid = id })
end

function AILogoutGuild(id)
	local service = GetAndCheckService("Guild")

	if not service then
		log.error("Guild service not exist.")
		return
	end

	service:Notify(Command.S_NOTIFY_AI_LOGOUT_GUILD, id, { pid = id })
end

function BountyQuery(id)
	local service = GetAndCheckService("Fight")

	if not service then
		log.error("Fight service not exists.")
		return false
	end

	local respond = service:Request(Command.S_BOUNTY_QUERY_REQUEST, id, { pid = id})
	return respond
end

function BountyStart(id, activity_id)
	local service = GetAndCheckService("Fight")

	if not service then
		log.error("Fight service not exists.")
		return false
	end

	return service:Notify(Command.S_BOUNTY_START_REQUEST, id, { pid = id, activity_id = activity_id })
end

function BountyFight(id, activity_id)
	local service = GetAndCheckService("Fight")

	if not service then
		log.error("Fight service not exists.")
		return false
	end

	return service:Notify(Command.S_BOUNTY_FIGHT_REQUEST, id, { pid = id, activity_id = activity_id })
end

function QueryTeamBattleTime(id, battle_id)
	local service = GetAndCheckService("Fight")

	if not service then
		log.error("Fight service not exists.")
		return false
	end

	return service:Notify(Command.S_TEAM_QUERY_BATTLE_TIME_REQUEST, id, {pid = id, battle_id = battle_id })
end

function EnterBattle(id, battle_id)
	local service = GetAndCheckService("Fight")

	if not service then
		log.error("Fight service not exists.")
		return false
	end

	print(string.format("AI %d enter battle %d", id, battle_id))
	return service:Notify(Command.S_TEAM_ENTER_BATTLE_REQUEST, id, {pid = id, battle_id = battle_id })
end

CHAT_SYSTEM = 0 
CHAT_WORLD = 1 
CHAT_COUNTRY = 2 
CHAT_GUILD = 3 

function Chat(id, chat_channel, message)
	local service = GetAndCheckService("Chat")

	if not service then
		log.error("Chat service not exists.")
		return false
	end

	return service:Notify(Command.S_CHAT_MESSAGE_REQUEST, id, { from = id, channel = chat_channel, message = message})
end

function ChangeNickName(id, name, head)
	local success = cell.ChangeAINickName(id, name, head or 0)
	return success	
end

function NotifyAIEnter(id) 
	local service = GetAndCheckService("Arena")

	if not service then
		log.error("Fight service not exists.")
		return false
	end

	local respond = service:Notify(Command.NOTIFY_ARENA_AI_ENTER, 0, { id = id })
	return respond
end 

function ChangeLeader(id, new_leader)
	local service = GetAndCheckService("Map")

	if not service then
		log.error("Map service not exists.")
		return false
	end

	return service:Notify(Command.S_TEAM_CHANGE_LEADER_REQUEST, 0, { id = id, new_leader = new_leader })
end

function GetTargetPriority(targets)
	local service = GetAndCheckService("Map")

	if not service then
		log.error("Map service not exists.")
		return false
	end

	return service:Request(Command.S_TEAM_GET_PLAYER_AI_RATIO_REQUEST, 0, {targets = targets})
end

function Vote(id, candidate, agree)
	local service = GetAndCheckService("Map")

	if not service then
		log.error("Map service not exists.")
		return false
	end

	return service:Notify(Command.S_TEAM_VOTE_REQUEST, 0, {pid = id, candidate = candidate, agree = agree})
end

function ConfirmJoinRequest(id, pid)
	local service = GetAndCheckService("Map")

	if not service then
		log.error("Map service not exists.")
		return false
	end

	return service:Notify(Command.S_TEAM_JOIN_CONFIRM_REQUEST, 0, {opt_id = id, pid = pid})

end

function QueryPlayerProperty(id, types)
	local service = GetAndCheckService("Quiz")

	if not service then
		log.error("Quiz service not exists.")
		return false
	end

	return service:Request(Command.S_PLAYERPROPERTY_QUERY_REQUEST, 0, {pid = id, types = types})
end

function ModifyPlayerProperty(id, type, tab)
	local service = GetAndCheckService("Quiz")

	if not service then
		log.error("Quiz service not exists.")
		return false
	end

	return service:Request(Command.S_PLAYERPROPERTY_MODIFY_REQUEST, 0, {pid = id, typa = type, tab = tab})
end
