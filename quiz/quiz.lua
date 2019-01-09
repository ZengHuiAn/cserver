#!../bin/server 

-- init env --
package.cpath=package.cpath .. ";../lib/?.so";
package.path =package.path  .. ";../lib/?.lua";
math.randomseed(os.time());
math.random();

require "log"
require('yqlog_sys')
require('yqmath')
require "cell"
require "AMF"
require "Command"
--require "protos"
require "NetService"
require "printtb"
require "bit32"
--require "FAMManager"
local DailyQuiz = require "DailyQuiz"
local WeekQuiz = require "WeekQuiz"
local WorldQuiz = require "WorldQuiz"
local groupscore = require "groupscore"
local Backyard = require "Backyard"
local PlayerProperty = require "PlayerProperty"
local RankListManager = require "RankListManager"

-- func --
local function sendClientRespond(conn, cmd, channel, msg)
	assert(conn);
	assert(cmd);
	assert(channel);
	assert(msg and (table.maxn(msg) >= 2));

	local sid = tonumber(bit32.rshift_long(channel, 32))
	assert(sid > 0)
	local code = AMF.encode(msg);
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

local function sendServiceRespond(conn, cmd, channel, protocol, msg)
    local code = encode(protocol, msg);
	local sid = tonumber(bit32.rshift_long(channel, 32))
    if code then
        return conn:sends(2, cmd, channel, sid, code);
    else
        return false;
    end
end

local function onServiceRegister(conn, channel, req)

end

local function onLogin(conn, channel, req)
	
end

local function onLogout(conn, channel, req)

end

local function onFamQueryPlayer(conn, pid, req)
    local sn         = req[1] or 0
    local cmd      = Command.C_FAM_QUERY_PLAYER_RESPOND
    local msg      = {sn, Command.RET_ERROR}
    local instance = FAMManager.Get()
    if not instance then
        msg[2] = Command.RET_DEPEND
        return conn:sendClientRespond(cmd, pid, msg)
    end
    log.info("Begin C_FAM_QUERY_PLAYER_REQUEST", pid)
    local err, resp = instance:QueryPlayer(pid)
    if not err then
        msg[2] = Command.RET_SUCCESS
        msg[3] = resp
    else
        msg[2] = err
    end
    return conn:sendClientRespond(cmd, pid, msg)

end

local function onFamGetQuestion(conn, pid, req)
    local sn         = req[1] or 0
    local pre_request= req[2] or 0
    local cmd      = Command.C_FAM_GET_QUESTION_RESPOND
    local msg      = {sn, Command.RET_ERROR}
    local instance = FAMManager.Get()
    if not instance then
        msg[2] = Command.RET_DEPEND
        return conn:sendClientRespond(cmd, pid, msg)
    end
    log.info("Begin C_FAM_GET_QUESTION_REQUEST", pid, pre_request)
    local err, resp = instance:GetQuestion(pid,pre_request)
    if not err then
        msg[2] = Command.RET_SUCCESS
        msg[3] = resp
    else
        msg[2] = err
    end
    return conn:sendClientRespond(cmd, pid, msg)

end

local function onFamAnswerQuestion(conn, pid, req)
    local sn         = req[1] or 0
    local qid        = req[2]
    local select_num = req[3]
    local answer     = req[4]

    local cmd      = Command.C_FAM_ANSWER_QUESTION_RESPOND
    local msg      = {sn, Command.RET_ERROR}
    local instance = FAMManager.Get()
    if not instance then
        msg[2] = Command.RET_DEPEND
        return conn:sendClientRespond(cmd, pid, msg)
    end
    log.info("Begin C_FAM_ANSWER_QUESTION_REQUEST", pid, qid,select_num,answer)
    local err, resp = instance:AnswerQuestion(pid,qid,select_num,answer)
    if not err then
        msg[2] = Command.RET_SUCCESS
        msg[3] = resp
    else
        msg[2] = err
    end
    return conn:sendClientRespond(cmd, pid, msg)


