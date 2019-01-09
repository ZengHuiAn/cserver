local script_data
local dead_count_1 = 0
local dead_count_2 = 0 

function TIMELINE_Finished()
    script_data = script_data or game:API_GetBattleData()
    if game.timeline.winner == 1 then
        --无阵亡
        for k, v in pairs(game.roles) do
            if v.side == 1 and v.hp <= 0 then
                dead_count_1 = dead_count_1 + 1
            end
        end  
        
        if dead_count_1 == 0 then
            game:API_AddRecord(nil, 2607011)
        end
    end
end

function Unit_DEAD_SYNC(_, role)
    --杀2只暴走
    script_data = script_data or game:API_GetBattleData()
    if role.mode == 19038 then
        dead_count_2 = dead_count_2 + 1
        if dead_count_2 >= 2 then
            game:API_AddRecord(nil, 2607007)
        end
    end
end
