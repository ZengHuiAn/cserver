local string =string
local io = io

module "util"
function make_player_rich_text(pid, name)
	return string.format("#[type=player,pid=%d]%s#[end]", pid, name)
end
function make_goods_rich_text(type, id)
	return string.format("#[type=goods,gid=%d,gtype=%d]#[end]", id, type)
end
function encode_quated_string(str)
	str =string.gsub(str, "\\", "\\\\")
	str =string.gsub(str, "'", "\\'")
	str =string.gsub(str, '"', '\\"')
	return str
end

function file_exist(filename)
	local f = io.open(filename)

	if f then
		f:close()
		return true
	else
		return false
	end
end
