local loop = loop;
local string = string;
local ipairs = ipairs;
local pairs = pairs;
local table = table;
local print = print;
local os = os;
local type = type;
local next = next;

local database = require "database"
local NetService = require "NetService"
local Class = require "Class"
local Command = require "Command"
local Scheduler = require "Scheduler"
local util = require "util"

-- DEBUG ==================
require "Debug"
local ps = ps;
local pe = pe;
local pm = pm;
local pr = pr;
local debugOn = debugOn;
local debugOff = debugOff;
local dumpObj = dumpObj;
debugOn(true);
--debugOff();
-- ================== DEBUG

module "TimingNotifyManager"

local AllMsg = {};
local _now = os.time();
loadSuccess = false;

function Add(start, duration, interval, type, msg, gm_id)
	local lastTime = start - interval;
	local success, result = 
		database.update(
			"INSERT INTO TIMING_NOTIFY(`START`, `LAST_TIME`, `DURATION`, `INTERVAL`, `TYPE`, `MSG`, `GM_ID`) VALUES(%u, %u, %u, %u, %u, '%s', %u)",
			start, lastTime, duration, interval, type, util.encode_quated_string(msg), gm_id or 0);
	if success then
		local id = database.last_id();
		AllMsg[id] = {
				start = start,
				lastTime = lastTime,
				duration = duration,
				interval = interval,
				type = type,
				msg = msg,
				gm_id = gm_id or 0
			};
		return id;
	else
		return nil;
	end
end

function Delete(id, gm_id)
	local success
	if gm_id then 
		local index = 0
		for i, v in pairs(AllMsg) do
			if v.gm_id == gm_id then
				AllMsg[i] = nil
				index = i
				break
			end
		end
		success = database.update("UPDATE TIMING_NOTIFY SET EXPIRE = 1 WHERE ID = %u", index);
	else
		AllMsg[id] = nil;
		success = database.update("UPDATE TIMING_NOTIFY SET EXPIRE = 1 WHERE ID = %u", id);
	end

	if success then
		return id;
	else
		return nil;
	end
end

function Query()
	return AllMsg;
end

function LoadNotify(playerId)
	for k, v in pairs(AllMsg) do
		if v.type >= 1 then
			NetService.NotifyClients(Command.NOTIFY_DISPLAY_MESSAGE, {v.type, v.msg}, {playerId});
		end
	end
end

Scheduler.Register(function(now)
	_now = now;
	
	for k, v in pairs(AllMsg) do
		if _now >= v.lastTime + v.interval then
			if 0 == v.lastTime or v.type >= 1 then
				NetService.NotifyClients(Command.NOTIFY_DISPLAY_MESSAGE, {v.type, v.msg});
			end
			v.lastTime = _now;
			database.update("UPDATE TIMING_NOTIFY SET LAST_TIME = %u WHERE ID = %u", v.lastTime, k);
		end
		if _now > v.start + v.duration then
			Delete(k);
		end
	end
end);

function onLoad()
	local success, TIMING_NOTIFY = database.query(
		"SELECT ID, START, LAST_TIME, DURATION, `INTERVAL`, `TYPE`, MSG, EXPIRE, GM_ID FROM TIMING_NOTIFY");
	if success and "table" == type(TIMING_NOTIFY) then
		for _, row in pairs(TIMING_NOTIFY) do
			if 0 == row.EXPIRE and _now <= row.START + row.DURATION then
				AllMsg[row.ID] = {
						start = row.START,
						lastTime = row.LAST_TIME,
						duration = row.DURATION,
						interval = row.INTERVAL,
						type = row.TYPE,
						msg = row.MSG,
						gm_id = row.GM_ID
					};
			end
		end
	end
	loadSuccess = success;
end

function onUnload()
end
