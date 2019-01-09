local database = require "database"
local BossInfo = require "BossInfo"
require "boss_util"

local WorldBoss = {}

function WorldBoss.New(o)
	o = o or {}
	return setmetatable(o, { __index = WorldBoss })
end

function WorldBoss:Update()
	local ok, id = self.boss_info:Update()
	if ok then
		self.id = id
	end
	if not self.is_db then
		local ok = database.update([[insert into world_boss(`type`, id) values(%d, %d);]], self.type, self.id)
		if ok then
			self.is_db = true
		end
	end
end

function WorldBoss.Load(type)
	local ok, result = database.query([[select `type`, `id` from `world_boss` where `type` = %d;]], type)

	local ret = {}
	if ok and #result > 0 then
		local m = {}
		local ids = {}
		for _, v in ipairs(result) do
			table.insert(ids, v.id)
			m[v.id] = v
		end
		
		local list = BossInfo.Load(ids)
		for _, v in ipairs(list) do
			if m[v.id] then
				m[v.id].boss_info = v
				m[v.id].is_db = true
				table.insert(ret, WorldBoss.New(m[v.id]))
			end
		end
	end

	return ret
end

return WorldBoss
