#!../bin/server 

-- init env --
package.cpath=package.cpath .. ";../lib/?.so";
package.path =package.path  .. ";../lib/?.lua";
math.randomseed(os.time());
math.random();

g_cache ={}
local sn = 1;
-- func util --
function str_split(str, pattern)
	local arr ={}
	while true do
		if #str==0 then
			return arr
		end
		local pos,last =string.find(str, pattern)
		if not pos then
			table.insert(arr, str)
			return arr
		end
		if pos>1 then
			table.insert(arr, string.sub(str, 1, pos-1))
		end
		if last<#str then
			str =string.sub(str, last+1, -1)
		else
			return arr
		end
	end
end

function str2time(str)
	local tok_list =str_split(str, '[:%- ]')	
	if #tok_list==6 then
		local dt ={
			year =tonumber(tok_list[1]),
			month =tonumber(tok_list[2]),
			day =tonumber(tok_list[3]),
			hour =tonumber(tok_list[4]),
			min =tonumber(tok_list[5]),
			sec =tonumber(tok_list[6]),
		};
		if dt.year==0 and dt.month==0 and dt.day==0 and dt.hour==0 and dt.min==0 and dt.sec==0 then
			return 0
		end
		return os.time(dt)
	end
	return 0
end

require "consume_config"
BuyConfig =ConsumeConfig.Buy
--[[for k, v in pairs(BuyConfig) do
	if not v.Offset then
		v.Offset = 5*3600
	else
		v.Offset = str2time(v.Offset)
	end	
end
--]]
-- dependence module --
require "XMLConfig"
require ("database")
require "log"
require('yqlog_sys')
require('yqmath')
require "cell"
require "AMF"
require "Command"
--require "protos"
require "NetService"
require "printtb"
require "buy"
require "bit32"
require "gift_bag"
require "Sweepstake"
require "SweepstakeConfig"
require "SweepstakePlayerManager"
require "SweepstakeRankManager"
require "SweepstakeRewardConfig"
local Trade = require "Trade"


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

local function exchange(conn, pid, consume, reward, reason, drops)
	             -- sendReward(pid, reward, consume, reason, manual, limit, name, drops, heros, first_time)
	local ret =cell.sendReward(pid, reward, consume, reason, nil,    nil,   nil,  drops)
	if type(ret)=='table' then
		if ret.result== Command.RET_SUCCESS then
			return true
		else
			if ret.result== Command.RET_NOT_ENOUGH then
				return false, Command.RET_NOT_ENOUGH
			else
				return false, Command.RET_ERROR
			end
		end
	else 
		return false, Command.RET_ERROR
	end
end

