


--[[
create table build_city_player (
	`pid` bigint,
	`round_index` integer,
	`today_count` integer,
	`update_time` timestamp,
	`current_group` int not null default 0,
	primary key (`pid`)
) DEFAULT CHARSET=utf8;
--]]

local database = require "database"
local Command = require "Command"
local cell = require "cell"

--[[
database = database or {
	query = function(...)
		print(string.format(...));
		return true, {}
	end,
	
	update = function(...)
		print(string.format(...));
		return true;
	end
}

loop = loop or {
	now = function() return os.time(); end
}

log = log or {
	debug = function(...) return print(...) end,
	info = function(...) return print(...) end,
	error = function(...) return print(...) end,
}
--]]


local BOSS = require "CityContructBoss";

local START_TIME = 1467302400
local PERIOD_TIME = 3600 * 24

local QUEST_POOL = {
	[41] = { 101, 102, 103, 104, 105, 106, 107, 108, 109, 110 },
	[42] = { 201, 202, 203, 204, 205, 206, 207, 208, 209, 210 },
	[43] = { 301, 302, 303, 304, 305, 306, 307, 308, 309, 310 },
	[44] = { 401, 402, 403, 404, 405, 406, 407, 408, 409, 410 },
}

local QUEST_TYPES = {}
for k, _ in pairs(QUEST_POOL) do
	table.insert(QUEST_TYPES, k);
end

local QUEST_COUNT_PRE_ROUND = #QUEST_POOL[41];
local DAILY_MAX_ROUND  = 2

local function ROUND(t)
	return math.floor((t-START_TIME)/PERIOD_TIME);
end

local function update_player_data(player)
	if ROUND(player.update_time) ~= ROUND(loop.now()) then
		player.today_count = 0;
		player.update_time = loop.now();
	end
	return player;
end

local players = {}
local function get_player_info(pid)
	if not players[pid] then
		local success, rows = database.query('select round_index, today_count, unix_timestamp(update_time) as update_time from build_city_player where pid = %d', pid);
		if not success then
			return nil;
		end

		local player = {pid = pid}
		if rows[1] == nil then
			player.not_in_database = true;
			player.round_index   = 0;
			player.today_count   = 0;
			player.update_time   = loop.now();
		else
			player.round_index = rows[1].round_index;
			player.today_count = rows[1].today_count;
			player.update_time = rows[1].update_time;
		end

		players[pid] = player;
	end

	local player = players[pid]

	if not player.quest_uuid then
		local quests = cell.QueryPlayerQuestList(pid, QUEST_TYPES);
		if quests and quests[1] then
			player.quest_uuid = quests[1].uuid;
			player.current_group = quests[1].type;
		else
			print(' ---> empty');
			player.quest_uuid = 0;
			player.current_group = 0;
		end
	end

	return update_player_data(players[pid]);
end

local function save_player_data(player, only_round_index)
	if player.not_in_database then
		if database.update('insert into build_city_player (pid, round_index, today_count, update_time) values(%d, %d, from_unixtime_s(%d), %d)',
				player.pid, player.round_index, player.today_count, player.update_time) then
			player.not_in_database = nil;
		end
	elseif only_round_index then
		return database.update('update build_city_player set round_index = %d where pid = %d', player.round_index, player.pid);
	else
		return database.update('update build_city_player set round_index = %d, today_count = %d, update_time = from_unixtime_s(%d) where pid = %d',
				player.round_index, player.today_count, player.update_time, player.pid);
	end
end


local  function add_quest_to_player(pid, group, idx)
	local pool = QUEST_POOL[group][idx];
	if not pool then
		return nil;
	end

	log.debug(string.format('------- pid %d, activity %d, pool %d', pid, group, pool));

	return cell.SetPlayerQuestInfo(pid, {pool = pool}) or 0;
end

local function player_accept_quest(pid, group)
	local player = get_player_info(pid);

	log.debug(string.format("player %d accept quest of group %d, finished count %d, pool %d", player.pid, group, player.today_count, player.round_index + 1));

	if not QUEST_POOL[group] then
		log.debug(" group error");
		return;
	end

	print('----', player.current_group, group);

	if player.current_group ~= 0 and player.current_group ~= group then
		log.debug(" group not match");
		return;
	end

	if player.today_count >= QUEST_COUNT_PRE_ROUND * DAILY_MAX_ROUND and player.round_index == 0 then
		log.debug(" reach daily limit");
		return;
	end

	if player.quest_uuid ~= 0 then
		log.debug(" already have quest uuid %d", player.quest_uuid);
		return;
	end

	player.quest_uuid = add_quest_to_player(pid, group, player.round_index+1);

	if player.quest_uuid == 0 then
		log.debug(string.format(' add quest failed'));
		return;
	end

	log.debug(string.format("  uuid %d", player.quest_uuid));

	player.current_group = group;

	return player.quest_uuid;
