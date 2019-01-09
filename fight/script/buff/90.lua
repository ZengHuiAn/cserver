--增加持续回血或持续伤害
function onStart(target, buff)



    
end

function onPostTick(target, buff)
	buff.round = buff.round - 1
	if buff.round <= 0 then
		UnitRemoveBuff(buff)
	end
end

function onEnd(target, buff)



end
