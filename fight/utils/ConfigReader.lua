local protobuf = require "protobuf"

local ConfigReader = {
    tables = {}
}

local emptyTable = {}

function ConfigReader.Load(name)
    local table = ConfigReader.tables[name];
    if table == emptyTable then
            return nil;
    end

    if table then
        return table;
    end

    local def = SGK.ResourcesManager.Load("config/" .. name .. ".def.bytes");
    if not def then
        print("ConfigReader", name, "not exists")
        ConfigReader.tables[name] = emptyTable;
        return nil;
    end

    protobuf.register(def.bytes);

    local bytes = SGK.ResourcesManager.Load("config/" .. name .. ".cfg.bytes").bytes;

    local cfg = protobuf.decode("sgk.config.config_" .. name, bytes);

    if cfg then
        ConfigReader.tables[name] = cfg.rows;
        return cfg.rows;
    end
    return {};
end

function ConfigReader.ForEach(name, callback)
    local t = ConfigReader.Load(name)
    for i, row in ipairs(t or {}) do
        callback(row, i)
    end
end


return ConfigReader;