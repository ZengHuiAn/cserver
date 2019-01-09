local script_data
local dead_count_1 = 0

function TIMELINE_Finished()
    script_data = script_data or game:API_GetBattleData()
    if game.timeline.winner == 1 then
        --雪莲不死
        if script_data.Record_2604003 == 2 then
            game:API_AddRecord(nil, 2604003)
        end
        --没有回血
        if not script_data.Record_2604004 then
            game:API_AddRecord(nil, 2604004)
        end

        --无阵亡
        for k, v in pairs(game.roles) do
            if v.side == 1 and v.hp <= 0 then
                dead_count_1 = dead_count_1 + 1
            end
        end  
        
        if dead_count_1 == 0 then
            game:API_AddRecord(nil, 2604010)
        end
    end
end

function Unit_DEAD_SYNC(_, role)
    script_data = script_data or game:API_GetBattleData()
    if role.id == 31041 then
        if role.id_98017 == 5 then
            game:API_AddRecord(nil, 2604005)
        end
    end
end
