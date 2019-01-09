

local next_id = 0;
local function Next()
	next_id = next_id + 1;
	return next_id;
end

return {Next = Next}
