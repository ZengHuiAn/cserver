

local player_data = {}

function GetPlayer(pid)
	local player = player_data[pid];
	if not player then
		player =  {pid = pid} -- cell.getPlayerInfo(pid);
		player_data[pid] = player;
	end
	return player
end


return {
	Get = GetPlayer
}
