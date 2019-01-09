local Timeline = require "battlefield.Timeline"
local BuffManager = require "battlefield.BuffManager"
local Role = require "battlefield.Role"
local Assistant = require "battlefield.Assistant"
local Thread = require "utils.Thread"
local class = require "utils.class"
local EventManager = require "utils.EventManager"
local BattleCommandQueue = require "battlefield.BattleCommandQueue"
local SandBox = require "utils.SandBox"


local battle_config = require "config/battle";

local SleepingManager = {}
function SleepingManager.New()
    return setmetatable({sleeping_thread = {}, tick = 0}, {__index=SleepingManager});
end

function SleepingManager:Wait(co, tick)
    tick = self.tick + tick;
    self.sleeping_thread[tick] = self.sleeping_thread[tick] or {}
    table.insert(self.sleeping_thread[tick], co);
end

function SleepingManager:Tick()
    self.tick = self.tick + 1;
    local list = self.sleeping_thread[self.tick] or {}
    self.sleeping_thread[self.tick] = nil;
    for _, v in ipairs(list) do
        ASSERT(coroutine.resume(v))
    end
end

function SleepingManager:IsEmpty()
    return not next(self.sleeping_thread);
end

function SleepingManager:Clean()
    if self:IsEmpty() then return end

    local sleep_list = {}
    for k, sleep in pairs(self.sleeping_thread) do
        table.insert(sleep_list, sleep)
    end

    self.sleeping_thread = {}

    for _, co_list in ipairs(sleep_list) do
        for _, co in ipairs(co_list) do
            ASSERT(coroutine.resume(co))
        end
    end
end

local TICK_PER_SECOND = 30;

local Battle = class()

--[[
每个关卡应可配置3个条件
条件类型有以下：
   1.通过该关卡
   2.通过关卡时全队剩余X%血量（X为可配置）
   3.通关关卡时血量最少的角色剩余X%血量（X为可配置）
   4.通过阵亡人数少于N（N可配置）
   5.在X回合内通关
   6.没有使用召唤物通关
   7.不使用群体技能通关
   8.在1个回合内同时击杀怪物1和怪物2
   9.在X回合内击杀怪物1
   9.怪物1存活不超过x回合
   10.通过关卡时造成最高伤害达到X（X为可配置）
   11.通过关卡时己方受到伤害不超过X（X为可配置）
--]]

function Battle:_init_(fight_data, pid)
    self.eventManager    = EventManager.New(true);
    self.timeline        = Timeline(self.eventManager);
    self.buffManager     = BuffManager(self.eventManager);
    self.commandQueue    = BattleCommandQueue(self);
    self.sleepingManager = SleepingManager.New();

    self.timeline.game = self;

    -- self.eventManager.name = "Battle";

    self.wave_limit = 10;
    self.round_limit = 20;
    -- fight_data.duration = 20;
    if fight_data.duration and fight_data.duration > 0 then
        self.round_limit = fight_data.duration;
    end
    self.timeline.failed_round_limit = self.round_limit;

    self.seed = fight_data.seed or 0;
    self.fight_data = fight_data;
    self.pid = pid or self.fight_data.attacker.pid;
    self.attacker_pid = self.fight_data.attacker.pid;
    self.defender_pid = self.fight_data.defender.pid;

    if self.pid == self.fight_data.defender.pid then
        print("<color=red>battle work as defender</color>")
        self.timeline:WorkAsDefender();
    end

    if self.fight_data.win_type == 1 and self.fight_data.win_para > 0 then
        self.timeline.win_round_limit = self.fight_data.win_para + 1;
    end

    local this = self;

    self.roles = {}
    self.tick = 0;

    self.battle_script_data = {
        win_type = fight_data.win_type,
        fight_id = fight_data.defender.pid
    }

    self.time_left = 0;
    self.sleeping_thread = {};

    self.statistics = {
        skills_used = {},
        monsters = {},
        partners = {},
        total_round = 0,
        max_damage = 0,
        total_hurt = 0,
    }

    self.eventManager:addListener("TIMELINE_Enter", function(_, role)
        this:OnRoleEnter(role);
    end)

    self.eventManager:addListener("TIMELINE_Leave_Sync", function(_, role)
        this:OnRoleLeave(role);
    end)

    self.eventManager:addListener("RemovePet", function(_, role, pet)
        self.buffManager:Clean(pet);
    end);

    self.eventManager:addListener("UNIT_CAST_SKILL", function(_, role, skill)
        if role.side == 1 then
            self.statistics.skills_used[skill.skill_type or 0] = true;
        end
    end);

    self.eventManager:addListener("UNIT_Hurt", function(_, role, value)
        if role.side == 2 and value >= self.statistics.max_damage then
            self.statistics.max_damage = value;
        elseif role.side == 1 then
            self.statistics.total_hurt = self.statistics.total_hurt + value;
        end
    end)

    self.eventManager:addListener("TIMELINE_BeforeRound", function()
        self.statistics.total_round = self.statistics.total_round + 1;
    end)

    local env = setmetatable({RAND=function(...)
        return (self:RAND());
    end}, {__index=_G});
    self.fight_hurt_calc = loadfile("battlefield/fight_hurt_calc.lua", 'bt', env)();

    local Fight_Listener_byid = SandBox.New(string.format("script/fight/%s.lua", fight_data.defender.pid), self)
    Fight_Listener_byid:Call()
    Fight_Listener_byid:LoadLib("script/common.lua");

    local events = {
        "Unit_DEAD_SYNC",
        "TIMELINE_BeforeRound_SYNC",
        "TIMELINE_Finished",
        "TIMELINE_AfterAction_SYNC",
        "TIMELINE_BeforeAction_SYNC"
    }

    for k, v in ipairs(events) do
        if Fight_Listener_byid[v] then
            self.eventManager:addListener(v, Fight_Listener_byid[v])
        end
    end

