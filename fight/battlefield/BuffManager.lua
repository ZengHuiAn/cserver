local class = require "utils.class"
local Property = require "utils.Property"
local SandBox = require "utils.SandBox"
local Thread  = require "utils.Thread"

local safe_pack = table.pack or function(...)
    local r = {...}
    r.n = select('#', ...)
    return r;
end

local safe_unpack = table.unpack or function(arg)
    return unpack(arg, 1, arg.n);
end

local GlobalEvents = {
	-- UnitDead = true,

	-- Enter = true,
	TIMELINE_Leave = 'onUnitDead',
	TIMELINE_Enter = 'onUnitEnter',
	TIMELINE_BeforeRound_SYNC = 'onRoundStart',
	TIMELINE_AfterRound_SYNC = 'onRoundEnd',
	PET_Enter = 'onPetEnter',
	BATTLE_GUIDE_CHANE = 'AfterGuide',
	TIMELINE_Finished = 'onFightEnd',
	-- AfterWave = 'AfterWave',
	-- BeforeWave = 'BeforeWave',
	-- Finish = 'Finish'
};

local TargetEvents = {
	PET_BeforeAction = 'onTick',
	PET_AfterAction = 'onPostTick',

	TIMELINE_BeforeAction_SYNC = 'onTick',
	TIMELINE_AfterAction_SYNC  = 'onPostTick',

	BULLET_attackerBeforeAttack = 'attackerBeforeAttack',
	BULLET_targetBeforeAttack   = 'targetBeforeAttack',

	BULLET_attackerFilter = 'attackerFilter',

	BULLET_attackerAfterAttack = 'attackerAfterAttack',
	BULLET_targetAfterAttack   = 'targetAfterAttack',

	BULLET_attackerBeforeHit = 'attackerBeforeHit',
	BULLET_targetBeforeHit   = 'targetBeforeHit',

	BULLET_targetFilter = 'targetFilter',

	BULLET_attackerAfterCalc = 'attackerAfterCalc',
	BULLET_targetAfterCalc = 'targetAfterCalc',

	BULLET_attackerWillHit = 'attackerWillHit',
	BULLET_targetWillHit   = 'targetWillHit',

	BULLET_attackerAfterHit = 'attackerAfterHit',
	BULLET_targetAfterHit   = 'targetAfterHit',

	UNIT_CAST_SKILL = 'onSkillCast',
	SPINE_ANIMATION_EVENT = 'spineAnimationEvent',
};

local BuffTarget = class()
function BuffTarget:_init_(events)
	self.buffs = {}
	self.events = {}
	for _, v in pairs(events) do
		self.events[v] = {}
	end
end

