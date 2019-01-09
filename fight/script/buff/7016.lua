function onStart(target, buff)
	add_buff_parameter(target, buff, 1)
	target[7016] = target[7016] + 1
	target[7089] = target[7089] + 1
	target[7010] = target[7010] + 1
end

--buff消失的时候触发
function onEnd(target, buff)
	add_buff_parameter(target, buff, -1)
	target[7016] = target[7016] - 1
	target[7089] = target[7089] - 1
	target[7010] = target[7010] - 1
end

function onPostTick(target, buff, round)
	buff.round = buff.round - 1;
	if buff.round <= 0 then
		UnitRemoveBuff(buff);
	end
end

function targetBeforeHit(target, buff, bullet)
	if bullet.hurt_disabled == 0 then
		bullet.magicDamagePromote = bullet.magicDamagePromote + 1
	end
end