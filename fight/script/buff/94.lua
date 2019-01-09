--增加若干个其他被动，没什么卵用
local function add_Buff(target, buff, reverse)
	for i = 1, 3, 1 do
		local k = buff.cfg["parameter_"..i]
		Common_UnitAddBuff(target, k, 0, {hide = 1})
	end
end

function onStart(target, buff)
	if buff.cfg and buff.cfg ~= 0 then
		add_Buff(target, buff, 1)
	end
end
