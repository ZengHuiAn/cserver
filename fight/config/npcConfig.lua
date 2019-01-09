local NpcFriendList = nil
local ItemRelyNpcList = nil
local NpcConsortia = nil
local function GetNpcFriendList()
	if not NpcFriendList then
		NpcFriendList = {}
		ItemRelyNpcList = {}
		NpcConsortia = {}
		--NpcFriendList = LoadDatabaseWithKey("arguments_npc","npc_id")
		DATABASE.ForEach("arguments_npc", function(row)
			NpcFriendList[row.npc_id] = row
			ItemRelyNpcList[row.arguments_item_id] = row
			if NpcConsortia[row.consortia] == nil then
				NpcConsortia[row.consortia] = {}
			end
			table.insert(NpcConsortia[row.consortia], row)
		end)
	end
	return NpcFriendList
end
local function GetItemRelyNpc(itemid)
	if not ItemRelyNpcList then
		GetNpcFriendList()
	end
	return ItemRelyNpcList[itemid]
end
local function GetNpcConsortia(id)
	if not ItemRelyNpcList then
		GetNpcFriendList()
	end
	return NpcConsortia[id]
end
local npcList = nil
local function GetnpcList()
	if not npcList then
		npcList = LoadDatabaseWithKey("true_npc","npc_id")
	end
	return npcList
end
local npc_talking = nil
local function Get_npc_talking(id)
	if not npc_talking then
		npc_talking = {}
		DATABASE.ForEach("arguments_npc_talking", function(row)
			if not npc_talking[row.npc_id] then
				npc_talking[row.npc_id] = {}
			end
			npc_talking[row.npc_id][#npc_talking[row.npc_id]+1] = row
		end)
	end
	return npc_talking[id]
end
return {
	GetNpcFriendList = GetNpcFriendList,
	GetnpcList = GetnpcList,
	Get_npc_talking = Get_npc_talking,
	GetItemRelyNpc = GetItemRelyNpc,
	GetNpcConsortia = GetNpcConsortia,
}