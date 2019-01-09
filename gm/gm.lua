package.cpath = package.cpath .. ";../lib/?.so"
package.path = package.path .. ";../lib/?.lua"

require "NetService"
require "Command"
require "printtb"
require "ArenaInfo"
require "MailReward"
require "AMF"
require "bit32"
require "protobuf"
require "GuildInfo"
require "SocialManager"
local json = require "json"
local cell = require "cell"
local linelog = require "linelog"
local XMLConfig = require "XMLConfig"
local util = require "util"

local RET_CODE = {
	SUCCESS 		= 0, 		-- 成功
	PARAM_ERROR 		= 10001,	-- 参数错误
	SIGN_ERROR		= 10002,	-- 签名错误
	BAN_FAILED		= 10003,	-- 禁言/封号/踢下线失败
	RELEASE_FAILED		= 10004,	-- 解除处罚失败
	RECHARGE_LOG_FAILED	= 10005,	-- 充值记录补发失败
	PUNISH_NOTICE_FAILED	= 10006,	-- 发布公告失败
	SEND_MAIL_FAILED	= 10007,	-- 发放邮件失败
	RECHARGE_FAILED		= 10008,	-- 内部充值失败
	BUSY			= 10009,	-- 内部繁忙
}

-------------------------- 存储玩家信息 -----------------------------
local PlayerMap = { map = {} }
function PlayerMap.Login(pid)
	if PlayerMap.map[pid] == nil then	
		PlayerMap.map[pid] = { is_online = true }
	else
		PlayerMap.map[pid].is_online = true
	end
end

function PlayerMap.Logout(pid)
	if PlayerMap.map[pid] then
		PlayerMap.map[pid].is_online = false
	end
end

function PlayerMap.Online(pid)
	if PlayerMap.map[pid] and PlayerMap.map[pid].is_online then
		return true	
	end
	return false
end

----------------------------------------------------------------------
local function encode(protocol, msg)
	local code = protobuf.encode("com.agame.protocol." .. protocol, msg);
	if code == nil then
		print(string.format(" * encode %s failed", protocol));		
		return nil;
	end
	return code;
end

local function sendServiceRespond(conn, cmd, channel, protocol, msg)
	local code = encode(protocol, msg)
	local sid = tonumber(bit32.rshift_long(channel, 32))
	if code then
		return conn:sends(2, cmd, channel, sid, code);
	else
		return false;
	end
end

local function removeEndDot(str)
	local n = string.len(str) 	
	local sub = string.sub(str, n)	
	if sub == "," then
		return string.sub(str, 1, string.len(str) - 1)
	else
		return str
	end
end

local function split(str, deli)
	local start_index = 1	
	local n = 1
	local ret = {}

	while true do
		local end_index = string.find(str, deli, start_index)
		if not end_index then
			ret[n] = string.sub(str, start_index, string.len(str))
			break
		end
		ret[n] = string.sub(str, start_index, end_index - 1)
		n = n + 1
		start_index = end_index + string.len(deli)
	end	

	return ret
end

local function to_number(t)
	local ret = {}	
	for _, v in ipairs(t or {}) do
		table.insert(ret, tonumber(v) or 0)	
	end

	return ret
end

-- convert table to json string with "{" as border
local function toJsonStr(t)
	if t == nil then
		return ""
	end
	local str = ""
	-- array
	if #t > 0 then						
		str = str .. "["
		for i = 1, #t do 
			if type(t[i]) == "table" then
				str = str .. toJsonStr(t[i]) .. ","
			elseif type(t[i]) == "number" then
				str = str .. t[i] .. ","
			elseif type(t[i]) == "string" then
				str = str .. "\"" .. t[i] .. "\"" .. ","
			elseif type(t[i]) == "boolean" then
				local value = t[i] and "true" or "false"
				str = str .. value .. ","
			end
		end
		str = removeEndDot(str)
		str = str .. "]"
	-- map
	else		
		str = str .. "{"
		for k, v in pairs(t) do
			if type(k) == "string" then
				str = str .. "\"" .. k .. "\"" .. ": "
				if type(v) == "table" then
					str = str .. toJsonStr(v) .. ","
				elseif type(v) == "number" then
					str = str .. v .. ","	
				elseif type(v) == "string" then	
					str = str .. "\"" .. v .. "\"" .. ","
				elseif type(v) == "boolean" then
					local value = v and "true" or "false"
					str = str .. value .. ","
				end
			end
		end
		str = removeEndDot(str)
		str = str .. "}"
	end
	return str
end

