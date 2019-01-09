local database = require "database"
local SocialManager = require "SocialManager"

--[[
DROP TABLE IF EXISTS `build_city_boss`;
CREATE TABLE `build_city_boss` (
  `boss_id` int(11) NOT NULL,
  `exp` int(11) DEFAULT NULL default 0,
  PRIMARY KEY (`boss_id`)
) DEFAULT CHARSET=utf8 ;

--]]

local function readFile(fileName, protocol)
    local f = io.open(fileName, "rb")
    local content = f:read("*a")
    f:close()

    return protobuf.decode("com.agame.config." .. protocol, content);
end

local boss_info = nil
local function get_boss_exp(id)
	if boss_info == nil then
		boss_info = {}
		local success, rows = database.query('select boss_id, exp from build_city_boss');
		if not success then
			return nil;
		end

		for _, v in ipairs(rows) do
			boss_info[v.boss_id] = {
				id = v.boss_id,
				exp = v.exp,
			}
		end
	end

	if boss_info[id] then
		return boss_info[id].exp 
	else
		return 0;
	end
end

local function add_boss_exp(id, n)
	local exp = get_boss_exp(id);
	if boss_info[id] then
		boss_info[id].exp = boss_info[id].exp + n;
		database.update("update build_city_boss set exp = %d where boss_id = %d", boss_info[id].exp, id);
	else
		boss_info[id] = {
			id = id,
			exp = n,
		}
		database.update("insert into build_city_boss (boss_id, exp) values(%d, %d)", id, boss_info[id].exp);
	end
end

local function query_boss_info()
	get_boss_exp(0);

	local t = {}
	for _, v in pairs(boss_info) do
		table.insert(t, {v.id, v.exp});
	end
	return t;
end

local boss_config = nil;
local function get_boss_fight_id(id)
	if boss_config == nil then
		boss_config = {}
		local cfg = readFile("../etc/config/manor/config_activity_buildcity.pb", "config_activity_buildcity");

		if not cfg then return end

		for _, v in ipairs(cfg.rows) do
			boss_config[v.type] = boss_config[v.type] or {}
			
			table.insert(boss_config[v.type], {
				exp      = v.dcity_exp,
				level    = v.dcity_lv,
				fight_id = v.fight_id
			});

			table.sort(boss_config[v.type], function(a,b)
				return a.exp < b.exp		
			end)
		end
	end


	local cfg = boss_config[id]
	if not cfg then
		return
	end

	local exp = get_boss_exp(id);

	local level, fight_id;
	for _, v in ipairs(cfg) do
		if v.exp <= exp then
			level = v.level;
			fight_id = v.fight_id;
		end
	end

	return fight_id;
end


local function boss_fight(pid, id)
	local fight_id = get_boss_fight_id(id);	
	if not fight_id then
		log.error(string.format(' boss id %d not exist', id));
		return nil;
	end

	return SocialManager.TeamStartActivityFight(pid, fight_id);
end

return {
	Info = query_boss_info,
	Fight = boss_fight,
	AddExp = add_boss_exp,
}
