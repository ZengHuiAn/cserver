local database = require "database"

local BossInfo = {}
function BossInfo.New(o)
	o = o or {}
	return setmetatable(o, { __index = BossInfo })
end

function BossInfo:Update()
	local ok = false

	if self.is_db then
		ok = database.update([[update boss_info set refresh_time = from_unixtime_s(%d), `npc_id` = %d, `fight_id` = %d, `fight_data` = '%s', 
			terminator = %d, is_escape = %d, duration = %d, cd = %d, boss_level = %d, is_accu_damage = %d where id = %d;]], self.refresh_time, self.npc_id, self.fight_id, 
			tableToFormatStr(self.fight_data), self.terminator, self.is_escape, self.duration, self.cd, self.boss_level, self.is_accu_damage, self.id)
	else
		ok = database.update([[insert into boss_info(refresh_time, npc_id, fight_id, fight_data, terminator, is_escape, duration, cd, boss_level, is_accu_damage) 
			values(from_unixtime_s(%d), %d, %d, '%s', %d, %d, %d, %d, %d, %d);]], self.refresh_time, self.npc_id, 
			self.fight_id, tableToFormatStr(self.fight_data), self.terminator, self.is_escape, self.duration, self.cd, self.boss_level, self.is_accu_damage)
		if ok then
			self.id = database.last_id()
			self.is_db = true
		end
	end

	return ok, self.id
end

function BossInfo:Delete()
	local ok = database.update("delete from boss_info where id = %d;", self.id)

	return ok
end

function BossInfo.Load(ids)
	local sql = [[select `id`, unix_timestamp(`refresh_time`) as refresh_time, `npc_id`, `fight_id`, `fight_data`, `terminator`, 
			`is_escape`, `duration`, `cd`, `boss_level`, `is_accu_damage` from boss_info where id in (%d]]
	for i = 2, #ids do
		sql = sql .. ", %d"
	end
	sql = sql .. ");"

	local ok, result = database.query(sql, unpack(ids))
	local ret = {}
	if ok and #result > 0 then
		for _, v in ipairs(result) do
			v.fight_data = formatStrtoTable(v.fight_data)
			v.is_db = true
			table.insert(ret, BossInfo.New(v))
		end
	end

	return ret
end

return BossInfo
