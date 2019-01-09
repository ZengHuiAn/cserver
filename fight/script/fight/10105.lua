local script_data
local dead_count_1 = 0

function TIMELINE_Finished()
    script_data = script_data or game:API_GetBattleData()
    if game.timeline.winner == 1 then
        --通关
        game:API_AddRecord(nil, 2601001)
        --冰系角色不死
        for k, v in pairs(game.roles) do
            if v.side == 1 and v.hp > 0 then
                if v.id == 11001 or v.id == 11008 then
                    game:API_AddRecord(nil, 2601002)
                end
            end
        end     
        --脚本中记录的条件
        if script_data.record_list then
            for k, v in pairs(script_data.record_list) do
                game:API_AddRecord(k)
            end
        end
        --无阵亡
        for k, v in pairs(game.roles) do
            if v.side == 1 and v.hp <= 0 then
                dead_count_1 = dead_count_1 + 1
            end
        end  
        
        if dead_count_1 == 0 then
            game:API_AddRecord(nil, 2601013)
        end
    end
end

function Unit_DEAD_SYNC(_, role)
    script_data = script_data or game:API_GetBattleData()
    if role.side == 2 and role.id == 31010 then
        for k, v in pairs(game.roles) do
            if v.id == 31012 and v.hp/v.hpp >= 0.5 then
                script_data.record_list[2601006] = true
            end
        end     
    end
end