end

local function player_cancel_quest(pid)
	local player = get_player_info(pid);

	log.debug(string.format("player %d cancel quest, uuid %d", pid, player.quest_uuid));

	if player.quest_uuid == 0 then
		log.debug("  quest not exists");
		return false;
	end

	if not cell.SetPlayerQuestInfo(pid, {uuid = player.quest_uuid, status = 2}) then
		log.debug("  cancel quest failed");
		return;
	end

	player.round_index   = 0;
	player.quest_uuid    = 0;
	player.current_group = 0;

	save_player_data(player, true);
	return true;
end

local function player_submit_quest(pid)
	local player = get_player_info(pid);

	log.debug(string.format("player %d submit quest, uuid %d", pid, player.quest_uuid));

	if player.quest_uuid == 0 then
		log.debug("  quest not exists");
		return false;
	end

	local rich_reward = false;
	if player.today_count < QUEST_COUNT_PRE_ROUND * DAILY_MAX_ROUND then
		rich_reward = true;
	end

	local uuid = player.quest_uuid;
	if not cell.SetPlayerQuestInfo(pid, {uuid = uuid, status = 1, rich_reward = rich_reward}) then
		log.debug("  submit quest failed");
		return;
	end

	player.quest_uuid = 0
	player.today_count = player.today_count + 1;
	player.round_index = (player.round_index + 1) % QUEST_COUNT_PRE_ROUND;
	player.update_time = loop.now();

	--quest
	cell.NotifyQuestEvent(pid, {{type = 4, id = 6, count = 1}, {type = 86,id = player.current_group, count = 1}})

	save_player_data(player);

	BOSS.AddExp(player.current_group, 1);

	return uuid;
end


local service = select(1, ...);


service:on(Command.C_MANOR_CITY_CONTRUCT_ACCEPT_QUEST_REQUEST, function(conn, pid, request)
	local sn = request[1];
	local group = request[2] or 1;
	log.debug(string.format('player %d accept quest, group %d', pid, group)); 

	local uuid = player_accept_quest(pid, group);

	conn:sendClientRespond(Command.C_MANOR_CITY_CONTRUCT_ACCEPT_QUEST_RESPOND, pid, {sn, uuid and Command.RET_SUCCESS or Command.RET_ERROR, uuid});
end)

service:on(Command.C_MANOR_CITY_CONTRUCT_CANCEL_QUEST_REQUEST, function(conn, pid, request)
	local sn = request[1];
	log.debug(string.format('player %d cancel quest', pid)); 

	local ret = player_cancel_quest(pid);

	local player = get_player_info(pid);
	conn:sendClientRespond(Command.C_MANOR_CITY_CONTRUCT_CANCEL_QUEST_RESPOND, pid, {sn, ret and Command.RET_SUCCESS or Command.RET_ERROR, player.round_index, player.today_count});
end);

service:on(Command.C_MANOR_CITY_CONTRUCT_SUBMIT_QUEST_REQUEST, function(conn, pid, request)
	local sn = request[1];
	log.debug(string.format('player %d submit quest', pid)); 

	local ret = player_submit_quest(pid);

	local player = get_player_info(pid);

	conn:sendClientRespond(Command.C_MANOR_CITY_CONTRUCT_SUBMIT_QUEST_RESPOND, pid, {sn, ret and Command.RET_SUCCESS or Command.RET_ERROR, player.round_index, player.today_count});
end);

service:on(Command.C_MANOR_CITY_CONTRUCT_INTERACT_REQUEST, function(conn, pid, request)
	local sn = request[1];
	local id = request[2];
	log.debug(string.format('player %d interact %d', pid, id)); 

	-- local ret = true; -- player_submit_quest(pid);

	local ret = BOSS.Fight(pid, id);

	conn:sendClientRespond(Command.C_MANOR_CITY_CONTRUCT_INTERACT_RESPOND, pid, {sn, ret and Command.RET_SUCCESS or Command.RET_ERROR});
end);


service:on(Command.C_MANOR_CITY_CONTRUCT_QUERY_REQUEST,function(conn, pid, request)
	local sn = request[1];

	local player = get_player_info(pid);

	conn:sendClientRespond(Command.C_MANOR_CITY_CONTRUCT_QUERY_RESPOND , pid, {sn, Command.RET_SUCCESS, player.round_index, player.today_count, BOSS.Info()});
end);

-- player_accept_quest(123);
-- player_cancel_quest(123);
-- player_accept_quest(123);
