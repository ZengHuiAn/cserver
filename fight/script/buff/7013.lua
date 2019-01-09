--沉默
function onStart(target, buff)
	target[7013] = target[7013] + 1
	add_buff_parameter(target, buff, 1)
end

--buff消失的时候触发
function  onEnd(target, buff)
	target[7013] = target[7013] - 1
	add_buff_parameter(target, buff, -1)
end

function onPostTick(target, buff, round)
	buff.round = buff.round - 1;
	if buff.round <= 0 then
		UnitRemoveBuff(buff);
	end
end
