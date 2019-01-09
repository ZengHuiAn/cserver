local script_data
local dead_count_1 = 0
local dead_count_ky = 0
local dead_count_kyzl = 0
local live_count_ky = 0

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
            game:API_AddRecord(nil, 2602009)
        end
    end
end

function Unit_DEAD_SYNC(_, role)
    script_data = script_data or game:API_GetBattleData()
    --长老死，矿源都活
    if role.id == 31023 then
        for k, v in pairs(game.roles) do
            if v.id == 31024 and v.side ~= 1 and v.hp <= 0 then
                dead_count_ky = dead_count_ky + 1
            end
        end 

        if dead_count_ky == 0 then
            game:API_AddRecord(nil, 2602002)
        end
    end
    --长老活，矿源都死
    if role.id == 31024 then
        for k, v in pairs(game.roles) do
            if v.id == 31024 and v.side ~= 1 and v.hp > 0 then
                live_count_ky = live_count_ky + 1
            end

            if v.id == 31023 and v.side ~= 1 and v.hp <= 0 then
                dead_count_kyzl = dead_count_kyzl + 1
            end
        end 

        if live_count_ky == 0 and dead_count_kyzl == 0 then
            game:API_AddRecord(nil, 2602003)
        end
    end
end
