--受到若干次攻击后移除
function onStart(target, buff)
	add_buff_parameter(target, buff, 1)
end

function onPostTick(target, buff)
	buff.round = buff.round - 1
	if buff.round <= 0 then
		UnitRemoveBuff(buff)
	end
end

function onEnd(target, buff)
	add_buff_parameter(target, buff, -1)
end

function targetAfterHit(target, buff, bullet)
    if bullet.skilltype <= 4 and bullet.skilltype ~= 0 then
        buff.bear_times = buff.bear_times - 1
        if buff.bear_times <= 0 then
            UnitRemoveBuff(buff)
        end
    end
end