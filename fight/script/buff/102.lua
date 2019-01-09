--普通攻击后附加buff
function attackerAfterHit(target, buff, bullet)
	if bullet.skilltype <= 4 and bullet.skilltype ~= 0 then
		local round = (buff.cfg[value_3] ~= 0) and buff.cfg[value_3]
		if RAND(1, 10000) <= buff.cfg[value_2] then
			Common_UnitAddBuff(bullet.target, buff.cfg[value_1], 0, {
				round = round
			})
		end
	end
end