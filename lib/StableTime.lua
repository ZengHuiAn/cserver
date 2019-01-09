local get_time =loop.now
local os =require "os"
local database = require "database"
module "StableTime"

-- time
local t_recent =get_time()
function stable_now()
	local t =get_time()
	if t >= t_recent then
		t_recent =t
	end
	return t_recent
end
function get_today_begin_time()
	local now =stable_now()
	local dt =os.date("*t", now)
	dt.hour =0
	dt.min =0
	dt.sec =0
	return os.time(dt)
end

function get_begin_time_of_day(time)
	local dt = os.date("*t",time)
	dt.hour = 0
	dt.min = 0
	dt.sec = 0
	return os.time(dt)
end


function is_daily_refreshed(t, offset)
    local now = get_time()
    local refresh_time = get_today_begin_time() + offset;
    if now < refresh_time then
        refresh_time = refresh_time - 24 * 3600;
    end
    return t < refresh_time;
end

local open_server_time 
function get_open_server_time()
	if not open_server_time then
		local ok, result = database.query("SELECT UNIX_TIMESTAMP(`create`) as create_time FROM property WHERE pid = 100000");
   	    if ok and #result >= 1 then
		    local row = result[1]
		    open_server_time = row.create_time
	    end
	end
	return open_server_time
end
