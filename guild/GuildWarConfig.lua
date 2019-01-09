-- config for guild war
local io = io
module "GuildWarConfig"
g_prepare_status = 0;
g_check_status   = 1;
g_run_status     = 2;
g_reward_status  = 3;
g_end_status     = 4;

-- config for guild war 1 round
g_fight_wait    = 0;
g_fight_prepare = 1;
g_fight_run     = 2;
g_fight_end     = 3;
g_fight_over    = 4;

-- global room id
g_max_room_id = 2;
g_dz_map = {
    {{1,32,},{2,31,},{3,30,},{4,29,},{5,28,},{6,27,},{7,26,},{8,25,}, {9,24,}, {10,23,}, {11,22,}, {12,21,},{13,20,},{14,19,},{15,18,},{16,17,}}, 
    {{1,16,},{2,15,},{3,14,},{4,13,},{5,12,},{6,11,},{7,10,},{8, 9,}, }, 
    {{1,8,}, {2, 7,},{3, 6,},{4, 5,}, }, 
    {{1,4,}, {2, 3,},}, 
    {{1,2,}, {3, 4,},}, 
} 

g_guild_war_start_time = 1420041600
g_guild_fight_record_delta = 4;
g_guild_load_player_delta = 600;

local g_member_reward = {
    [1] = {
        {type = 41, id = 240101,  value = 10},
        {type = 90, id = 23,     value = 1200},
        {type = 41, id = 430209, value = 3},
        {type = 90, id = 2,      value = 200000},
        {type = 41, id = 410012, value = 1},
        {type = 41, id = 430195, value = 1},
        {type = 41, id = 430196, value = 1},
    },
    [2] = {
        {type = 41, id = 240101, value = 9}, 
        {type = 90, id = 23,    value = 1000},
        {type = 41, id = 430209,value = 3},
        {type = 90, id = 2,     value = 200000},
        {type = 41, id = 410012,value = 1},
        {type = 41, id = 430195,value = 1},
    },
    [3] = {
        {type = 41, id = 240101, value = 8}, 
        {type = 90, id = 23,    value = 900}, 
        {type = 41, id = 430209,value = 2},
        {type = 90, id = 2,     value = 100000},
        {type = 41, id = 410012,value = 1},
    },
    [4] = {
        {type = 41, id = 240101,  value = 7}, 
        {type = 90, id = 23,     value = 800}, 
        {type = 41, id = 430209, value = 2},
        {type = 90, id = 2,      value = 100000},
    },
    [5] = {
        {type = 41, id = 240101, value = 6}, 
        {type = 90, id = 23,    value = 700}, 
        {type = 41, id = 430209,value = 1},
        {type = 90, id = 2,     value = 50000},
    },
    [6] = {
        {type = 41, id = 240101, value = 5}, 
        {type = 90, id = 23,    value = 600}, 
        {type = 90, id = 2,     value = 50000},
    },
    [7] = {
        {type = 41, id = 240101, value = 4}, 
        {type = 90, id = 23,    value = 500}, 
        {type = 90, id = 2,     value = 50000},
    },
}


RoomConfig = {
    [1] = {
        WarPrepareTime  =  1425830400, 
        CheckDelta      =  3 * 86400 + 20 * 3600,
        BeginDelta      =  3 * 86400 + 20 * 3600 + 30 * 60,
        EndDelta        =  3 * 86400 + 21 * 3600 + 30 * 60,
        FreshPeriod     =  7 * 86400,
        GuildLevelLimit  =  2, 
        GuildMemberLimit =  16,
        FightBeginDelta = 60,
        FightPeriod     = 300,
        GoldInspireFactor = 50,
        WarInspireFactor  = {250, 150, 150, 150, 0, 0, 0, 0, 0};
        MaxMasterCount     = 4,
        MaxExpertCount     = 20,
        OrderPoint        = {30, 10, 10, 10, 0, 0, 0},
        MaxMemberCount    = 32,
        TeamPoint = 50,
        MaxInspireCount = 1,
        JoinConsume = {
            type = 90,
            id   = 2,
            value = 100000,
        },
        InspireConsume = {
            type = 90,
            id   = 6,
            value = 10,
        },
        TeamReward = {{
            type = 90,
            id   = 6,
            value = 20,
        }},
        LeaderReward = {
            [1] = {{ type = 90, id = 6, value = 1,}},
            [2] = {{ type = 90, id = 6, value = 1,} },
            [3] = {{ type = 90, id = 6, value = 1,} },
            [4] = {{ type = 90, id = 6, value = 1,} },
            [5] = {{ type = 90, id = 6, value = 1,} },
            [6] = {{ type = 90, id = 6, value = 1,} },
            [7] = {{ type = 90, id = 6, value = 1,} },
        },
        OrderReward = {
            [1] = { {type = 41, id = 430207, value = 1}, },
            [2] = { {type = 41, id = 430208, value = 1}, },
            [3] = { {type = 41, id = 430208, value = 1}, },
            [4] = { {type = 41, id = 430208, value = 1}, },
            [5] = { {}, },
        },
        MemberReward = g_member_reward,
    },
    [2] = {
        WarPrepareTime  = 1426176000, 
        CheckDelta      =  2 * 86400 + 20 * 3600,
        BeginDelta      =  2 * 86400 + 20 * 3600 + 30 * 60,
        EndDelta        =  2 * 86400 + 21 * 3600 + 30 * 60,
        FreshPeriod     =  7 * 86400,
        GuildLevelLimit  =  2, 
        GuildMemberLimit =  16,
        FightBeginDelta = 60,
        FightPeriod     = 5 * 60,
        GoldInspireFactor = 50,
        WarInspireFactor  = {250, 150, 150, 150, 0, 0, 0, 0, 0};
        MaxMasterCount     = 4,
        MaxExpertCount     = 20,
        OrderPoint        = {30, 10, 10, 10, 0, 0, 0},
        MaxMemberCount    = 32,
        TeamPoint = 50,
        MaxInspireCount = 1,
        JoinConsume = {
            type = 90,
            id   = 2,
            value = 100000,
        },
        InspireConsume = {
            type = 90,
            id   = 6,
            value = 10,
        },
        TeamReward = {{
            type = 90,
            id   = 6,
            value = 20,
        }},
        LeaderReward = {
            [1] = {{ type = 90, id = 6, value = 1,}},
            [2] = {{ type = 90, id = 6, value = 1,} },
            [3] = {{ type = 90, id = 6, value = 1,} },
            [4] = {{ type = 90, id = 6, value = 1,} },
            [5] = {{ type = 90, id = 6, value = 1,} },
            [6] = {{ type = 90, id = 6, value = 1,} },
            [7] = {{ type = 90, id = 6, value = 1,} },
        },
        OrderReward = {
            [1] = { {type = 41, id = 430207, value = 1}, },
            [2] = { {type = 41, id = 430208, value = 1}, },
            [3] = { {type = 41, id = 430208, value = 1}, },
            [4] = { {type = 41, id = 430208, value = 1}, },
            [5] = { {}, },
        },
        MemberReward = g_member_reward,
    },
}

