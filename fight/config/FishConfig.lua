local FishConfig = {}

local BaseConfig = nil
local function buildBaseInfo()
    if BaseConfig then
        return ;
    end
    BaseConfig = {}
    DATABASE.ForEach("fish_reward", function(row)
        local min,max = row.fish_number_min, row.fish_number_max;
        local reward = {};
        for i=1,2 do
            local type,id,value = row["reward_type"..i],row["reward_id"..i],row["reward_value"..i];
            if type and id and value and value ~= 0 then
                table.insert(reward,{type = type, id = id, value = value});
            end
        end
        BaseConfig[min] = {reward = reward, min = min, max = max};
    end)
end

function FishConfig.getBaseInfo(index)
    buildBaseInfo();
    local ret = BaseConfig[index];
    if ret then
        return ret;
    end
end

local FishConsume = nil;
local function buildRewardInfo()
    if FishConsume then
        return ;
    end
    FishConsume = {};
    DATABASE.ForEach("fish_consume", function(row)
        local money_type,money_id,money_value = row.fish_consume_type, row.fish_consume_id, row.fish_consume_value;
        local free_type,free_id,free_value = row.fish_consume_type_free, row.fish_consume_id_free, row.fish_consume_value_free;
        FishConsume = {
            money_consume = {type = money_type, id = money_id, value = money_value},
            free_consume = {type = free_type, id = free_id, value = free_value},
            gofish_time = row.gofish_time, walkfish_time = row.walkfish_time, helpfish_time = row.helpfish_time,
            qtefish_time = row.qtefish_time, effective_time = row.effective_time,
        };
    end)
end

function FishConfig.getConsumeInfo()
    buildRewardInfo();
    if FishConsume then
        return FishConsume;
    end
end

return FishConfig