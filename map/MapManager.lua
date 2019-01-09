require "Agent"

require "Scheduler"

local Map = {}
local maps = {}

local MAX_PLAYER_COUNT = 10;
local MIN_CHANNEL_NUM    = 1 
local CHANNEL_PRIVATE = 1
local CHANNEL_PUBLIC  = 2
local CHANNEL_TEAM    = 3
local CHANNEL_GUILD   = 4
local MAX_CHANNEL_NUM = 4

local playerMapId = {}
local ai_list = {}

local next_group_id = 0;
local function GroupID()
	next_group_id = next_group_id + 1;
	return next_group_id;
end

-- bot
local map_bots = {
	[1] = {
		[CHANNEL_PRIVATE] = {
			[5] = {5}	
		},
		[CHANNEL_PUBLIC] = {
			[1] = {1, 2, 3, 4}
		},
		[CHANNEL_TEAM] = {

		}
	}
}--{ [1] = {1, 2, 3, 4} }

local map_bots = {}

Scheduler.New(function()
	for mid, channels in pairs(map_bots) do
		local map = Map.Get(mid)
		for channel, rooms in pairs(channels) do
			for room, bots in pairs(rooms) do 
				for _, bot in ipairs(bots) do
					map:Move(bot, math.random() * 10 - 5, math.random() * 10 - 5, 0)
				end
			end
		end
	end
end)


-- bot end


function Map.Get(id)
	if not id then return nil; end

	if maps[id] == nil then
		local channels = {};
		for i = 1, MAX_CHANNEL_NUM do
			table.insert(channels, {});
		end

		maps[id] = setmetatable({id = id, objects={},channels=channels}, {__index=Map});

--[[
		map_bots[id] = {}
		for i = 1, 18 do
			maps[id]:Add(i);
			table.insert(map_bots[id], i);
		end
--]]
	end

	return maps[id];
end

local function Notify(pid, objects, ...)
	for k, _ in pairs(objects) do
		local agent = Agent.Get(k);			
		if agent then
			agent:Notify(...)
		end
	end

	-- notify team members
	local team = getTeamByPlayer(pid)
	if team then
		for _, v in ipairs(team.members) do
			if not objects[v.pid] then
				local agent = Agent.Get(v.pid)
				if agent then
					print(string.format("Notify player %d player %d move", v.pid, pid))
					agent:Notify(...);
				end
			end
		end
	end
end

local function IsTeamMember(pid)
	local team = getTeamByPlayer(pid)
	if not team then
		return false
	end

	if team.leader.pid == pid then
		return false
	end

	for _, id in ipairs(team.afk_list) do
		if id == pid then
			return false
		end	
	end

	return true, team.leader.pid
end

function Map:Add(id, channel, room, x, y, z, move_style)
	x = x or 0;
	y = y or 0;
	z = z or 0;

	channel = channel or CHANNEL_PUBLIC
	room = room or 1 

	if self.objects[id] then
		return self.objects[id].group.objects;
	end

	if channel < MIN_CHANNEL_NUM or channel > MAX_CHANNEL_NUM then
		log.debug(string.format("channel %d too big or too small", channel))
		channel = CHANNEL_PRIVATE
	end

	if not self.channels[channel][room] then
		local groups = {}
		for i = 1, MAX_PLAYER_COUNT, 1 do
			table.insert(groups, {})
		end
		self.channels[channel][room] = groups 
	end

	local obj = { id = id, channel = channel, room = room,  pos = {x, y, z}, move_style = move_style}


	local selectGroup = nil

--[[
	-- find leader group
	local team = getTeamByPlayer(id);
	if team and playerMapId[team.leader.pid] == self.id then
		selectGroup = self.objects[team.leader.pid].group;
	end
--]]

	if not selectGroup then
		for _, v in ipairs(self.channels[channel][room]) do
			selectGroup = next(v);
			if selectGroup then
				selectGroup = v[selectGroup];
				break;
			end
		end
	end

	if not selectGroup or selectGroup.count == MAX_PLAYER_COUNT then
		selectGroup = {id = GroupID(), objects = {} }
		selectGroup.count = 0;
	else
		self.channels[channel][room][selectGroup.count][selectGroup.id] = nil;
	end

	log.debug(string.format('map %d channel %d room %d add object %d', self.id, obj.channel, obj.room, id));

	selectGroup.objects[id] = obj
	selectGroup.count = selectGroup.count + 1;

	self.channels[channel][room][selectGroup.count][selectGroup.id] = selectGroup;

	obj.group = selectGroup;

	self.objects[id] = obj;

	playerMapId[id] = self.id;

	-- TODO: notify to client
	Notify(id, selectGroup.objects, {Command.NOTIFY_MAP_MOVE, {id, x, y, z}});

	if id < 100000 then
        ai_list[id] = true
    end

	return selectGroup.objects;
