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

local Command = require "Command"

local ServiceManager = require "ServiceManager"
local XMLConfig = require "XMLConfig"
local EventManager = require "EventManager"

local AMF=require "AMF"
local protobuf=require "protobuf"

--------------------------------------------------------
local ServiceName = {"Guild"};
local listen = {};
for idx, name in ipairs(ServiceName) do
    listen[idx] = {};
    listen[idx].host = XMLConfig.Social[name].host;
    listen[idx].port = XMLConfig.Social[name].port;
    listen[idx].name = name;
end

local service = ServiceManager.New("GuildInfo", unpack(listen));
if service == nil then
	log.error("connect to guild service failed");
	loop.exit();
	return;
end

service:RegisterCommands({
	{Command.S_GUILD_QUERY_BUILDING_LEVEL_REQUEST,"GuildQueryBuildingLevelRequest"},
	{Command.S_GUILD_QUERY_BUILDING_LEVEL_RESPOND,"GuildQueryBuildingLevelRespond"},
	{Command.S_GUILD_QUERY_BY_PLAYER_REQUEST, "GuildQueryByPlayerRequest"},
	{Command.S_GUILD_QUERY_BY_PLAYER_RESPOND, "GuildQueryByPlayerRespond"},
});

function GetGuildBuildingLevel(pid, building_type)
	if service:isConnected(pid) then
		local respond = service:Request(Command.S_GUILD_QUERY_BUILDING_LEVEL_REQUEST, 0, {playerid = pid, building_type = building_type})
		if not respond then
			log.error(string.format("GetGuildBuildingLevel error, respond is nil"))
			return nil
		end
		if respond.result ~= 0 then
			log.error(string.format("GetGuildBuildingLevel error, errno %d", respond.result))
			return nil
		end

		return respond
	else
        log.debug(string.format("`%d` fail to call GetGuildBuildingLevel, disconnected", pid))
		return nil
	end
end

function GetPlayerGuildInfo(pid)
	if not service:isConnected(pid) then
		log.debug(string.format("GetGuildInfo failed: %d disconnected.", pid))
		return nil	
	end
	local respond = service:Request(Command.S_GUILD_QUERY_BY_PLAYER_REQUEST, 0, { playerid = pid })
	if not respond then
		log.error("GetGuildInfo error: respond is nil.")
		return nil
	end
	if respond.result == 0 then
		log.debug("GetGuildInfo success.")
		return respond
	else
		log.debug(string.format("GetGuildInfo failed: result is %d", respond.result))
		return nil
	end
end
