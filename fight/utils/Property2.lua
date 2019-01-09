local default_formula = require "utils.PropertyFormula"

local function PropertyGet(t, key)
    if #t.path > 0 then
        t.depends[key] = t.depends[key] or {};
        for _, v in ipairs(t.path) do
            t.depends[key][v] = true;
            -- depend loop check
            if key == v then
                local str = '\n[WARNING] ' .. key .. " depend loop: ";
                for _, v in ipairs(t.path) do
                    str = str .. v .. " -> ";
                end
                str = str .. key;
                assert(false, str);
            end
        end
    end

    local change = t.change[key] or 0;

    local v = t.cache[key];
    if v then
        return v + change;
    end

    local c = t.formula[key];
    if c then
        t.path[#t.path + 1] = key;
        v = c and c(t) or 0;
        t.path[#t.path] = nil;
    else
        v = t.values[key] or 0;
        for xx, m in pairs(t.merge) do
            v = v + (m and m[key] or 0)
        end
    end

    t.cache[key] = v;
    return v + change;
end

local function PropertySet(t, key, value)
    assert(type(value) == "number", debug.traceback())

    local diff = value - t[key]
    if diff == 0 then
        return;
    end

    local change = (t.change[key] or 0) + diff;

    t.change[key] = change
    t.change_record[key] = change;

    for k, _ in pairs(t.depends[key] or {}) do
        t.cache[k] = nil;
    end
end

local function PropertyAdd(t, key, values)
    t.merge[key] = values;
    t.cache = {}
end

local function PropertyRemove(t, key)
    if t.merge[key] then
        t.merge[key] = nil
        t.cache = {}
    end
end

local function PropertyFormula(t, k, func)
    t.formula[k] = func
end

local function PropertyEncode(t)
    local list = {}
    for k, v in pairs(t.values) do
        table.insert(list, {k, v})
    end
    return list;
end

local function PropertyDecode(t, list)
    t.values = {}
    t.cache = {}

    for _, v in ipairs(list) do
        t.values[ v[1] ] = v[2]
    end
end

local function PropertyNotify(t)
    local list = {}

    for k, v in pairs(t.change_record) do
        table.insert(list, {k, v});
    end
    t.change_record = {}

    if #list > 0 then
        return list
    end
end

local function PropertyApply(t, modify)
    for _, v in pairs(modify) do
        t.change[ v[1] ] = v[2]
    end
    t.cache = {}
end

local function Property(values)
    return setmetatable({
        sync_id = 0,

        values = values or {},
        formula = default_formula,

        merge = {},

        change = {},

        cache = {},

        path = {},
        depends = {},

        change_record = {},

        Add = PropertyAdd,
        Remove = PropertyRemove,
        Formula = PropertyFormula,

        Encode = PropertyEncode,
        Decode = PropertyDecode,

        Notify = PropertyNotify,
        Apply  = PropertyApply,
    }, {__index = PropertyGet, __newindex = PropertySet})
end

return Property;
