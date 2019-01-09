local RewardItemShowTab = nil

local TYPE = {
    LUCKY_DRAW_TIME = 1001,
    UNION_WISH      = 2001,
    UNION_EXPLORE   = 2111,
}

local function Get(typeId)
    if not RewardItemShowTab then
        RewardItemShowTab = {}
        DATABASE.ForEach("item_show", function(data)
            if not RewardItemShowTab[data.id] then RewardItemShowTab[data.id] = {} end
            table.insert(RewardItemShowTab[data.id], {type = data.item_type, id = data.item_id, count = data.item_count})
        end)
    end
    return RewardItemShowTab[typeId]
end

return {
    TYPE = TYPE,
    Get = Get,
}
