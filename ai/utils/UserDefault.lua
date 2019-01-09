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

function UserDefault.Load(key, playerData)
	local pid = 0;
	if playerData then
		pid = playerModule.GetSelfID()
		if not pid or pid == 0 then
			return  {};
		end
	end

	UserDefault.values[pid] = UserDefault.values[pid] or {}
	UserDefault.values[pid][key] = UserDefault.values[pid][key] or {}
	return UserDefault.values[pid][key];
end

function UserDefault.Clear()
	UserDefault.values = {};
end

local UserDefaultFilePath = UnityEngine.Application.persistentDataPath .. "/UserDefault.lua";
if UnityEngine.Application.isEditor then
	UserDefaultFilePath = "./UserDefault.lua";
end

if CS.System.IO.File.Exists(UserDefaultFilePath) then
	local str =  CS.System.IO.File.ReadAllText (UserDefaultFilePath); --  UnityEngine.PlayerPrefs.GetString("UserDefaultValue", "{}")
	if str and str ~= "" then
		local func = loadstring(str);
		UserDefault.values = func and func() or {};
	end
end

function UserDefault.Save()
	CS.System.IO.File.WriteAllText(UserDefaultFilePath, "return " .. dumpValue(UserDefault.values));
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