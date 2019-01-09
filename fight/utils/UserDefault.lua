local EventManager = require 'utils.EventManager';
local playerModule = require "module.playerModule"

local function dumpValue(t, prefix, suffix)
	prefix = prefix or "";
	suffix = suffix or "";

	local ret = "";

	if t == true or t == false then
		ret = ret .. prefix .. tostring(t) .. suffix;
	elseif type(t) == "table" then
		ret = ret .. "{\n";
		for k, v in pairs(t) do
			if type(v) == "table" then
				ret = ret .. dumpValue(k, prefix .. "  [", "]") .. " = " .. dumpValue(v, prefix .. "  ") .. ",\n";
			else
				ret = ret .. dumpValue(k, prefix .. "  [", "]") .. " = " .. dumpValue(v) .. ",\n";
			end
		end
		ret = ret .. prefix .. "}";
	elseif type(t) == "string" then
		ret = ret .. prefix .. "\"" .. t .. "\"" .. suffix;
	elseif type(t) == "number" then
		ret = ret .. prefix .. t .. suffix;
	else
		ret = ret .. prefix .. "<" .. tostring(t) .. ">" .. suffix;
	end
	return ret;
end


local UserDefault = { values = {}, session = {} }
local UserChat = {values = {}}
function UserDefault.Set(key, value)
	UserDefault.values[key] = value;
	return value;
end

function UserDefault.Get(key)
	return UserDefault.values[key];
end

function UserDefault.LoadSessionData(key, playerData)
	local pid = 0;
	if playerData then
		pid = playerModule.GetSelfID()
		if not pid or pid == 0 then
			return  {};
		end
	end

	UserDefault.session[pid] = UserDefault.session[pid] or {}
	UserDefault.session[pid][key] = UserDefault.session[pid][key] or {}
	return UserDefault.session[pid][key];
end

function UserDefault.Load(key, playerData,type)
	local pid = 0;
	if playerData then
		pid = playerModule.GetSelfID()
		if not pid or pid == 0 then
			return  {};
		end
	end
	if type == 1 then
		UserChat.values[pid] = UserChat.values[pid] or {}
		UserChat.values[pid][key] = UserChat.values[pid][key] or {}
		return UserChat.values[pid][key];
	else
		UserDefault.values[pid] = UserDefault.values[pid] or {}
		UserDefault.values[pid][key] = UserDefault.values[pid][key] or {}
		return UserDefault.values[pid][key];
	end
end

function UserDefault.Clear()
	UserDefault.values = {};
end

local function WritePrefs(key, value)
	if UnityEngine.Application.isEditor then
		CS.System.IO.File.WriteAllText("./" .. key .. ".lua", value);
	else
		UnityEngine.PlayerPrefs.SetString(key, value)
		UnityEngine.PlayerPrefs.Save();
	end
end

local function ReadPrefs(key, default)
	if UnityEngine.Application.isEditor then
		local path = "./" .. key .. ".lua";
		if CS.System.IO.File.Exists(path) then
			return CS.System.IO.File.ReadAllText(path);
		else
			return default
		end
	else
		return UnityEngine.PlayerPrefs.GetString(key, default)
	end
end

local function Load(name)
	local str = ReadPrefs(name, "")
	if str and str ~= nil then
		local func = loadstring(str);
		local success, info = pcall(func)
		if success then
			return info or {}
		end
	end
	return {}
end

UserDefault.values = Load("UserDefault")
UserChat.values = Load("UserChat")

function UserDefault.Save(type)
	if type == 1 then
		WritePrefs("UserChat", "return " .. dumpValue(UserChat.values));
	else
		WritePrefs("UserDefault", "return " .. dumpValue(UserDefault.values));
	end
	-- UnityEngine.PlayerPrefs.SetString("UserDefaultValue", "return " .. dumpValue(UserDefault.values))
end

setmetatable(UserDefault, {__gc=function()
	UserDefault.Save();
end});

--[[
local EventManager = require 'utils.EventManager';
EventManager.getInstance():addListener('UNITY_OnApplicationQuit', function() 
	UserDefault.Save()
end);
--]]

return UserDefault