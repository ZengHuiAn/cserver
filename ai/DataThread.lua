local Thread = require "utils.Thread"
require "printtb"

local Dthread 
local DataThread = {}
function DataThread.getInstance()
	if not Dthread then
		Dthread = DataThread.New()
	end	

	return Dthread
end

function DataThread.New()
	local t = {
		listen = {},
		thread = Thread.Create(DataThread.OnMessage)
	}
	--t.thread:Start()
	return setmetatable(t, {__index = DataThread})
end

function DataThread:OnMessage()
	while true do 
		--print("thread  loop >>>>>>>>>>>>>>>>", self.thread)
		local cmd, channel, respond = self.thread:read_message()
		--print("@@@@@@@@@@@@@@@@@@@", cmd, channel, respond)
		if self.listen[cmd] then
			--print("has cmd >>>>>>>>>>>>>>>>>", cmd)
			local callBack = self.listen[cmd].callback
			if callBack then
				--print("do call back >>>>>>>>>>>>>>>")
				local success, info = xpcall(callBack, function()
					log.error('DataThread  onMessage error', debug.traceback(''));
				end, cmd, channel, respond)
			end	
		end
	end	
end

function DataThread:Start()
	self.thread:Start(self)
end

function DataThread:SendMessage(...)
	self.thread:send_message(...)
end

function DataThread:AddListener(cmd, func)
	self.listen[cmd] = {cmd = cmd, callback = func}	
end

function DataThread:RemoveListener(cmd)
	if self.listen[cmd] then
		self.listen[cmd] = nil
	end
end

return DataThread
