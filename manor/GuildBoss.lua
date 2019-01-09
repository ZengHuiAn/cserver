local database = require "database"
local BossInfo = require "BossInfo"
require "boss_util"

local GuildBoss = {}

function GuildBoss.New(o)
	o = o or {}
	return setmetatable(o, { __index = GuildBoss })
end

function GuildBoss:Update()
	local ok, id = self.boss_info:Update()
	if ok then
		self.id = id
	end
	if not self.is_db then
		local ok = database.update([[insert into guild_boss(guild_id, `type`, id) values(%d, %d, %d);]],
			self.guild_id, self.type, self.id)
		if ok then
			self.is_db = true
		end
	end
end

function GuildBoss:Delete()
	local ok = self.boss_info:Delete()	
	if ok then
		ok = database.update("delete from guild_boss where guild_id = %d and `type` = %d and `id` = %d;", self.guild_id, self.type, self.id)	
	end

	return ok
end

function GuildBoss.Load(guild_id, type)
	local ok, result = database.query("select `guild_id`, `type`, `id` from guild_boss where guild_id = %d and `type` = %d; ", 
		guild_id, type)

	local ret = {}
	if ok and #result > 0 then
		local ids = {}
		local m = {}
		for _, v in ipairs(result) do
			table.insert(ids, v.id)
			m[v.id] = v
		end

		local list = BossInfo.Load(ids)
		for _, v in ipairs(list) do
			if m[v.id] then
				m[v.id].boss_info = v
				m[v.id].is_db = true
				table.insert(ret, GuildBoss.New(m[v.id]))
			end
		end
	end

	return ret
end

return GuildBoss
