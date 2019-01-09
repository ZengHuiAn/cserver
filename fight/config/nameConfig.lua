local nameCfgTab = nil
local sexType = {
    Boy = 0,
    Girl = 1,
}

local function getRandomName(typeId)
    if not nameCfgTab then
        nameCfgTab = {}
        nameCfgTab.boy1 = {}
        nameCfgTab.boy2 = {}
        nameCfgTab.girl1 = {}
        nameCfgTab.girl2 = {}
        DATABASE.ForEach("randname", function(data)
            for i = 1, 2 do
                if data["boy"..i] and data["boy"..i] ~= "" then
                    table.insert(nameCfgTab["boy"..i], data["boy"..i])
                end
                if data["girl"..i] and data["girl"..i] ~= "" then
                    table.insert(nameCfgTab["girl"..i], data["girl"..i])
                end
            end
        end)
    end
    if typeId == sexType.Girl then
        return nameCfgTab.girl1[math.random(1, #nameCfgTab.girl1)]..nameCfgTab.girl2[math.random(1, #nameCfgTab.girl2)]
    else
        return nameCfgTab.boy1[math.random(1, #nameCfgTab.boy1)]..nameCfgTab.boy2[math.random(1, #nameCfgTab.boy2)]
    end
end

return {
    SexType = sexType,
    Get = getRandomName,
}
