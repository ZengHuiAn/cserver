-- rand by weight list --
function get_rand_index_by_weight_list(list)
	local sum_weight =0
	for i=1, #list do
		sum_weight =sum_weight + list[i]
	end
	local randnum =math.random(sum_weight)
	local cursor =1
	for i=1, #list do
		if random>=cursor and randnum<=cursor+list[i]-1 then
			return i
		end
		cursor =cursor + list[i]
	end
	yqassert(nil, 'never goto here')
end
function get_rand_list_by_weight_list(ls, cnt)
	-- select all
	if cnt <= 0 then
		local list ={}
		for i=1, #ls do
			table.insert(list, ls[i])	
		end
		return list
	end

	-- rand select
	local rand_list ={}
	local list ={}
	for i=1, #ls do
		if ls[i].weight==0 then
			table.insert(rand_list, ls[i])	
			if #rand_list==cnt then
				return rand_list
			end
		else
			table.insert(list, ls[i])	
		end
	end
	cnt =math.min(cnt-#rand_list, #list)
	while cnt>0 do
		local sum_weight =0
		for i=1, #list do
			sum_weight =sum_weight + list[i].weight
		end
		local randnum =math.random(sum_weight)
		local cursor =1
		for i=1, #list do
			if randnum>=cursor and randnum<=cursor+list[i].weight-1 then
				table.insert(rand_list, list[i])
				table.remove(list, i)
				break
			end
			cursor =cursor + list[i].weight
		end
		cnt =cnt - 1
	end
	return rand_list
end
function get_all_fix_and_one_rand(ls)
	-- prepare
	local rand_list ={}
	local list ={}

	-- get fix
	for i=1, #ls do
		if ls[i].weight==0 then
			table.insert(rand_list, ls[i])	
		else
			table.insert(list, ls[i])	
		end
	end

	-- get one rand
	if #list==0 then
		yqwarn('get_all_fix_and_one_rand: dynamic count is zero')
	else
		local sum_weight =0
		for i=1, #list do
			sum_weight =sum_weight + list[i].weight
		end
		local randnum =math.random(sum_weight)
		local cursor =1
		for i=1, #list do
			if randnum>=cursor and randnum<=cursor+list[i].weight-1 then
				table.insert(rand_list, list[i])
				table.remove(list, i)
				break
			end
			cursor =cursor + list[i].weight
		end
	end
	return rand_list
end

function get_all_fix_and_one_rand_extension(ls)
	local rand_list = {}
	local list ={}
	for k,v in pairs(ls) do
		if v.weight == 0 then
			table.insert(rand_list,v)
		else
			table.insert(list,v)
		end
	end
	if #list == 0 then
		yqwarn("get_all_fix_and_one_rank:dynamic count is Zeor")
	else
		local sum_weight = 0
		for i= 1,#list do
			sum_weight = sum_weight + list[i].weight
		end
		local randnum = math.random(sum_weight)
		local cursor = 1
		for i = 1,#list do 
			if randnum >= cursor and randnum <= cursor + list[i].weight - 1 then
				table.insert(rand_list,list[i])
				table.remove(list,i)
				break
			end
			cursor = cursor + list[i].weight
		end
	end
	return rand_list
end

function get_rand_unique_num(ls, num)
	assert(num > 0)
	local unique_tb = {}
	local unique_tb_size = 0
	local rand_list = {}
	if #ls <= num then
		for k, v in ipairs(ls) do
			table.insert(rand_list, v)
		end	
		return rand_list
	end
	if num > #ls/2 then
		while(1) 
		do
			local rand_num = math.random(#ls)
			if not unique_tb[rand_num] then
				unique_tb[rand_num] = 1
				unique_tb_size = unique_tb_size + 1
				if #ls - unique_tb_size == num then
					break
				end
			end		
		end
		for k ,v in ipairs(ls) do
			if not unique_tb[k] then
				table.insert(rand_list, v)
			end
		end
	else
		while(1) 
		do
			local rand_num = math.random(#ls)
			if not unique_tb[rand_num] then
				table.insert(rand_list, ls[rand_num])	
				unique_tb[rand_num] = 1
				if #rand_list == num then
					break
				end
			end		
		end
	end
	return rand_list
end