end

function Battle:Dispatch( ... )
    self.eventManager:dispatch(...)
end

function Battle:DispatchImmediately( ... )
    self.eventManager:dispatchImmediately(...)
end

function Battle:Watch( ... )
    self.eventManager:addListener(...)
end

function Battle:Unwatch( ... )
    self.eventManager:removeListener(...);
end

function Battle:GetRole(uuid, refid, sync_id)
    if uuid then
        return self.roles[uuid]
    end
    
    for _, v in pairs(self.roles) do
        if v.refid == refid and v.sync_id == sync_id then
            return v;
        end
    end
end

function Battle:ChangeRoleHP(refid, sync_id, value)
    local role = self:GetRole(nil, refid, sync_id)
    if role then
        role:ChangeHP(value);
    else
        self:DEBUG_LOG("Battle:ChangeRoleHP failed", refid, sync_id, value)
    end

--[[
    if self.timeline.waiting then
        self.thread:resume('cancel')
    end
--]]
end


function Battle:OnRoleEnter(role)
    self.roles[role.uuid] = role;

    if role.side == 2 then
        local round = self.statistics.total_round
        if round <= 0 then round = 1 end;
        self.statistics.monsters[role.id] = self.statistics.monsters[role.id] or { enter_round = round}
    else
        self.statistics.partners[role.id] = self.statistics.partners[role.id] or {role=role, hurt = 0, health = 0, damage = 0};
    end
end

function Battle:OnRoleLeave(role)
    self.buffManager:Clean(role);
    self.roles[role.uuid] = nil;

    role._Focus_tag = 0
    if role.side == 2 and self.statistics.monsters[role.id]    then
        self.statistics.monsters[role.id].leave_round = self.statistics.total_round;
    end
end

function Battle:GetDataByRefid(refid)
    local FRIEND, ENEMY = 1, 2;

    if self.pid == self.fight_data.defender.pid then
        FRIEND, ENEMY = 2, 1;
    end

    for _, v in ipairs(self.fight_data.attacker.roles) do
        if v.refid == refid then
            return v, FRIEND;
        end
    end

    for _, v in ipairs(self.fight_data.defender.roles) do
        if v.refid == refid then
            return v, ENEMY;
        end
    end

    for _, v in ipairs(self.fight_data.attacker.assists) do
        if v.refid == refid then
            return v, FRIEND;
        end
    end

    for _, v in ipairs(self.fight_data.defender.assists) do
        if v.refid == refid then
            return v, ENEMY;
        end
    end
    return;
end

function Battle:AddRoleByRef(refid, sync_id)
    sync_id = sync_id or 0;

    local data, side = self:GetDataByRefid(refid)
    if not data then
        self:DEBUG_LOG("role data", refid, "no found");
        return;
    end

    if side == 1 then
        for _, v in pairs(self.roles) do
            if v.refid == refid then
                self:DEBUG_LOG('set partner sync_id', v.refid, v.sync_id, sync_id);
                v.sync_id = sync_id;
                return;
            end
        end
    end

    if side ~= 1 and (data.share_mode == 1 or data.share_mode == 2) then
        if sync_id == 0 then
            self:DEBUG_LOG("can't create shared role by sync_id 0 and side ~= 1, share_mode = ", data.share_mode);
            return
        end
    end

    local npc = battle_config.LoadNPC(data.id)

    assert(npc, 'npc ' .. data.id .. ' not exists');

    local cfg = {
        refid = data.refid,

        side  = side,
        pos   = data.pos,
        level = data.level,
        id    = data.id,

        skills = {},

        name  = npc.name,
        mode  = data.mode,
        icon  = npc.mode~=data.mode and data.mode or npc.icon,--如果npc形象穿着时装则使用时装Icon
        -- icon  = npc.icon,
        scale = npc.scale,

        x = data.x or 0,
        y = data.y or 0,
        z = data.z or 0,

        share_mode = data.share_mode,
        sync_id    = sync_id,

        enter_script = data.skills[5] or 0,

        grow_star  = data.grow_star,
        grow_stage = data.grow_stage,
        assist_cd  = data.assist_cd,

        server_uuid = data.uuid,

        npc_type = npc.npc_type,

        wave = data.wave,

        v = {
            sync_id = true;
            pos = true;
        }
    };

    if data.pos <= 100 then
        cfg.skills = {
            battle_config.LoadSkill(data.skills[1]),
            battle_config.LoadSkill(data.skills[2]),
            battle_config.LoadSkill(data.skills[3]),
            battle_config.LoadSkill(data.skills[4]),
        };
    else
        for k, v in ipairs(data.assist_skills) do
            if v.id ~= 0 and v.weight ~= 0 then
                table.insert(cfg.skills, setmetatable({weight = v.weight}, {__index=battle_config.LoadSkill(v.id)}));
            end
        end
    end

    local property_list = {};
    for _, vv in ipairs(data.propertys) do
        property_list[vv.type] = (property_list[vv.type] or 0) + vv.value;
    end

    local reader = nil;
    if (side == 1 and (data.pos >= 1 and data.pos <= 5)) or data.share_mode == 2 then
        reader = function(...)
            self:Dispatch("UNIT_INPUT", ...);
        end
    end

    if npc.npc_type == 3 then
        self:InitAiProperty(data.level, data.id, cfg, property_list)
    end

    return self:AddRole(Role(self, property_list, cfg, reader));
