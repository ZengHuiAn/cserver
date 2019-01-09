local QueueClass = {};

function QueueClass:push(value)
	self.content[self.tail] = value;
	self.tail = self.tail + 1;
end

function QueueClass:pop()
	if self.head < self.tail then
		local value = self.content[self.head];
		self.content[self.head] = nil;

		self.head = self.head + 1;
		if self.head == self.tail then
			self.head = 1;
			self.tail = 1;
		end
		return value;
	end
end

function QueueClass:get(index)
	if index > 0 and index <= self.tail - self.head then
		return self.content[self.head + index - 1];
	end
end

function QueueClass:front()
	if self.head < self.tail then
		return self.content[self.head];
	end
end

function QueueClass:isEmpty()
	return self.head >= self.tail;
end

function QueueClass:empty()
	return self.head >= self.tail;
end

function QueueClass:size()
	return self.tail - self.head;
end

function QueueClass.New()
	return setmetatable({head=1,tail=1,content={}}, {__index=QueueClass});
end

return  QueueClass;
