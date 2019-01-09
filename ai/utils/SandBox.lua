-- assert(setfenv == nil, "need lua version >= 5.2")

local ThreadCounter = {};
function ThreadCounter.New(count) 
	return setmetatable({count = count or 0, main = coroutine.running()}, {__index=ThreadCounter});
end

function ThreadCounter:Retain()
	self.count = self.count + 1;
end

function ThreadCounter:Release(force)
	local co = coroutine.running();
	self.count = self.count - 1;
	if force or self.count <= 0 then
		if co == self.main then
			return;
		else
			local success, info = coroutine.resume(self.main);
			if not success then
				ERROR_LOG(info, debug.traceback());
			end
		end
	else
		if co == self.main then
			coroutine.yield();
		end
	end
end

local __api_count = 0;

local function ScriptEnv(game, role)
	return setmetatable({
		game = game,
		attacker = role,

		table = table,
		math  = math,
		string = string,
		ipairs = ipairs,
		pairs = pairs,
		tonumber = tonumber,
		tostring = tostring,
		type = type,
		unpack = table.unpack or unpack,
		select = select,
		next = next,
		assert = assert,

		ERROR_LOG = ERROR_LOG or print,
		WARNING_LOG = WARNING_LOG or print,
	}, {__index = function(t, k)
		local v = game['API_' .. k];
		if not v then return end;
		
		__api_count = __api_count + 1;
		assert(__api_count < 1000, "too much api [" .. k .. "] call in one script") -- .. debug.traceback());

		if type(v) == "function" then
			return setmetatable({}, {__call=function(_, ...)
				return (v(game, role, ...));
			end})
		else
			return v;
		end
	end});
end


local SandBox = {}

function SandBox.New(fileName, game, role, importValues)
	local __importValues = ScriptEnv(game, role);
	for k, v in ipairs(importValues or {}) do
		rawset(__importValues, k, v);
	end

	local env = {__importValues = __importValues or {}, _cos = {}};

	if UnityEngine and UnityEngine.Application.isEditor then
		env.print = function( ... ) if game and game.DEBUG_LOG then game:DEBUG_LOG("[SandBox]", ...) else   print("[SandBox]", ...) end end
	else
		env.print = function( ... ) end
	end

	env.Run   = function(func, ...)
		local threadCounter = env.__thread_counter;

		threadCounter:Retain();

		local co = coroutine.create(function()
			func();
			threadCounter:Release();
		end);

		-- save coroutine to avoid gc
		local idx = #env._cos + 1;
		table.insert(env._cos, co);

		local success, info = coroutine.resume(co, ...);
		if not success then
			ERROR_LOG(info, debug.traceback());
			threadCounter:Release();
		end

		-- remove from coroutine list
		env._cos[idx] = nil;
	end


	local chunk, info = loadfile(fileName, "bt", env);
	if chunk == nil then
		ERROR_LOG(info);
		chunk = function() ERROR_LOG("script error", fileName, info) end
	end

	if setfenv then
		setfenv(chunk, env)
	end

	env.__chunk = chunk;
	env.__thread_counter = nil;
	env.__file = fileName;

	return setmetatable(env, {__index = function(t, k)
		return SandBox[k] and SandBox[k] or t.__importValues[k];
	end})
end

local scriptLibrary = {}

function SandBox:LoadLib(scriptFileName)
	local script;
	if SGK then
		script = scriptLibrary[scriptFileName] or SGK.FileUtils.LoadStringFromFile(scriptFileName);
		assert(load(script, scriptFileName, 'bt', self))();
	else
	    assert(loadfile(scriptFileName, 'bt', self))();
	end
end

function SandBox:Detach()
	self.__thread_counter:Release(true);
end

function SandBox:Call(...)
	self.__thread_counter = ThreadCounter.New(1);

	__api_count = 0;

	local success, v1, v2, v3 = pcall(self.__chunk, ...);
	if not success then
		ERROR_LOG(v1);
	end

	self.__thread_counter:Release();

	if success then
		return v1, v2, v3;
	else
		return false;
	end
end


return {
	New = SandBox.New,
	ThreadCounter = ThreadCounter,
}
