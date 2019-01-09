local setmetatable = setmetatable;
local pairs = pairs;
local table = table;
local log = log;

local all = {};

-- global callback
function onUpdate(now)
	for k, opt in pairs(all) do
		local cb = opt.cb;	
		if type(cb) == "function" then
			local status, info = pcall(cb, now);
			if status == false then
				log.error(info);
			end
		else
			log.warning("Scheduler.onUpdate callback is not function");
		end

		opt.count = opt.count - 1

		if opt.count == 0 then
			all[k] = nil;
		end
	end
end

module "Scheduler"

local SchedulerOpt = {};
function SchedulerOpt:Register(func)
	table.insert(self.cb, func);
end

local nid = 0;
local function nextID()
	nid = nid + 1;
	return nid;
end

function Register(cb, count)
	local opt = setmetatable({cb=cb, id = nextID(), count = count or -1}, {__index=SchedulerOpt});
	all[opt.id] = opt;
	return opt;
end

function UnRegister(opt)
	if opt and opt.id  then
		all[opt.id] = nil;
	end
end

New = Register;
Release = UnRegister;
