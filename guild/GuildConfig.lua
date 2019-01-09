package.cpath=package.cpath .. ";../lib/?.so";
package.path =package.path  .. ";../lib/?.lua";

local xml = require "xml"

local string = string;
local ipairs = ipairs;
local pairs = pairs;
local type = type;
local tonumber = tonumber;
local tostring = tostring;
local print = print;
local log  = log;

local Command = require "Command"
local XMLConfig = require "XMLConfig"
require "GuildBossConfig"
local NPC_HP =NPC_HP
local NPC_NAME = NPC_NAME
require "GuildMemberConfig"
local CONFIG_GUILD_MAX_MEMBER_LEVEL = CONFIG_GUILD_MAX_MEMBER_LEVEL
local CONFIG_GuildMemberInitConfig = CONFIG_GuildMemberInitConfig
local CONFIG_GUILD_MAX_MEMBER_BUY_COUNT = CONFIG_GUILD_MAX_MEMBER_BUY_COUNT
local CONFIG_GuildMemberAddConfig  = CONFIG_GuildMemberAddConfig
module "GuildConfig"

FIGHT_COUNT_PER_DAY = 100
CreateCost = {
	{id = Command.RESOURCES_COIN, value = 100000},
};
CreateLevel= 10;

local ServiceName = {"Guild"};
--------------------------------------------------------------------------------
-- load config from xml
FightDetailLocation  = XMLConfig.FightDetailLocation;

listen = {};
for idx, name in ipairs(ServiceName) do
    listen[idx] = {};
    listen[idx].host = XMLConfig.Social[name].host;
    listen[idx].port = XMLConfig.Social[name].port;
    listen[idx].name = name;
end

Listen = listen;

YQ_MAX_PLACEHOLDER = 5;
GUILD_MAX_LEVEL = 15;--for guild activity boss
GUILD_MAX_ADD_EXP_PER_DAY   =40000
GUILD_MAX_MEMBER_LEVEL = CONFIG_GUILD_MAX_MEMBER_LEVEL 
GUILD_MAX_MEMBER_BUY_COUNT = CONFIG_GUILD_MAX_MEMBER_BUY_COUNT

