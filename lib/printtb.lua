local function output(...)
	print(string.format(...))
end
function printtb(tb, tabspace)
	do return; end;

	tabspace =tabspace or ''
	output(tabspace .. '{' )
	for k,v in pairs(tb or {}) do
		if type(v)=='table' then
			if type(k)=='string' then
				output("%s%s =", tabspace..'\t', tostring(k))
				printtb(v, tabspace..'\t')
			elseif type(k)=='number' then
				output("%s[%d] =", tabspace..'\t', k)
				printtb(v, tabspace..'\t')
			end
		else
			if type(k)=='string' then
				output("%s%s =%s,", tabspace..'\t', tostring(k), tostring(v))
			elseif type(k)=='number' then
				output("%s[%s] =%s,", tabspace..'\t', tostring(k), tostring(v))
			end
		end
	end
	output(tabspace .. '},' )
end

function sprinttb(tb, tabspace)
	tabspace =tabspace or ''
	local str =string.format(tabspace .. '{\n' )
	for k,v in pairs(tb or {}) do
		if type(v)=='table' then
			if type(k)=='string' then
				str =str .. string.format("%s%s =\n", tabspace..'\t', k)
				str =str .. sprinttb(v, tabspace..'\t')
			elseif type(k)=='number' then
				str =str .. string.format("%s[%d] =\n", tabspace..'\t', k)
				str =str .. sprinttb(v, tabspace..'\t')
			end
		else
			if type(k)=='string' then
				str =str .. string.format("%s%s =%s,\n", tabspace..'\t', tostring(k), tostring(v))
			elseif type(k)=='number' then
				str =str .. string.format("%s[%s] =%s,\n", tabspace..'\t', tostring(k), tostring(v))
			end
		end
	end
	str =str .. string.format(tabspace .. '},\n' )
	return str
end