end

function Battle:InitAiProperty(level, id, cfg, property_list)
    local ai_suit, ai_titles = battle_config.LoadAiNpcCfg(level, id)

    local range_1 = #ai_titles > 0 and #ai_titles or 1
    local range_2 = #ai_suit.suit_rand_pool > 0 and #ai_suit.suit_rand_pool or 1
    local random_num_1, random_num_2 = self:AiPropertyRandom(range_1, range_2)

    if next(ai_titles) then
        local title = ai_titles[random_num_1]
        cfg.Ai_Title = title.title_name
        property_list[title.title_script] = 1
    end

    if next(ai_suit) then
        local suit_cfg = battle_config.LoadSuitCfg(ai_suit.suit_rand_pool[random_num_2])

        if ai_suit.num >= 2 then
            local k = suit_cfg[2][ai_suit.quality].type1
            local v = suit_cfg[2][ai_suit.quality].value1
            property_list[k] = (property_list[k] or 0 ) + v
        end

        if ai_suit.num >= 4 then
            local k = suit_cfg[4][ai_suit.quality].type1
            local v = suit_cfg[4][ai_suit.quality].value1
            property_list[k] = (property_list[k] or 0 ) + v    
        end
 
        if ai_suit.num >= 6 then
            local k = suit_cfg[6][ai_suit.quality].type1
            local v = suit_cfg[6][ai_suit.quality].value1
            property_list[k] = (property_list[k] or 0 ) + v    
        end
    end
end

function Battle:AiPropertyRandom(range_1, range_2)
    local rng = WELLRNG512a(self.fight_data.defender.pid)
    local a = (rng() % range_1) + 1
    local b = (rng() % range_2) + 1

    return a, b
end

function Battle:AddRole(role)
    for _, v in pairs(self.roles) do
        if v.refid == role.refid and v.sync_id == role.sync_id then
            self:DEBUG_LOG('role ', v.name, "is already in battle")
            return;
        end
    end

    assert(role.hp   and role.hp   > 0, 'battle role need `hp` field');
    assert(role.side and role.side > 0, 'battle role need `side` field');
    assert(role.pos  and role.pos  > 0, 'battle role need `pos` field');

    self.wave_limit  = self.timeline.wave + 10;
    -- self.round_limit = self.timeline.round + 100;

    -- local wave = (role.share_mode > 0) and self.timeline.wave or role.wave;
    local wave = role.wave;

    if role.pos > 100 then
        if self.assistant == nil then
            self.assistant = Assistant(self, 1);
            self.timeline:Assist(self.assistant)
        end
        self.assistant:Add(role);
    else
        self.timeline:Add(role, wave);
        if wave == 1 then
            self:OnRoleEnter(role)
        end
    end
    return role;
end

function Battle:Fastforward()
    while not self.sleepingManager:IsEmpty() do
        self.sleepingManager:Tick()
        self.eventManager:Tick();
    end
end

function Battle:Update(dt, max_tick)
    if not self.thread or self.paused then return; end

    self.time_left = self.time_left + dt;
    local tick = math.floor(self.time_left * TICK_PER_SECOND);
    if tick == 0 then return; end

    for i = 1, tick do
        self:Tick(max_tick)

        if self.paused then
            self.time_left = 0;
            return;
        end
    end

    self.time_left = self.time_left - tick / TICK_PER_SECOND;
end

