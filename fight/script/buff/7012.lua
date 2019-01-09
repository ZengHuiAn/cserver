--盲目
function onStart(target, buff)
	target[7012] = target[7012] + 1
	add_buff_parameter(target, buff, 1)
end

function onEnd(target, buff)
	target[7012] = target[7012] - 1
	add_buff_parameter(target, buff, -1)
end

function onPostTick(target, buff, round)
	buff.round = buff.round - 1;
	if buff.round <= 0 then
		UnitRemoveBuff(buff);
	end
end

function attackerBeforeHit(target, buff, bullet)
	if RAND(1,100) <= 50 and bullet.skilltype ~= 0 and bullet.skilltype <= 4 then
		bullet.hurt_disabled = 1
		UnitShowNumber(bullet.target,"", "hitpoint", "hurt_normal", "丢失");
	end
end