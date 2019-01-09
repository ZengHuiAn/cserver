local cemeteryConf = nil
local team_battle_activity_id = nil
local team_battle_conf = {}
local function GetCemetery(Type)
	 if cemeteryConf == nil then
		cemeteryConf = {}
		team_battle_activity_id = {}

		DATABASE.ForEach("team_battle_config", function(row)
			team_battle_conf[row.gid_id] = row
			cemeteryConf[row.difficult] = cemeteryConf[row.difficult] or {}
			cemeteryConf[row.difficult][row.gid_id] = row
			team_battle_activity_id[row.activity_id] = team_battle_activity_id[row.activity_id] or {}
			team_battle_activity_id[row.activity_id][#team_battle_activity_id[row.activity_id]+1] = row
		end)
		for k,v in pairs(team_battle_activity_id) do
			table.sort(team_battle_activity_id[k],function (a,b)
				return a.limit_level < b.limit_level
			end)
		end
	end
	if Type then
		return cemeteryConf[Type]
	else
		return cemeteryConf
	end
end
local function Getteam_battle_conf(gid)
	GetCemetery()
	if gid then
		return team_battle_conf[gid]
	end
	return team_battle_conf
end
local function Getteam_battle_activity(id,type)
	GetCemetery()
	if type then
		if type == 0 then
			return team_battle_activity_id[id]
		end
		if team_battle_activity_id[id] then
			return team_battle_activity_id[id][type]
		else
			return nil
		end
	end
	-- local level = module.playerModule.Get().level
	-- local temp = team_battle_activity_id[id][1]
	-- for i = 2,#team_battle_activity_id[id] do
	-- 	if level >= team_battle_activity_id[id][i].limit_level and temp.limit_level < team_battle_activity_id[id][i].limit_level then
	-- 		temp = team_battle_activity_id[id][i]
	-- 	end
	-- end
	if team_battle_activity_id[id] then
		return team_battle_activity_id[id][1]
	else
		return nil
	end
end
local team_describe = nil
local function GetteamDescribeConf(gid)
	if team_describe == nil then
		team_describe = {}
		DATABASE.ForEach("team_describe", function(row)
			team_describe[row.gid_id] = team_describe[row.gid_id] or {}
			team_describe[row.gid_id][row.sequence] = row
		end)
	end
	return team_describe[gid]
end
local bounty_quest = nil
local function Get_bounty_quest(id,idx)
	if bounty_quest == nil then
		bounty_quest = {}
		DATABASE.ForEach("bounty_quest", function(row)
			if not bounty_quest[row.activity_id] then
				bounty_quest[row.activity_id] = {}
			end
			bounty_quest[row.activity_id][row.theme] = row
		end)
	end
	return bounty_quest[id][idx]
end
return{
	GetCemetery = GetCemetery,
	Getteam_battle_activity = Getteam_battle_activity,
	GetteamDescribeConf = GetteamDescribeConf,
	Getteam_battle_conf = Getteam_battle_conf,
	Get_bounty_quest = Get_bounty_quest,
}