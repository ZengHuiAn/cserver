--加属性，每个回合开始结算cd

function onStart(target, buff)
	add_buff_parameter(target, buff, 1)
end

function onTick(target, buff)
	buff.round = buff.round - 1;
	if buff.round <= 0 then
		UnitRemoveBuff(buff);
	end
end

function onEnd(target, buff)
	add_buff_parameter(target, buff, -1)
end