------------------------------------------------------------------

-- 设置玩家状态(禁言和封号)
-- @status 0为正常，1为封号，2为禁言
local function setPlayerStatus(pid, status)
	assert(pid)
	assert(status)
	local flag, err = cell.setPlayerStatus(pid, status)
	local ret = {}
	if flag then
		ret.code = RET_CODE.SUCCESS
		ret.msg = "success"	
	else
		log.warning(string.format("set status failed: %s", err))
		ret.code = RET_CODE.BAN_FAILED
		ret.msg = err
	end
	return ret
end

-- 查询处罚信息
local function getPunishmentInfo(pid)
	assert(pid)
	local info = cell.getPlayerInfo(pid)
	local ret = {}
	if info then
		ret.roleId = info.id
		ret.roleName = info.name
		ret.serverId = XMLConfig.ServerId
		-- ret.serverName = 	
		ret.roleStatus = info.status	
		if ret.roleStatus == 1 then
			ret.roleStatus = 2
		elseif ret.roleStatus == 2 then
			ret.roleStatus = 1
		end
	end
	return ret
end 

-- 查询玩家信息
local function getPlayerInfo(pid)	
	assert(pid)
	local info = cell.getPlayerInfo(pid)
	local guildInfo = GetPlayerGuildInfo(pid)
	local ret = {}
	if info and guildInfo then
		ret.roleId = info.id
		ret.roleName = info.name
		ret.roleRank = info.level
		ret.roleType = info.sex
		-- ret.channelName   渠道名称
		ret.isOnline = PlayerMap.Online(pid)
		ret.lastLoginTime = info.login
		ret.vipRank = info.vip
		-- ret.sumPaidMoney 累计充值
		ret.lastDiamond = info.count
		ret.gameUnion = guildInfo.guild.name
		ret.regTime = info.create
	else
		log.debug("get player info failed.")
	end
	return ret
end

-- 查询登录记录
local function getLoginInfo(pid)
	assert(pid)
	local info = cell.getPlayerInfo(pid)
	local ret = {}
	if info then
		--  ret.serverName 服务器名称
		ret.roleId = info.id
		ret.roleName = info.name
		-- ret.channelName 渠道名称
		-- ret.loginType  登录类型
		ret.time = info.login
		ret.ip = info.ip
	else
		log.debug("login and logout record not exist.")
	end
	return ret
end

-- 查询聊天记录
--[[local function getChatRecord()
	local record = getChatRecordMessageByPid()	
	local ret = {}
	if record and #record > 0 then
		for i, v in ipairs(record) do
			local temp = {
				roleId = v.pid,
				roleName = v.name,
				time = v.time,
				content = v.message
			}
			table.insert(ret, temp)
		end
	end
	return ret
end--]]

-- 查询邮件记录
local function getMailRecord(pid, begintime, endtime)
	local mails = getMail(pid)
	local ret = {}
	if mails then
		for i, v in ipairs(mails) do
			if v.time >= begintime and v.time <= endtime then
				local temp = {
					mailId = v.id,
					roleId = v.from.id,
					serverId = XMLConfig.ServerId,
					status = v.status,
				}
				table.insert(ret, temp)	
			end
		end
	end
	return ret	
end

-- 增加财力值
local function addWealth(pid, wealth)
	local filename = "../log/enable_reward_from_client"
	if not util.file_exist(filename) then
		log.debug(filename .. "not exist")
		return RET_CODE.RECHARGE_FAILED, filename .. " not exist"
	end

	local respond = SocialManager.AddWealth(pid, wealth)
	if respond and respond.result == 0 then
		return RET_CODE.SUCCESS, "success"
	else
		return RET_CODE.RECHARGE_FAILED, "inner add wealth error"
	end
end

------------------------------------------------------------------------
local cfg = XMLConfig.Social["Gm"]
local service = {}
service = NetService.New(cfg.port, cfg.host, cfg.name or "Gm")
assert(service, "listen on " .. cfg.host .. ":" .. cfg.port .. "failed.")

-- register client connect callback
service:on("accept", function (client)
	log.debug(string.format("Service: client %d connected.", client.fd))
end)

-- register client close callback
service:on("close", function (client)
	log.debug(string.format("Service: client %d closed.", client.fd))
end)

-- register client login callback
service:on(Command.C_LOGIN_REQUEST, function (conn, pid, request)
	log.debug(string.format("Service: player %d login.", pid))
	PlayerMap.Login(pid)
end)