end

local moveCache = {}
local CACHE_CD = 1 

local function recordMoveCache(id, x, y, z)
	local info = moveCache[id] or {last_broad_time = 0};
	if info.x == x and info.y == y and info.z == z then
		return false;
	end

	local now = loop.now()
	local need_broadcast = (now - info.last_broad_time > CACHE_CD)

	info.x = x
	info.y = y
	info.z = z
	
	if need_broadcast then
		info.last_broad_time = now
	else
		info.dirty = true
	end

	moveCache[id] = info;

	return need_broadcast;
end

local function cleanMoveCache(id)
	if moveCache[id] then
		moveCache[id] = nil
	end
end

function Map:Remove(id)
	local obj = self.objects[id];
	if not obj then
		return;
	end

	local group  = obj.group;
	local channel = obj.channel
	local room = obj.room
	self.channels[channel][room][group.count][group.id] = nil;
	group.objects[obj.id] = nil;
	group.count = group.count - 1;

	if group.count > 0 then
		self.channels[channel][room][group.count][group.id] = group;
	end

	log.debug(string.format('map %d channel %d room %d remove object %d', self.id, obj.channel, obj.room, id));

	-- TODO: notify to client
	Notify(id, group.objects, {Command.NOTIFY_MAP_MOVE, {id}});

	self.objects[id] = nil;

	playerMapId[id] = nil;

	cleanMoveCache(id)

	if ai_list[id] then
        ai_list[id] = nil
    end

	return obj;
end

function Map:Replace(old_id, new_id)
	if old_id == new_id then
		return 
	end

	local obj = self.objects[old_id]
	if not obj then
		return 
	end

	obj.id = new_id;

	self.objects[new_id] = obj;
	self.objects[old_id] = nil;

	obj.group.objects[new_id] = obj;
	obj.group.objects[old_id] = nil;

	playerMapId[new_id] = self.id
	playerMapId[old_id] = nil;

	if new_id < 100000 then
        ai_list[new_id] = true
    end
	ai_list[old_id] = nil;
end


function Map:Move(id, x, y, z, move_style)
	local obj = self.objects[id]
	if not obj then
		return
	end

	local group = obj.group;

	if obj.x == x and obj.y == y and obj.z == z then
		return;
	end

	obj.pos = {x, y, z}
	obj.move_style = move_style;

	log.debug(string.format('map %d channel %d room %d move object %d to (%s,%s, %s)', self.id, obj.channel, obj.room, id, x, y, z));

	if recordMoveCache(id, x, y, z) then
		Notify(id, group.objects, {Command.NOTIFY_MAP_MOVE, {id, x, y, z}})
	end
end

function Map:GetPlayerPos(id)
	local obj = self.objects[id]
	if not obj then
		return
	end

	return {self.id, obj.pos[1], obj.pos[2], obj.pos[3], obj.channel, obj.room}
end

function Map:NotifySync(id, data, leader_id)
	leader_id = leader_id or id;

	local obj = self.objects[leader_id]	
	if not obj then
		return 
	end

	if not data then
		return 
	end

	local group = obj.group;

	Notify(id, group.objects, {Command.NOTIFY_MAP_SYNC, data})
	return true
end

function Map.GetByObject(id)
	return Map.Get(playerMapId[id]);
end

function Map.Enter(id, mid, channel, room, x, y, z, move_style)
	local map = Map.GetByObject(id)

	if map then
		if map.id ~= mid then
			-- player not in save map
			map:Remove(id);
		else
			local obj = map.objects[id];
			if obj and (obj.channel ~= channel or obj.room ~= room) then
				-- player not in save channel or room
				map:Remove(id);
			end
		end
	end

	map = Map.Get(mid);
	
	local objects = map:Add(id, channel, room, x, y, z, move_style);

	return objects;
