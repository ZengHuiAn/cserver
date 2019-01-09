local loop = loop;
local string = string;
local pairs = pairs;
local ipairs = ipairs;
local os = os;
local log = log;
local assert = assert;
local tonumber = tonumber;
local setmetatable = setmetatable;
local rawset = rawset;
local next = next;
local table = table;
local print = print;
local coroutine = coroutine;
local math = math;
local type = type;
local Scheduler = require "Scheduler"
require "printtb"
local sprinttb = sprinttb

module "InviteManager"

local queue = {}
local g_count  = 0
local t_min = 0;

--[[
--queue
--1.是否已经使用
--2.邀请人
--3.被邀请人
--4.对应的军团
--5.时间
--]]


function Add(host, guest, gid)
    g_count = g_count + 1
    queue[g_count] = {false, host, guest, gid, loop.now()}
    return g_count
end

function Get(idx)
    if not idx or idx < 1 then
        log.info("InviteManager Get Fail, err idx for queue", idx or -1)
        return nil
    end
    return queue[idx]
end

function Use(idx)
    queue[idx][1] = true
    return 
end

Scheduler.Register(function(now)
    if not next(queue) then
        return;
    end
    if now > t_min then 
        t_min = now + 300 
        for k, v in pairs(queue) do
            t_min = math.min(t_min, v[5]);
            if now - v[5] > 300 then
                queue[k] = nil
            end
        end
    end
end)
