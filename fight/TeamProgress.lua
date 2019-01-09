local BattleConfig = require "BattleConfig"
local StableTime = require "StableTime"

local TeamProgress = {}

local teamProgress = {} 
local function getTeamProgress(teamid)
	if not teamProgress[teamid] then
		teamProgress[teamid] = TeamProgress.New(teamid)
	end
	return teamProgress[teamid]
end

local function deleteTeamProgress(teamid)
	if teamProgress[teamid] then
		if teamProgress[teamid] then
			for k, v in pairs(teamProgress[teamid].fights) do
				if v.db_exists then
					database.update("delete from team_fight where teamid = %d", teamid)
					break
				end
			end
		end
		teamProgress[teamid] = nil
	end
end

local BUFF_TYPE_ATTACKER_BUFF = 2   --增加队伍玩家属性
local BUFF_TYPE_DEFENDER_DEBUFF = 1 --降低boss属性 
local BUFF_TYPE_DEFENDER_PROPERTY_REPLACE = 3 --改变boss属性
local function AddTeamBuff(t, fight_id)
	local cfg = BattleConfig.Get(fight_id)
	if not cfg then
		return 
	end
	
	local target_battle_id = cfg.effect_battle_id
	local target_fight_id = cfg.effect_fight_id

	if target_battle_id > 0 and target_fight_id == 0 then
		local fights = BattleConfig.GetBattleFights(target_battle_id)
		if not fights then 
			return 
		end

		for fight_id, v in pairs(fights) do
			t[fight_id] = t[fight_id] or { attacker_buff = {}, defender_debuff = {}, defender_property_replace = {} }
			if cfg.effect_who == BUFF_TYPE_ATTACKER_BUFF then
				t[fight_id].attacker_buff[cfg.effect_type] = cfg.effect_value
			elseif cfg.effect_who == BUFF_TYPE_DEFENDER_DEBUFF then
				t[fight_id].defender_debuff[cfg.effect_type] = cfg.effect_value
			elseif cfg.effect_who == BUFF_TYPE_DEFENDER_PROPERTY_REPLACE then
				t[fight_id].defender_property_replace[cfg.effect_type] = cfg.effect_value
			end
		end
	elseif target_battle_id > 0 and target_fight_id > 0 then
		t[target_fight_id] = t[target_fight_id] or { attacker_buff = {}, defender_debuff = {}, defender_property_replace = {} }
		if cfg.effect_who == BUFF_TYPE_ATTACKER_BUFF then
			t[target_fight_id].attacker_buff[cfg.effect_type] = cfg.effect_value
		elseif cfg.effect_who == BUFF_TYPE_DEFENDER_DEBUFF then
			t[target_fight_id].defender_debuff[cfg.effect_type] = cfg.effect_value
		elseif cfg.effect_who == BUFF_TYPE_DEFENDER_PROPERTY_REPLACE then
			t[target_fight_id].defender_property_replace[cfg.effect_type] = cfg.effect_value
		end		
	end
end

local function DeleteTeamBuff(t, fight_id)
	local cfg = BattleConfig.Get(fight_id)
	if not cfg then
		return 
	end
	
	local target_battle_id = cfg.effect_battle_id
	local target_fight_id = cfg.effect_fight_id

	if target_battle_id > 0 and target_fight_id == 0 then
		local fights = BattleConfig.GetBattleFights(target_battle_id)
		if not fights then 
			return 
		end

		for fight_id, v in pairs(fights) do
			if t[fight_id] then
				if cfg.effect_who == BUFF_TYPE_ATTACKER_BUFF and t[fight_id].attacker_buff[cfg.effect_type] then
					t[fight_id].attacker_buff[cfg.effect_type] = nil 
				elseif cfg.effect_who == BUFF_TYPE_DEFENDER_DEBUFF and t[fight_id].defender_debuff[cfg.effect_type] then
					t[fight_id].defender_debuff[cfg.effect_type] = nil 
				elseif cfg.effect_who == BUFF_TYPE_DEFENDER_PROPERTY_REPLACE and t[fight_id].defender_property_replace[cfg.effect_type] then
					t[fight_id].defender_property_replace[cfg.effect_type] = nil 
				end
			end
		end
	elseif target_battle_id > 0 and target_fight_id > 0 then
		if t[target_fight_id] then
			if cfg.effect_who == BUFF_TYPE_ATTACKER_BUFF and t[target_fight_id].attacker_buff[cfg.effect_type] then
				t[target_fight_id].attacker_buff[cfg.effect_type] = nil 
			elseif cfg.effect_who == BUFF_TYPE_DEFENDER_DEBUFF and t[target_fight_id].defender_debuff[cfg.effect_type] then
				t[target_fight_id].defender_debuff[cfg.effect_type] = nil 
			elseif cfg.effect_who == BUFF_TYPE_DEFENDER_PROPERTY_REPLACE and t[target_fight_id].defender_property_replace[cfg.effect_type] then
				t[target_fight_id].defender_property_replace[cfg.effect_type] = nil 
			end		
		end
	end
end