end


local remove_list = {}
local POS_SAVE_TIME = 5 * 60 
function Map.OnPlayerLogout(id)
	local map = Map.GetByObject(id);
	if map then
		--map:Remove(id);
		remove_list[id] = {id = id, remove_time = loop.now() + POS_SAVE_TIME}
	end
end

function Map.OnPlayerLogin(id)
	if remove_list[id] then
		remove_list[id] = nil
	end
end

Scheduler.New(function(t)
	for id, v in pairs(remove_list) do
		if t > v.remove_time then
			local map = Map.GetByObject(id);
			if map then
				map:Remove(id);
			end		
			remove_list[id] = nil
		end	
	end
end)

for mid, bots in pairs(map_bots) do
	for mid, channels in pairs(map_bots) do
		local map = Map.Get(mid)
		for channel, rooms in pairs(channels) do
			for room, bots in pairs(rooms) do 
				for _, bot in ipairs(bots) do
					Map.Enter(bot, mid, channel, room, 0, 0, 0)
				end
			end
		end
	end
end

function Map.registerCommand(service)
	service:on(Command.C_MAP_MOVE_REQUEST, function(conn, pid, request)
		local sn = request[1];
		local x = request[2] or 0;
		local y = request[3] or 0;
		local mid = request[4];
		local channel = request[5] or CHANNEL_PUBLIC
		local room = request[6] or 1;
		local move_style = request[7];

		local objects;
		local info

		local z = 0;
		if type(x) == "table" then
			local pos = x;
			x, y, z = pos[1], pos[2], pos[3]
		end

		local old_move_style = Map.GetMoveStyle(pid)
		local is_team_member, leader_pid = IsTeamMember(pid)
		if move_style == nil then
			local target_pid = pid--is_team_member and leader_pid or pid;
			local map = Map.GetByObject(target_pid)
			if map and map.objects[target_pid] then
				move_style = map.objects[target_pid].move_style or 0;
			end
		end

		move_style = move_style or 0;

		if is_team_member and move_style == 0 then
			if old_move_style ~= 0 then
				Map.RemoveObject(pid, true)
			end

			local map = Map.GetByObject(leader_pid)
			if map then
				objects = map.objects[leader_pid].group.objects 	
				info = {}
				for _, v in pairs(objects) do
					table.insert(info, {v.id, v.pos[1], v.pos[2], v.pos[3]});
				end
				return conn:sendClientRespond(Command.C_MAP_MOVE_RESPOND, pid, {sn, Command.RET_SUCCESS, info});
			else
				return conn:sendClientRespond(Command.C_MAP_MOVE_RESPOND, pid, {sn, Command.RET_ERROR});
			end
		end

		local map = Map.GetByObject(pid);

		if not map and (not mid or not channel) then
			conn:sendClientRespond(Command.C_MAP_MOVE_RESPOND, pid, {sn, Command.RET_CHANNEL_INVALID});
			return;
		end

		if not map or mid or (mid and map.id ~= mid) then
			mid = mid or 1
			objects = Map.Enter(pid, mid, channel, room, x, y, z, move_style);
		else
			map:Move(pid, x, y, z, move_style);
		end

		if objects then
			info = {}
			for _, v in pairs(objects) do
				table.insert(info, {v.id, v.pos[1], v.pos[2], v.pos[3]});
			end
		end

		conn:sendClientRespond(Command.C_MAP_MOVE_RESPOND, pid, {sn, Command.RET_SUCCESS, info});
	end)

	service:on(Command.C_MAP_QUERY_PLAYER_INFO_REQUEST, function(conn, pid, request)
		local sn = request[1];
		local tid = request[2] or pid;

		log.debug(string.format("Player %d begin to query target_player %d map info", pid, tid))
		local map = Map.GetByObject(tid);
		if not map then
			log.debug(string.format("not in map"))
			conn:sendClientRespond(Command.C_MAP_QUERY_PLAYER_INFO_RESPOND, pid, {sn, Command.RET_ERROR});
		else
			local pos_info = map:GetPlayerPos(tid)
			conn:sendClientRespond(Command.C_MAP_QUERY_PLAYER_INFO_RESPOND, pid, {sn, pos_info and Command.RET_SUCCESS or Command.RET_ERROR, pos_info});
		end

	end)

	service:on(Command.S_MAP_QUERY_POS_REQUEST, "MapQueryPosRequest", function(conn, channel, request)
        local cmd = Command.S_MAP_QUERY_POS_RESPOND;
        local proto = "MapQueryPosRespond";

        if channel ~= 0 then
            log.error(id .. "Fail to `S_MAP_QUERY_POS_REQUEST`, channel ~= 0")
            sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_PREMISSIONS});
            return;
        end

        local tid = request.pid
		local map = Map.GetByObject(tid);
		if not map then
			log.debug(string.format("not in map sn %d", request.sn))
            return sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_ERROR});
		else
			local pos_info = map:GetPlayerPos(tid)
			if pos_info then
            	return sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_SUCCESS, mapid = pos_info[1], x = pos_info[2], y = pos_info[3], z = pos_info[4], channel = pos_info[5], room = pos_info[6]});
			else
            	return sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_ERROR});
			end
		end
    end)

	service:on(Command.C_MAP_NOTIFY_SYNC_REQUEST, function(conn, pid, request)
		local sn = request[1];
		local data = request[2]

		log.debug(string.format("Player %d begin to notify sync", pid))

		local map = Map.GetByObject(pid);

		local inTeam, leader_id = nil, nil;
		if not map then
			inTeam, leader_id = IsTeamMember(pid);
			if inTeam then
				map = Map.GetByObject(leader_id);
			end
		end

		if not map then
			log.debug(string.format("not in map"))
			conn:sendClientRespond(Command.C_MAP_NOTIFY_SYNC_RESPOND, pid, {sn, Command.RET_ERROR});
		else
			local success = map:NotifySync(pid, data, leader_id)
			conn:sendClientRespond(Command.C_MAP_NOTIFY_SYNC_RESPOND, pid, {sn, success and Command.RET_SUCCESS or Command.RET_ERROR});
		end

	end)

	service:on(Command.S_MAP_MOVE_REQUEST, "MapMoveRequest", function(conn, channel, request) 
		local cmd = Command.S_MAP_MOVE_RESPOND;
		local proto = "aGameRespond";

		if channel ~= 0 then
			log.error(id .. "Fail to `S_MAP_MOVE_REQUEST`, channel ~= 0")
			sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_PREMISSIONS});
			return;
		end

		local pid = request.pid
		local x = request.x
		local y = request.y
		local z = request.z
		local mid = (request.mapid ~= 0) and request.mapid or nil;
		local chanl = (request.channel ~= 0) and request.channel or CHANNEL_PUBLIC
		local room = (request.room ~= 0) and request.room or 1;

		local objects;
		--[[local z = 0;
		if type(x) == "table" then
			local pos = x;
			x, y, z = pos[1], pos[2], pos[3]
		end--]]

		--log.debug(string.format("AI %d move  x %f y %f z %f", pid, x, y, z))
		local map = Map.GetByObject(pid);
		if not map and (not mid or not channel) then
			return sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn, result = Command.RET_CHANNEL_INVALID});
		end

		local is_team_member, leader_pid = IsTeamMember(pid)
		if is_team_member then
			return sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn, result = Command.RET_SUCCESS});
		end

		if not map or mid or (mid and map.id ~= mid) then
			mid = mid or 1
			--log.debug(string.format("AI %d enter >>>>>>>>>>", pid))
			objects = Map.Enter(pid, mid, chanl, room, x, y, z, 0);
		else
			--log.debug(string.format("AI %d move >>>>>>>>>>", pid))
			map:Move(pid, x, y, z, 0);
		end

		--log.info("Success `S_MAP_MOVE`")
		sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn, result = Command.RET_SUCCESS});
	end)
