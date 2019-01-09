--隐身
function onStart(target, buff)
	add_buff_parameter(target, buff, 1)
	BuffParameterChange(buff,attacker)
	UnitChangeAlpha(target,  0.5)
	target[7001] = target[7001] + 1
end

--buff消失的时候触发
function onEnd(target, buff)
	add_buff_parameter(target, buff, -1)
	BuffParameterChange(buff,attacker,-1)
	UnitChangeAlpha(target,  1)
	target[7001] = target[7001] - 1
end

function attackerAfterHit(target, buff, bullet)
    if bullet.skilltype == 0 and buff.attack_remove == 1 and bullet.hurt_disabled == 0 then
		UnitRemoveBuff(buff)		
    end
end

function onPostTick(target, buff, round)
	buff.round = buff.round - 1;
	if buff.round <= 0 then
		UnitRemoveBuff(buff);
	end
end
