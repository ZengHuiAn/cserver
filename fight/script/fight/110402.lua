local script_data
local dead_count_1 = 0
local Killer = {}
local Kill_wave = 0

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
            game:API_AddRecord(nil, 2604009)
        end
    end
end

function Unit_DEAD_SYNC(_, role)
    --粉 红一起杀
    script_data = script_data or game:API_GetBattleData()
    if role.id == 31042 or role.id == 31043 then
        if self.game.timeline.current_running_obj == Killer and Kill_wave == script_data.current_wave then
            game:API_AddRecord(nil, 2604002)
        end
        Killer = self.game.timeline.current_running_obj
        Kill_wave = script_data.current_wave
    end
end
