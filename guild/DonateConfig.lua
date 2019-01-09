package.cpath=package.cpath .. ";../lib/?.so";
package.path =package.path  .. ";../lib/?.lua";
local Command = require "Command"

GUILD_DONATE_TYPE_PRIMARY =1
GUILD_DONATE_TYPE_MIDDLE =2
GUILD_DONATE_TYPE_ADVANCE =3
GUILD_DONATE_TYPE_HIGH =4
--[[DonateConfig ={
	[GUILD_DONATE_TYPE_PRIMARY] ={
		Consume ={
			type =41,
			id =90002,
			value =2000,
		},
		GuildAddExpValue =200,
		SelfAddExpValue =100,
        VipLimit = 0,
		ErrorNo = 1--Command.RET_RESOURCE_COIN_NOT_ENOUGH,
	},
	[GUILD_DONATE_TYPE_MIDDLE] ={
		Consume ={
			type =41,
			id =90006,
			value =30,
		},
		GuildAddExpValue =400,
		SelfAddExpValue =200,
        VipLimit = 0,
		ErrorNo = 1--Command.RET_RESOURCE_MDEAL_NOT_ENOUGH
	},
	[GUILD_DONATE_TYPE_ADVANCE] ={
		Consume ={
			type =41,
			id =90006,
			value =298,
		},
		GuildAddExpValue =4000,
		SelfAddExpValue =2000,
        VipLimit = 0,
		ErrorNo = 1--Command.RET_RESOURCE_MDEAL_NOT_ENOUGH
	},
    [GUILD_DONATE_TYPE_HIGH] = {
		Consume ={
			type =41,
			id =90002,
			value =0,
		},
		GuildAddExpValue =2000,
		SelfAddExpValue =2000,
        VipLimit = 3,
		ErrorNo = 1--Command.RET_RESOURCE_MDEAL_NOT_ENOUGH
    }
}--]]


require "protobuf"
local log = require "log"
DonateConfig = {}

-- init protocol
local function loadProtocol(file)
	local f = io.open(file, "rb")
	local protocol= f:read "*a"
	f:close()
	protobuf.register(protocol)
end

loadProtocol("../protocol/config.pb");


local function readFile(fileName, protocol)
	local f = io.open(fileName, "rb")
	local content = f:read "*a"
	f:close()

	return protobuf.decode("com.agame.config." .. protocol, content);
end

local function insertItem(t, type, id, value)
    if not type or type == 0 then
        return
    end

    if not id or id == 0 then
        return
    end

    if not value or value == 0 then
        return
    end

    table.insert(t, {type = type, id = id, value = value})
end


local cfg = readFile("../etc/config/guild/config_team_donate.pb", "config_team_donate");
for _, v in ipairs(cfg.rows) do
	DonateConfig[v.DonateType] = {}
	DonateConfig[v.DonateType].Consume = {}
	if v.ExpendItemType ~= 0 then
		table.insert(DonateConfig[v.DonateType].Consume, {type = v.ExpendItemType, id = v.ExpendItemID, value = v.ExpendItemValue})	
	end
	DonateConfig[v.DonateType].Reward = {}
	insertItem(DonateConfig[v.DonateType].Reward, v.ItemType, v.ItemID,  v.Value)
	insertItem(DonateConfig[v.DonateType].Reward, v.ItemType2, v.ItemID2, v.Value2)
	DonateConfig[v.DonateType].GuildAddExpValue = v.BuildExp
	DonateConfig[v.DonateType].VipLimit = 0
	DonateConfig[v.DonateType].ErrorNo = 1
	DonateConfig[v.DonateType].GuildAddWealth = v.Guild_mammon or 100
end


