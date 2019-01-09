local team_battle_conf = nil
local function GetTeam_battle_conf(id)
	team_battle_conf = team_battle_conf or LoadDatabaseWithKey("team_battle_config", "gid_id") or {}

	if id then
		return team_battle_conf[id]
	end
	return team_battle_conf
end

local group_list_id = nil
local function Getgroup_list_id(id)
	group_list_id = group_list_id or LoadDatabaseWithKey("group_list", "List_id") or {}

	if id then
		return group_list_id[id]
	else
		return group_list_id
	end
end


local group_list = nil
local function Getgroup_list(id)
	if group_list == nil then
		Getgroup_list_id();

		group_list = {}

		for _, row in pairs(group_list_id) do
			if row.List_level == 3 then
				local Affiliation_id = group_list_id[row.Affiliation_id].Affiliation_id
				if not group_list[Affiliation_id] then
					group_list[Affiliation_id] = {}
				end
				if not group_list[Affiliation_id][row.Affiliation_id] then
					group_list[Affiliation_id][row.Affiliation_id] = {}
				end
				group_list[Affiliation_id][row.Affiliation_id][row.List_id] = row
			end
		end
	end

	if id then
		return group_list[id]
	else
		return group_list
	end
end

local fight_reward = nil
local function GetFight_reward(drop_id)
	if fight_reward == nil then
		fight_reward = {}
		DATABASE.ForEach("fight_reward", function(row)
			fight_reward[row.drop_id] = fight_reward[row.drop_id] or {}
			table.insert(fight_reward[row.drop_id], row);
		end)
	end
	return fight_reward[drop_id]
end

local team_pve_fight = nil
local function GetTeam_pve_fight(id)
	if team_pve_fight == nil then
		team_pve_fight = {}
		DATABASE.ForEach("team_pve_fight_config", function(row)
			if not team_pve_fight[row.gid_id] then
				team_pve_fight[row.gid_id] = {gid = {},idx = {},sequence = {}}
			end

			if not team_pve_fight[row.gid_id].idx[row.sequence] then
				team_pve_fight[row.gid_id].idx[row.sequence] = {}
			end
			table.insert(team_pve_fight[row.gid_id].idx[row.sequence], row);
			team_pve_fight[row.gid_id].sequence[row.sequence] = row

		end)
	end
	if id then
		return team_pve_fight[id]
	else
		return team_pve_fight
	end
end

local team_pve_fightMonster = nil
local function Getteam_pve_fightMonster(id)
	if team_pve_fightMonster == nil then
		team_pve_fightMonster = {}
		DATABASE.ForEach("team_pve_fight_config", function(row)
			local fight = setmetatable({
				battle = GetTeam_battle_conf(row.gid_id),
			}, {__index=row});

			team_pve_fightMonster[row.monster_id] = team_pve_fightMonster[row.monster_id] or {}
			table.insert(team_pve_fightMonster[row.monster_id], fight);
		end)
	end
	return team_pve_fightMonster[id] or {}
end

local team_pve_fight_gid = nil
local function GetTeam_pve_fight_gid(gid)
	team_pve_fight_gid =team_pve_fight_gid or LoadDatabaseWithKey("team_pve_fight_config", "gid") or {}

	return team_pve_fight_gid[gid]
end

local team_pve_monster_item = nil
local teamPveMonsterList = nil
local function GetTeam_pve_monster_item(gid,role_id)
	if team_pve_monster_item == nil then
		team_pve_monster_item = {}
		teamPveMonsterList = {}
		DATABASE.ForEach("team_wave_config", function(row)
			if row.show_itemid1 ~= 0 then
				team_pve_monster_item[row.gid] = team_pve_monster_item[row.gid] or {}
				team_pve_monster_item[row.gid][row.role_id] = row
			end
			teamPveMonsterList[row.gid] = teamPveMonsterList[row.gid] or {}
			teamPveMonsterList[row.gid][row.role_id] = row
		end)
	end

	if team_pve_monster_item[gid] then
		return team_pve_monster_item[gid][role_id]
	else
		return nil
	end
end

local function GetTeamPveMonsterList(fightId)
	GetTeam_pve_monster_item(0)
	if fightId then
		return teamPveMonsterList[fightId]
	end
end

return {
	GetTeam_battle_conf = GetTeam_battle_conf,
	GetFight_reward = GetFight_reward,
	GetTeam_pve_fight = GetTeam_pve_fight,
	GetTeam_pve_fight_gid = GetTeam_pve_fight_gid,
	Getgroup_list = Getgroup_list,
	Getgroup_list_id = Getgroup_list_id,
	Getteam_pve_fightMonster = Getteam_pve_fightMonster,
	GetTeam_pve_monster_item = GetTeam_pve_monster_item,
	GetTeamPveMonsterList = GetTeamPveMonsterList,
}