function Battle:Tick(max_tick)
    self.tick = self.tick + 1;
    self.sleepingManager:Tick()
    self.eventManager:Tick();

    if not self.sleepingManager:IsEmpty() then
        return;
    end

    if self.buffManager.running then
        self.buff_running_start_tick = (self.buff_running_start_tick or 0) + 1;
        if self.buff_running_start_tick >= 600 then
            self:DEBUG_LOG("Battle:Tick self.buffManager.running tick > 300, skip")
            self.buff_running_start_tick = nil;
        else
            self:DEBUG_LOG("Battle:Tick self.buffManager.running")
            return;
        end
    else
        self.buff_running_start_tick = nil;
    end

    if self.timeline.running then
        self:DEBUG_LOG("Battle:Tick self.timeline.running")
        return;
    end

    -- self.commandQueue:Tick(self.timeline.tick)

    if not max_tick or self.timeline.tick <= max_tick then
        self.timeline:Tick()
        if self.timeline.is_object_idle then
            self.commandQueue:Tick(self.timeline.tick, self.timeline.waiting_input)
        end
    end

    self.eventManager:Tick();
end

function Battle:Pause()
    self.paused = true;
end

function Battle:Resume()
    self.paused = false;
end

function Battle:Start()
    if self.thread then
        return;
    end

    self.thread = {}
end

function Battle:Stop()
    self.thread = nil;
end

function Battle:API_FindUnit(_, unit)
    return unit;
end

local function matchFilter(role, filters, reverseFilters, assistant)
    if role == assistant then
        return false;
    end
    if role[7015] > 0 and role[7008] == 0 then return false end;

    for _, v in ipairs(reverseFilters or {}) do
        if role.property[v] > 0 then
            return false;
        end
    end

    if filters == nil then return true; end

    for _, v in ipairs(filters or {}) do
        if role.property[v] <= 0 then
            return false;
        end
    end
    return true;
end

function Battle:API_FindEnemy(attacker, filters, reverseFilters)
    for _, v in pairs(self.roles) do
        if v.pos <= 100 and v.side ~= attacker.side and matchFilter(v, filters, reverseFilters, self.assistant) then
            return v;
        end
    end
end

function Battle:API_FindAllEnemy(attacker, filters, reverseFilters)
    local t = {};
    for _, v in pairs(self.roles) do
        if v.pos <= 100 and v.side ~= attacker.side and matchFilter(v, filters, reverseFilters, self.assistant) then
            table.insert(t, v);
        end
    end

    table.sort(t, function(a,b)
        return a.pos < b.pos;
    end)

    return t;
end

function Battle:API_FindPartner(attacker, filters, reverseFilters)
    for _, v in pairs(self.roles) do
        if v.pos <= 100 and v.side == attacker.side and matchFilter(v, filters, reverseFilters, self.assistant) then
            return v;
        end
    end
end

function Battle:API_FindAllPartner(attacker, filters, reverseFilters)
    local t = {};
    for _, v in pairs(self.roles) do
        if v.pos <= 100 and v.side == attacker.side and matchFilter(v, filters, reverseFilters, self.assistant) then
            table.insert(t, v);
        end
    end

    table.sort(t, function(a,b)
        return a.pos < b.pos;
    end)

    return t;
end

function Battle:API_FindAllUnitLit(attacker, filters, reverseFilters)
    return self:API_FindAllUnit(attacker, filters, reverseFilters);
end

function Battle:API_Sleep(attacker, n)
    local co = coroutine.running();
    assert(co and (not coroutine.isyieldable or coroutine.isyieldable()), 'must sleep in thread');

    local tick = math.floor(n * TICK_PER_SECOND);
    if tick <= 0 then tick = 1; end

    self.sleepingManager:Wait(co, tick);

    return coroutine.yield();
end

function Battle:CleanSleep()
    self.sleepingManager:Clean()
end

function Battle:API_UnitPlay(attacker, ...)
    self:Dispatch("UnitPlay",...);
end

function Battle:API_UnitPlayLoopAction(attacker, role, action)
    self:Dispatch("UnitPlayLoopAction", role, action);
end

function Battle:API_UnitChangeMode(attacker, target, mode_id)
    self:Dispatch("UnitChangeMode", target, mode_id)
end

function Battle:API_UnitConsumeActPoint(attacker, n)
    attacker:ConsumeActPoint(n);
end

function Battle:API_UnitRegainActPoint(attacker, n)
    attacker:RegainActPoint(n);
end

function Battle:API_UnitHurt(attacker, role, n, valueType, num_text)
    local value, absorbValue = role:Hurt(n, valueType, num_text);
    value = value or 0;
    absorbValue = absorbValue or 0;
    attacker.record.total_hurt = (attacker.record.total_hurt or 0) + (value + absorbValue);
end

function Battle:API_UnitHealth(attacker, role, n, valueType, num_text)
    local value = role:Health(n, valueType, num_text);
    attacker.record.total_health = (attacker.record.total_health or 0) + value;
end

function Battle:API_UnitChangeMP(attacker, role, n, typa)
    typa = typa or 'mp';
    role:ChangeMP(n, typa);
    self:Dispatch("UpdateRoleEpBar", role);
end

function Battle:API_UnitPetList(attacker,target)
    target = target or attacker;
    if target.petManager == nil or target.petManager == 0 then
        return {};
    end
    return target.petManager:All();
