local GuildData = {}
local Command = require "Command"

local MAX_HELP_COUNT = 2		-- 最多协助其他玩家的次数

math.randomseed(os.time())

-- 查询军团信息
function GuildData.GetGuildInfo(pid)	
	if GuildData[pid] == nil then
		local respond = GetGuildInfo(pid)
		if respond and respond.result == 0 then
			if respond.gid > 0 then
				GuildData[pid] = { 
					gid = respond.gid, 			-- 军团id
					leader = respond.leader,
					help_count = respond.help_count, 	-- 协助次数
					is_dispatch = false,			-- 是否派遣过队伍进行探险
					count = 0,
					join_time = respond.join_time or loop.now()
				}
			else
				GuildData[pid] = { gid = 0, help_count = 0, is_dispatch = false, count = 0, join_time = 0 }
			end
		else
			AI_WARNING_LOG("GetGuildInfo: search for guild info failed.")	
			GuildData[pid] = { gid = 0, help_count = 0, is_dispatch = false, count = 0, join_time = 0 }
		end
	end
	return GuildData[pid]
end

function GuildData.Unload(pid)
	GuildData[pid] = nil
end

-- 是否有军团
function GuildData.HasGuild(pid)
	local info = GuildData.GetGuildInfo(pid)	
	return info.gid ~= 0
end

-- 申请军团
function GuildData.ApplyGuild(pid)
	AI_DEBUG_LOG("apply for guild, pid = ", pid)	
	if math.random(100) <= 50 then
		ApplyGuild(pid)
	end
	GuildData.Unload(pid)	
	return "Finish"
end

-- 做一些军团相关的事情
function GuildData.DoGuildWork(pid)
	local info = GuildData.GetGuildInfo(pid)
	if info.gid > 0 then
		GuildData.DonateExp(pid)
		GuildData.SeekPrayHelp(pid)	
		GuildData.HelpPray(pid)
		if loop.now() - info.join_time > 24 * 3600 then
			GuildData.FinishExplore(pid)
		end
		GuildData.Unload(pid)	
		return "Finish"
	elseif info.count > 10 then
		GuildData.Unload(pid)
		return "Finish"	
	end

	info.count = info.count + 1
end

-- 进行高级捐献
function GuildData.DonateExp(pid)
	AI_DEBUG_LOG(string.format("DonateExp: pid = %d", pid))
	DonateExp(pid, 1)
end

-- 寻求祈愿协助
function GuildData.SeekPrayHelp(pid)
	AI_DEBUG_LOG(string.format("SeekPrayHelp: pid = %d", pid))
	SeekPrayHelp(pid)
end

-- 完成其他玩家的协助
function GuildData.HelpPray(pid)
	AI_DEBUG_LOG(string.format("HelpPray: pid = %d", pid))
	HelpPray(pid)
end

-- 完成军团探险
function GuildData.FinishExplore(pid)
	FinishExplore(pid)	
end

function GuildData.IsLeader(pid)	
	local info = GuildData.GetGuildInfo(pid)	
	return info.leader == pid
end

function GuildData.DoLeaderWork(pid)
	DoLeaderWork(pid)
end

return GuildData
