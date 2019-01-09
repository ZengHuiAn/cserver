local mazeConfig = {}

local BaseConfig = nil;

local function buildBaseInfo()
    if BaseConfig then
        return ;
    end
    BaseConfig = {}
    DATABASE.ForEach("team_activity_npc", function(row)
		BaseConfig[row.id] = row
	end)
end


function mazeConfig.GetInfo(id)
	buildBaseInfo();
	if not id then
		return BaseConfig;
	end
	
	return BaseConfig[id];
end 

local baseNpcBattle = nil
local function buildNpcBattleCfgInfo()
    if baseNpcBattle then
        return ;
    end
    baseNpcBattle = {}
    DATABASE.ForEach("team_activity_cube", function(row)
		baseNpcBattle[row.id] = row
	end)
end


local itemConfig = nil; 
local function buildItemCfgInfo()

	if itemConfig then
		return;
	end
	itemConfig = itemConfig or {}
	DATABASE.ForEach("item", function(row)
		itemConfig[row.id] = row;
	end)
end

function mazeConfig.getItem(id)
	buildItemCfgInfo();

	local cfg = {};
	for k,v in pairs(itemConfig) do
		if v.type == 89 then
			cfg[v.id] = v;
		end
	end
	return cfg[id];
end



function mazeConfig.GetNPCByID(id)
	buildNpcBattleCfgInfo();
	if not id then
		return baseNpcBattle;
	end

	return baseNpcBattle[id];

end

local teamPveMonsterList = nil
local function GetTeam_pve_monster_item()
	if teamPveMonsterList == nil then
		teamPveMonsterList = {}
		DATABASE.ForEach("team_wave_config", function(row)
			teamPveMonsterList[row.gid] = teamPveMonsterList[row.gid] or {}
			teamPveMonsterList[row.gid][row.role_id] = teamPveMonsterList[row.gid][row.role_id] or {};
			table.insert(teamPveMonsterList[row.gid][row.role_id],row); 
		end)
	end
end
function mazeConfig.GetTeamPveMonsterList(fightId)
	GetTeam_pve_monster_item()
	-- ERROR_LOG("战斗配置数据",fightId,sprinttb(teamPveMonsterList))
	if fightId then
		return teamPveMonsterList[fightId] or teamPveMonsterList;
	end
end





return mazeConfig