-- register client logout callback
service:on(Command.C_LOGOUT_REQUEST, function (conn, pid, request)
	log.debug(string.format("Service: player %d logout.", pid))
	PlayerMap.Logout(pid)	
end)

-- 处理请求
service:on(Command.GM_INTERFACE_REQUEST, "GMRequest", function (conn, pid, request)	
	assert(pid == 0)
	local cmd = Command.GM_INTERFACE_RESPOND  
	local protoc = "GMRespond"
	local sn = request.sn or 0
	local command = request.command
	local req, err = json.toTable(request.json)
	if err ~= nil then
		log.warning(string.format("gm: %s.", err))
		sendServiceRespond(conn, cmd, pid, protoc, { code = Command.RET_ERROR, msg = "json format error" })
	end

	local ret = {}
	if command == "forbidden" then					-- 封号和禁言
		if req.type == 1 then
			req.type = 2
			ret = setPlayerStatus(req.roleId, req.type or 0)		
		elseif req.type == 2 then
			req.type = 1
			ret = setPlayerStatus(req.roleId, req.type or 0)		
		elseif req.type == 3 then
			local code = cell.KickPlayer(req.roleId)
			if code and code == 0 then
				ret.code = RET_CODE.SUCCESS
				ret.msg = "success" 
			elseif code and code == Command.RET_PREMISSIONS then
				ret.code = RET_CODE.BAN_FAILED
				ret.msg = "permission deny" 	
			else
				ret.code = RET_CODE.BAN_FAILED
				ret.msg = "inner error"
			end 
		end	
	elseif command == "relieve" then				-- 解除惩罚
		ret = setPlayerStatus(req.roleId, 0)	
	elseif command == "info" then					-- 查询玩家信息
		ret = getPlayerInfo(req.roleId)	
	elseif command == "punishinfo" then				-- 查询处罚
		ret = getPunishmentInfo(req.roleId)
	elseif command == "logininfo" then				-- 查询登录信息
		ret = getLoginInfo(req.roleId)
	elseif command == "mail" then					-- 发放邮件
		local pids = to_number(split(req.roleIds, ";"))
		local appendix = {}
		local list = split(req.items, ",")
		for _, v in ipairs(list) do
			local t = split(v, ":")	
			table.insert(appendix, { type = 41, id = tonumber(t[1]), value = tonumber(t[3]) })
		end			
		local code = send_multi_mail(Command.MAIL_TYPE_SYSTEM, 0, pids, req.title, req.content, appendix)
		if code and code.result == 0 then
			ret.code = RET_CODE.SUCCESS
			ret.msg = "success"
		else
			log.warning("send mail failed.")
			ret.code = RET_CODE.SEND_MAIL_FAILED	 
			ret.msg = "inner error"
		end		
	elseif command == "notice" then					-- 流水灯管理
		if req.isPublish == 1 then	
			local code = AddTimingNotify(req.startTime, req.endTime - req.startTime, req.rollInterval, 0, req.content, req.noticeId)
			if code and code.result then
				ret.code = RET_CODE.SUCCESS
				ret.msg = "success"
			else
				ret.code = RET_CODE.PUNISH_NOTICE_FAILED
				ret.code = "inner error"
			end
		elseif req.isPublish == -1 then
			local code = DelTimingNotify(0, req.noticeId)	
			if code and code.result then
				ret.code = RET_CODE.SUCCESS
				ret.msg = "success"
			else
				ret.code = RET_CODE.PUNISH_NOTICE_FAILED
				ret.msg = "inner error"
			end
		else
			log.warning("unknown notice, isPublish is ", req.isPublish)	
			ret.code = RET_CODE.PUNISH_NOTICE_FAILED
			ret.msg = "the request is unknown"
		end
	elseif command == "reward" then					-- send reward
		local code = cell.sendReward(req.pid, req.reward, req.consume)
		if code and code.result == 0 then
			ret.code = RET_CODE.SUCCESS
			ret.msg = "success"
		else
			log.warning("send reward failed.")
			log.debug(sprinttb(req))
			ret.code = Command.RET_ERROR 
			ret.msg = "send reward failed"
		end
	elseif command == "wealth" then					-- 增加财力值
		ret.code, ret.msg = addWealth(pid, req.wealth or 0)	
	end
	log.debug("gm: ---------------------------")
	log.debug(sprinttb(ret))
	local respond = {}
	respond.sn = sn
	respond.result = ret.code or RET_CODE.SUCCESS 
	respond.json = toJsonStr(ret)

	sendServiceRespond(conn, cmd, pid, protoc, respond)
end)		
