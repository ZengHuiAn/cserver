local Container = {}

local Time = require "module.Time"

local containers = {};

local function Container_New(_, name, timeout)
    if containers[name] then
        return containers[name];
    end

    local t = setmetatable({
        name = name,
        list = {},
        timeout = timeout or 5 * 60,
        notify = {},
        respond = {},
        all_is_querying = false,
        waiting_list = {},
        Query = false,
        QueryAll = false,
        event_info = string.format("CONTAINER_%s_INFO_CHANGE", name),
        event_list = string.format("CONTAINER_%s_LIST_CHANGE", name),
    }, {__index= function(t, k)
        if Container[k] then
            return Container[k];
        end

        return Container.Get(t, k);
    end})

    t.query_thread = coroutine.create(function()
        while true do
            local _id = next(t.waiting_list);
            if not _id then
                -- ERROR_LOG("container", t.name, 'sleep')
                coroutine.yield();
                -- ERROR_LOG("container", t.name, 'resume')
            else
                local info = t.list[_id]

                if not info or info.query_time + t.timeout < Time.now() then
                    if _id ~= '_all' and t.Query then
                        t:_AddItems(t:Query(_id))
                    elseif t.QueryAll and not t.all_is_querying then
                        t.all_is_querying = true;
                        t:_AddItems(t.QueryAll());
                    end
                end

                local cos = t.waiting_list[_id] or {};
                t.waiting_list[_id] = nil;

                for _, co in ipairs(cos) do
                    local success, info = coroutine.resume(v);
                    if not success then
                        ERROR_LOG(info);
                    end
                end
            end
        end
    end)

    containers[name] = t;

    return t;
end

function Container:OnServerNotify(cmd, callback)
    if self.notify[cmd] then
        self.notify[cmd] = callback;
        return;
    end

    self.notify[cmd] = callback;

    utils.EventManager.getInstance():addListener("server_notify_" .. cmd, function(cmd, _, data)
        local func = self.notify[cmd];
        return self:_AddItems(func and func(data) or {});
    end)
end

function Container:OnServerRespond(cmd, callback)
    if self.respond[cmd] then
        self.respond[cmd] = callback;
        return;
    end

    self.respond[cmd] = callback;

    utils.EventManager.getInstance():addListener("server_respond_" .. cmd, function(cmd, _, data)
        if data[2] ~= 0 then
            return;
        end

        local func = self.respond[cmd];
        return self:_AddItems(func and func(data) or {});
    end)
end

function Container:_AddItems(items)
    local list_changed = false;
    for _, item in ipairs(items or {}) do
        list_changed = self:Update(item) or list_changed;
    end

    if list_changed then
        utils.EventManager.getInstance():dispatch(self.event_list);
    end
end

function Container:Update(item)
    local list_changed = false;
    local info = self.list[item.id]
    if not info or not info.item.id then
        list_changed = true;
    end
    
    self.list[item.id] = self.list[item.id] or {};
    self.list[item.id].query_time = Time.now()
    self.list[item.id].item = item;

    utils.EventManager.getInstance():dispatch(self.event_info, item.id);

    return list_changed;
end

function Container:Remove(id)
    self.list[id] = nil
end

function Container:Clean()
    self.list = {}
    self.all_is_querying = false;
end

local function getCurrentThread()
    local co = coroutine.running();
	if co == nil or (coroutine.isyieldable and not coroutine.isyieldable()) then
        return nil;
    end
    return co;
end

function Container:TryQuery(id)
    if id == 0 then
        ERROR_LOG(debug.traceback());
        return;
    end

    if id == '_all' and self.all_is_querying and not self.waiting_list[id] then -- all is ready
        return;
    end

    local no_need_start_query_thread = next(self.waiting_list)

    self.waiting_list[id] = self.waiting_list[id] or {}

    local co = getCurrentThread()
    if co then
        table.insert(self.waiting_list[id], co)
    end

    if not no_need_start_query_thread then
        assert(coroutine.resume(self.query_thread));
    end

    if co then
        return coroutine.yield();
    else
        return;
    end
end

function Container:Get(id, not_query)
    local info = self.list[id];
    if not_query or (info and info.query_time + self.timeout > Time.now()) then
        return info and info.item;
    end

    self:TryQuery(id);

    local info = self.list[id];
    return info and info.item;
end

function Container:GetList(hash)
    -- ERROR_LOG('Container:GetList', self.name, getCurrentThread());

    self:TryQuery('_all');

    local list = {}
    for _, v in pairs(self.list) do
        if v.item.id then
            if hash then
                list[v.item.id] = v.item;
            else
                table.insert(list, v.item);
            end
        end
    end
    return list;
end

Container = setmetatable(Container, {
    __call  = Container_New,
})

return Container;