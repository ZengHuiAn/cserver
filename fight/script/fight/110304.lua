local script_data
local dead_count_1 = 0

function TIMELINE_Finished()
   if game.timeline.winner == 1 then
        script_data = script_data or game:API_GetBattleData()
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
            game:API_AddRecord(nil, 2603012)
        end
    end
end
