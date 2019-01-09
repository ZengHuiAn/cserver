local database = require "database"
local ai_male_name_min = -1 
local ai_male_name_max = -1 
local ai_female_name_min = -1 
local ai_female_name_max = -1 

local ai_name_min = -1;
local ai_name_max = -1;

local function InitAINameCount()
	ai_male_name_min = 0
	ai_male_name_max = 0
	ai_female_name_min = 0
	ai_female_name_max = 0

	local success, result = database.query("select MAX(id) as id from ai_name where sexual = 0")	
	if success and #result > 0 then
		ai_male_name_max = result[1].id		
	end

	local success, result = database.query("select MAX(id) as id from ai_name where sexual = 1")	
	if success and #result > 0 then
		ai_female_name_max = result[1].id		
	end

	ai_name_min = 0
	ai_name_max = ai_male_name_max + ai_female_name_max;

	if ai_male_name_max < ai_female_name_max then
		ai_male_name_min = 1
		ai_female_name_min = ai_male_name_max + 1
	else
		ai_female_name_min = 1
		ai_male_name_min = ai_female_name_max + 1
	end	

	--print("male_name_min, male_name_max, female_name_min, female_name_max >>>>>>>>>>>>>>>>>>>>>>", ai_male_name_min, ai_male_name_max, ai_female_name_min, ai_female_name_max)
end

InitAINameCount()

local function GetRandomName(sexual)
	local min = ai_name_min;
	local max = ai_name_max;

	sexual = 3

	if sexual == 0 then
		min = ai_male_name_min 
		max = ai_male_name_max
	elseif sexual == 1 then
		min = ai_female_name_min 
		max = ai_female_name_max
	end	

	if min == 0 and max == 0 then
		return nil
	end

	--print("Get random name for sexual", sexual, min, max)
	local id = math.random(min, max)
	local success, result = database.query("select name from ai_name where id = %d", id)	
	if success and #result > 0 then
		return result[1].name		
	end	
end

module "AIName"

GetAIRandomName = GetRandomName

