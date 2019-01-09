require "yqmath"
require "yqlog_sys"
require "printtb"
require "yqmath"
require "ArenaPlayerPool"
local BinaryConfig = require "BinaryConfig"
local OpenlevConfig = require "OpenlevConfig"

local yqinfo = yqinfo
local ipairs = ipairs
local pairs = pairs
local table = table
local math = math
local sprinttb = sprinttb
local get_rand_unique_num = get_rand_unique_num
local getPlayerFightData = ArenaPlayerPool.GetPlayerFightData
local STRIDE = ArenaPlayerPool.Stride 
local ArenaPlayerPool = ArenaPlayerPool.Get()
local print = print
local assert = assert
local next = next

module "ArenaEnemyConfigManager"

local enemyListFast = {}
local enemyListMap = {}
local rankArenaAIList = {}

local ai_not_join_rank_arena = {}
local function reOriganizeEnemyList()
	local rows = BinaryConfig.Load("config_random_arena_ai", "arena")
	if rows then
		for _ ,enemy in ipairs(rows) do 
			local index = math.ceil(enemy.score/STRIDE)	
			enemyListFast[index] = enemyListFast[index] or {}
			local temp = { pid = enemy.gid, power = enemy.score, name = enemy.name, level = enemy.level1, type = enemy.type, wealth = enemy.wealth }
			if enemy.type == 1 then
				table.insert(enemyListFast[index], temp)
			end
			if enemy.type == 1 or enemy.type == 2 then
				enemyListMap[enemy.gid] = temp
			end
			if enemy.type == 3 then
				rankArenaAIList[enemy.gid] = temp
				if enemy.gid >= 105560 then
					ai_not_join_rank_arena[enemy.gid] = true
				end
			end
		end
	end
end
reOriganizeEnemyList()

function getEnemyInfoByPid(pid)
	return enemyListMap[pid] and enemyListMap[pid] or {}
end

local function notIn(num, mask)
	return (not mask[num]) and true or false
end

function getAllEnemy()
	local ret = {}

	for i, v in pairs(enemyListMap) do
		if v.level >= OpenlevConfig.get_open_level(1901) and v.type == 1 then
			table.insert(ret, v)	
		end
	end

	return ret
end

function get_main_role_list()
	local ret = {}

	for i, v in pairs(enemyListMap) do
		if v.type == 2 then
			table.insert(ret, v)
		end
	end

	return ret
end

function getEnemyList(averagePowerLower, averagePowerUpper, num, mask)
	yqinfo("begin to getEnemyList  lower:%d  upper:%d  num:%d  mask:%s", averagePowerLower, averagePowerUpper, num, sprinttb(mask))
	mask = mask or {}
	local EnemyList = {}
	local indexLower = math.ceil(averagePowerLower / STRIDE)
	local indexUpper = math.ceil(averagePowerUpper / STRIDE)
	local player_fast_list = ArenaPlayerPool:getPlayerFastList()
	for i = indexLower, indexUpper, 1 do
		for k, v in ipairs(player_fast_list[i] or {}) do
			local _, power = getPlayerFightData(v._pid)
			if power >= averagePowerLower and power < averagePowerUpper and notIn(v._pid, mask) then
				table.insert(EnemyList, v._pid)
			end
		end
	end
	
	local ret = {}
	
	if num > 0 then
		ret = get_rand_unique_num(EnemyList, num)
	else
		yqinfo("num is less than 0, num = ", num)	
	end

	yqinfo("result of getEnemyList :%s",sprinttb(ret))
	return ret
end 

function getAIEnemyList(averagePowerLower, averagePowerUpper, num, mask)
    yqinfo("begin to getAIEnemyList  lower:%d  upper:%d  num:%d  mask:%s", averagePowerLower, averagePowerUpper, num, sprinttb(mask))
    mask = mask or {}
    local EnemyList = {}
    local indexLower = math.ceil(averagePowerLower/STRIDE)
    local indexUpper = math.ceil(averagePowerUpper/STRIDE)
    for i=indexLower, indexUpper, 1 do
        for k, v in ipairs(enemyListFast[i] or {}) do
            if v.power >= averagePowerLower and v.power < averagePowerUpper and notIn(v.pid, mask) and v.level >= OpenlevConfig.get_open_level(1911) then
                table.insert(EnemyList,v.pid)
            end
        end
    end
	
    local ret = {}
    if num > 0 then
    	ret = get_rand_unique_num(EnemyList, num)
    else	
	yqinfo("num is less than 0, num = ", num)	
    end

    yqinfo("result of getAIEnemyList :%s",sprinttb(ret))
    return ret
end

function getPowerByEnemyID(enemyID)
	return enemyListMap[enemyID] and enemyListMap[enemyID].power or nil
end

local function mergeTb(t1, t2)
	assert(t2)
	for _, v in ipairs(t2) do
		table.insert(t1, v)
	end
end

function genOriginalRankArenaAIEnemy()
	local ret = {}
	-- 1
	local rand = math.random(1, 10)	
	table.insert(ret, 105000 + rand -1)	
	-- 2-10	
	local pool = {}
	for i = 1, 50 do
		table.insert(pool, 105010 + i - 1)
	end
	mergeTb(ret, get_rand_unique_num(pool, 9))
	-- 11-50
	pool = {}
	for i = 1, 200 do
		table.insert(pool, 105060 + i - 1)
	end
	mergeTb(ret, get_rand_unique_num(pool, 40))
	-- 51-150
	pool = {}
	for i = 1, 300 do
		table.insert(pool, 105260 + i - 1)
	end
	mergeTb(ret, get_rand_unique_num(pool, 100))
	

	return ret
end

function genRankArenaAIEnemy()
	local t = {}
	for pid, v in pairs(ai_not_join_rank_arena) do
		table.insert(t, pid)
	end	

	if #t > 0 then
		return get_rand_unique_num(t, 3)
	end	

	return
end

function AIJoinRankArena(id)
	ai_not_join_rank_arena[id] = nil
end

function AllAIJoinRankArena()
	return not next(ai_not_join_rank_arena)
end

