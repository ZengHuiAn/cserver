local database = require "database"
local ArenaFormation = {}
local base64 = require "base64"  
local Property = require "Property"

local function encode(protocol, msg)
	local code = protobuf.encode("com.agame.protocol." .. protocol, msg);
	if code == nil then
		print(string.format(" * encode %s failed", protocol));		
		loop.exit();
		return nil;
	end
	return code;
end

local function decode(code, protocol)
	return protobuf.decode("com.agame.protocol." .. protocol, code);
end

local function phaseFightData(b64_code)
	local code = base64.decode(b64_code)
	local fight_data = decode(code, 'FightPlayer')

	for k, role in pairs(fight_data.roles) do
		local property = {}
		for _, v in ipairs(role.propertys) do
			property[v.type] = (property[v.type] or 0) + v.value
		end
		role.Property = Property(property);
	end

	local capacity = 0;
	for k, v in ipairs(fight_data.roles) do
		capacity = capacity + v.Property.capacity
	end

	return fight_data
end

local function encodeFightDataToB64(fight_data)
	local code = encode('FightPlayer', fight_data);
	return base64.encode(code)	
end

local all = {}

local STRIDE = 1000
local fight_data_by_cap_list = {}
local fight_data_by_cap_map = {}

local function InsertIntoFightDataList(type, pid, cap)
	if not fight_data_by_cap_list[type] then
		fight_data_by_cap_list[type] = {}
	end	

	if not fight_data_by_cap_map[type] then
		fight_data_by_cap_map[type] = {}
	end

	local idx = math.ceil(cap / STRIDE)
	if not fight_data_by_cap_list[type][idx] then
		fight_data_by_cap_list[type][idx] = {}
	end
	
	local temp = {pid = pid, cap = cap, idx = idx, idx2 = 0}
	table.insert(fight_data_by_cap_list[type][idx], temp)
	temp.idx2 = #fight_data_by_cap_list

	fight_data_by_cap_map[type][pid] = temp
end

local function UpdateFightDataList(type, pid, cap)
	if not fight_data_by_cap_map[type] or not fight_data_by_cap_map[type][pid] then
		return 
	end

	local t = fight_data_by_cap_map[type][pid]
	local new_idx = math.ceil(cap / STRIDE)
	if t.idx ~= new_idx then
		if t.idx2 < #fight_data_by_cap_list[t.idx] then
			for i = #fight_data_by_cap_list[t.idx], t.idx2 + 1, -1 do
				fight_data_by_cap_list[t.idx][i].idx2 = fight_data_by_cap_list[t.idx][i].idx2 - 1
			end
			table.remove(fight_data_by_cap_list[t.idx], t.idx2)
			table.insert(fight_data_by_cap_list[new_idx], t)	
			t.idx2 = #fight_data_by_cap_list[new_idx]
		end	
	end
end

local function LoadAll()
	local success, result = database.query("select pid, type, fight_data, cap from arena_formation")	
	if success and #result > 0 then
		for _, row in ipairs(result) do
			if not all[row.pid] then
				all[row.pid] = ArenaFormation.New(row.pid)
			end	
		
			all[row.pid]:AddFightData(row.type, row.fight_data, row.cap)
		end
	end
end

local function Get(pid)
	if not all[pid] then
		all[pid] = ArenaFormation.Load(pid)
	end

	return all[pid]
end

function ArenaFormation.Load(pid)
	local t = {
		pid = pid, 
		fight_data = {},
		caps = {}
	}
	local success, result = database.query("select pid, type, fight_data, cap from arena_formation where pid = %d", pid)	
	if success and #result > 0 then
		for _, row in ipairs(result) do
			local fight_data = phaseFightData(row.fight_data)
			t.fight_data[row.type] = fight_data 
			t.caps[row.type] = row.cap 
			InsertIntoFightDataList(row.type, pid, row.cap)
		end
	end

	return setmetatable(t, {__index = ArenaFormation})
end

