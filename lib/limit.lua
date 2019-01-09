

require "xml"

local cfg = xml.open("../etc/config/common_limit.xml")


local limit = {};
for _, v in ipairs(cfg) 
do
	local id   = tonumber(v.id["@text"]);
	local star = tonumber(v.star_count["@text"]);
	local vip  = tonumber(v.vip_level["@text"]);
	local level = tonumber(v.property_level["@text"]);

	limit[id] = {star = star, vip = vip, level = level};
end

function limit.check(id, level, vip, star)
	local cfg = limit[id];
	if cfg == nil then
		return true;
	end

	if level and level >= cfg.level then
		return true;
	end

	if vip and vip >= cfg.vip then
		return true;
	end

	if star and star >= cfg.star then
		return true;
	end

	return false;
end

function limit.get(id)
	local cfg = limit[id];
    if cfg then
        return cfg.level, cfg.vip, cfg.star;
    end
end

return limit;
