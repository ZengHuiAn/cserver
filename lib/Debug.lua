

local debugStack = {};
local debugSwitch = false;
local singleUserTest = true;

local function out(msg, warning)
	if 0 == warning then
		log.info(msg);
	elseif 1 == warning then
		log.info(msg);
	elseif 2 == warning then
		log.warning(msg);
	end
end

local function toStr(v)
	if type(v) == "string" then
		v = "\"" .. v .. "\"";
	elseif type(v) == "number" then
		v = tostring(v);
	elseif type(v) == "nil" then
		v = "nil";
	elseif type(v) == "function()" then
		v = "function";
	elseif type(v) == "boolean" then
		if v then
			v = "TRuE";
		else
			v = "FALsE";
		end
	elseif type(v) ~= "table" then
		v = type(v) .. "-TYPE";
	end
	return v;
end

function debugOn(isSingleUser)
	debugSwitch = true;
	singleUserTest = isSingleUser;
end

function debugOff()
	debugSwitch = false;
end

function dumpObj(t, prefix, warning, stackLevel)
	if prefix and "string" ~= type(prefix) then
		out("type(prefix) is \"" .. type(prefix) .. "\"", 2);
		return;
	end
	prefix = prefix or "";
	if not warning then
		warning = 0;
	end
	local follow = (-1 == warning);
	if debugSwitch ~= true and not follow and prefix then
		return;
	end
	t = toStr(t);
	if type(t) ~= "table" then
		if not follow then
			out(string.format("%s	%s", prefix, tostring(t)), warning);
			return;
		else
			return string.format("%s", tostring(t));
		end
	end
	local debugMsg = "[";
	for k, v in pairs(t) do
		local detail = "<" .. tostring(k) .. ">";
		if type(v) == "table" then
			if not stackLevel then
				stackLevel = 1;
			end
			local dump;
			if stackLevel < 10 then
				dump = dumpObj(v, "", -1, stackLevel + 1);
			else
				dump = " ...... ]";
			end
			dump = detail .. dump;
			if debugMsg == "[" then
				debugMsg = debugMsg .. dump;
			else
				debugMsg = debugMsg .. ", " .. dump;
			end
		else
			v = toStr(v);
			v = detail .. v;
			if debugMsg == "[" then
				debugMsg = debugMsg .. v;
			else
				debugMsg = debugMsg .. ", " .. v;
			end
		end
	end
	if not follow then
		local message = prefix .. "	" .. debugMsg .. "]";
		out(message, warning);
	else
		return debugMsg .. "]";
	end
end

function p(...)
	dumpObj({...}, "\n");
end

function ps(funcName, id, parameters)
	if debugSwitch ~= true then
		return;
	end
	prefix = "[" .. funcName .. "]";
	if not singleUserTest then
		if id then
			prefix = prefix .. "[" .. id .. "]";
		end
	else
		local tablemaxn = table.maxn(debugStack) + 1;
		if tablemaxn > 10 then
			tablemaxn = 10;
		end
		debugStack[tablemaxn] = funcName;
		for i = 1, table.maxn(debugStack) do
			prefix = "	" .. prefix;
		end
	end
	if parameters then
		out(prefix .. "START	Parameters:" .. dumpObj(parameters, prefix, -1), 0);
	elseif singleUserTest then
		out(prefix .. "START", 0);
	end
end

function pm(funcName, id, msg, msgTable, warning)
	if debugSwitch ~= true then
		return;
	end
	prefix = "[" .. funcName .. "]";
	if not singleUserTest then
		if id then
			prefix = prefix .. "[" .. id .. "]";
		end
	else
		for i = 1, table.maxn(debugStack) + 1 do
			prefix = "	" .. prefix;
		end
	end
	if not singleUserTest then
		if msg ~= "" then
			if msgTable == nil then
				out(prefix .. msg, 0);
			else
				out(prefix .. msg .. "	" .. dumpObj(msgTable, prefix, -1), 0);
			end
		else
			if msgTable == nil then
				out(prefix, 0);
			else
				dumpObj(msgTable, prefix, 0);
			end
		end
	else
		if msg ~= "" then
			out(prefix .. msg, 0);
		end
		if msgTable ~= nil then
			dumpObj(msgTable, prefix, 0);
		end
	end
end

function pe(funcName)
	if debugSwitch ~= true then
		return;
	end
	prefix = "[" .. funcName .. "]";
	if singleUserTest then
		for i = 1, table.maxn(debugStack) do
			prefix = "	" .. prefix;
		end
		if debugStack[table.maxn(debugStack)] == funcName then
			debugStack[table.maxn(debugStack)] = nil;
		else
			out("Debug error at function:" .. funcName, 1);
		end
		out(prefix .. "END", 0);
	end
end

function pr(funcName, id, rtTable, isError)
	if debugSwitch ~= true then
		return;
	end
	prefix = "[" .. funcName .. "]";
	if not singleUserTest then
		if id then
			prefix = prefix .. "[" .. id .. "]";
		end
	else
		for i = 1, table.maxn(debugStack) + 1 do
			prefix = "	" .. prefix;
		end
	end
	if isError then
		out(prefix .. "ERROR:" .. dumpObj(rtTable, prefix, -1), 2);
	else
		out(prefix .. "RETURN:" .. dumpObj(rtTable, prefix, -1), 0);
	end
	pe(funcName);
end
