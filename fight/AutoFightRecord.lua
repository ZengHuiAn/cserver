require "printtb"
local base64 = require "base64"

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
    local fight_data = decode(code, 'FightData')

    for k, role in pairs(fight_data.attacker.roles) do
        local property = {}
        for _, v in ipairs(role.propertys) do
            property[v.type] = (property[v.type] or 0) + v.value
        end
        --role.Property = Property(property);
    end

    for k, role in pairs(fight_data.defender.roles) do
        local property = {}
        for _, v in ipairs(role.propertys) do
            property[v.type] = (property[v.type] or 0) + v.value
        end
        role.Property = Property(property);
    end

    return fight_data
end


local function encodeFightDataToB64(fight_data)
    local code = encode('FightData', fight_data);
    return base64.encode(code)
end

local AutoFightRecord = {
	records = {},
}

function AutoFightRecord.Query(id)
	if not AutoFightRecord.records[id] then
		AutoFightRecord.records[id] = {}
		local success, result = database.query("select fight_id, winner, fight_data from auto_fight_record where fight_id = %d", id)
		if success and #result > 0 then
			AutoFightRecord.records[id] = {
				winner = result[1].winner,
				code = phaseFightData(result[1].fight_data),
			}
		end
	end

	return AutoFightRecord.records[id].code
end

function AutoFightRecord.Save(id, winner, seed, scene, attacker_data, defender_data)
	if AutoFightRecord.records[id] and AutoFightRecord.records[id].code then
		return
	end

	local fightData = {
		attacker = attacker_data,
		defender = defender_data,
		seed = seed,
		scene = scene 
	}

	AutoFightRecord.records[id] = {
		winner = winner,
		code = fightData,	
	}

	database.update("insert into auto_fight_record (fight_id, winner, fight_data) values(%d, %d, '%s')", id, winner, encodeFightDataToB64(fightData))
end

--print(">>>>>>>>>>>>>>>>", sprinttb(AutoFightRecord.Query(1528103771001)))

return AutoFightRecord
