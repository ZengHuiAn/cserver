local FriendData = {}
local Command = require "Command"
require "printtb"

-- 获取好友信息
function FriendData.GetFriendInfo(pid)
	if not FriendData[pid] then
		FriendData[pid] = { future_friends = {} }
		-- 查询获赠记录
	 	local respond = GetPresentRecord(pid)	
		if respond and respond.result == 0 then
			local set = {}
			for _, v in ipairs(respond.donors or {}) do
				if set[v] == nil then
					table.insert(FriendData[pid].future_friends, v)
					set[v] = v
				end
			end
		else
			log.warning("GetFriendInfo: get present record failed.")	
		end

	end
	return FriendData[pid]
end

-- 是否有玩家向AI赠送体力
function FriendData.IsPresent(pid)
	local info = FriendData.GetFriendInfo(pid)
	return #info.future_friends ~= 0
end

-- 添加好友
function FriendData.AddFriend(pid)
	AI_DEBUG_LOG("add friend, pid = ", pid)
	local info = FriendData.GetFriendInfo(pid)
	AddFriend(pid, info.future_friends)
end

-- 给好友赠送体力
function FriendData.PresentEnergy(pid)
	AI_DEBUG_LOG("present energy, pid = ", pid)
	PresentEnergy(pid)
end

function FriendData.Unload(pid)
	FriendData[pid] = nil
end

return FriendData