function key_visiable(k)
	return type(k)=='number' or (type(k)=='string' and #k>0 and string.sub(k, 1, 1)~='_' and string.sub(k, -1)~='_')
end

function isstring(k)
	return type(k)=='string'
end

function isnumber(k)
	return type(k)=='number'
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

function get_player_cache(pid)
	g_cache[pid] =g_cache[pid] or {
		buy ={},
		lucky_draw ={
			history ={},
            info = {},
		}
	};
	return g_cache[pid]
end

function clean_player_cache(pid)
	g_cache[pid] =nil
end

-- create service --
local cfg = XMLConfig.Social["Consume"];
service = NetService.New(cfg.port, cfg.host, cfg.name or "Consume");
assert(service, "listen on " .. cfg.host .. ":" .. cfg.port .. " failed");

-- basic route  --
service:on("accept", function (client)
	client.sendClientRespond = sendClientRespond;
	client.exchange= exchange;
	log.debug(string.format("Service: client %d connected", client.fd));
end);

service:on("close", function(client)
	log.debug(string.format("Service: client %d closed", client.fd));
end);

service:on(Command.C_LOGIN_REQUEST, function(conn, pid, req)
	get_player_cache(pid)
end);

service:on(Command.C_LOGOUT_REQUEST, function(conn, pid, req)
	clean_player_cache(pid)
end);

-- business route --
-- buy 
service:on(Command.C_BUY, function(conn, pid, req)
	process_buy(conn, pid, req);
end);

service:on(Command.C_BUY_FOR_GUILD_SHOP, function(conn, pid, req)
	process_buy_for_guild_shop(conn, pid, req);
end);

service:on(Command.C_BUY_FOR_HERO_ITEM, function(conn, pid, req) process_buy_for_hero_item(conn, pid, req); end);

service:on(Command.C_GET_SPECIAL_SHOP, function(conn, pid, req)
	process_get_special_shop(conn, pid, req);
end);

service:on(Command.C_GET_VALID_TIME, function(conn, pid, req)
	process_get_valid_time(conn, pid, req);
end);

service:on(Command.C_FRESH_SPECIAL_SHOP, function(conn, pid, req)
	process_fresh_special_shop(conn, pid, req);
end);

--service:on(Command.C_GET_BUY_HISTORY, function(conn,pid,req)
--	process_get_buy_history(conn,pid,req);
--end);

-- gift bag
service:on(Command.C_OPEN_GIFT_BAG, function(conn, pid, req)
    process_open_gift_bag(conn, pid, req);
end);
service:on(Command.C_GET_GIFT_BAG, function(conn, pid, req)
    process_get_gift_bag(conn, pid, req);
end);
service:on(Command.C_GET_OPEN_GIFT_BAG_HISTORY, function(conn, pid, req)
    process_get_open_gift_bag_history(conn, pid, req);
end);

--sweepstake
service:on(Command.C_SWEEPSTAKE_REQUEST, function(conn, pid, req)
    process_sweepstake(conn, pid, req);
end);

service:on(Command.C_QUERY_SWEEPSTAKE_CONFIG_REQUEST, function(conn, pid, req)
    SweepstakeConfig.process_query_sweepstake_config(conn, pid, req);
end);

service:on(Command.C_QUERY_SWEEPSTAKE_PLAYER_INFO_REQUEST, function(conn, pid, req)
    SweepstakePlayerManager.process_query_sweepstake_player_info(conn, pid, req);
end);

service:on(Command.C_QUERY_SWEEPSTAKE_RANKLIST_REQUEST, function(conn, pid, req)
    SweepstakeRankManager.process_query_ranklist(conn, pid, req);
end);

service:on(Command.C_QUERY_SWEEPSTAKE_SCORE_REQUEST, function(conn, pid, req)
    SweepstakeRankManager.process_query_rankscore(conn, pid, req);
end);

service:on(Command.C_QUERY_SWEEPSTAKE_FINAL_REWARD_CONFIG_REQUEST, function(conn, pid, req)
    SweepstakeRewardConfig.process_query_final_reward_config(conn, pid, req);
end);

service:on(Command.C_QUERY_SWEEPSTAKE_SCORE_REWARD_CONFIG_REQUEST, function(conn, pid, req)
    SweepstakeRewardConfig.process_query_score_reward_config(conn, pid, req);
end);

service:on(Command.C_ACHIEVE_SWEEPSTAKE_SCORE_REWARD_REQUEST, function(conn, pid, req)
    SweepstakeRankManager.process_achieve_reward(conn, pid, req);
end);

service:on(Command.C_SWEEPSTAKE_CHANGE_POOL_REQUEST, function(conn, pid, req)
    process_change_pool(conn, pid, req);
end);

service:on(Command.C_SWEEPSTAKE_CHANGE_POOL_AND_SWEEPSTAKE_REQUEST, function(conn, pid, req)
	process_change_pool_and_sweepstake(conn, pid, req)
end)

local function onLogin(conn, channel, request)
    SweepstakeRankManager.Login(channel);
end

local function onLogout(conn, channel, request)
    SweepstakeRankManager.Logout(channel);
end

local function onServiceRegister(conn, channel, request)
    if request.type == "GATEWAY" then
        for k, v in pairs(request.players) do
            -- print(k, v);
            onLogin(conn, v, nil)
        end
    end
end

service:on(Command.C_LOGIN_REQUEST,         onLogin);
service:on(Command.C_LOGOUT_REQUEST,        onLogout);
service:on(Command.S_SERVICE_REGISTER_REQUEST,  onServiceRegister);

Trade.RegisterCommand(service)
