local class = require "utils.class"
local Thread = require "utils.Thread"

local function array_new()
	return { objs = {} }
end

local function array_find(array, obj)
	return array.objs[obj.uuid];
end

local function array_remove(array, obj)
	for i = #array, 1, -1 do
		if array[i] == obj then
			array.objs[obj.uuid] = nil;
			local v = table.remove(array, i)
			return v;
		end
	end
end

local function array_push(array, obj)
	if not array.objs[obj.uuid] then
		array.objs[obj.uuid] = obj
		table.insert(array, obj)
		array.dirty = true;
	end
end

local function array_pop(array)
	local obj = array[#array]
	if obj then
		array.objs[obj.uuid] = nil
		array_remove(array, obj)
	end
	return obj;
end

local  function array_peek(array)
	return array[#array]
end

local function order_queue_sort(queue, work_as_defender)
	if queue.dirty then
		queue.dirty = false;
		table.sort(queue, function(b, a)
			if a.lock  ~= b.lock  then return a.lock end
			if a.share_mode == 2 and b.share_mode ~= 2 then return false end;
			if a.share_mode ~= 2 and b.share_mode == 2 then return true  end;
			if a.speed ~= b.speed then return a.speed > b.speed end

			if a.side ~= b.side then 
				if work_as_defender then
					return (a.side >= b.side)
				else
					return (a.side <  b.side) 
				end
			end

			return a.pos < b.pos
		end)
		return true;
	end
end

local function order_queue_insert(queue, obj)
	array_push(queue, obj)
end

local function order_queue_remove(queue, obj)
	return  (array_remove(queue, obj))
end

local function order_queue_next(queue)
	return (array_peek(queue))
end

local function order_queue_pop(queue)
	return (array_pop(queue))
end

local function waiting_stack_push(stack, obj)
	return (array_push(stack, obj))
end

local function waiting_stack_pop(stack)
	return (array_pop(stack))
end

local function waiting_stack_next(stack)
	return (array_peek(stack))
end

local Timeline = class()
function Timeline:_init_(eventManager)
	assert(eventManager and eventManager.addListener and eventManager.dispatch, 'timeline must init with a EventManager');
	self.eventManager = eventManager;

	self.round = 0
	self.wave  = 0
	self.waves = { }
	self.max_wave = 0;
	self.total_round = 0;

	self.assit_objects = {}

	self.current_round_order_queue = array_new()
	self.next_round_order_queue    = array_new()
	self.current_round_wait_stack  = array_new()

	self.current_wave_dead_list = {}
	self.current_round_object_tick = {};

	self.side_left = {}
	self.winner = 0;
	self.enter_script_count = 0;
	self.tick = 0;
	self.next_tick_action = {}

	local this = self;
	eventManager:addListener("UNIT_SPEED_CHANGE", function(_, obj) this:UNIT_SPEED_CHANGE(obj); end)
	eventManager:addListener("UNIT_DEAD_SYNC",    function(_, obj) this:UNIT_DEAD_SYNC(obj); end)
	eventManager:addListener("UNIT_RELIVE",       function(_, obj) this:UNIT_RELIVE(obj); end)
	eventManager:addListener("UNIT_WAIT",         function(_, obj) this:UNIT_WAIT(obj); end)
	eventManager:addListener("UNIT_FINISHED",     function(_, obj) this:UNIT_FINISHED(obj); end)
	eventManager:addListener("UNIT_SKILL_ERROR",  function(_, obj) this:UNIT_SKILL_ERROR(obj); end)
end

function Timeline:DEBUG_LOG(...)
	if self.game then
		self.game:DEBUG_LOG(...)
	else
		print(...)
	end 
end

function Timeline:WorkAsDefender()
	self.work_as_defender = true;
end

function Timeline:WorkAsAttacker()
	self.work_as_defender = false;
end

function Timeline:Dispatch( ... )
	self.eventManager:dispatch(...)
end

function Timeline:DispatchSync(...)
	self.eventManager:dispatchImmediately(...)
end

function Timeline:SortAssistant(queue, side)
	local assistant = self.assit_objects[side]
	if assistant and array_find(queue, assistant) then
		array_remove(queue, assistant);
		queue.objs[assistant.uuid] = assistant;
		for i = 1, #queue do
			if queue[i].side == side then
				table.insert(queue, i, assistant)
				return;
			end
		end
		table.insert(queue, assistant)
	end
end

function Timeline:UNIT_SPEED_CHANGE(obj)
	if array_find(self.current_round_order_queue, obj) then
		self:Sort(self.current_round_order_queue)
	elseif array_find(self.next_round_order_queue, obj) then
		self:Sort(self.next_round_order_queue);
	end
end

function Timeline:UNIT_DEAD_SYNC(obj)
	self:Remove(obj);
end

function Timeline:UNIT_RELIVE(obj)
	if self.current_wave_dead_list[obj.uuid] then
		self.current_wave_dead_list[obj.uuid] = nil;
		self:Add(obj, self.wave);
	end
	-- return self.dead[obj.uuid] and self:Add(obj) or nil;
end

function Timeline:UNIT_WAIT(obj)
	assert(obj);
	obj.lock = false;

	if array_find(self.current_round_order_queue, obj) then
		local assistant = self.assit_objects[obj.side];

		if assistant and obj ~= assistant and array_find(self.current_round_order_queue, assistant) then
			order_queue_remove(self.current_round_order_queue, assistant)
			waiting_stack_push(self.current_round_wait_stack, assistant)
		end

		order_queue_remove(self.current_round_order_queue, obj)
		waiting_stack_push(self.current_round_wait_stack, obj)
		self:Sort();
	end
end

function Timeline:UNIT_SKILL_ERROR(obj)
	self.error = true;
end

function Timeline:Index(idx)
	if idx <= #self.current_round_order_queue then
		return self.current_round_order_queue[#self.current_round_order_queue - idx + 1]
	end
	idx = idx - #self.current_round_order_queue;

	if idx <= #self.current_round_wait_stack then
		return self.current_round_wait_stack[#self.current_round_wait_stack - idx + 1]
	end
	idx = idx - #self.current_round_wait_stack

	if idx <= #self.next_round_order_queue then
		return self.next_round_order_queue[#self.next_round_order_queue - idx + 1]
	end
end

function Timeline:DUMP()
	for i = #self.current_round_order_queue, 1, -1 do
		print("+", self.current_round_order_queue[i].name);
	end

	for i = #self.current_round_wait_stack, 1, -1 do
		print("+", self.current_round_wait_stack[i].name);
	end

	for i = #self.next_round_order_queue, 1, -1 do
		print("+", self.next_round_order_queue[i].name);
	end
end

function Timeline:_getter_(key)
	if type(key) ~= "number" or key < 0 or (key+2^52)-2^52 ~= key then
		return
	end
	return (self:Index(key));
end

function Timeline:_setter_(key, v)
	if type(key) == "number" and key > 0 and (key+2^52)-2^52 == key then
		assert("can't set index of timeline");
	end
	rawset(self, key, v);
end

function Timeline:Add(obj, wave)
	wave = wave or self.wave + 1

	-- assert(class.check(obj, TimelineObject))

	assert(obj.side and obj.side ~= 0, 'timeline object must have side')
	assert(obj.timeline == 0 or obj.timeline == nil, 'add object to timeline more than one times');
	assert(wave >= self.wave, 'add object to timeline with wrong wave ' .. wave .. "/" .. self.wave)

	obj.lock = false;

	self.winner = nil;

	if wave > self.max_wave then
		self.max_wave = wave;
	end

	if wave == self.wave then
		obj.timeline = self;
		obj.round = self.round + 1;

		if self.assit_objects[obj.side] ~= obj then
			self.side_left[obj.side] = (self.side_left[obj.side] or 0) + 1;
		end

		order_queue_insert(self.next_round_order_queue, obj);
		self:Sort(self.next_round_order_queue);

		self:Dispatch("TIMELINE_Enter", obj);
		-- self:Dispatch("UnitShow", obj);

		obj:SetActive()

		if obj.enter_script  
            and obj.enter_script ~= 0 
            and obj.enter_script ~= "0" then

			self.enter_script_count = self.enter_script_count + 1;
			self.running =  true;
			ASSERT(coroutine.resume(coroutine.create(function()
				obj:RunScriptFile(obj.enter_script);
				self.enter_script_count = self.enter_script_count - 1;
				if self.enter_script_count <= 0 then
					self.running = nil;
				end
			end)))
		end
	else
		-- add object for waiting
		self.waves[wave] = self.waves[wave] or {}
		table.insert(self.waves[wave], obj);
	end

	if self.waiting_roles_enter_thread then
		self.waiting_roles_enter_thread:send_message('TIMELINE_ROLE_ENTER');
	end

	return obj;
end

function Timeline:UNIT_FINISHED(obj)
	assert(obj);

	self:DEBUG_LOG("Timeline:UNIT_FINISHED", obj.name)

	local find = false;
	if order_queue_remove(self.current_round_order_queue, obj) then
		order_queue_insert(self.next_round_order_queue, obj);

		obj.lock = false;
		self:Sort(self.current_round_order_queue, self.next_round_order_queue)

		find = true;
	elseif order_queue_remove(self.current_round_wait_stack, obj) then
		order_queue_insert(self.next_round_order_queue, obj);

		obj.lock = false;
		self:Sort(self.next_round_order_queue)

		find = true;
	end

	if find then
		self:DispatchSync("TIMELINE_AfterAction_SYNC", obj);
		self:Dispatch("TIMELINE_AfterAction", obj);
	end

	self.finished_in_tick = true;

	self.tick = self.tick + 1; self:DEBUG_LOG("++++++++++++++++++++++ obj finished", self.tick);
end

function Timeline:Assist(obj)
	self.assit_objects[obj.side] = obj;
	self:Add(obj);
end

function Timeline:Summon(id, pos, remove)
	for _, list in pairs(self.waves) do
		for k, v in ipairs(list) do
			if v.id == id and v.pos == pos then
				if remove then
					table.remove(list, k);
				end
				self:Add(v, self.wave);
				return;
			end
		end
	end
end

function Timeline:Remove(obj, forceRemove)
	obj.lock = false;
	obj.timeline = nil;

	if array_find(self.current_round_order_queue, obj) then
		array_remove(self.current_round_order_queue, obj)
		self:Sort(self.current_round_order_queue);
	elseif array_find(self.current_round_wait_stack, obj) then
		array_remove(self.current_round_wait_stack, obj)
	elseif array_find(self.next_round_order_queue, obj) then
		array_remove(self.next_round_order_queue, obj);
		self:Sort(self.next_round_order_queue);
	else
		assert(false, 'remove object not in timeline');
	end

	self.side_left[obj.side] = self.side_left[obj.side] - 1;

	if forceRemove then
		self:DispatchSync("TIMELINE_Leave_Sync", obj);
		self:Dispatch("TIMELINE_Leave", obj);
		self:Dispatch("TIMELINE_Remove", obj);
	else
		self.current_wave_dead_list[obj.uuid] = obj;
		self:DispatchSync("TIMELINE_Leave_Sync", obj);
		self:Dispatch("TIMELINE_Leave", obj);
	end

	--[[
	if self:GetWinner() and not self.winner then
		-- self.tick = self.tick + 1; self:DEBUG_LOG("++++++++++++++++++++++ obj before action", self.tick);
	end
	-- self:CheckWinner()
	--]]
end

function Timeline:Tick()
	self.waiting_input = false;
	self.is_object_idle = false;
	
	if self.running then
		return;
	end

	if self.finished_in_tick then
		self.finished_in_tick = nil;
		return;
	end

	local func = table.remove(self.next_tick_action, 1);
	if func then
		return func();
	end

	if self.call_next_wave_on_next_tick then
		self.call_next_wave_on_next_tick = nil;
		return self:NextWave();
	end

	self:CheckWinner();

	local obj = order_queue_next(self.current_round_order_queue) or waiting_stack_next(self.current_round_wait_stack);
	if self.winner then
		if  obj and self.current_round_object_tick[obj.uuid] then
			self:UNIT_FINISHED(obj);
		end
		self.call_next_wave_on_next_tick = true;
		self.is_object_idle = true;
		return;
	end

	if self.call_next_round_on_next_tick then
		self.call_next_round_on_next_tick = nil;
		 self:NextRound();
		 return;
	end

	if not obj then
		self:FinishRound();
		self.call_next_round_on_next_tick = true;
		return;
	end

	if not self.current_round_object_tick[obj.uuid] then
		if not obj:Renew() then
			return;
		end

		obj.lock = true;

		self.current_round_object_tick[obj.uuid] = 0;

		self:DEBUG_LOG("TIMELINE_BeforeAction", obj.name);

		self:DispatchSync("TIMELINE_BeforeAction_SYNC", obj);
		self:Dispatch("TIMELINE_BeforeAction", obj);

		self.tick = self.tick + 1; self:DEBUG_LOG("++++++++++++++++++++++ obj before action", self.tick);

		return;
	end

	if self.current_running_obj ~= obj then
		self.tick = self.tick + 1; self:DEBUG_LOG("++++++++++++++++++++++ obj parepare action", self.tick);

		self:Dispatch("TIMELINE_StartAction", obj);
		self.current_running_obj = obj;
	end

	local ready, is_prepare_step = obj:PrepareCommand(self.current_running_obj_prepared) 
	if not ready then
		self.current_running_obj_prepared = true;
		if not is_prepare_step then
			self.waiting_input = true;
			self.is_object_idle = true;
		end
		return;
	end

	self.current_running_obj_prepared = false;

	self.tick = self.tick + 1; self:DEBUG_LOG("++++++++++++++++++++++ obj start action", self.tick);

	self.current_round_object_tick[obj.uuid] = self.current_round_object_tick[obj.uuid] + 1;
	if self.current_round_object_tick[obj.uuid] > 200 then
		self:Finished("error")

		if UnityEngine and UnityEngine.Application.isEditor then
			showDlgError(nil, "[" .. obj.name .. "] 尝试行动次数过多，请检查相关【技能脚本】")
			showDlg(nil, "[" .. obj.name .. "] 尝试行动次数过多，请检查相关【技能脚本】", function ()end)
		end
		assert(false, string.format('too much action for object %s  pos %d', obj.name, obj.pos));
		return;
	end

	if self.call_obj_action_next_tick then
		self.call_obj_action_next_tick = nil;
		self.running = coroutine.create(function()
			obj:Action();
			table.insert(self.next_tick_action, function()
				self.current_running_obj = nil;
				self:Dispatch("TIMELINE_EndAction", obj);
				self.tick = self.tick + 1; self:DEBUG_LOG("++++++++++++++++++++++ obj end action", self.tick);
			end)

			self.running = nil;
		end)
		ASSERT(coroutine.resume(self.running));
	else
		self.tick = self.tick + 1; self:DEBUG_LOG("++++++++++++++++++++++ obj  start action", self.tick);
		self.call_obj_action_next_tick = true;
	end
end

function Timeline:Sort(...)
	for _, queue in ipairs({...}) do
		if order_queue_sort(queue, self.work_as_defender) then
			self:SortAssistant(queue, 1);
		end
	end
	self:Dispatch("TIMELINE_Update");
end

function Timeline:IsFailedByRoundLimit()
	return self.failed_round_limit and self.failed_round_limit > 0 and self.total_round > self.failed_round_limit;
end

function Timeline:CheckRoundLimit()
	if self.failed_round_limit and self.failed_round_limit > 0 and self.total_round > self.failed_round_limit then
		return 2
	end

	if self.win_round_limit and self.win_round_limit > 0 and self.total_round >= self.win_round_limit and self.side_left[1] > 0 then
		return 1;
	end
end

function Timeline:GetWinner()
	if self.force_winner then
		return self.force_winner
	end

	if self.winner then
		return self.winner
	end

	local winner = self:CheckRoundLimit()
	if winner then
		return winner;
	end

	local side, n = 0, 0

	for k, v in ipairs(self.side_left) do
		if v > 0 then
			side = k
			n = n + 1
		end
	end

	if n <= 1 then
		return side;
	end
end

function Timeline:CheckWinner()
	local winner = self:GetWinner()
	if not winner then
		return;
	end

	if self.winner == winner then
		return self.winner
	end

	self.winner = winner

	local obj = order_queue_next(self.current_round_order_queue) or waiting_stack_next(self.current_round_wait_stack);
	if obj and self.current_round_object_tick[obj.uuid] then
		self:UNIT_FINISHED(obj);
	end

	self:FinishRound();
	self:FinisheWave();
	self.call_next_wave_on_next_tick = true;

	return self.winner
end

function Timeline:NextRound()
	self:DEBUG_LOG("Timeline:NextRound", self.round);
	while true do
		local obj = order_queue_pop(self.next_round_order_queue);
		if not obj then break; end
		obj.lock = false;
		array_push(self.current_round_order_queue, obj);
	end

	while true do
		local obj = waiting_stack_pop(self.current_round_wait_stack);
		if not obj then break; end
		obj.lock = false;
		array_push(self.current_round_order_queue, obj);
	end
	self:Sort(self.current_round_order_queue)

	self.current_round_object_tick = {};
	self.round = self.round + 1;
	self.total_round = self.total_round + 1;

	self.tick = self.tick + 1; self:DEBUG_LOG("++++++++++++++++++++++ before round", self.tick);

	self:DispatchSync("TIMELINE_BeforeRound_SYNC");
	self:Dispatch("TIMELINE_BeforeRound");
end

function Timeline:FinishRound()
	if self.round > 0 then
		self:DEBUG_LOG("TIMELINE_AfterRound", self.round);
		self:DispatchSync("TIMELINE_AfterRound_SYNC");
		self:Dispatch("TIMELINE_AfterRound");
		assert(self.total_round * 1000 > self.tick);
		self.tick = self.total_round * 1000; self:DEBUG_LOG("++++++++++++++++++++++ finish round", self.tick);
	end
end

function Timeline:HaveMoreEnemy()
	return self.waves[self.wave + 1];
end

function Timeline:NextWave()
	if not self.winner and self:CheckRoundLimit() then
		return self:Finished("round limit");
	end

	-- move left role
	while true do
		local obj = order_queue_pop(self.current_round_order_queue);
		if not obj then break; end
		obj.lock = false;
		array_push(self.next_round_order_queue, obj);
	end

	while true do
		local obj = waiting_stack_pop(self.current_round_wait_stack);
		if not obj then break; end
		obj.lock = false;
		array_push(self.next_round_order_queue, obj);
	end
	self:Sort(self.next_round_order_queue)

	-- clean dead enemy, left side 1
	local dead = {}
	for _, v in pairs(self.current_wave_dead_list) do
		if v.side == 1 then
			dead[v.uuid] = v;
		else
			self:Dispatch("TIMELINE_Remove", v);
		end
	end
	self.current_wave_dead_list = dead;
	self.round = 0

	-- find new enemy
	local current_wave, waiting_objects = self.wave, self.waves[self.wave];
	if not waiting_objects then
		current_wave, waiting_objects = self.wave + 1, self.waves[self.wave + 1];
	end

	local new_enemy= false;
	local add_list = {};
	for _, obj in ipairs(waiting_objects or {}) do
		if obj.side ~= self.winner then
			new_enemy = true;
		end
		table.insert(add_list, obj);
	end
	self.waves[current_wave] = nil; -- remove waiting object

	-- add new enemy to wave
	for _, v in ipairs(add_list) do
		self:Add(v, self.wave);
		self.winner = nil; -- reset winner record
	end

	local last_wave = self.wave
	if self:CheckWinner() then
		return self:Finished("winner");
	else
		self:DEBUG_LOG("Timeline:NextWave", self.wave, self.winner)
		self.wave = current_wave;
	end

	if last_wave > 0 then
		self:DEBUG_LOG("TIMELINE_BeforeWave ", self.wave, #add_list);
		self.tick = self.tick + 1; self:DEBUG_LOG("++++++++++++++++++++++ wave", self.tick);
	end;

	if self.wave > 0 then
		self:Dispatch("TIMELINE_BeforeWave");
	end
end

function Timeline:Finished(reason)
	if self.last_finished_wave ~= self.wave and self.wave > 0 then
		self.tick = self.tick + 1; self:DEBUG_LOG("++++++++++++++++++++++ finished", reason or "", self.tick);
		self:DEBUG_LOG('TIMELINE_Finished, winner side', self.winner); -- TODO:
		self:DispatchSync("TIMELINE_Finished", self.winner);
		self.last_finished_wave = self.wave;
	end
end

function Timeline:FinisheWave()
	-- change round when wave change
	if self.wave > 0 then
		-- clean dead enemy, left side 1
		local dead = {}
		for _, v in pairs(self.current_wave_dead_list) do
			if v.side == 1 then
				dead[v.uuid] = v;
			else
				self:Dispatch("TIMELINE_Remove", v);
			end
		end
		self.current_wave_dead_list = dead;

		self:Dispatch("TIMELINE_AfterWave");
	end
end

return Timeline
