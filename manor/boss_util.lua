local protobuf = require "protobuf"

function encode(protocol, msg)
	local code = protobuf.encode("com.agame.protocol." .. protocol, msg);
	if code == nil then
		print(string.format(" * encode %s failed", protocol));
		loop.exit();
		return nil;
	end
	return code;								 
end

function decode(code, protocol)
	return protobuf.decode("com.agame.protocol." .. protocol, code)
end

function BeginTime(ref, period, time)
	return ref + math.floor((time - ref) / period) * period
end

function EndTime(ref, period, time)
	return ref + math.ceil((time - ref) / period) * period 
end

local function split(str, deli)	
	if str == "" then
		return {}
	end

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

-- 1:100|2:200|3:300
function formatStrtoTable(str)
	local ret = {}

	local source = split(str, "|")
	for _, v in ipairs(source) do
		local t = split(v, ":")
		ret[tonumber(t[1])] = tonumber(t[2])
	end

	return ret
end

function tableToFormatStr(t)
	local str = ""

	for i, v in pairs(t) do
		str = str .. "|" .. tostring(i) .. ":" .. tostring(v)
	end

	if str ~= "" then
		str = string.sub(str, 2)
	end

	return str
end
