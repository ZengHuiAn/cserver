package.cpath=package.cpath .. ";../lib/?.so";
package.path =package.path  .. ";../lib/?.lua";

require "NetService"
require "protobuf"
require "Thread"

require "battle_init"

local Battle = require "battlefield/Battle"
local Skill = require "battlefield/Skill"
local battle_config = require "config/battle";
local Thread = require "utils.Thread"
local Pipe = require "utils.Pipe"
local cell = require "cell"

local BattlefieldView = {}

function BattlefieldView.New(reactor, ctx, fight_data)
	return setmetatable({reactor = reactor, ctx = ctx, fight_data = fight_data, writer = writer}, {__index=BattlefieldView});
end

local function input_writer(view)
	return function(...)
		if view and view.writer then
			view.writer(...)
		end
		-- print('INPUT', role.refid, role.name, ...);
	end
end

function BattlefieldView:Start()
	local game = Battle(self.fight_data);
	
	game.runing_in_server = true;

	self.roles = {}
	self.shared_object = {}

	-- add listener
	local this = self;
	game:Watch('*', function(event, ...)
		local func = this.reactor[event];
		if func then
			func(this.reactor, this.ctx, ...)
		else
			-- print("!!! EVENT !!!", event, ...);
		end
	end);

    local attacker_roles = {};
    for k, v in ipairs(self.fight_data.attacker.roles) do
        table.insert(attacker_roles, v);
    end
    table.sort(attacker_roles, function(a,b) return a.pos < b.pos; end)
    local start_pos = ({2, 1, 1, 0, 0})[#attacker_roles] or 0;    
    for k, v in ipairs(attacker_roles) do
        v.pos = start_pos + k;
    end

	for k, v in pairs(self.fight_data.attacker.roles) do
		game:AddRoleByRef(v.refid, 0);
	end

	for k, v in pairs(self.fight_data.defender.roles) do
		game:AddRoleByRef(v.refid, 0);
	end

	for k, v in pairs(self.fight_data.attacker.assists) do
		game:AddRoleByRef(v.refid, 0);
	end

	for k, v in pairs(self.fight_data.defender.assists) do
		game:AddRoleByRef(v.refid, 0);
	end

	print("BattlefieldView game start");

	self.game = game;

	self.time = -1;

	game:Start();	
end

function BattlefieldView:Update(now, tick)
	now = now or loop.now();

	if self.time == -1 then
		self.time = now
	end

	if self.game then
		local dt = now - self.time;
		self.time = now;
		self.game:Update(dt, tick);
	end
end

function BattlefieldView:PushCommand(t)
	self.game.commandQueue:Push(t);
end

function BattlefieldView:INPUT(refid, sync_id, skill, target)
	skill = skill or 0

	if skill == "def"  then skill = Skill.ID_DEF;  end
	if skill == "auto" then skill = Skill.ID_AUTO; end

	target = target or 0;
	self:PushCommand({ 
				 type    = "INPUT", pid     = self.game.pid,
				 refid   = refid, sync_id = sync_id,
				 skill   = skill, target  = target, });
	return skill, target;
end

function BattlefieldView:MONSTER_ENTER(refid, sync_id)
	self:PushCommand({ 
				 type    = "MONSTER_ENTER", pid = self.game.pid,
				 refid   = refid,           sync_id = sync_id,
				 value   = value});
end



function BattlefieldView:MONSTER_HP_CHANGE(pid, refid, sync_id, value)
	self:PushCommand({ 
				 type    = "MONSTER_HP_CHANGE", pid = pid,
				 refid   = refid,           sync_id = sync_id,
				 value   = value});
end

function BattlefieldView:MONSTER_COUNT_CHANGE(pid, refid, sync_id, count)
	self:PushCommand({ 
				 type    = "MONSTER_COUNT_CHANGE", pid = pid,
				 refid   = refid,              sync_id = sync_id,
				 value = count});
end

function BattlefieldView:Fastforward()
	self.game:Fastforward();
end

function BattlefieldView:GetCommandQueue()
	return self.game.commandQueue:GetQueue();
end

function BattlefieldView:GetTick()
	return self.game.timeline.tick;
end

function BattlefieldView:GetWinner()
	return self.game.timeline.winner;
end

return BattlefieldView;