function BuffTarget:Add(buff)
	assert(self.buffs[buff.uuid] == nil);

	self.buffs[buff.uuid] = buff;

	-- callbacks
	for k, v in pairs(self.events) do 
		if buff.env and buff.env ~= 0 and buff.env[k] then
			v[#v+1] = buff.uuid
		end
	end
end

function BuffTarget:Remove(buff)
	assert((self.buffs[buff.uuid] == buff) or (self.buffs[buff.uuid] == nil));
	self.buffs[buff.uuid] = nil;
end

function BuffTarget:All()
	local t = {}
	for _, v in pairs(self.buffs) do
		table.insert(t, v);
	end
	return t;
end

function BuffTarget:Call(event, ...)
	if not self.events[event] then
		return;
	end

	local olist = self.events[event]
	local nlist = {}
	local clist = {}
	self.events[event] = nlist


	-- get buffs and cleanup callback
	for _, uuid in ipairs(olist)  do
		local buff = self.buffs[uuid]
		if buff then
			nlist[#nlist+1] = uuid;
			if buff.env and buff.env ~= 0 and buff.env[event] then
				clist[#clist+1] = buff
			end
		end
	end

	for _, buff in ipairs(clist) do
		coroutine.resume(coroutine.create(function(...)
			ASSERT(pcall(buff.env[event], buff.target, buff, ...));
		end), ...)
	end
end

--------------------------------------------------------------------------------
local Buff = class()
local buff_config = LoadDatabaseWithKey("battle_buff", "id", "fight")

function Buff:_init_(id, property, game, target, extra)
	self.id = id;
	self.game = game;
	self.target = target;
	self.cfg = buff_config[id]
	self.script_id = self.cfg and self.cfg.script_id or id
	self.property = Property(property);
	self.extra = extra or {};
	self.env = SandBox.New(string.format("script/buff/%s.lua", self.script_id), game, target);
	if self.env then
		self.env:LoadLib("script/common.lua");
		self.env:Call();
	end
end

function Buff:_getter_(key)
	if key == "desc" then
		if self.env.GetDesc then
			return self.env.GetDesc(self);
		else
			return nil;
		end
	end
	return self.extra[key] or self.property[key]
end

function Buff:_setter_(key, value)
	if self.extra[key] ~= nil then
		self.extra[key] = value;
		return;
	end

	self.property[key] = value
end

--------------------------------------------------------------------------------
local BuffManager = class()

function BuffManager:_init_(event)
	assert(event.addListener, 'BuffManager must init with a EventManager');

	self.event = event;

	self.targets = {}
	self.global_target = BuffTarget(GlobalEvents);

	local this = self;
	self.thread = Thread.Create(function()
		while true do
			local data = safe_pack(Thread.Self():read_message());
			self.running = true;
			this:onEvent(safe_unpack(data));
			self.running = false;
		end
	end)
	self.thread:Start();

	for k, _ in pairs(GlobalEvents) do
		event:addListener(k, self.thread)
	end

	for k, _ in pairs(TargetEvents) do
		event:addListener(k, self.thread)
	end
end

function BuffManager:onEvent(event, role, ...)
	local callback = GlobalEvents[event]
	if callback then
		self.global_target:Call(callback, role, ...);
	end

	callback = TargetEvents[event]
	if callback then
		assert(role, event);
		self:LocalTarget(role.uuid):Call(callback, ...)
	end
end

function BuffManager:LocalTarget(uuid)
	if not self.targets[uuid] then
		self.targets[uuid] = BuffTarget(TargetEvents)
	end
	return self.targets[uuid]
end

function BuffManager:Add(target, id, property, extra)
	assert(target.uuid > 0, "buff target must have uuid");
	assert(class.check(target.property, Property), "buff target must have property");

	local buff = Buff(id, property, target.game, target, extra)

	self:LocalTarget(target.uuid):Add(buff);
	self.global_target:Add(buff);

	buff.target.property:Add(buff.uuid, buff.property);

	buff.target.game:Dispatch("BUFF_Add", buff, buff.target);

	if buff.env and buff.env ~= 0 and buff.env.onStart then
		local success, info = pcall(buff.env.onStart, buff.target, buff)
		if not success then
			ERROR_LOG(info);
		end
	end

	if buff.cfg and buff.cfg ~= 0 then
		buff.icon = (buff.cfg.icon ~= "" ) and buff.cfg.icon or buff.icon;
		buff.desc_head = (buff.cfg.name ~= "" ) and buff.cfg.name or buff.desc_head;
	end

	return buff;
end

function BuffManager:Move(buff, target)
	if buff.target.uuid == target.uuid then
		return;
	end

	local from = self:LocalTarget(buff.target.uuid)
	local to = self:LocalTarget(target.uuid)

	from:Remove(buff)
	buff.target.property:Remove(buff.uuid);

	if buff.env and buff.env ~= 0 and buff.env.onEnd then
		local success, info = pcall(buff.env.onEnd, buff.target, buff)
		if not success then
			ERROR_LOG(info);
		end
	end

	buff.target.game:Dispatch("BUFF_Remove", buff, buff.target);

	to:Add(buff);
	buff.target = target;
	buff.target.property:Add(buff.uuid, buff.property)

	if buff.env and buff.env ~= 0 and buff.env.onStart then
		local success, info = pcall(buff.env.onStart, buff.target, buff)
		if not success then
			ERROR_LOG(info);
		end
	end

	buff.target.game:Dispatch("BUFF_Add", buff, buff.target);
end

function BuffManager:Remove(buff, local_target)
	local_target = local_target or self:LocalTarget(buff.target.uuid);

	local_target:Remove(buff)
	self.global_target:Remove(buff);

	buff.target.property:Remove(buff.uuid);

	if buff.env and buff.env ~= 0 and buff.env.onEnd then
		local success, info = pcall(buff.env.onEnd, buff.target, buff)
		if not success then
			ERROR_LOG(info, buff.id);
		end
		buff.env.onEnd = nil;
	end

	buff.target.game:Dispatch("BUFF_Remove", buff, buff.target);
end

function BuffManager:Get(target)
	local local_target = self:LocalTarget(target.uuid);
	return local_target and local_target:All() or {};
end

function BuffManager:Clean(target)
	local local_target = self:LocalTarget(target.uuid);

	local buffs = local_target:All();
	for _, buff in ipairs(buffs) do
		self:Remove(buff, local_target);
	end
end

function BuffManager:LoadBuffCfg(id)
	local cfg = buff_config[id]
	return cfg
end

return BuffManager;
