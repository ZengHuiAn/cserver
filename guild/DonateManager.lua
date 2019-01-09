local cell =require "cell"
local math =require "math"
local database =require "database"
local StableTime =require "StableTime"
local stable_time =StableTime.stable_time
local get_today_begin_time =StableTime.get_today_begin_time
local table=table
local loop=loop;
local log = log
require "DonateConfig"
local DonateConfig = DonateConfig
require "GuildSummaryConfig"
local DAILY_MAX_DONATE_COUNT = GuildSummaryConfig.DailyMaxDonateCount

module "DonateManager"

local MAX_DONATE_RECORD_COUNT =100
local g_donate ={}

local function is_vip_donate_type(donate_type)
    local Config = DonateConfig[donate_type] or {VipLimit = 0};
    if Config.VipLimit > 0 then
        return true
    end
    return false;
end

function get_donate(pid)
	local donate =g_donate[pid]
	if not donate then
		--[[ base
		local ok, result =database.query("SELECT total_exp FROM guild_donate WHERE pid=%d", pid)
		if ok and #result>=1 then
			local row =result[1]
			donate ={
				pid =pid,
				total_exp =row.total_exp,
				record_list ={},
			}
		else
			donate ={
				pid =pid,
				total_exp =0,
				record_list ={}
			}
		end
		]]
		donate ={
			pid =pid,
			record_list ={},
            vip_record_list = {},
		}
		-- record
		ok, result =database.query("SELECT donate_time, donate_type FROM guild_donate_record WHERE pid=%d ORDER BY donate_time DESC LIMIT %d", pid, MAX_DONATE_RECORD_COUNT)
		log.info(ok)
		log.info(#result)
		if ok and #result>=1 then
			for i=1, #result do
				local row =result[i]
                if not is_vip_donate_type(row.donate_type) then
                    table.insert(donate.record_list, {
                        donate_time =row.donate_time,		
                        donate_type =row.donate_type,		
                    })
                else
                    table.insert(donate.vip_record_list, {
                        donate_time =row.donate_time,		
                        donate_type =row.donate_type,		
                    })
                end
			end
		end
		g_donate[pid] =donate
	end
	return donate
end
function Clean(pid)
	if pid then
		g_donate[pid] =nil
	end
end
function CanDonate(player, donate_type)
	-- prepare
	local pid =player.id
	local donate =get_donate(pid)
	--local today_begin =get_today_begin_time() + 5 * 3600
    --if today_begin > loop.now() then
    --    today_begin = today_begin - 24 * 3600;
    --end

    if not is_vip_donate_type(donate_type) then
        local last_donate_time = donate.record_list[1] and donate.record_list[1].donate_time or 0
        --local can =last_donate_time < today_begin
		local can = player.today_donate_count < DAILY_MAX_DONATE_COUNT 
        return can, last_donate_time
    else
        local last_donate_time = donate.vip_record_list[1] and donate.vip_record_list[1].donate_time or 0
        --local can =last_donate_time < today_begin
		local can = player.today_donate_count < DAILY_MAX_DONATE_COUNT 
        return can, last_donate_time
    end
end
function HasDonatedToday(player)
	-- prepare
	local pid =player.id
	local donate =get_donate(pid)
	local today_begin =get_today_begin_time() + 5 * 3600
    if today_begin > loop.now() then
        today_begin = today_begin - 24 * 3600;
    end

	local last_donate_time = donate.record_list[1] and donate.record_list[1].donate_time or 0
    local last_vip_donate_time = donate.vip_record_list[1] and donate.vip_record_list[1].donate_time or 0;
    
    local has_common_donate =  (last_donate_time >= today_begin)
    local has_vip_donate = (last_vip_donate_time >= today_begin)

    if has_vip_donate then
       if not has_common_donate then
           return 2;
       else
           return 3;
       end
   else
       if not has_common_donate then
           return 0;
       else
           return 1;
       end
   end
end
function Donate(player, donate_type, self_add_exp)
	-- prepare
	local pid =player.id
	local donate =get_donate(pid)

	--[[ add exp
	donate.total_exp =donate.total_exp + self_add_exp
	database.update("REPLACE INTO guild_donate(pid, total_exp)VALUES(%d, %d)", pid, donate.total_exp)
	]]

	-- record
	local record ={
		donate_time =StableTime.stable_now(),
		donate_type =donate_type,
	}
    if not is_vip_donate_type(donate_type) then
        table.insert(donate.record_list, 1, record) -- push front
    else
        table.insert(donate.vip_record_list, 1, record) -- push front
    end
	
	database.update("INSERT INTO guild_donate_record(pid, donate_type, donate_time)VALUES(%d, %d, %d)", pid, record.donate_type, record.donate_time)
end

function QueryDonate(player, max_count)
	-- prepare
	local max_count =max_count or 0
	local pid =player.id
	local donate =get_donate(pid)

	-- get
	local ret ={}
	local cnt =math.min(max_count, #donate.record_list)
	for i=1, cnt do
		local item =donate.record_list[i]
		table.insert(ret, { item.donate_time, item.donate_type })
	end
    local cnt = math.min(max_count, #donate.vip_record_list)
	for i=1, cnt do
		local item =donate.vip_record_list[i]
		table.insert(ret, { item.donate_time, item.donate_type })
	end
	return ret
end