function ArenaFormation.New(pid)
	local t = {
		pid = pid, 
		fight_data = {},
		caps = {}
	}

	return setmetatable(t, {__index = ArenaFormation})
end

function ArenaFormation:AddFightData(type, fight_data, cap)
	local decode_fight_data = phaseFightData(fight_data)
	self.fight_data[type] = decode_fight_data
	self.caps[type] = cap 
	InsertIntoFightDataList(type, self.pid, cap)
end
LoadAll()

function ArenaFormation:Query(type, attacker)
	if self.fight_data[type] and not attacker then
		for k, role in pairs(self.fight_data[type].roles) do
			if role.refid < 100 then
				role.refid = role.refid + 100
			end	
		end
	end

	if self.fight_data[type] and attacker then
		for k, role in pairs(self.fight_data[type].roles) do
			if role.refid >= 100 then
				role.refid = role.refid - 100
			end	
		end
	end
	
	return self.fight_data[type]
end

function ArenaFormation:Update(type, fight_data)
	if not fight_data then
		return 
	end

	local cap = 0;
	for k, v in ipairs(fight_data.roles) do
		cap = cap + v.Property.capacity
	end

	local code = encodeFightDataToB64(fight_data)
	if not self.fight_data[type] then
		database.update("insert into arena_formation(pid, type, fight_data, cap) values(%d, %d, '%s', %d)", self.pid, type, code, cap)	
		InsertIntoFightDataList(type, self.pid, cap)
	else
		database.update("update arena_formation set fight_data = '%s', cap = %d where pid = %d and type = %d", code, self.pid, type, cap)	
		UpdateFightDataList(type, self.pid, cap)
	end

	self.fight_data[type] = fight_data  --encodeFightDataToB64(fight_data)
	self.caps[type] = cap
end

function GetFightDataByCap(type, lower_cap, upper_cap, mask)
	assert(upper_cap > lower_cap)
	local list = fight_data_by_cap_list[type]
	if not list then
		return 
	end

	local save_lower_cap = lower_cap
	local save_upper_cap = upper_cap
	local mask_tb = {}
	for k, v in ipairs(mask or {}) do
		mask_tb[v] = 1 
	end

	local lower_idx = math.ceil(lower_cap / STRIDE)
	local upper_idx = math.ceil(upper_cap / STRIDE)
	local step = math.ceil((upper_cap - lower_cap) / STRIDE)

	local candidate = {} 
	while #candidate == 0 do 
		for idx = lower_idx, upper_idx, 1 do
			if list[idx] then
				for k, v in ipairs(list[idx]) do
					if v.cap >= lower_cap and v.cap <= upper_cap and not mask_tb[v.pid] then
						table.insert(candidate, {pid = v.pid, cap = v.cap})
					end
				end
			end		
		end

		upper_idx = lower_idx - 1
		lower_idx = upper_idx - step
		if lower_idx < 0 then
			lower_idx = 1
		end
		lower_cap = STRIDE * lower_idx 
		upper_cap = STRIDE * upper_idx

		if upper_idx <= 1 then
			break	
		end
	end

	if #candidate == 0 then
		return 
	end

	local final = candidate[math.random(1, #candidate)]
	local factor = 1
	if final.cap < save_lower_cap then
		factor = math.random(save_lower_cap, save_upper_cap) / final.cap
	end
	
	local m = Get(final.pid)		
	assert(m)
	local fight_data = m:Query(type, false)
	--correct fight data
	if factor ~= 1 then
		for _, role in ipairs(fight_data.roles)	do
			for _, property in ipairs(role.propertys) do
				if property.type == 1034 then
					property.value = math.ceil(property.value * factor) 	
				end
				
				if property.type == 1314 then
					property.value = math.ceil(property.value * factor) 	
				end
			
				if property.type == 1514 then
					property.value = math.ceil(property.value * factor) 	
				end
			end
		end
	end

	return fight_data
end

--GetFightDataByCap(1, 9000, 10000) --{146028988202})

return {
	Get = Get,
	GetFightDataByCap = GetFightDataByCap,
}
