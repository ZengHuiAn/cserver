local EventList = {}

function EventList.Create(id)
	if not EventList[id] then
		EventList[id] = {

		}
	end
end

function EventList.Push(id, callback, param)
	if not EventList[id] then
		return 
	end
	table.insert(EventList[id], {callback = callback, param = param})	
end

function EventList.Pop(id)
	if not EventList[id] then
		return
	end

	for k, v in ipairs(EventList[id]) do
		local callback = v.callback
		local param = v.param
		if not param then
			callback()
		else
			callback(unpack(v.param))
		end
	end

	EventList[id] = {}
end

function EventList.Remove(id)
	EventList[id] = nil
end

return EventList
