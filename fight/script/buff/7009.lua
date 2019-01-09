--混乱
local script_data = GetBattleData()

function onStart(target, buff)
	add_buff_parameter(target, buff, 1)
	script_data.record_2607004 = true
	target[7009] = target[7009] + 1
end

--buff消失的时候触发
function onEnd(target, buff)
	add_buff_parameter(target, buff, -1)
	target[7009] = target[7009] - 1
end

function onPostTick(target, buff, round)
	buff.round = buff.round - 1;
	if buff.round <= 0 then
		UnitRemoveBuff(buff);
	end
end

function attackerAfterHit(target, buff, bullet)
	if script_data.fight_id == 20201 then
		if bullet.target.side == target.side and bullet.target.hp <= 0 then
			AddRecord(2607002)
		end

		if bullet.target.mode == 19011 and bullet.target.hp <= 0 then
			AddRecord(2607003)
		end

		if target.mode == 19011 and bullet.target.side == target.side and bullet.target.hp <= 0 then
			AddRecord(2607006)
		end
	end
end
