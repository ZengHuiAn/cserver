local database = require "database"

local BossPlayer = {}
function BossPlayer.New(o)
	o = o or {}
	return setmetatable(o, { __index = BossPlayer })
end

function BossPlayer.Load(pid)
	local ok, result = database.query([[select `pid`, `damage`, unix_timestamp(`time`) as `time` from `player_day_info` where `pid` = %d;]], pid)
	if ok and #result > 0 then
		result[1].is_db = true
		return BossPlayer.New(result[1])
	else
		return BossPlayer.New({ pid = pid, damage = 0, time = 0, is_db = false })
	end
end

function BossPlayer:Update()
	local ok = false
	if self.is_db then
		ok = database.update([[update `player_day_info` set `damage` = %d, `time` = from_unixtime_s(%d) where `pid` = %d;]], self.damage, self.time, self.pid)
	else
		ok = database.update([[insert into `player_day_info`(`pid`, `damage`, `time`) values(%d, %d, from_unixtime_s(%d));]], self.pid, self.damage, self.time)
		if ok then
			self.is_db = true
		end
	end

	return ok
end

function BossPlayer:Delete()
	local ok = database.update([[delete from `player_day_info` where `pid` = %d;]], self.pid)

	return ok
end

return BossPlayer