end

function Battle:API_AddEffect(attacker, ...)
    self:Dispatch("AddEffect",...);
end

function Battle:API_UnitAddEffect(attacker, ...)
    self:Dispatch("UnitAddEffect",...);
end

function Battle:API_AddStageEffect(attacker, ... )
    self:Dispatch("AddStageEffect", attacker, ...);
end

function Battle:API_GuideChangeScene(attacker, map)
    self:Dispatch("GuideChangeScene",map);
end

function Battle:API_StageAddEffect(attacker, ... )
    self:Dispatch("StageAddEffect",...);
end

function Battle:API_UnitShowNumber(attacker, role, value, point, type, name)
    self:Dispatch("UnitShowNumber", role, value, point, type, name);
end

function Battle:API_UnitShowBuffEffect(attacker, role, name, isUp)
    self:Dispatch("UnitShowBuffEffect", role, name, isUp);
end

function Battle:API_ChangeBuffEffect(attacker, buff, effect)
    self:Dispatch("ChangeBuffEffect", buff, effect);
end

function Battle:API_UnitAddBuff(attacker, target, id, _round, context, extra)
    context = context or {};
    local buff = self.buffManager:Add(target, id, context, extra);
    target.UNIT_PropertyChange = true;
    context.uuid = buff.uuid;
    return buff;
end

function Battle:API_UnitRemoveBuff(attacker, buff)
    self.buffManager:Remove(buff);
    buff.target.UNIT_PropertyChange = true;
end

function Battle:API_UnitMoveBuff(attacker, buff, target)
    self.buffManager:Move(buff, target);
    if buff.target ~= target then
        buff.target.UNIT_PropertyChange = true;
        target.UNIT_PropertyChange = true;
    end
end

function Battle:API_LoadBuffCfg(attacker, id)
    return self.buffManager:LoadBuffCfg(id);
end

function Battle:API_UnitPlayHit(attacker, target)
    self:Dispatch("UnitPlayHit",target);
end

function Battle:API_UnitChangeColor(attacker, target, color, params)
    self:Dispatch("UnitChangeColor",target, color, params);
end

function Battle:API_UnitChangeAlpha(attacker, target, alpha)
    self:Dispatch("UnitChangeAlpha",target, alpha);
end

function Battle:API_StageEffect_Shake(attacker)
    self:Dispatch("StageEffect_Shake");
end

function Battle:API_StageEffect_Scale(attacker, target, scale, params)
    self:Dispatch("StageEffect_Scale",target, scale, params);
end

function Battle:API_ChangeScene(attacker, name, effect, animations, options)
    self:Dispatch("ChangeScene",name, effect, animations, options);
end

function Battle:API_ShowBattleWarning(attacker, type, offset)
    self:Dispatch("ShowBattleWarning", type, offset);
end

function Battle:API_showErrorInfo(attacker, desc)
    self:Dispatch("showErrorInfo", desc);
end

function Battle:API_BattleChatClick(attacker, enabled)
    self:Dispatch("BattleChatClick", enabled);
end

function Battle:API_UnitWait(attacker, target)
    target = target or attacker;
    target:Wait();
end

function Battle:API_PlaySound(attacker, name)
    self:Dispatch("PlaySound",name)
end

local function BulletGetter(t, k)
    if t.cfg[k] == nil then
        return 0;
    else
        return t.cfg[k];
    end
end

local fight_parameter_calc = require "battlefield.fight_parameter_calc"

local function BulletSetter(t, k, v)
    v = fight_parameter_calc:Bullet_calc(t, k, v)
    t.cfg[k] = v;
end

function Battle:API_CreateBullet(attacker, hurt, health, effect, cfg, hitEffectName, hitEffectCfg)
    self.bullet_uuid = self.bullet_uuid or 0;
    self.bullet_uuid = self.bullet_uuid + 1;
    local bullet = setmetatable({
        attacker = attacker, 
        game = self, target = nil,
        disabled = false,
        num_text = "",
        hurt = hurt or 0, health = health or 0, 
        base = { hurt = hurt, health = health },
        effect = effect, cfg = cfg or {},
        hit = { effect = hitEffectName, cfg = hitEffectCfg or {}, },
        skip = {},
        uuid = self.bullet_uuid,
    }, {__index=BulletGetter, __newindex=BulletSetter})
    return bullet;
end

local function cloneTable(t)
    local nt = {}
    for k, v in pairs(t) do
        nt[k] = v
    end
    return nt;
end

local function BulletClone(bullet)
    return setmetatable({
        attacker = bullet.attacker, target = bullet.target, game = bullet.game,
        hurt = bullet.hurt,    health  = bullet.health, disabled = bullet.disabled,
        base = {hurt = bullet.base.hurt, health = bullet.base.health},
        effect = bullet.effect, cfg = cloneTable(bullet.cfg), num_text = bullet.num_text,
        hit = {effect = bullet.hit.effect, cfg = cloneTable(bullet.hit.cfg)},
        skip = cloneTable(bullet.skip),
    }, {__index = BulletGetter, __newindex = BulletSetter});
