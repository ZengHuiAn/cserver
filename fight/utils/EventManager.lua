local safe_pack = table.pack or function(...)
    local r = {...}
    r.n = select('#', ...)
    return r;
end

local safe_unpack = table.unpack or function(arg)
    return unpack(arg, 1, arg.n);
end

-- local event = {}
local function EventManager_New()
    return { list = {}, watcher = {}, cos = {} }
end

local function EventManager_Dispatch(manager, event, ...)
    if event and (manager.watcher[event] or manager.watcher['*'] or manager.cos[event]) then
        table.insert(manager.list, safe_pack(event, ...));
    end
end

local function EventManager_Watch(manager, event, callback)
    local list = manager.watcher[event];
    if not list then
        list = {n=0} -- setmetatable({n=0}, {__mode="v"});
        manager.watcher[event] = list;
    end

    if type(callback) == "table" and callback.send_message then
        table.insert(list, {ptr = callback, func = function(...) callback:send_message(...) end})
    else
        table.insert(list, {ptr = callback, func = callback})
    end
    list.n = list.n + 1;
end

local function EventManager_Unwatch(manager, event, callback)
    local list = manager.watcher[event] or {n=0}

    for i = 1, list.n do
        if list[i] and list[i].ptr == callback then
            list[i] = false;
            return;
        end
    end
end

local function EventManager_CallList(list, event, ...)
    if not list then
        return;
    end

    local nlist = {n=0} -- setmetatable({n=0}, {__mode="v"});
    for i = 1, list.n do
        local cb = list[i];
        if cb then
            -- cb.func(event, ...)
            xpcall(cb.func, function(...)
                ERROR_LOG(..., debug.traceback());
            end, event, ...)

            cb = list[i];
            if cb then
                table.insert(nlist, cb);
                nlist.n = nlist.n + 1;
            end
        end
    end

    if nlist.n > 0 then
        return nlist
    end
end

local function EventManager_Call(manager, event, ...)
    if manager.name then
        print("[EventManager:" .. manager.name .. "]", event, ...);
    end

    manager.watcher[event] = EventManager_CallList(manager.watcher[event], event, ...)
    manager.watcher[ '*' ] = EventManager_CallList(manager.watcher[ '*' ], event, ...)

    if manager.cos then
        local cos = manager.cos[event] or {}
        manager.cos[event] = nil;

        for _, co in ipairs(cos) do
            local success, info = coroutine.resume(co, event, ...);
            if not success then
                ERROR_LOG(info);
            end
        end
    end
end

local function EventManager_DispatchImmediately(manager, event, ...)
    EventManager_Call(manager, event, ...)
end

local function EventManager_ThreadWait(manager, event)
    local co = coroutine.running();
    manager.cos[event] = manager.cos[event]  or {}
    table.insert(manager.cos[event], co);
    return coroutine.yield();
end

local function EventManager_Tick(manager)
    local list = manager.list;

    local i = 0; 
    while i < #list do
        i = i + 1;
        EventManager_Call(manager, safe_unpack(list[i]));
    end

    manager.list = {};
end

-- manager
local managers = setmetatable({}, {__mode='v'});

local function New(alone)
    local e = setmetatable(EventManager_New(), {__index={
        dispatch = EventManager_Dispatch,
        dispatchImmediately = EventManager_DispatchImmediately;
        addListener = EventManager_Watch,
        removeListener = EventManager_Unwatch,
        ThreadWait = EventManager_ThreadWait,
        Tick = EventManager_Tick,
    }});

    if not alone then
        table.insert(managers, e);
    end

    return e;
end

local g_instance = nil

local function getInstance()
    if g_instance == nil then
        g_instance = New();
    end
    return g_instance;
end

local function Tick()
    -- collectgarbage();
    for _, v in pairs(managers) do
        EventManager_Tick(v);
    end
end

if CS and CS.SGK and CS.SGK.CoroutineService then
    CS.SGK.CoroutineService.Schedule(Tick);
end

return {
    New = New,
    getInstance = getInstance,
    Tick = Tick,
}
