--标记目标buff
function onEnd(target, buff)
	if buff.Skill_buff and buff.Skill_buff ~= 0 then
		buff.Skill_buff.tag_buff = 0
		UnitRemoveBuff(buff.Skill_buff)
	end
end