end

local function BulletSnap(bullet)
    bullet.snap = BulletClone(bullet);
end

local function BulletFilter(bullet, role, action)
    bullet.game.eventManager:dispatchImmediately(action, role, bullet);
end

function Battle:API_BulletClone(attacker, bullet)
    return BulletClone(bullet.snap or bullet)
end

local function BulletHit(bullet)
    local attacker = bullet.attacker
    local target = bullet.target
    local game = bullet.game

    if target.owner ~= 0 and target.count == 0 then
        return game:DEBUG_LOG("pet is dead", target.uuid)
    end

    local owner = (target.owner ~= 0) and target.owner or target;
    
    if not bullet.game:GetRole(owner.uuid) then
        return game:DEBUG_LOG('bullet target not exists', target.uuid, target.name)
    end

    BulletFilter(bullet, attacker, "BULLET_attackerBeforeHit")
    BulletFilter(bullet, target, "BULLET_targetBeforeHit") 

    BulletFilter(bullet, target, "BULLET_targetFilter")
    game:API_Sleep(nil, 0)
    -- hurt
    bullet.hurt_final_value = game.fight_hurt_calc.Hurt(bullet);
    game:API_Sleep(nil, 0)
    -- health
    bullet.heal_final_value = game.fight_hurt_calc.Heal(bullet);

    game:API_Sleep(nil, 0)
    BulletFilter(bullet, attacker, "BULLET_attackerAfterCalc")
    BulletFilter(bullet, target, "BULLET_targetAfterCalc")
    if bullet.disabled then return; end

    BulletFilter(bullet, attacker, "BULLET_attackerWillHit")
    BulletFilter(bullet, target, "BULLET_targetWillHit")
    if bullet.disabled then return; end

    -- hurt
    bullet.hurt_final_value = math.floor(bullet.hurt_final_value);
    -- health
    bullet.heal_final_value = math.floor(bullet.heal_final_value);

    if bullet.hurt_final_value > 0 then
        game:API_UnitHurt(attacker, target, bullet.hurt_final_value, bullet.hurt_number_prefab, bullet.num_text);
    end

    if bullet.heal_final_value > 0 then
        game:API_UnitHealth(attacker, target, bullet.heal_final_value, bullet.heal_number_prefab, bullet.num_text);
    end

    bullet.target.shield = nil;

    local s_attacker = bullet.attacker;
    if bullet.attacker.owner and bullet.attacker.owner ~= 0 then
        s_attacker = bullet.attacker.owner;
    end

    local statistics = game.statistics.partners[s_attacker.id];
    if statistics then
        statistics.damage = statistics.damage + bullet.hurt_final_value
        statistics.health = statistics.health + bullet.heal_final_value
    end

    local statistics = game.statistics.partners[bullet.target.id];
    if statistics then
        statistics.hurt = statistics.hurt + bullet.hurt_final_value
    end

    game:API_Sleep(nil, 0)
    -- effect
    if bullet.hit.effect then
        game:Dispatch("UnitAddEffect", bullet.target, bullet.hit.effect, bullet.hit.cfg)
    end

    BulletFilter(bullet, attacker, "BULLET_attackerAfterHit")
    BulletFilter(bullet, target, "BULLET_targetAfterHit")
end

function Battle:API_BulletFire(attacker, bullet, target, duration)
    -- bullet.attacker = attacker;
    if target == nil then
        ERROR_LOG("bullet fire must have target");
        return;
    end

    bullet.target = target;
    bullet.game = self;

    duration = duration or 0.1;
    bullet.cfg.duration = duration;

    ASSERT(coroutine.resume(coroutine.create(function()
        BulletFilter(bullet, attacker, "BULLET_attackerBeforeAttack")
        BulletFilter(bullet, target, "BULLET_targetBeforeAttack")

        BulletFilter(bullet, attacker, "BULLET_attackerFilter")

        BulletFilter(bullet, attacker, "BULLET_attackerAfterAttack")
        BulletFilter(bullet, target, "BULLET_targetAfterAttack")

        if bullet.disabled then return; end

        if bullet.effect ~= nil then
            local from = bullet.attacker;

            if bullet.from and bullet.from ~= 0 then
                from = bullet.from;
            end
            self:Dispatch("CreateBullet", from, bullet.target, bullet.effect, bullet.cfg);
        end

        self:API_Sleep(nil, duration);

        BulletHit(bullet);
    end)))
end

function Battle:Sleep(n, callback)
    ASSERT(coroutine.resume(coroutine.create( function ()
        self:API_Sleep(nil, n)
        callback();
    end)));
end

function Battle:API_PlayGuide(attacker, id, delay)
    self:Dispatch("PlayBattleGuide", id, delay)
end

function Battle:API_UnitShow(attacker, target)
    self:Dispatch("UnitShow",target or attacker)
end

