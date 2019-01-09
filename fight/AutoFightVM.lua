local battle_loader = require "battle_loader"

local VM = {}

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


function VM.New(attacker_pid, defender_pid, scene)
	local t = {
		attacker_pid = attacker_pid;
		defender_pid = defender_pid;
	}

	t.scene = scene;

	t = setmetatable(t, {__index=VM})

	return t;
end

function VM:SetFightData(attacker_data, defender_data)
	if attacker_data and attacker_data.pid > 0 then
		self.attacker_data = attacker_data;
	end

	if defender_data and defender_data.pid > 0 then
		self.defender_data = defender_data;
	end
end

function VM:Fight()
	log.debug("AutoFightVM start", self.attacker_pid, self.defender_pid)
	if self.attacker_pid == self.defender_pid then
		log.debug(' same player, skip');
		return;
	end

	local seed = math.random(1, 0x7fffffff)
	local fight_data = {
		attacker = self.attacker_data,
		defender = self.defender_data,
		seed = seed,
		scene    = self.scene or '18hao',
	}

	if not self.attacker_data then
		local attacker, err = cell.QueryPlayerFightInfo(self.attacker_pid, false, 0);
		if err then
			log.debug(string.format('  load fight data %d error %s', self.attacker_pid, err))
			return;
		end

		fight_data.attacker = attacker;
		self.attacker_data = attacker;
	end

	if not self.defender_data then
		local defender, err = cell.QueryPlayerFightInfo(self.defender_pid, false, 100);
		if err then
			log.debug(string.format('  load fight data %d error %s', self.defender_pid, err))
			return;
		end

		fight_data.defender = defender;
		self.defender_data = defender;
	end

	local code = encode('FightData', fight_data);
	if code == nil then
		log.debug(string.format('encode fight data failed'));
		return 
	end

	self.code = code;
	self.battle = battle_loader.New(self, self.attacker_pid, fight_data);
	self.battle:Start();

	local sec = 0;
	while not self.battle:GetWinner() and sec < 5 * 60 do
		self.battle:Update(sec);
		sec = sec + 1;
	end

	local ret = {}
	for _, v in pairs(self.battle.game.roles) do
		table.insert(ret, { refid = v.refid, hp = v.hp })
	end

	return { self.battle:GetWinner(), seed, ret }, self.attacker_data, self.defender_data
end

function VM:UNIT_INPUT(pid, role)
	self:LOG('UNIT_INPUT %s, %s, refid %d, sync_id %d', pid or 'nil', role.name or '-', role.refid or 0, role.sync_id or 0);
	self.battle:PushCommand({
			type="INPUT", pid = pid, tick = self.battle:GetTick(),
			refid=role.refid, sync_id=role.sync_id,
			skill = 0, target = 0});
end

function VM:LOG(...)
	print('[AutoFightVM]', string.format(...));
end

return VM;
