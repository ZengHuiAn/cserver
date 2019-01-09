local script_data
local dead_count_1 = 0

function TIMELINE_Finished()
    script_data = script_data or game:API_GetBattleData()
    if game.timeline.winner == 1 then
        --提升不超过60%
        if not script_data.record_2602005 then
            game:API_AddRecord(nil, 2602005)
        end
        --一次都没召唤
        if not script_data.Record_summon then
            game:API_AddRecord(nil, 2602004)
        end
        --无阵亡
        for k, v in pairs(game.roles) do
            if v.side == 1 and v.hp <= 0 then
                dead_count_1 = dead_count_1 + 1
            end
        end  
        
        if dead_count_1 == 0 then
            game:API_AddRecord(nil, 2602010)
        end
    end
end
