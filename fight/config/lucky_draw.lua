local lucky_drawConf = nil
local lucky_drawConf_weight = nil
local function GetConf(idx,type)
	if lucky_drawConf == nil then
		lucky_drawConf = {}
		lucky_drawConf_weight = {}
		
		DATABASE.ForEach("lucky_draw", function(row)
			if row.reward_item_id ~= 90401 then
				lucky_drawConf[row.pool_type] = lucky_drawConf[row.pool_type] or {}
				lucky_drawConf_weight[row.pool_type] = lucky_drawConf_weight[row.pool_type] or {}

				lucky_drawConf[row.pool_type][row.sub_type] = lucky_drawConf[row.pool_type][row.sub_type] or {}
				lucky_drawConf_weight[row.pool_type][row.sub_type] = lucky_drawConf_weight[row.pool_type][row.sub_type] or 0

				local j = #lucky_drawConf[row.pool_type][row.sub_type]
				lucky_drawConf[row.pool_type][row.sub_type][j+1] = row

				lucky_drawConf_weight[row.pool_type][row.sub_type] = lucky_drawConf_weight[row.pool_type][row.sub_type] + row.weight
			end
		end)
	end
	return lucky_drawConf[idx][type]--idx抽卡类型type抽卡奖池1普通2首抽3保底
end

local function GetMaxWeight(idx,type)
	if lucky_drawConf_weight == nil then
		return 0
	end
	return lucky_drawConf_weight[idx][type]
end

local dailyDrawConfig=nil
local function GetDailyDrawConfig(pool_type)
	if not dailyDrawConfig then
		dailyDrawConfig = {}
		DATABASE.ForEach("everyday_draw", function(data)
			dailyDrawConfig[data.pool_type] = dailyDrawConfig[data.pool_type] or {}
			table.insert(dailyDrawConfig[data.pool_type],data)
		end)
	end
	if not pool_type then return dailyDrawConfig end
	return dailyDrawConfig[pool_type]
end

return {
	GetConf = GetConf,
	GetMaxWeight = GetMaxWeight,
	GetDailyDrawConfig=GetDailyDrawConfig,
}