local Class = require "Class"
local cell = require "cell"
local database = require "database"
local loop = loop;
local log = log;
local string = string;
local tonumber = tonumber;
local pairs = pairs;
local print = print;
local table = table;
local next  = next;
local type  = type;
local unpack = unpack;
local Command       = require "Command"
local Config        = require "GuildWarConfig"
local RoomConfig    = Config.RoomConfig
local SocialManager = require "SocialManager"
local YQSTR         = require "YQSTR"
local GuildManager  = require "GuildManager"
local PlayerManager  = require "PlayerManager"
require "yqlog_sys"
require "printtb"
local yqinfo  = yqinfo
local yqerror = yqerror
local yqwarn  = yqwarn 
local sprinttb = sprinttb
-----------------------------
module "FootmanManager"
local All = {};
local Footman = {}

local function isCaptain(pid)
    local player = PlayerManager.Get(pid);
    if not player then
        log.info("[isCaptain] fail, player info is nil")
        return nil;
    end
    if player.guild.leader.id == pid then
        return true;
    end
    return nil;
end

function Footman:getAutoMasterOrder(order)
    local t_order = {0,0,0,0}
    local player_list = self.top_k_player;
    local idx = 1
    local room_id = self.room_id;
    for i = 1, RoomConfig[room_id].MaxMasterCount do
        if not order[i] or order[i] == 0 then
           while player_list[idx] and self:InMasterOrder(player_list[idx]) do
               idx = idx + 1;
           end
           if not self:InMasterOrder(player_list[idx]) then
               t_order[i] = player_list[idx] or 0;
               idx = idx + 1;
           end
       else
           t_order[i] = order[i]
       end
    end
    return t_order
end

function Footman:saveMasterOrder(order)
    local str = "UPDATE guild_war_member SET ";
    for i = 1, #order do
        if i ~= #order then
            str = str .. string.format("order%d = %d,",i, order[i]);
        else
            str = str .. string.format("order%d = %d WHERE gid = %d",i, order[i], self._id);
        end
    end
    if database.update(str) then
        self._master_order = order;
        return true;
    end
    return false
end

function Footman:ResetMasterOrder(pid)
    if type(pid) ~= 'number' then
        log.info("[ResetMasterOrder] fail, no pid");
        return nil;
    end
    local flag = true;
    for k, v in pairs(self.master_order) do
        if v == pid then
            flag = false;
            self._master_order[k] = nil;
        end
    end
    if flag then
        log.info("[ResetMasterOrder] player not in master order, return true");
        return true;
    end
    local t = self:getAutoMasterOrder(self._master_order);
    return self:saveMasterOrder(t);
end


-- 1 boss 2(xb1) 3(xb2) 4(xb3)
function Footman:SetMasterOrder(pid, order)
    -- judge time in out side!!!!
    --
    print("Footman:SetMasterOrder -", pid, unpack(order));
    if not pid then
        log.error(string.format("SetOrder: some number is nil, `%d`",  pid or -1));
        return nil;
    end
    if not order then
        log.error("SetOrder :order is nil");
        return nil;
    end
    local guild = GuildManager.Get(self._id);
    if not guild then
        return nil
    end
    if pid ~= 0 and not isCaptain(pid)then
        return nil;
    end
    local room_id = self._room_id;
    if #order > RoomConfig[room_id].MaxMasterCount then
        log.error(string.format("the order `%d` is out of range", order));
        return nil;
    end
    local player = PlayerManager.Get(pid);
    if not player then
        log.error(string.format("no such player `%d`", pid or -1));
        return nil
    end
    print("Footman:SetMasterOrder + ", pid, unpack(order));
    order = self:getAutoMasterOrder(order);
    if self:saveMasterOrder(order) then
        return true, self.master_order;
    else
        return false;
    end
end

function Make(self, inspire_sum, order_table)
    self._inspire_sum = inspire_sum;
    self._master_order = {}
    for k, v in pairs(order_table) do
        table.insert(self._master_order, v);
    end
    All[self._room_id][self._id] = self;
end

function Create(self)
    local gid = self._id
    local room_id = self._room_id
    self._inspire_sum = 0;
    self._master_order = {};
    All[self._room_id][self._id] = self;
end

function Footman:_init_(room_id, id, inspire_sum, order_table)
    self._id = id;
    self._room_id = room_id;
    self._inspire_count = {};
    self.expert_attack_count = {};
    self.visitor = {};
    if inspire_sum then
        Make(self, inspire_sum, order_table);
    else
        Create(self);
    end
end

function Footman:InMasterOrder(pid)
    local room_id = self._room_id
    for i = 1, RoomConfig[room_id].MaxMasterCount do
        if pid == self._master_order[i] then
            return true;
        end
    end
    return false;
end

Footman.id = {
    get = '_id',
}

Footman.room_id = {
    get = '_room_id',
}

Footman.inspire_sum = {
    get = '_inspire_sum',
    set = function(self, v)
        local room_id = self.room_id;
        if database.update("UPDATE guild_war_member SET inspire_sum = %d WHERE gid = %d AND room_id = %d", v, self.id, room_id) then
            self._inspire_sum = v;
        end
    end
}

Footman.expert_order = {
    get = function(self)
        if self._expert_order then
            return self._expert_order;
        end
        local player_list = self.top_k_player
        local room_id = self._room_id
        local t = {}
		for k, v in pairs(player_list) do
            if not self:InMasterOrder(v) then
                if #t >= RoomConfig[room_id].MaxExpertCount then
                    break;
                end
                table.insert(t,v);
            end
        end
		local final_t = {}
		for k = RoomConfig[room_id].MaxExpertCount, 1, -1 do
			if t[k] then
				log.debug('expert_order', room_id, t[k]);
				table.insert(final_t, t[k]);
			end
		end


        self._expert_order = final_t;
        return self._expert_order;
    end,
    set = function(self, t)
        self._expert_order = t;
        if t == nil then
            log.info(string.format("[expert_order]set `%d` expoert order empty",self._id or -1));
        else
            local str = "";
            for k, v in pairs(t) do
                str = str .. (v and v or -1 ) .. ", "
            end
            log.info(string.format("[expert_order]set `%d` expert order-> %s", self._id or -1, str))
        end
    end
}

Footman.top_k_player = {
    get = function(self)
        local guild = GuildManager.Get(self._id)
        if not guild then
            print(self._id)
            return
        end

        local t = {};

        local pids = { };

        for k, v in pairs(guild.members) do
            table.insert(pids, k);
        end

		return pids;
--[[
        local ret = cell.getGuildTopKList(self._id, pids);
        if not ret then
            ret = {}
            ret.pids = pids;
        end
        for k, v in pairs(ret.pids) do
            table.insert(t, v);
        end
        return t;
--]]
    end
}

Footman.master_order = {
    get = function(self)
        local room_id = self._room_id
        if #self._master_order < RoomConfig[room_id].MaxMasterCount then
            local t_order = self:getAutoMasterOrder(self._master_order);
            self:saveMasterOrder(t_order);
            return self._master_order;
        end
        return self._master_order;
    end
}

Footman.inspire_count = {
    get = '_inspire_count',
    set = function(self, k)
        self._inspire_count = k
    end
}

function Get(room_id, gid, inspire_sum, master_order)
    if not gid then
        return ;
    end
    if not All[room_id] then
        All[room_id] = {};
    end
    local footman = All[room_id][gid]
	if footman == nil then
		footman = Class.New(Footman, room_id, gid, inspire_sum, master_order); 
	end
	return footman;
end
function Unload(room_id)
    All[room_id] = nil
end

