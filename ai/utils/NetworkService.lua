require "network";

local c = network;
local max_package_pre_tick = 20;
local conn = nil;

local coroutines = {};

local function Tick()
	if conn == nil then
		return;
	end

	for i = 1, max_package_pre_tick do
		local cmd, pkg = conn:read()
		if not cmd then
			break;
		end

		if pkg and pkg[2] ~= 0 then
			ERROR_LOG("server error", cmd, sprinttb(pkg));
		end

		if cmd == 104 then
			DispatchEvent("server_notify_start");
			for idx = 3, #pkg do
				local notify = pkg[idx];
				local type = notify[1];
				local data = notify[2];
				DispatchEvent("server_notify_" .. type, type, data);
			end
			DispatchEvent("server_notify_end");
		else
			-- print("server_respond_"..cmd);
			DispatchEvent("server_respond_" .. cmd, cmd, pkg);
		end

		if pkg then
			local sn = pkg[1] or pkg.sn;
			if sn and coroutines[sn] then
				local co = coroutines[sn]
				coroutines[sn] = nil;
				print("finished sync request", co, coroutine.status(co), pkg, cmd)
				print("", coroutine, coroutine.resume);
				assert(coroutine.resume(co, pkg, cmd));
			end
		end

		if cmd == "closed" then
			conn = nil;
			break;
		end
	end
end

local function Connect(host, port)
	if conn then
		conn:close()
		conn = nil;
	end
	print("connect", host, port)
	conn = c.open(host, port)
end

local nextSN = 0;
function createSerialNubmer()
    nextSN = nextSN + 1;
    return nextSN;
end

local function Send(cmd, data)
	if conn then
		data = data or {};
		local sn = data[1] or data["sn"] or nil;
		if sn == nil then
			sn = createSerialNubmer();
			data[1] = sn;
		end
		print("send cmd:", cmd, "package: [", data and unpack(data) or '', "]");
		conn:write(cmd, data)
		return sn;
	end
	return false;
end

local will_stop = false;

CS.SGK.CoroutineService.Schedule(Tick)

local EventManager = require 'utils.EventManager';
EventManager.getInstance():addListener('UNITY_OnApplicationQuit', function() 
	if conn then
		print("UNITY_OnApplicationQuit");
		will_stop = true;
		print("netwok stoped")
		conn:close()
		conn = nil;
	end
end)


local function SyncRequest(cmd, data)
	local co = coroutine.running();

	if co == nil or (coroutine.isyieldable and not coroutine.isyieldable()) then
		assert(false, "can't call SyncRequest in main thread");
	end

	print("start sync request", co)

	local sn = Send(cmd, data);
	coroutines[sn] = co;
	return coroutine.yield();
end

local function QueueRequest(cmd, data)
	return Send(cmd, data);
end

return {
	Connect = Connect,
	Send = Send,
	SyncRequest = SyncRequest,
	QueueRequest = QueueRequest,
}
