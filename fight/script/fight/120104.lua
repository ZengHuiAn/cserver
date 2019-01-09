local script_data
local dead_count_1 = 0

function TIMELINE_Finished()
    script_data = script_data or game:API_GetBattleData()
    if game.timeline.winner == 1 then
        --水系场景击败
        if game:API_GetSceneName() == "xuedi_0"  
		or game:API_GetSceneName() == "xuedi_1"  
        or game:API_GetSceneName() == "xuedi_2" 
        then
            game:API_AddRecord(nil, 2606006)
        end
        
        --没复活
        if not script_data.record_2606007 then
            game:API_AddRecord(nil, 2606007)
        end
        
        --通关
        game:API_AddRecord(nil, 2606001)
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
            game:API_AddRecord(nil, 2606011)
        end
    end
end