--implement
function TeamProgress.Get(teamid)
	return getTeamProgress(teamid)
end

function TeamProgress.Delete(teamid)
	return deleteTeamProgress(teamid)
end

function TeamProgress.New(teamid)
	local success, results = database.query("select teamid, gid, flag, today_count, unix_timestamp(update_time) as update_time, star from team_fight where teamid = %d", teamid)
	if not success then return end
	local fight = {
		teamid = teamid,
		fights = {},
		buff = {}
	}
	for _, row in ipairs(results) do
		fight.fights[row.gid] = fight.fights[row.gid] or {}	
		fight.fights[row.gid].gid              = row.gid
		fight.fights[row.gid].flag             = row.flag
		fight.fights[row.gid].today_count      = row.today_count
		fight.fights[row.gid].update_time      = row.update_time
		fight.fights[row.gid].star             = row.star
		fight.fights[row.gid].db_exists         = true 

		--init team buff
		if row.star >= 1 then
			AddTeamBuff(fight.buff, row.gid)
		end
	end

	return setmetatable(fight, {__index = TeamProgress})	
end

function TeamProgress:CheckDependFightFinish(gid)
	local finish = true 
	local fight_config = BattleConfig.Get(gid)	

	if not fight_config then
		log.debug("check depend fight fail, fight:%d config is nil", gid)
		return false		
	end

	local depend_fight0_id = fight_config.depend_fight0_id
	local depend_fight1_id = fight_config.depend_fight1_id
	local progress0 = depend_fight0_id ~= 0 and self:GetTeamProgress(depend_fight0_id) or 0
	local progress1 = depend_fight1_id ~= 0 and self:GetTeamProgress(depend_fight1_id) or 0

	if depend_fight0_id ~= 0 and progress0 == 0 then
		finish = false
	end
	if depend_fight1_id ~= 0 and progerss1 == 0 then
		finish = false
	end
	return finish
end

function TeamProgress:RebuildTeamProgress(gid, time)
	--time = time or loop.now()
	time = loop.now()
	local fight_config = BattleConfig.Get(gid)	

	if not fight_config then
		log.debug(string.format("rebuild team progress fail, fight:%d config is nil", gid))
		return 		
	end

	if not self.fights[gid] then
		self.fights[gid] = {
			gid = gid, 
			flag = 0,
			today_count = 0,
			update_time = 0,
			star = 0,
			db_exists = false,
		}
	end

	if StableTime.get_begin_time_of_day(time) > StableTime.get_begin_time_of_day(self.fights[gid].update_time) then
		self.fights[gid].today_count = 0
		self.fights[gid].update_time = time 
	end
end

function TeamProgress:ResetTeamProgress(gid)
	local time = loop.now()
	self:RebuildTeamProgress(gid, time)

	self.fights[gid].star = 0
	self.fights[gid].update_time = loop.now() 
	DeleteTeamBuff(self.buff, gid)
	
	if not self.fights[gid].db_exists then
		database.update("insert into team_fight(teamid, gid, flag, today_count, update_time, star) values(%d, %d, %d, %d, from_unixtime_s(%d), %d)", self.teamid, gid, self.fights[gid].flag, self.fights[gid].today_count, loop.now(), self.fights[gid].star)
		self.fights[gid].db_exists = true
	else
		database.update("update team_fight set star = %d, update_time = from_unixtime_s(%d) where teamid = %d and gid = %d", 0, loop.now(), self.teamid, gid)
	end
end

function TeamProgress:UpdateTeamProgress(gid, flag, count, star, time)
	--time = time or loop.now()
	time = loop.now()
	self:RebuildTeamProgress(gid, time)

	if not self.fights[gid] then
		return
	end

	if self.fights[gid].star == 0 and star > 0  then
		AddTeamBuff(self.buff, gid)	
	end

	self.fights[gid].flag = flag 
	self.fights[gid].update_time = time 
	self.fights[gid].today_count = count 

	if star <= self.fights[gid].star then
		return 
	end

	self.fights[gid].star = star 

	if not self.fights[gid].db_exists then
		database.update("insert into team_fight(teamid, gid, flag, today_count, update_time, star) values(%d, %d, %d, %d, from_unixtime_s(%d), %d)", self.teamid, gid, flag, count, time, star)
		self.fights[gid].db_exists = true
	else
		database.update("update team_fight set flag = %d, update_time = from_unixtime_s(%d), today_count = %d, star = %d where teamid = %d and gid = %d", flag, time, count, star, self.teamid, gid)
	end

	local team = getTeam(self.teamid)
	if team then
		team:Notify(Command.NOTIFY_TEAM_PROGRESS_CHANGE, {gid, self.fights[gid].star})
	end 
end

function TeamProgress:GetTeamProgress(gid, time)
	--time = time or loop.now()
	time = loop.now()
	self:RebuildTeamProgress(gid, time)
	return self.fights[gid] and self.fights[gid].star or nil, self.fights[gid] and self.fights[gid].today_count or nil
end

function TeamProgress:GetTeamBuff(gid)
	return self.buff[gid] and self.buff[gid] or nil
end

return TeamProgress