GuildBossInfo = {
    [1] = {
        Id =889001,
        Hp =NPC_HP[889001],
        Name=NPC_NAME[889001],
        RewardList = {
            {
                type = 90,
                id   = 21,
                value = 500,
            }
        }
    },
    [2] = {
        Id =889002,
        Hp =NPC_HP[889002],
        Name=NPC_NAME[889002],
        RewardList = {
            {
                type = 90,
                id   = 21,
                value = 500,
            }
        }
    },
    [3] = {
        Id =889003,
        Hp =NPC_HP[889003],
        Name=NPC_NAME[889003],
        RewardList = {
            {
                type = 90,
                id   = 21,
                value = 550,
            }
        }

    },
    [4] = {
        Id =889004,
        Hp =NPC_HP[889004],
        Name=NPC_NAME[889004],
        RewardList = {
            {
                type = 90,
                id   = 21,
                value = 550,
            }
        }

    },
    [5] = {
        Id =889005,
        Hp =NPC_HP[889005],
        Name=NPC_NAME[889005],
        RewardList = {
            {
                type = 90,
                id   = 21,
                value = 600,
            }
        }

    },
    [6] = {
        Id =889006,
        Hp =NPC_HP[889006],
        Name=NPC_NAME[889006],
        RewardList = {
            {
                type = 90,
                id   = 21,
                value = 600,
            }
        }

    },
    [7] = {
        Id =889007,
        Hp =NPC_HP[889007],
        Name=NPC_NAME[889007],
        RewardList = {
            {
                type = 90,
                id   = 21,
                value = 650,
            }
        }

    },
    [8] = {
        Id =889008,
        Hp =NPC_HP[889008],
        Name=NPC_NAME[889008],
        RewardList = {
            {
                type = 90,
                id   = 21,
                value = 650,
            }
        }

    },

    [9] = {
        Id =889009,
        Hp =NPC_HP[889009],
        Name=NPC_NAME[889009],
        RewardList = {
            {
                type = 90,
                id   = 21,
                value = 700,
            }
        }
    },


    [10] = {
        Id =889010,
        Hp =NPC_HP[889010],
        Name=NPC_NAME[889010],
        RewardList = {
            {
                type = 90,
                id   = 21,
                value = 700,
            }
        }
    },


    [11] = {
        Id =889011,
        Hp =NPC_HP[889011],
        Name=NPC_NAME[889011],
        RewardList = {
            {
                type = 90,
                id   = 21,
                value = 750,
            }
        }
    },

    [12] = {
        Id =889012,
        Hp =NPC_HP[889012],
        Name=NPC_NAME[889012],
        RewardList = {
            {
                type = 90,
                id   = 21,
                value = 750,
            }
        }
    },

    [13] = {
        Id =889013,
        Hp =NPC_HP[889013],
        Name=NPC_NAME[889013],
        RewardList = {
            {
                type = 90,
                id   = 21,
                value = 1000,
            }
        }
    },
    [14] = {
        Id =889014,
        Hp =NPC_HP[889014],
        Name=NPC_NAME[889014],
        RewardList = {
            {
                type = 90,
                id   = 21,
                value = 1250,
            }
        }
    },
    [15] = {
        Id =889015,
        Hp =NPC_HP[889015],
        Name=NPC_NAME[889015],
        RewardList = {
            {
                type = 90,
                id   = 21,
                value = 1500,
            }
        }
    },
    [16] = {
        Id =889016,
        Hp =NPC_HP[889016],
        Name=NPC_NAME[889016],
        RewardList = {
            {
                type = 90,
                id   = 21,
                value = 1750,
            }
        }
    },  
}
GuildActivityConfig = {
    Guild = {
        MaxAttackCount   = 4,
        AddFactor        = 500,
        FreshPeriod      = 7 * 24 * 3600,
        AttackFirstTime  = 1410105600,
        AttackDuration   = 7 * 24 * 3600,
        AttackFreezeDuration = 0,
        BuyConsume  = { -- 增加挑战次数花费
            {
                Type  = 90,
                Id    = 6,
                Value = 50, 
            }
        },
    },
    Boss = {
        [1] = {
            MaxBossCount = 2,
            [1] = GuildBossInfo[1],
            [2] = GuildBossInfo[2],
        },
        [2] = {
            MaxBossCount = 3,
            [1] = GuildBossInfo[1],
            [2] = GuildBossInfo[2],
            [3] = GuildBossInfo[3],
        },
        [3] = {
            MaxBossCount = 4,
            [1] = GuildBossInfo[1],
            [2] = GuildBossInfo[2],
            [3] = GuildBossInfo[3],
            [4] = GuildBossInfo[4],
        },
        [4] = {
            MaxBossCount = 5,
            [1] = GuildBossInfo[1],
            [2] = GuildBossInfo[2],
            [3] = GuildBossInfo[3],
            [4] = GuildBossInfo[4],
            [5] = GuildBossInfo[5],
        },
        [5] = {
            MaxBossCount = 6,
            [1] = GuildBossInfo[1],
            [2] = GuildBossInfo[2],
            [3] = GuildBossInfo[3],
            [4] = GuildBossInfo[4],
            [5] = GuildBossInfo[5],
            [6] = GuildBossInfo[6],
        },
        [6] = {
            MaxBossCount = 7,
            [1] = GuildBossInfo[1],
            [2] = GuildBossInfo[2],
            [3] = GuildBossInfo[3],
            [4] = GuildBossInfo[4],
            [5] = GuildBossInfo[5],
            [6] = GuildBossInfo[6],
            [7] = GuildBossInfo[7],
        },
        [7] = {
            MaxBossCount = 8,
            [1] = GuildBossInfo[1],
            [2] = GuildBossInfo[2],
            [3] = GuildBossInfo[3],
            [4] = GuildBossInfo[4],
            [5] = GuildBossInfo[5],
            [6] = GuildBossInfo[6],
            [7] = GuildBossInfo[7],
            [8] = GuildBossInfo[8],
        },
        [8] = {
            MaxBossCount = 9,
            [1] = GuildBossInfo[1],
            [2] = GuildBossInfo[2],
            [3] = GuildBossInfo[3],
            [4] = GuildBossInfo[4],
            [5] = GuildBossInfo[5],
            [6] = GuildBossInfo[6],
            [7] = GuildBossInfo[7],
            [8] = GuildBossInfo[8],
            [9] = GuildBossInfo[9],
        },
        [9] = {
            MaxBossCount = 10,
            [1] = GuildBossInfo[1],
            [2] = GuildBossInfo[2],
            [3] = GuildBossInfo[3],
            [4] = GuildBossInfo[4],
            [5] = GuildBossInfo[5],
            [6] = GuildBossInfo[6],
            [7] = GuildBossInfo[7],
            [8] = GuildBossInfo[8],
            [9] = GuildBossInfo[9],
            [10] = GuildBossInfo[10],
        },
        [10] = {
            MaxBossCount = 11,
            [1] = GuildBossInfo[1],
            [2] = GuildBossInfo[2],
            [3] = GuildBossInfo[3],
            [4] = GuildBossInfo[4],
            [5] = GuildBossInfo[5],
            [6] = GuildBossInfo[6],
            [7] = GuildBossInfo[7],
            [8] = GuildBossInfo[8],
            [9] = GuildBossInfo[9],
            [10] = GuildBossInfo[10],
            [11] = GuildBossInfo[11],
        },
        [11] = {
            MaxBossCount = 12,
            [1] = GuildBossInfo[1],
            [2] = GuildBossInfo[2],
            [3] = GuildBossInfo[3],
            [4] = GuildBossInfo[4],
            [5] = GuildBossInfo[5],
            [6] = GuildBossInfo[6],
            [7] = GuildBossInfo[7],
            [8] = GuildBossInfo[8],
            [9] = GuildBossInfo[9],
            [10] = GuildBossInfo[10],
            [11] = GuildBossInfo[11],
            [12] = GuildBossInfo[12],
        },
        [12] = {
            MaxBossCount = 13,
            [1] = GuildBossInfo[1],
            [2] = GuildBossInfo[2],
            [3] = GuildBossInfo[3],
            [4] = GuildBossInfo[4],
            [5] = GuildBossInfo[5],
            [6] = GuildBossInfo[6],
            [7] = GuildBossInfo[7],
            [8] = GuildBossInfo[8],
            [9] = GuildBossInfo[9],
            [10] = GuildBossInfo[10],
            [11] = GuildBossInfo[11],
            [12] = GuildBossInfo[12],
            [13] = GuildBossInfo[13],
        },
        [13] = {
            MaxBossCount = 14,
            [1] = GuildBossInfo[1],
            [2] = GuildBossInfo[2],
            [3] = GuildBossInfo[3],
            [4] = GuildBossInfo[4],
            [5] = GuildBossInfo[5],
            [6] = GuildBossInfo[6],
            [7] = GuildBossInfo[7],
            [8] = GuildBossInfo[8],
            [9] = GuildBossInfo[9],
            [10] = GuildBossInfo[10],
            [11] = GuildBossInfo[11],
            [12] = GuildBossInfo[12],
            [13] = GuildBossInfo[13],
            [14] = GuildBossInfo[14],
        },
        [14] = {
            MaxBossCount = 15,
            [1] = GuildBossInfo[1],
            [2] = GuildBossInfo[2],
            [3] = GuildBossInfo[3],
            [4] = GuildBossInfo[4],
            [5] = GuildBossInfo[5],
            [6] = GuildBossInfo[6],
            [7] = GuildBossInfo[7],
            [8] = GuildBossInfo[8],
            [9] = GuildBossInfo[9],
            [10] = GuildBossInfo[10],
            [11] = GuildBossInfo[11],
            [12] = GuildBossInfo[12],
            [13] = GuildBossInfo[13],
            [14] = GuildBossInfo[14],
            [15] = GuildBossInfo[15],
        },
        [15] = {
            MaxBossCount = 16,
            [1] = GuildBossInfo[1],
            [2] = GuildBossInfo[2],
            [3] = GuildBossInfo[3],
            [4] = GuildBossInfo[4],
            [5] = GuildBossInfo[5],
            [6] = GuildBossInfo[6],
            [7] = GuildBossInfo[7],
            [8] = GuildBossInfo[8],
            [9] = GuildBossInfo[9],
            [10] = GuildBossInfo[10],
            [11] = GuildBossInfo[11],
            [12] = GuildBossInfo[12],
            [13] = GuildBossInfo[13],
            [14] = GuildBossInfo[14],
            [15] = GuildBossInfo[15],
            [16] = GuildBossInfo[16],
        },
    },
    BuyAttackCountVipLimit = 0,
}

GuildMemberInitConfig = CONFIG_GuildMemberInitConfig
GuildMemberAddConfig = CONFIG_GuildMemberAddConfig