end

function Map.CleanAIData()
	log.debug("AI service restart , begin to clean map data")
	for id, _ in pairs(ai_list) do
		local map = Map.GetByObject(id);
		if map then
			map:Remove(id);
		end
	end
end

function Map.Sync(pid, data)
	local map = Map.GetByObject(pid);

	local inTeam, leader_id = nil, nil;
	if not map then
		inTeam, leader_id = IsTeamMember(pid);
		if inTeam then
			map = Map.GetByObject(leader_id);
		end
	end

	if not map then
		log.debug(string.format("Map Sync fail, not in map"))
		return 
	else
		return map:NotifySync(pid, data, leader_id)
	end
end

function Map.RemoveObject(pid, force)
	local map = Map.GetByObject(pid);
	if not map then
		log.debug(string.format("Map RemoveObject fail, not in map"))
		return 
	else
		local move_style = nil
		if map.objects[pid] then
			move_style = map.objects[pid].move_style or 0;
		end
		move_style = move_style or 0

		if move_style ~= 0 and not force then
			log.debug(string.format("Map fail to RemoveObject, move_style is %d", move_style))
			return 
		end

		return map:Remove(pid)
	end
end

function Map.GetMoveStyle(id)
	local map = Map.GetByObject(old_id);
	if not map then
		return 0
	end

	local move_style = nil
	if map.objects[id] then
		move_style = map.objects[id].move_style or 0;
	end
	move_style = move_style or 0

	return move_style
