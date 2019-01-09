function onStart(target, buff)
	add_buff_parameter(target, buff, 1)
	target[7005] = target[7005] + 1
end

--buff消失的时候触发
function onEnd(target, buff)
	add_buff_parameter(target, buff, -1)
	target[7005] = target[7005] - 1
end


function onPostTick(target, buff, round)
	buff.round = buff.round - 1;
	if buff.round <= 0 then
		UnitRemoveBuff(buff);
	end
end
