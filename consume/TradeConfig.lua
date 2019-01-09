local BinaryConfig = require "BinaryConfig"

local item_info = {}
local function load_item_config()
	local rows = BinaryConfig.Load("config_item", "item")
	
	if rows then
		for _,row in ipairs(rows) do
			item_info[row.id] = item_info[row.id] or { item_name = row.name}
		end
	end

end

local function get_item_config(id)
	if item_info[id] then
		return item_info[id]
	end
	return nil
end

load_item_config()

local trade_config = {}
local function load_trade_config()
	local rows = BinaryConfig.Load("config_trading_firm", "consume")	

	if rows then
		for _, row in ipairs(rows) do
			trade_config[row.item_type] = trade_config[row.item_type] or {}
			trade_config[row.item_type][row.item_id] = trade_config[row.item_type][row.item_id] or {
				sale_value = row.sale_value,
				assess_price = {
					type = row.price_type,
					id = row.price_id,
					value = row.price_value, 
				},
				fee_type = row.fee_type,
				fee_id = row.fee_id,
				fee_rate = row.fee_rate,

				sub_name = row.sub_name,
				is_special = row.is_special
			}
		end
	end
end

local function get_trade_config(type, id)
	if trade_config[type] and trade_config[type][id] then
		return trade_config[type][id]
	end

	return nil
end

local function get_all_trade_config()
	return trade_config
end

local trade_exchange_rate_config = {}
local function load_trade_exchange_rate_config()
	local rows = BinaryConfig.Load("config_trading_transform", "consume")	

	if rows then
		for _, row in ipairs(rows) do
			trade_exchange_rate_config[row.item_id_1] = trade_exchange_rate_config[row.item_id_1] or {}
			trade_exchange_rate_config[row.item_id_1][row.item_id_2] = trade_exchange_rate_config[row.item_id_1][row.item_id_2] or {
				rate1 = row.item_value_1,
				rate2 = row.item_value_2,
			}
		end
	end
end

local function get_trade_exchange_rate_config(id1, id2)
	if trade_exchange_rate_config[id1] and trade_exchange_rate_config[id1][id2] then
		return trade_exchange_rate_config[id1][id2]
	end

	return nil
end

load_trade_exchange_rate_config()
load_trade_config()


local trading_ai_info = {}
local function load_trading_ai_config()
        local rows = BinaryConfig.Load("config_trading_ai", "consume")

        if rows then
                for _,row in ipairs(rows) do
                        trading_ai_info[row.function_type] = trading_ai_info[row.function_type] or {}
			trading_ai_info[row.function_type][row.item_type] = trading_ai_info[row.function_type][row.item_type] or {}
			trading_ai_info[row.function_type][row.item_type][row.item_id] = { 
					grounding_num_conditon = row.grounding_num_conditon,
                                        grounding_price_down = row.grounding_price_down,
                                        grounding_price_up = row.grounding_price_up,

					begin_time = row.begin_time,
					end_time   = row.end_time,
					time_cd    = row.time_cd,
					period     = row.period
					}
                end
        end

end

local function get_trading_ai_config(type)

	return trading_ai_info[type] and trading_ai_info[type] or nil

end


load_trading_ai_config()


return {
	GetTradeConfig = get_trade_config,
	GetAllTradeConfig = get_all_trade_config,
	GetTradeExchangeRateConfig = get_trade_exchange_rate_config,
	GetItemConfig	= get_item_config,
	GetTradingAIConfig = get_trading_ai_config
}