local file, err = io.open("../log/DEBUG");
if file then
    RoomConfig = {
        [1] = {
            WarPrepareTime  =  1425639600, 
            CheckDelta      =  1800,
            BeginDelta      =  1830,
            EndDelta        =  3600 - 10,
            FreshPeriod     =  7200,
            GuildLevelLimit  =  1, 
            GuildMemberLimit =  1,
            FightBeginDelta = 30,
            FightPeriod     = 200,
            GoldInspireFactor = 50,
            WarInspireFactor  = {250, 150, 150, 150, 0, 0, 0, 0, 0};
            MaxMasterCount     = 4,
            MaxExpertCount     = 20,
            OrderPoint        = {30, 10, 10, 10, 0, 0, 0},
            MaxMemberCount    = 32,
            TeamPoint = 50,
            MaxInspireCount = 1,
            JoinConsume = {
                type = 90,
                id   = 2,
                value = 0,
            },
            InspireConsume = {
                type = 90,
                id   = 6,
                value = 10,
            },
            TeamReward = {{
                type = 90,
                id   = 6,
                value = 20,
            }},
            LeaderReward = {
                [1] = {{ type = 90, id = 6, value = 1,}},
                [2] = {{ type = 90, id = 6, value = 1,} },
                [3] = {{ type = 90, id = 6, value = 1,} },
                [4] = {{ type = 90, id = 6, value = 1,} },
                [5] = {{ type = 90, id = 6, value = 1,} },
                [6] = {{ type = 90, id = 6, value = 1,} },
                [7] = {{ type = 90, id = 6, value = 1,} },
            },
            OrderReward = {
                [1] = { {type = 41, id = 430207, value = 1}, },
                [2] = { {type = 41, id = 430208, value = 1}, },
                [3] = { {type = 41, id = 430208, value = 1}, },
                [4] = { {type = 41, id = 430208, value = 1}, },
                [5] = { {}, },
            },
            MemberReward = g_member_reward,
        },
        [2] = {
            WarPrepareTime  =  1425643200, 
            CheckDelta      =  1800,
            BeginDelta      =  1830,
            EndDelta        =  3600 - 10,
            FreshPeriod     =  7200,
            GuildLevelLimit  =  1, 
            GuildMemberLimit =  1,
            FightBeginDelta = 30,
            FightPeriod     = 200,
            GoldInspireFactor = 50,
            WarInspireFactor  = {250, 150, 150, 150, 0, 0, 0, 0, 0};
            MaxMasterCount     = 4,
            MaxExpertCount     = 20,
            OrderPoint        = {30, 10, 10, 10, 0, 0, 0},
            MaxMemberCount    = 32,
            TeamPoint = 50,
            MaxInspireCount = 1,
            JoinConsume = {
                type = 90,
                id   = 2,
                value = 0,
            },
            InspireConsume = {
                type = 90,
                id   = 6,
                value = 10,
            },
            TeamReward = {{
                type = 90,
                id   = 6,
                value = 20,
            }},
            LeaderReward = {
                [1] = {{ type = 90, id = 6, value = 1,}},
                [2] = {{ type = 90, id = 6, value = 1,} },
                [3] = {{ type = 90, id = 6, value = 1,} },
                [4] = {{ type = 90, id = 6, value = 1,} },
                [5] = {{ type = 90, id = 6, value = 1,} },
                [6] = {{ type = 90, id = 6, value = 1,} },
                [7] = {{ type = 90, id = 6, value = 1,} },
            },
            OrderReward = {
                [1] = { {type = 41, id = 430207, value = 1}, },
                [2] = { {type = 41, id = 430208, value = 1}, },
                [3] = { {type = 41, id = 430208, value = 1}, },
                [4] = { {type = 41, id = 430208, value = 1}, },
                [5] = { {}, },
            },
            MemberReward = g_member_reward,
        },
    }
end

