--冰冻
function onStart(target, buff)
	if target.side ~= 1 then AddRecord(56, "add", 1) end
	add_buff_parameter(target, buff, 1)
	target[7010] = target[7010] + 1
	target[7014] = target[7014] + 1	
end

--buff消失的时候触发
function onEnd(target, buff)
	add_buff_parameter(target, buff, -1)
	target[7010] = target[7010] - 1
	target[7014] = target[7014] - 1		
end

function onPostTick(target, buff, round)
	buff.round = buff.round - 1;
	if buff.round <= 0 then
		UnitRemoveBuff(buff);
	end
end