end

local function onFamQueryTop(conn, pid, req)
    local sn         = req[1] or 0

    local cmd      = Command.C_FAM_QUERY_TOP_RESPOND
    local msg      = {sn, Command.RET_ERROR}
    local instance = FAMManager.Get()
    if not instance then
        msg[2] = Command.RET_DEPEND
        return conn:sendClientRespond(cmd, pid, msg)
    end
    log.info("Begin C_FAM_QUERY_TOP_REQUEST", pid)
    local err, resp = instance:QueryTop()
    if not err then
        msg[2] = Command.RET_SUCCESS
        msg[3] = resp
    else
        msg[2] = err
    end
    return conn:sendClientRespond(cmd, pid, msg)

end

local function onFamReward(conn, pid, req)
    local sn         = req[1] or 0
    local kind, kind_num = req[2], req[3]

    local cmd      = Command.C_FAM_REWARD_RESPOND
    local msg      = {sn, Command.RET_ERROR}
    local instance = FAMManager.Get()
    if not instance then
        msg[2] = Command.RET_DEPEND
        return conn:sendClientRespond(cmd, pid, msg)
    end
    log.info("Begin C_FAM_REWARD_REQUEST", pid)
    local err, reward_table = instance:Reward(pid, kind, kind_num)
    if not err then
        msg[2] = Command.RET_SUCCESS
        msg[3] = reward_table
    else
        msg[2] = err
    end
    return conn:sendClientRespond(cmd, pid, msg)
end

local function onFamBuyAct(conn, pid, req)
    local sn         = req[1] or 0

    local cmd      = Command.C_FAM_BUYACT_RESPOND
    local msg      = {sn, Command.RET_ERROR}
    local instance = FAMManager.Get()
    if not instance then
        msg[2] = Command.RET_DEPEND
        return conn:sendClientRespond(cmd, pid, msg)
    end
    log.info("Begin C_FAM_BUYACT_REQUEST", pid)
    local err = instance:BuyActCount(pid)
    if not err then
        msg[2] = Command.RET_SUCCESS
    else
        msg[2] = err
    end
    return conn:sendClientRespond(cmd, pid, msg)

end

-- 重置玩家答题数量
local function onFamResetAnswerQuestionCount(conn, pid, req)
    local sn = req[1];
    if pid and type(pid) == "number" and pid > 0 then
        local instance = FAMManager.Get()
        local result = instance:Reset(pid);
        return conn:sendClientRespond(Command.S_FAM_RESET_ANSWER_QUESTION_COUNT_RESPOND, pid, {sn, result});
    else
        return conn:sendClientRespond(Command.S_FAM_RESET_ANSWER_QUESTION_COUNT_RESPOND, pid, {sn, Command.RET_ERROR});
    end
end

-- create service --
local cfg = XMLConfig.Social["Quiz"];
service = NetService.New(cfg.port, cfg.host, cfg.name or "Quiz");
assert(service, "listen on " .. cfg.host .. ":" .. cfg.port .. " failed");

-- basic route  --
service:on("accept", function (client)
	client.sendClientRespond = sendClientRespond;
	log.debug(string.format("Service: client %d connected", client.fd));
end);

service:on("close", function(client)
	log.debug(string.format("Service: client %d closed", client.fd));
end);

service:on(Command.C_LOGIN_REQUEST, function(conn, pid, req)
	onLogin(conn, channel, req)
end);

service:on(Command.C_LOGOUT_REQUEST, function(conn, pid, req)
	onLogout(conn, channel, req)
end);

service:on(Command.S_SERVICE_REGISTER_REQUEST,  onServiceRegister)

--[[for fam game]]
DailyQuiz.RegisterCommand(service)

WeekQuiz.RegisterCommand(service)

WorldQuiz.RegisterCommand(service)

groupscore.RegisterCommand(service)

Backyard.RegisterCommand(service)

PlayerProperty.RegisterCommand(service)

RankListManager.RegisterCommand(service)
