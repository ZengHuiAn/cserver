local MapConf = nil
local MapName2ID = nil;
local function GetMapConf(id)
	if MapConf == nil then
		MapConf = {}
		MapName2ID = {};
		DATABASE.ForEach("all_map", function(row)
			MapConf[row.gid] = row
			MapName2ID[row.map_id] = row.gid;
		end)
	end
	if id then
		return MapConf[id]
	else
		return MapConf
	end
end

local function GetMapId(name)
	return MapName2ID[name];
end

local MapNpcConf = nil
local MapMonsterConf = nil

local function GetMapNpcConf(mapid)
   if MapNpcConf == nil then
		MapNpcConf = {}
		MapMonsterConf = {}
		DATABASE.ForEach("all_npc", function(row)
			MapNpcConf[row.mapid] = MapNpcConf[row.mapid] or {}
			if row.type == 2 or row.type == 6 then
				table.insert(MapNpcConf[row.mapid], row);
			end
			MapMonsterConf[row.gid] = row
		end)
	end

	if mapid then
		return MapNpcConf[mapid]
	else
		return MapNpcConf
	end
end
local NpcTransport = nil
local function GetNpcTransport(id)
	if NpcTransport == nil then
		NpcTransport = {}
		DATABASE.ForEach("all_npc_transport", function(row)
			NpcTransport[row.id] = row
		end)
	end
	return NpcTransport[id]
end
local function GetMapMonsterConf(gid)
	GetMapNpcConf();
	return MapMonsterConf[gid]
end

return {
    GetMapConf = GetMapConf,
    GetMapId = GetMapId,
    GetMapNpcConf = GetMapNpcConf,
    GetMapMonsterConf = GetMapMonsterConf,
    GetNpcTransport= GetNpcTransport,
    }
