local msec = 60;
local hsec = msec * 60;
local dsec = hsec * 24;
local wsec = dsec * 7;

local floor = math.floor;
local time  = os.time;
local print = print;

module "Time"

local time_base = 1356192000 - wsec * 100;

local function foo(t)
	return t;
end

local function CALC(t, base, func)
	t = t or time();

	if t > time_base then t = t - time_base; end

	func = func or foo;

	return floor(t/base), func(t % base);
end

function SEC(t, deep)
	return CALC(t, 1);
end

function MINUTE(t, deep)
	return CALC(t, msec, deep and SEC or nil);
end

function HOUR(t, deep)
	return CALC(t, hsec, deep and MINUTE or nil);
end

function DAY(t, deep)
	return CALC(t, dsec, deep and HOUR or nil);
end

function WEEK(t, deep)
	return CALC(t, wsec, deep and DAY or nil);
end