function Battle:API_UnitBuffList(attacker, target)
    return self.buffManager:Get(target);
end

function Battle:API_StageAddPowerEffect(attacker, info)
    self:Dispatch("StageAddPowerEffect",info)
end

function Battle:API_BuffChangeRound(attacker, buff, newRound)
    assert(false, "API_BuffChangeRound discard");
end

function Battle:API_SummonPet(attacker, id, count, cd, property)
    if attacker.petManager == nil or attacker.petManager == 0 then
        return;
    end
    return attacker.petManager:Add(id, count or 1, cd or 1, property or {})
end

function Battle:API_CameraMoveTo(attacker, pos, offset, time)
    self:Dispatch("CameraMoveTo", pos, offset, time);
end

function Battle:API_CameraLookAt(attacker, pos, offset, time)
    self:Dispatch("CameraLookAt", pos, offset, time);
end

function Battle:API_EnemyMoveFront(attacker, ...)
    self:Dispatch("EnemyMoveFront", ...)
end

function Battle:API_EnemyMoveBack(attacker, ...)
    self:Dispatch("EnemyMoveBack", ...)
end

function Battle:API_PlaySound(attacker, ...)
    self:Dispatch("PlaySound", ...)
end

function Battle:API_ShowTotalHurt(attacker, role, value)
    self:Dispatch("ShowTotalHurt", role, value)
end

function Battle:API_SetAutoInput(attacker, auto)
    self:Dispatch("SetAutoInput", auto)
end

function Battle:ForceNextLevel()
--[[
    for _, v in ipairs(l) do
        self.commandQueue:Push({
            type    = "HURT",
            pid     = 0,
            refid   = v.refid,
            sync_id = v.sync_id,
            value   = math.ceil(v.hp / 5),
        })
    end
--]]
end

function Battle:API_SkillGetInfo(attacker, target, index)
    target = target or attacker;
    if index then
        if target.skill_boxs then
            return target.skill_boxs[index] or target.skill_boxs.saved[index];
        end
    else
        return target.select_skill;
    end
end

function Battle:API_SkillChangeId(attacker, skill, id)
    if skill and skill.owner.pos < 100 then
        skill:ChangeID(id)
        self:Dispatch("SKILL_CHANGE", attacker, skill);
    end
end

function Battle:API_UnitSelectSkill(attacker, target, ...)
    target = target or attacker;
    target:SelectSkill(...);
end

function Battle:API_SkillAddEffect(attacker, skill, effect, n)
end

function Battle:API_SkillRemoveEffect(attacker, skill, effect)
end

function Battle:API_SkillChangCD(attacker, skill, cd)
    -- assert(type(skill) == "table", debug.traceback());
    if skill then
        skill.current_cd = cd;
    end
end

function Battle:API_SkillChangType(attacker, type, skill)
    skill = skill or attacker.select_skill;
    skill.skill_type = type;
end

function Battle:API_SceneChange(attacker, name)
    self:Dispatch('CHANGE_SCENE', name)
    self.current_scene = name
end


function Battle:API_GetSceneName()
    return self.current_scene or self.fight_data.scene
end

function Battle:API_ShowBattleHalo(attacker, skill)
    self:Dispatch('ShowBattleHalo', skill)
end

function Battle:SetBattleFocusTag(role, type)
    if type == 0 then
        self:DEBUG_LOG("SetBattleFocusTag", 0)
        for _, v in pairs(self.roles) do
            v._Focus_tag = 0
        end
    elseif role then
        self:DEBUG_LOG("SetBattleFocusTag", role.refid, role.sync_id, role.name, type)
        role._Focus_tag = type
        -- self:Dispatch('SetBattleFocusTag', role, type)
    end
end

function Battle:RAND(...)
    self.rng = self.rng or WELLRNG512a(self.seed);
    local a, b = select(1, ...);

    local o = self.rng();

    if not a then
        local f = math.floor(o / 0xffffffff * 100) / 100;
        self:DEBUG_LOG("RAND", o, a, b, "->",f);
        return f
    end

    if a <= 0 then
        assert(a > 0, 'interval is empty' .. debug.traceback());
    end

    local v = 0;
    if not b then
        v = 1 + o % a;
    elseif b >= a then
        v = a + (o % (b-a+1))
    else
        v = a;
    end

    self:DEBUG_LOG("RAND", o, a, b, "->", v);

    return v;
end

function Battle:API_RAND(attacker, ...)
    return self:RAND(...);
end

function Battle:API_SummonMonster(attacker, id, pos, remove)
    return self.timeline:Summon(id, pos, remove)
end

function Battle:API_RemoveMonster(attacker, target)
    self.timeline:Remove(target, true);
end

function Battle:DeadList()
    local t = {}
    for _, v in pairs(self.timeline.current_wave_dead_list) do
        table.insert(t, v)
    end
    return t;
end

function Battle:API_GetDeadList()
    return self:DeadList();
end

function Battle:API_UnitRelive(attacker, target, hp)
    if target.share_mode == 0 then
        target:Relive(hp);
    end
