local Command = require "Command"
local XMLConfig = require "XMLConfig"
local ServiceManager = require "ServiceManager"

local ServiceName = { "Arena" }
local listen = {}
for index, name in ipairs(ServiceName) do
	listen[index] = {};
	listen[index].host = XMLConfig.Social[name].host
	listen[index].port = XMLConfig.Social[name].port
	listen[index].name = name
end

local service = ServiceManager.New("ArenaInfo", unpack(listen))
if service == nil then
	log.error("connect to Arena service failed.")
	loop.exit()
	return
end

service:RegisterCommands({
	{Command.S_GET_RANKLIST_REQUEST, "ArenaGetRankListRequest"},
	{Command.S_GET_RANKLIST_RESPOND, "ArenaGetRankListRespond"}
})

-- 获取前n个对象的排名
function getArenaRankList(pid, n)
	if not service:isConnected(pid) then
		log.debug(string.format("getArenaRankList failed: %d disconnected", pid))
		return nil
	end

	local respond = service:Request(Command.S_GET_RANKLIST_REQUEST, 0, { sn = 1, topcnt = n})
	if not respond then
		log.error("getArenaRankList error, respond is nil.")
		return nil
	end

	if respond.result == Command.RET_SUCCESS then
		log.debug("getArenaRankList success.")
		return respond
	else
		log.debug(string.format("getArenaRankList failed, result is %d"), respond.result)
		return nil
	end
end
