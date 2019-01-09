--通用护盾
function targetWillHit(target, buff, bullet)
	Shield_calc(buff,bullet)
end

function onStart(target, buff)
	add_buff_parameter(target, buff, 1)
end

function onTick(target, buff)
	if buff.shield_to_hp > 0 then
		local bullet = CreateBullet_Bytype(6)
		bullet.healValue = buff.shield * buff.shield_to_hp
		BulletFire(bullet, target, 0)
		UnitRemoveBuff(buff);
	end

	buff.round = buff.round - 1;
	if buff.round <= 0 then
		UnitRemoveBuff(buff);
	end
end

function onEnd(target, buff)
	add_buff_parameter(target, buff, -1)
end
