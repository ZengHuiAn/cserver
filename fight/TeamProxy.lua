require "SocialManager"
require "Agent"

local PlayerManager = require "PlayerManager"

local TeamProxy =  {}

local function playerProxy(pid)
	return setmetatable({pid = pid}, {__index=function(t, k)
		print("player proxy get", pid, k);	
	end});
end

local function teamProxy(id, leader_pid, members, afk_list)
	if not id then return nil; end

	local tmembers = { }
	for _, v in ipairs(members) do
		table.insert(tmembers, playerProxy(v.pid))
	end

	return setmetatable({
		id = id,
		leader = playerProxy(leader_pid),
		members = members,
		afk_list = afk_list,
	}, {__index = TeamProxy})
end

function TeamProxy:Notify(cmd, msg, pids)
    local list = self.members;
    if pids then
		list = {}
        local m = {};
        for _, v in ipairs(pids) do
			if not m[v] then
				table.insert(list, {pid=v});
				m[v] = true;
			end
        end
    end

    for _, v in ipairs(list) do
        local agent = Agent.Get(v.pid);
        if agent then
            agent:Notify({cmd, msg});
        else
            print('team member agent not exists', v.pid, cmd);
        end
    end
end

--TODO
function TeamProxy:NotifyByTeamServcie(cmd, msg)

end

function TeamProxy:GetAIMembers()
	local ai = {}
	for k, v in ipairs (self.members) do
		if v.pid <= 0xffffffff then
			table.insert(ai, v.pid)	
		end
	end
	return ai
end

function TeamProxy:PlayerAFK(pid)
	for _, id in ipairs(self.afk_list or {}) do
		if id == pid then
			return true
		end
	end

	return false
end

function TeamProxy:GetMemsNotAFK()
	local mems = {}
	for k, v in ipairs (self.members) do
		if not self:PlayerAFK(v.pid) then
			table.insert(mems, v.pid)
		end	
	end

	return mems
end

local team_in_vm = {}
function TeamProxy:StartVM(vm)
	log.debug(string.format('team %d start vm', self.id));

	if team_in_vm[self.id] then
		log.debug("already in vm")
		return false
	end

	if not vm:Start() then
		log.debug("start vm fail")
		return false
	end

	team_in_vm[self.id] = vm

	return true
end

function TeamProxy:StopVM()
	log.debug(string.format('team %d exit vm', self.id));
	team_in_vm[self.id] = nil;
end

local observers = {}
local function RegisterObserver(reactor)
	local key = #observers + 1
	observers[key] = reactor;
	return key;
end

local function RemoveObserver(o_id)
	observers[o_id] = nil;	
end


local function onTeamDissolve(id)
	print('onTeamDissolve', id);

	if team_in_vm[id] and team_in_vm[id].Command then
		team_in_vm[id]:Command(0, 'STOP');
	end

	for _, v in pairs(observers) do
		if v.OnTeamDissolve then
			v:OnTeamDissolve(id);	
		end
	end
end

function TeamProxy:Snap()
	return teamProxy(self.id, self.leader.pid, self.members, self.afk_list);
end

function getTeamByPlayer(pid, allow_single_player)
	local info = SocialManager.GetTeamInfo(nil, pid)

	if not info and allow_single_player then
		info = {teamid = -pid, leader = pid, members = { {pid = pid} }}
	end

	if not info and not allow_single_player then
		return 
	end
	
	return teamProxy(info.teamid, info.leader, info.members, info.afk_list);
end

function getTeam(id)
	if id < 0 then return nil; end

	local info = SocialManager.GetTeamInfo(id, nil) or {}
	return teamProxy(info.teamid, info.leader, info.members, info.afk_list);
end

local function registerCommand(service)
	service:on(Command.C_FIGHT_SYNC_REQUEST, function(conn, channel, request) 
		local sn, type, data = request[1], request[2], request[3];
		local pid = channel;

		local result = Command.RET_SUCCESS;

		local player = PlayerManager.Get(pid);
		if player and player.vm and player.vm.Command then
			-- print('C_FIGHT_SYNC_REQUEST', pid, type, data);
			player.vm:Command(pid, type, data);
		else
			print('vm not exists', pid, type, data);
			result = Command.RET_TARGET_NOT_EXIST;
		end

		return conn:sendClientRespond(Command.C_FIGHT_SYNC_RESPOND, pid, {sn, result});
	end)

	service:on(Command.S_TEAM_QUERY_INFO_REQUEST, "TeamQueryInfoRequest", function(conn, channel, request)
		onTeamDissolve(request.tid);
	end);
end

return {
	registerCommand = registerCommand,
	RegisterObserver = RegisterObserver,
	RemoveObserver = RemoveObserver,
}
