require "yqmath"
require "yqlog_sys"
require "printtb"
require "yqmath"
local database = require "database"
local yqinfo = yqinfo
local ipairs = ipairs
local table = table
local math = math
local sprinttb = sprinttb
local Class = require "Class"
local assert = assert

module "GuildPrayConfig"

local single_instance = nil
local GuildPrayConfig = {}

local function insertItem(list, type, id, value, cost, contribution)
	if type == 0 or id == 0 then
		return 
	end
	local temp = {
		type = type,
		id = id,
		value = value,
		cost = cost,
		contribution = contribution
	}
	table.insert(list, temp)
end

function GuildPrayConfig:_init_()
	self.guildPrayConfig = {}
	self.guildPrayConfigMap = {}
	self.guildPrayConfigByLevel = {}
	local indexTb = {}
	--local ok, result = database.query("SELECT id, product_type, product_id, product_value, progress_needed, consume_type1, consume_id1, consume_value1, cost1, contribution1, consume_type2, consume_id2, consume_value2, cost2, contribution2, consume_type3, consume_id3, consume_value3, cost3, contribution3, consume_type4, consume_id4, consume_value4, cost4, contribution4, consume_type5, consume_id5, consume_value5, cost5, contribution5 FROM pray_config")
	local ok, result = database.query("SELECT id, product_type, product_id, product_value, progress_needed, consume_type, consume_id, consume_value, cost, contribution, armylev FROM pray_config ORDER BY id, `index`")
    if ok and #result >= 1 then
       	 for i = 1, #result do
           	local row = result[i];
			--[[local temp = {
				id = row.id,
				product_type = row.product_type,
				product_id = row.product_id,
				product_value = row.product_value,
				progress_needed = row.progress_needed,
				consume = {},
			}
			insertItem(temp.consume, row.consume_type1, row.consume_id1, row.consume_value1, row.cost1, row.contribution1)
			insertItem(temp.consume, row.consume_type2, row.consume_id2, row.consume_value2, row.cost2, row.contribution2)
			insertItem(temp.consume, row.consume_type3, row.consume_id3, row.consume_value3, row.cost3, row.contribution3)
			insertItem(temp.consume, row.consume_type4, row.consume_id4, row.consume_value4, row.cost4, row.contribution4)
			insertItem(temp.consume, row.consume_type5, row.consume_id5, row.consume_value5, row.cost5, row.contribution5)
			table.insert(self.guildPrayConfig, temp)
			self.guildPrayConfigMap[row.id] =  temp
			]]
			if indexTb[row.id] then
				local key = indexTb[row.id]
				insertItem(self.guildPrayConfig[key].consume, row.consume_type, row.consume_id, row.consume_value, row.cost, row.contribution)
				--insertItem(self.guildPrayConfigMap[row.id].consume, row.consume_type, row.consume_id, row.consume_value, row.cost, row.contribution)
			else
				local temp = {
					id = row.id,
					product_type = row.product_type,
					product_id = row.product_id,
					product_value = row.product_value,
					progress_needed = row.progress_needed,
					level = row.armylev,
					consume = {},
				}
				insertItem(temp.consume, row.consume_type, row.consume_id, row.consume_value, row.cost, row.contribution)
				table.insert(self.guildPrayConfig, temp)
				self.guildPrayConfigMap[row.id] = temp
				indexTb[row.id] = #self.guildPrayConfig
			end
        end
    end
end

function GuildPrayConfig:getConfigContent(id)
	return self.guildPrayConfigMap[id] and self.guildPrayConfigMap[id] or nil 
end

function GuildPrayConfig:getRandomConfig(level)
	assert(#self.guildPrayConfig > 0, "GuildPrayConfig is empty")
	if not self.guildPrayConfigByLevel[level] then
		self.guildPrayConfigByLevel[level] = {}
		for k, v in ipairs(self.guildPrayConfig) do
			if v.level == level then
				table.insert(self.guildPrayConfigByLevel[level], self.guildPrayConfig[k])
			end
		end
	end	
	if not self.guildPrayConfigByLevel[level] or #self.guildPrayConfigByLevel[level] == 0 then
		yqinfo("GuildPrayConfig for level:%d is empty", level)	
		return nil
	end
	local randIndex = math.random(1, #self.guildPrayConfigByLevel[level])
	return self.guildPrayConfigByLevel[level][randIndex]
end

function Get()
	if not single_instance then
		single_instance = Class.New(GuildPrayConfig)
	end
	return single_instance
end

