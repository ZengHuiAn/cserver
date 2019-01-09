require "yqmath"

local function getSkip(pos)
	if pos <= 50 then
		return 1;
	elseif pos <= 100 then
		return 2;
	elseif pos <= 200 then
		return 5;
	elseif pos <= 500 then
		return 10;
	elseif pos <= 1000 then
		return 20;
	elseif pos <= 5000 then
		return 50;
	elseif pos <= 10000 then
		return 100;
	else
		return 200;
	end
end

local function getNeighborPosList(pos)
	if pos <=5 then
		return {1, 2, 3, 4, 5, 6, 7, 8}
	else
		local skip =getSkip(pos)
		local ret ={}
		for i=5, 1, -1 do
			table.insert(ret, pos-i*skip)
		end
		table.insert(ret, pos)
		for i=1, 2 do
			table.insert(ret, pos+i*skip)
		end
		return ret
	end
end


-- 建立1 - 12000 几个位置之间的关系
local relation = {};
local function getRelation(pos)
	local v = relation[pos];
	if v == nil then
		v = {watch = {}, watcher = {}};
		relation[pos] = v;
	end
	return v;
end

for pos = 1, 12000 do
	local r = getRelation(pos);
	r.watch =  getNeighborPosList(pos);
	for _, wpos in ipairs(r.watch) do
		if pos ~= wpos then
			local nr = getRelation(wpos);
			nr.watcher[pos] = true;
		end
	end
end

local function set2queue(set)
	local queue = {};
	for k, _ in pairs(set) do
		table.insert(queue, k);
	end
	return queue;
end

for pos = 1, 12000 do
	local r = getRelation(pos);
	r.watcher = set2queue(r.watcher);
end

local function getWatcher(pos)
	if pos > 11000 then
		return {pos-400, pos-200, pos+200, pos+400, pos+600, pos+800, pos+1000};
	else 
		return relation[pos].watcher;
	end
end

local function getNeighbor(pos)
	if pos > 12000 then
		return {pos-1000, pos-800, pos-600, pos-400, pos-200, pos, pos+200,pos+400};
	else
		return relation[pos].watch;
	end
end

local function getRankArenaEnemyList(pos)
	local num_pool = {}
	if pos <= 5 then
		for i = 5, 1, -1 do
			if i ~= pos then
				table.insert(num_pool, i)
			end
		end
	else	
		for i = pos, ((pos - 50) > 0 and (pos - 50) or 1), -1 do
			table.insert(num_pool, i)		
		end	
	end

	return get_rand_unique_num(num_pool, 4)
end

local function getRankArenaEnemyList_sgk(pos, max_pos)
	if pos <= 10 then
		local t = {}
		for i = 1, 10, 1 do
			if i ~= pos then
				table.insert(t, i)
			end
		end
		return t
	elseif pos >= 11 and pos <= 13 then
		return {pos - 3, pos - 2, pos-1, math.random(pos + 5, pos + 10)}
	elseif pos == 14 then
		return {10, 12, 13, math.random(pos + 5, pos + 10)}
	elseif pos == 15 then
		return {10, math.random(11, 12), math.random(13, 14), math.random(pos + 5, pos + 10)}
	elseif pos == 16 then
		return {10, math.random(12, 13), math.random(14, 15), math.random(pos + 5, pos + 10)}
	elseif pos == 17 then
		return {10, math.random(13, 14), math.random(15, 16), math.random(pos + 5, pos + 10)}
	elseif pos == 18 then
		return {10, math.random(14, 15), math.random(16, 17), math.random(pos + 5, pos + 10)}
	elseif pos == 19 then
		return {10, math.random(15, 16), math.random(17, 18), math.random(pos + 5, pos + 10)}
	elseif pos >= 20 and pos <= 50 then
		return {math.random(pos - 9, pos - 7), math.random(pos - 6, pos - 4), math.random(pos - 3, pos - 1), math.random(pos + 5, pos + 10)}	
	else
		local t = {}
		local lower = math.ceil(pos * 0.85)
		local upper = math.ceil(pos * 0.9)
		table.insert(t, math.random(lower, upper - 1))	
		lower = math.ceil(pos * 0.9)
		upper = math.ceil(pos * 0.95)
		table.insert(t, math.random(lower, upper - 1))
		lower = math.ceil(pos * 0.95)
		upper = pos
		table.insert(t, math.random(lower, upper - 1))

		lower = pos + 1
		upper = math.min(max_pos, pos + 500)
		if upper >= lower then
			--table.insert(t, math.random(pos + 1, pos + 500))
			table.insert(t, math.random(lower, upper))
		end

		return t	
	end	
end


--------------------------------------------------------------------------------
-- test start
local function queue2set(queue)
	local set = {};
	for _, v in pairs(queue) do
		set[v] = true;
	end
	return set;
end
print(unpack(getNeighbor(1)))
print(unpack(getWatcher(1)))
for pos = 1, 12000 do
	local neighbor = getNeighbor(pos);
	assert(table.maxn(neighbor)<=8);
	for _, wpos in ipairs(neighbor) do
		local w = queue2set(getWatcher(wpos));
		if pos~=wpos and w[pos] == nil then
			print(pos,  ":", pos);
			print(wpos, ":", wpos);
			assert(false);
		end
	end
end
-- test end
--------------------------------------------------------------------------------

module "VPosition"

Watcher  = getWatcher;
Neighbor = getNeighbor;
GetRankArenaEnemyList = getRankArenaEnemyList
GetRankArenaEnemyList_sgk = getRankArenaEnemyList_sgk
