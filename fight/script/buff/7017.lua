local per = 0.5

function onStart(target, buff)
	add_buff_parameter(target, buff, 1)
	target[7017] = target[7017] + 1
end

--buff消失的时候触发
function  onEnd(target, buff)
	add_buff_parameter(target, buff, -1)
	target[7017] = target[7017] - 1
end

function onPostTick(target, buff, round)
	buff.round = buff.round - 1;
	if buff.round <= 0 then
		UnitRemoveBuff(buff);
	end
end

function onTick(target, buff)
	if RAND(1, 10000) <= per * 10000 then return end
	for i = 1, 3, 1 do
		local skill = SkillGetInfo(attacker, i + 1) or 0
		if skill ~= 0 then
			skill.current_cd = math.max(skill.current_cd - 1, 0)
		end
	end
end