end

function Battle:API_Exit(attacker, winner)
    self.timeline.force_winner = winner or 1;
    self:Dispatch('EXIT_FIGHT', target, text, duration, effect);
end

function Battle:API_SetForceWinner(attacker, winner, force)
    if attacker and attacker.share_mode == 0 or force then
        self.timeline.force_winner = winner or 1;
    end
end

function Battle:API_ShowDialog(attacker, target, text, duration, effect, cfg)
    target = target or attacker;
    self:Dispatch('SHOW_DIALOG', target, text, duration, effect, cfg)
end

function Battle:API_AddConversation(attacker, target, message, bg, clean_delay)
    target = target or attacker;
    self:Dispatch('AddConversation', target, message, bg, clean_delay);
end

function Battle:API_ChangeDiamond(attacker, index)
    attacker.diamond_index = index;
    self:Dispatch("ChangeDiamond", index);
end

function Battle:API_UnitChangeSkin(attacker, target, skinName)
    self:Dispatch("UnitChangeSkin", target or attacker, skinName);
end

function Battle:API_ShowUI(attacker, show)
    self:Dispatch("ShowUI", show);
end

function Battle:API_ShowMonsterInfo(attacker, info_id, ...)
    self:Dispatch("ShowMonsterInfo", attacker, info_id);
end

function Battle:API_GetFightType()
    return self.fight_data.fight_type;
end

function Battle:API_GetBattleData()
    if not self.battle_script_data.___have_meta then
        self.battle_script_data.___have_meta = true;
        setmetatable(self.battle_script_data, {__index = function(t, k)
            if k == "current_wave" then
                return self.timeline.wave;
            end
        end})
    end
    self.record_list = {}
    return self.battle_script_data
end

function Battle:API_AddRecord(attacker, id, type, value)
    self.battle_event_record = self.battle_event_record or {};
    if type == "max" then
        if not self.battle_event_record[id] or value > self.battle_event_record[id] then
            self.battle_event_record[id] = value;
        end
    elseif type == "min" then
        if not self.battle_event_record[id] or value < self.battle_event_record[id] then
            self.battle_event_record[id] = value;
        end
    else
        self.battle_event_record[id] = (self.battle_event_record[id] or 0) + (value or 1);
    end
end

function Battle:API_SetSingBar(attacker, target, active, values)
    self:Dispatch("SetSingBar" , target, active, values)
end

function Battle:GetEventRecord()
    if not self.battle_event_record then
        return {}
    end

    local t = {}
    for k, v in pairs(self.battle_event_record) do
        table.insert(t, {k,v})
    end
    return t;
end

local star_checker = {
    [1] = function(battle) 
        return battle.timeline.winner == 1;
    end,
    [2] = function(battle, value) -- "全队平均血量X%血量";
        local hp, hpp = 0, 0;
        for _, v in pairs(battle.statistics.partners) do
            hp = hp + v.role.hp;
            hpp = hpp + v.role.hpp;
        end

        if hpp == 0 then
            return false;
        end

        return (hp / hpp) >= (value / 100)
    end,

    [3] = function(battle, value) -- 通关关卡时血量最少的角色剩余X%血量
        for _, v in pairs(battle.statistics.partners) do
            if v.role.hp / v.role.hpp < value / 100 then
                return false
            end
        end
        return true
    end,

    [4] = function(battle, value) --  通过阵亡人数少于N
        local dead = 0;
        for _, v in pairs(battle.statistics.partners) do
            if v.role.hp <= 0 then
                dead = dead + 1;
            end
        end
        return dead < value
    end,

    [5] = function(battle, value) -- 在X回合内通关
        return battle.statistics.total_round <= value
    end,

    [6] = function(battle, value) -- 没有使用XX技能通关
        return not battle.statistics.skills_used[value]
    end,

    [7] = function(battle, id1, id2) -- 在同一回合内击杀怪物1和怪物2
        if not battle.statistics.monsters[id1] or not battle.statistics.monsters[id2] then
            return false
        end
        return battle.statistics.monsters[id1].leave_round == battle.statistics.monsters[id2].leave_round
    end,

    [8] = function(battle, id, round) -- 怪物(id)存活不超过round回合
        if not battle.statistics.monsters[id] then
            return false
        end
        return battle.statistics.monsters[id].leave_round - battle.statistics.monsters[id].enter_round <= round
    end,

    [9] = function(battle, value) -- 通过关卡时造成最高伤害达到
        return battle.statistics.max_damage >= value
    end,

    [10] = function(battle, value) -- 通过关卡时己方受到伤害不超过x
        return battle.statistics.total_hurt <= value
    end,
}

function Battle:CheckStar(id, ...)
    if star_checker[id] then
        return star_checker[id](self, ...)
    end
end

function Battle:DEBUG_LOG(...)
    if not UnityEngine or UnityEngine.Application.isEditor then
        print(...)
    end
    BATTLE_LOG(self.seed, self.timeline.tick, ...);
end

return Battle;
