local guildTask = nil
local function GetguildTask(quest_id,task_type)
	if not guildTask then
		guildTask = {}
		DATABASE.ForEach("guild_quest", function(row)
			guildTask[row.quest_id] = row
		end)
	end
	if quest_id then
		return guildTask[quest_id]
	end
	if task_type then
		local list = {}
		for k,v in pairs(guildTask) do
			if v.task_type == task_type then
				list[#list+1] = v
			end
		end
		return list
	end
	return guildTask
end
local npc_quests = nil;
local function GetguildTaskByNpc(npc_id,task_type)
	if not npc_quests then
		npc_quests = {}
		DATABASE.ForEach("guild_quest", function(row)
			npc_quests[row.npcid] = npc_quests[row.npcid] or {};
			table.insert(npc_quests[row.npcid], row);
		end)
	end
	local qs = npc_quests[npc_id];
	if not task_type then
		return qs;
	end
	local ret = {};
	for k,v in ipairs(qs or {}) do
		if v.task_type == task_type then
			table.insert(ret, v);
		end
	end
	return ret;
end

local guild_quest_stepreward = nil
local function Getguild_quest_stepreward(quest_id)
	if not guild_quest_stepreward then
		guild_quest_stepreward = {}
		DATABASE.ForEach("guild_quest_stepreward", function(row)
			if not guild_quest_stepreward[row.quest_id] then
				guild_quest_stepreward[row.quest_id] = {}
			end
			guild_quest_stepreward[row.quest_id][row.index] = row
		end)
	end
	return guild_quest_stepreward[quest_id]
end
return {
	GetguildTask = GetguildTask,
	Getguild_quest_stepreward = Getguild_quest_stepreward,
	GetguildTaskByNpc= GetguildTaskByNpc,
}