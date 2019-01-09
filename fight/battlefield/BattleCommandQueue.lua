local class = require "utils.class"

local BattleCommandQueue = class({});

function BattleCommandQueue:_init_(game)
    self.game = game;
    self.queue = {}
    self.index = 0;
    self.watchers = {}
end

function BattleCommandQueue:AddWatcher(cb)
    table.insert(self.watchers, cb);
end

function BattleCommandQueue:GetQueue()
    return self.queue;
end

function BattleCommandQueue:IsEmpty()
    return self.index >= #self.queue;
end

function BattleCommandQueue:Peek()
    return self.queue[#self.index + 1];
end

function BattleCommandQueue:Push(cmd)
    self:DEBUG_LOG("BattleCommandQueue:Push", cmd.type, cmd.tick, cmd.refid, cmd.sync_id, cmd.skill, cmd.target);

    if not cmd.tick or cmd.tick == 0 then
        cmd.tick = self.game.timeline.tick;
    end

    if #self.queue > 0 then
        if self.queue[#self.queue].tick > (cmd.tick + 1) then
            ERROR_LOG('tick error', cmd.tick, self.queue[#self.queue].tick, cmd.type);
        end

        --[[
        if self.queue[#self.queue].tick > cmd.tick then
            for i = #self.queue, self.index, -1 do
                if i == self.index or self.queue[i].tick <= cmd.tick then
                    table.insert(self.queue, i + 1, cmd)
                    return cmd;
                end
            end    
        end
        --]]
    end

    --[[
    if cmd.type == 'INPUT' then
        cmd.tick = self.game.timeline.tick;
        table.insert(self.queue, self.index + 1, cmd);
    else
        table.insert(self.queue, cmd);
    end
    --]]

    table.insert(self.queue, cmd);

    return cmd;
end

function BattleCommandQueue:DUMP()
    print("BattleCommandQueue:DUMP")
    for i = self.index + 1, #self.queue do
        local cmd = self.queue[i];
        print('-', cmd.tick, cmd.type, cmd.refid, cmd.sync_id, cmd.skill, cmd.target, cmd.value);
    end
end

function BattleCommandQueue:Tick(tick, do_input)
    while true do
        local cmd = self.queue[self.index+1];
        if not cmd or cmd.tick > tick then return end

        if not do_input and self:IsInput(cmd) then
            break;
        end

        self.index = self.index + 1;

        cmd.tick = self.game.timeline.tick;

        if self:Action(cmd) then
            break;
        end
    end
end

function BattleCommandQueue:DEBUG_LOG(...)
    self.game:DEBUG_LOG(...)
end

function BattleCommandQueue:Action(t)
    local break_tick = false;
    if BattleCommandQueue[t.type] then
        break_tick = BattleCommandQueue[t.type](self, t);
    else
        ERROR_LOG("BattleCommandQueue:Action", t.tick, t.type)
    end

    for _, cb in ipairs(self.watchers) do
        cb(t);
    end
    return break_tick;
end

function BattleCommandQueue:IsInput(t)
    if t.type ~= "INPUT" then
        return;
    end

    if t.pid ~= 0 and t.pid ~= self.game.attacker_pid and t.pid ~= self.game.defender_pid then
        return;
    end

    if t.skill == 98000 then
        return;
    end

    if t.skill >= 99000 then
        return;
    end

    return true;
end

function BattleCommandQueue:INPUT(t)
    if t.pid ~= 0 and t.pid ~= self.game.attacker_pid and t.pid ~= self.game.defender_pid then
        return;
    end

    self:DEBUG_LOG("BattleCommandQueue:INPUT", t.tick, t.refid, t.sync_id, t.skill, t.target);

    if t.skill == 98000 then
        local role = self.game:GetRole(nil, t.refid, t.sync_id)
        self.game:SetBattleFocusTag(role, t.target);
        return;
    end

    if t.skill >= 99000 then
        return;
    end

    local role = self.game:GetRole(nil, t.refid, t.sync_id)
    if not role then
        ERROR_LOG("not found", t.refid, t.sync_id)
        return;
    end
    role:Input(t.skill, t.target)
    return true;
end

function BattleCommandQueue:MONSTER_ENTER(t)
    if t.pid ~= 0 and t.pid ~= self.game.attacker_pid and t.pid ~= self.game.defender_pid then
        return;
    end

    self:DEBUG_LOG("BattleCommandQueue:MONSTER_ENTER", t.tick, t.refid, t.sync_id);
    self.game:AddRoleByRef(t.refid, t.sync_id)
end

function BattleCommandQueue:MONSTER_HP_CHANGE(t)
    if t.pid == self.game.pid then
        return;
    end

    self:DEBUG_LOG("BattleCommandQueue:MONSTER_HP_CHANGE", t.tick, t.refid, t.sync_id, t.value);
    self.game:ChangeRoleHP(t.refid, t.sync_id, t.value);
end

function BattleCommandQueue:PLAYER_STATUS_CHANGE(t)
    self:DEBUG_LOG("BattleCommandQueue:PLAYER_STATUS_CHANGE", t.tick, t.pid, t.target, t.value);
end

--[[
local cc = BattleCommandQueue({DEBUG_LOG=function() end});
cc:Push({tick=1, value=1});
cc:Push({tick=8, value=3})
cc:Push({tick=10, value=2});
cc:Push({tick=9, value=3})

assert(cc.queue[1].tick == 1);
assert(cc.queue[2].tick == 8);
assert(cc.queue[3].tick == 9);
assert(cc.queue[4].tick == 10);
--]]

return BattleCommandQueue;
