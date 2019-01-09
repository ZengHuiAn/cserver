--增加被动
function onStart(target, buff)
	if buff.cfg and buff.cfg ~= 0 then
		add_buff_parameter(target, buff, 1)
	end
end

function _desc_cfg_add(buff)
	local desc_add_list = {
		[3000061] = string.format("造成伤害提高<color=#3bffbc>%s%%</color>",math.floor(buff[1021]/100)),
		[3000062] = string.format("造成伤害提高<color=#3bffbc>%s%%</color>",math.floor(buff[1021]/100)),
	}

	local desc = desc_add_list[buff.id] or ""
	return desc
end