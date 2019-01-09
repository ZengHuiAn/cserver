local PlayerManager = require "RankArenaPlayerManager"
local Queue     = require "Queue"
local base64 = require "base64"  
local Property = require "Property"
local MAX_LOG = 10

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
        role.Property = Property(property);
    end

	for k, role in pairs(fight_data.defender.roles) do
        local property = {}
        for _, v in ipairs(role.propertys) do
            property[v.type] = (property[v.type] or 0) + v.value
        end
        role.Property = Property(property);
    end

    --[[local capacity = 0;
    for k, v in ipairs(fight_data.roles) do
        capacity = capacity + v.Property.capacity
    end--]]

    return fight_data
end


local function encodeFightDataToB64(fight_data)
	local code = encode('FightData', fight_data);
	return base64.encode(code)	
end


local all = {}
local function getFightLog(id)
    if all[id] == nil then
        local success, result = database.query("select fid, attacker, target, winner, unix_timestamp(ftime) as ftime, pos1, pos2, fight_data from arena_fight_log where attacker = %u or target = %u order by fid desc limit %d", id, id, MAX_LOG);
        if not success then
            log.error("load fight log failed");
            return nil;
        end

        local fights = Queue.New();
		for _, row in ipairs(result) do
			local fight = {
				attacker = PlayerManager.Get(row.attacker),
                target = PlayerManager.Get(row.target);
                fid = row.fid,
                pos = {pos1 = row.pos1, pos2 = row.pos2},
                winner = row.winner,
                time = row.ftime,
				fight_data = phaseFightData(row.fight_data),
			}
			fights:push(fight)
		end
        all[id] = fights;
    end

    return all[id];
end

local function Notify(pid, fight)
    local agent = Agent.Get(pid);
	assert(fight)
    if agent then
		local amf = {
			fight.attacker.id,
			fight.target.id,
			fight.fid,	
			fight.pos.pos1,
			fight.pos.pos2,
			fight.winner,
			fight.time,
			encode('FightData', fight.fight_data)
		}
        agent:Notify({Command.NOTIFY_RANK_ARENA_LOG_CHANGE, amf});
    end
end

local function addLog(attacker, target, winner, fight_id, fight_data)
	if (not attacker or not attacker.id) or (not target or not target.id) then
        log.error("fail to add arena log, invalidate argument");
        return false 
    end

    -- log
	local code = encodeFightDataToB64(fight_data)
    database.update([[insert into arena_fight_log(fid, attacker, target, winner, ftime, pos1, pos2, fight_data)
            values (%u, %u, %u, %u, from_unixtime(%u), %u, %u, '%s')]],
            fight_id, attacker.id, target.id, winner, loop.now(), attacker.order, target.order, code);

    -- save fight list to player
    local fight = {
        attacker = attacker,
        target = target,
        fid = fight_id,
        pos = {pos1 = attacker.order, pos2 = target.order},
        winner = winner,
        time = loop.now(),
		fight_data = fight_data,
    };
    local fight_log = getFightLog(attacker.id);
    fight_log:push(fight);
	if fight_log:size() > MAX_LOG then
		fight_log:pop()
	end
	Notify(attacker.id, fight)

    fight_log = getFightLog(target.id);
    fight_log:push(fight);
	if fight_log:size() > MAX_LOG then
		fight_log:pop()
	end
	Notify(target.id, fight)
	
    return true
end

local function queryLog(id)
	local fight_log = getFightLog(id)
	if not fight_log then
		return 
	end	

	local logs = {}
	for i = 1, MAX_LOG, 1 do
		local fight = fight_log:get(i)
		if fight then
			table.insert(logs, {
				fight.attacker.id,
				fight.target.id,
				fight.fid,	
				fight.pos.pos1,
				fight.pos.pos2,
				fight.winner,
				fight.time,
				encode('FightData', fight.fight_data),
			})	
		end
	end	

	return logs
end

return {
	GetFightLog = getFightLog,
	AddLog = addLog,
	QueryLog = queryLog,
}
