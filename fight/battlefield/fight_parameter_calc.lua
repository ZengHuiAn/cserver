local Calc = {}

--table子弹属性，value表示最终设置的值
function Calc:Bullet_calc(table, key, value)
    if not table then
        return value
    end

    if key == "phyDamageReduce" or key == "magicDamageReduce" then
        local change = value - table[key]
        if change < 0 then
            value = table[key] + (1 + table[key]) * change 
        end
    end
    return value
end

local Reduce_parameter_list = {
    [1421] = true,
    [1321] = true,
    [1891] = true,
    [1892] = true, 
    [1893] = true,
    [1894] = true,
    [1895] = true,
    [1896] = true,
    [1897] = true,
}

--table人物属性 ，value表示最终设置的值
function Calc:Role_calc(table, key, value)
    if Reduce_parameter_list[key] then
        local change = value - table[key]
        if change > 0 then
            value = table[key] + (10000 - math.min(10000, table[key])) * change / 10000
        end
    end

    return value
end

return Calc