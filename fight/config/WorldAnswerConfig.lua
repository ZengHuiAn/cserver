local WorldAnswerConfig = {}

local BaseConfig = nil

local function KEY(type, id)
    if type and id then
        return type * 1000000 + id;
    end
    return 0;
end

local function buildBaseInfo()
    if BaseConfig then
        return ;
    end
    BaseConfig = {}
    DATABASE.ForEach("dailyanswer", function(row)

    		local te_key = KEY(row.id, row.group);
    		BaseConfig[te_key] = row
		end)
end

function WorldAnswerConfig.getBaseInfo(id, group)
    buildBaseInfo();
    local ret = BaseConfig[KEY(id, group)];

    -- ERROE_LOG(id,group,sprinttb(ret))
    if not ret then
        return nil;
    end


    return ret;
end

local BaseReward = nil;
local function buildRewardInfo()
    if BaseReward then
        return ;
    end
    BaseReward = {}
    DATABASE.ForEach("dailyanswer_reward", function(row)
        local reward = {}
        for i=1,2 do
            if row["reward_type"..i] and row["reward_id"..i] then
                local config = {
                    type    = row["reward_type"..i],
                    id      = row["reward_id"..i],
                    value   = row["reward_value"..i],
                }
                table.insert(reward,config);
            end
        end
        BaseReward[row.correct_number] = reward
    end)
end

function WorldAnswerConfig.getRewardInfo( cNum)
    buildRewardInfo();
    if not cNum then
        return BaseReward;
    end

    local ret = BaseReward[cNum];
    if not ret then
        return nil;
    end
    return ret;
end

return WorldAnswerConfig