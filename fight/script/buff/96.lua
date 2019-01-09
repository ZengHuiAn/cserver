--角色升星类被动（配置表中，所有参数的值 和 attacker[buff_id] 相等）
local function add_parameter(target, buff, reverse)
	for i = 1, 3, 1 do
		local k = buff.cfg["parameter_"..i]
		local v = target[buff.id]
		target[k] = target[k] + v * reverse
	end
end

function onStart(target, buff)
	if buff.cfg and buff.cfg ~= 0 then
		add_parameter(target, buff, 1)
	end
end

function _desc_cfg_add(buff)
	local desc_add_list = {
		[1200132] = string.format(",当前造成伤害提高<color=#3bffbc>%s%%</color>",math.floor(buff.target.id_27018/100))
	}

	local desc = desc_add_list[buff.id] or ""
	return desc
end