end

function Map.ReplaceObject(old_id, new_id)
	local map = Map.GetByObject(old_id);
	if not map then
		log.debug(string.format("Map ReplaceObject fail, not in map"))
		return 
	else
		--[[local move_style = nil
		if map.objects[old_pid] then
			move_style = map.objects[old_pid].move_style or 0;
		end
		move_style = move_style or 0

		if move_style ~= 0 then
			log.debug(string.format("Map fail to ReplaceObject, move_style is %d", move_style))
			return 
		end

		return map:Replace(old_id, new_id)--]]
		local o_move_sytle = Map.GetMoveStyle(old_id)	
		local n_move_sytle = Map.GetMoveStyle(new_id)	
		if o_move_style == 0 and n_move_style == 0 then
			map:Replace(old_id, new_id)
		elseif o_move_style ~= 0 and n_move_style ~= 0 then
			--do nothing
		elseif o_move_style	== 0 and n_move_style ~= 0 then
			Map.RemoveObject(old_id)
		elseif o_move_style ~= 0 and n_move_style == 0 then
			local pos = Map.GetPlayerPos(old_id)
			if pos then
				Map.Enter(new_id, pos[1], pos[5], pos[6], pos[2], pos[3], pos[4], 0);
			end	
		end	
	end
end

function Map.GetPos(pid)
	local map = Map.GetByObject(pid);
	if not map then
		return
	else
		local pos_info = map:GetPlayerPos(pid)
		return pos_info
	end	
end


local function BroadPlayerPosition(id, x, y, z)
	local map = Map.GetByObject(id)
	if not map then return end
	local obj = map.objects[id];
	if not obj then return end

	Notify(id, obj.group.objects, {Command.NOTIFY_MAP_MOVE, {id, x, y, z}});
end

local function PrintMapObject(mapid, channel, room)
	channel = channel or CHANNEL_PUBLIC
	room = room or 1 
	local map = Map.Get(mapid)
	if map then
		local public_map 	
		if map.channels and map.channels[channel] and map.channels[channel][room] then
			public_map = map.channels[channel][room]
		end

		if public_map then
			for count, v in pairs(public_map) do
				for group_id, group in pairs(v) do
					for id, _ in pairs(group.objects) do
						log.debug(string.format("PrintMapObject: map %d channel %d room %d  group_count %d group_id %d pid %d %s", mapid, channel, room, count, group_id, id, IsTeamMember(pid) and "member" or "not member"))
					end	
				end
			end
		end
	end
end

Scheduler.New(function(t)
	for id, v in pairs(moveCache) do
		if t - v.last_broad_time >= CACHE_CD then
			if v.dirty then
				v.dirty = false
				v.last_broad_time = t
				BroadPlayerPosition(id, v.x, v.y, v.z)
			else
				moveCache[id] = nil
			end
		end	
	end

	if t % 5 == 0 then
		--PrintMapObject(10)
	end
end)


return Map
