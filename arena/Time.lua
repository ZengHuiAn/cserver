local floor = math.floor;
local loop = loop
--local time  = os.time;
local print = print;
local date  = os.date;

module "Time"

MSEC = 60;
HSEC = MSEC * 60;
DSEC = HSEC * 24;
WSEC = DSEC * 7;

local time_base = 1295712000; -- 1356192000 - WSEC * 100;
-- print(date("%c", time_base));

local function foo(t)
    return t;
end


function ROUND(t, base, func)
    t = t or loop.now();

    if t > time_base then t = t - time_base; end

    func = func or foo;

    return floor(t/base), func(t % base);
end

function SEC(t, deep)
    return ROUND(t, 1);
end

function MINUTE(t, deep)
    return ROUND(t, MSEC, deep and SEC or nil);
end

function HOUR(t, deep)
    return ROUND(t, HSEC, deep and MINUTE or nil);
end

function DAY(t, deep)
    return ROUND(t, DSEC, deep and HOUR or nil);
end

function WEEK(t, deep)
    return ROUND(t, WSEC, deep and DAY or nil);
end

