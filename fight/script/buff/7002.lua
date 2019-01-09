--麻痹
local ori_skills = {}
function onStart(target, buff)
	for i = 1,4,1 do
		local skill = target.skill_boxs[i]
		if skill and skill[8001] < 0 then
			ori_skills[i] = skill[8001]
			

		end
	end
end

function onEnd(target, buff)
end

function onPostTick(target, buff, round)
	buff.round = buff.round - 1;
	if buff.round <= 0 then
		UnitRemoveBuff(buff);
	end
end
