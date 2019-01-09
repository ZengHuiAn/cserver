local script_data
local dead_count_1 = 0

function TIMELINE_Finished()
    script_data = script_data or game:API_GetBattleData()
    if game.timeline.winner == 1 then
        --不打断射线
        if not script_data.record_2606003 then
            game:API_AddRecord(nil, 2606003)
        end
        --回满
        if script_data.record_2606004 then
            game:API_AddRecord(nil, 2606004)
        end

        --恶心抵抗
        if not script_data.record_2606005 then
            game:API_AddRecord(nil, 2606005)
        end
        
        --无阵亡
        for k, v in pairs(game.roles) do
            if v.side == 1 and v.hp <= 0 then
                dead_count_1 = dead_count_1 + 1
            end
        end  
        
        if dead_count_1 == 0 then
            game:API_AddRecord(nil, 2606010)
        end
    end
end
