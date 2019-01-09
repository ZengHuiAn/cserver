--加属性，每个回合结束开始结算cd
function onStart(target, buff)
	add_buff_parameter(target, buff, 1)
	if buff.tick_heal ~= 0 then


	end

	if buff.tick_hurt ~= 0 then


	end

end

function onPostTick(target, buff)
	buff.round = buff.round - 1;
	if buff.round <= 0 then
		UnitRemoveBuff(buff);
	end
end

function onEnd(target, buff)
	add_buff_parameter(target, buff, -1)
end
