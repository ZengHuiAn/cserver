local BinaryConfig = require "BinaryConfig"
local database = require "database"
local Command = require "Command"
require "printtb"

local Player = {}
local PropertyCost = nil
--------------------------------------------------- Config ------------------------------------
local function loadPropertyCost()
	local rows = BinaryConfig.Load("config_common_data_cost", "quiz")
	PropertyCost = {}
        for _,row in ipairs(rows) do
                PropertyCost[row.type] = PropertyCost[row.type] or {}
                PropertyCost[row.type][row.index] = PropertyCost[row.type][row.index] or {}

                PropertyCost[row.type][row.index][row.value]=
                {
                        cost_id  = row.cost_id,
                        cost_type = row.cost_type,
                        cost_value = row.cost_value
                }
        end
end
loadPropertyCost()
---------------------------------------------------- Database ----------------------------------
local PlayerDB = {}
function PlayerDB.Insert(info)
	if type(info) ~= "table" then
		return false
	end

	local ok = database.update("insert into player_common_data(pid,type,inta,intb,intc,stra) values(%d,%d,%d,%d,%d,'%s')",info.pid,info.type,info.inta,info.intb,info.intc,info.stra)
	if not ok then
		return false
	end
	return true
end

function PlayerDB.Select(pid)
        if type(pid) ~= "number" then
                log.warning(dd"In_PlayerDB_Select: parameter error, pid is not number.")
                return false
        end
	
       	local ok, result = database.query("select pid,type,inta,intb,intc,stra from player_common_data where pid = %d;", pid)
       	if ok and #result > 0 then
               	return result
	else
               	return nil
       	end
end

function PlayerDB.SyncData(info)
	if type(info) ~= "table" then
                log.warning("In_PlayerDB_SyncData: param error, info is not table.")
                return false
        end
	
	if info.in_db then
        	local ok = database.update("update player_common_data set inta = %d,intb = %d,intc = %d,stra = '%s' where pid = %d and type = %d;",info.inta,info.intb,info.intc,info.stra,info.pid,info.type)
        	if not ok then
			print('-----------not update')
			return false
        	end
		return true
	else 
		if PlayerDB.Insert(info) then
			info.in_db = true
			return true
		end
		print('-----------not insert')
		return false
	end
end
------------------------------------------------------logic -----------------------------------
local function getPlayerProperty(pid)
	if Player[pid] == nil then
		Player[pid] = {}
		local pinfo = PlayerDB.Select(pid)
		if pinfo then
			for _,v in ipairs(pinfo) do
					Player[pid][v.type] = {pid = pid,type = v.type, inta = v.inta,intb = v.intb,intc = v.intc,stra = v.stra ,in_db = true}
			end	
		end
       	end
	return Player[pid]
end

local function query_player_property(obj_id,types)
	if type(types) ~= 'table' then
		log.warning("2th para is not table.....")
		return false
	end
	local pro = getPlayerProperty(obj_id)
	if not pro then
		log.warning("there is no this playerid...")
		return nil
	end
	local amf = {}
	for _,v in ipairs(types) do
		if pro[v] then
			local tmp = { v, pro[v].inta, pro[v].intb, pro[v].intc, pro[v].stra }
			table.insert(amf,tmp)
		end
	end	
	return amf
end

local function query_playerself_property(pid)
	local pro = getPlayerProperty(pid)
        if not pro then
                log.warning("there is no type...")
                return nil
        end
        local amf = {}
        for t,v in pairs(pro) do
		local tmp =  { t , v.inta, v.intb, v.intc, v.stra }
                table.insert(amf,tmp)
        end
        return amf
end

local function updataPlayerPropertyData(pid,type,index,value)
	if Player[pid] and Player[pid][type] then
		if index == 1 then
        		Player[pid][type].inta = value
        	elseif index == 2 then
                	Player[pid][type].intb = value
        	elseif index == 3 then
                	Player[pid][type].intc = value
        	elseif index == 4 then
                	Player[pid][type].stra = value
        	end
	end
end

local function itemsCost(pid,type,index,value)	--消耗
	print('pid='..pid,'type='..type,'index='..index,'value='..value)
	if not PropertyCost[type] or not PropertyCost[type][index] then
		log.warning("the configuration file is no  field...")
		return false
	end
	
	for i,v in pairs(PropertyCost[type][index]) do
		if v.cost_type == 0 then
			log.info("you can change this type without consuming ...")
			return true
		end
	end
	if PropertyCost[type] and PropertyCost[type][index] and PropertyCost[type][index][tostring(value)] then
		local co_type  = PropertyCost[type][index][tostring(value)].cost_type
       		local co_id    = PropertyCost[type][index][tostring(value)].cost_id
        	local co_value = PropertyCost[type][index][tostring(value)].cost_value

        	if not co_type or not co_id or not co_value then
                	log.warning("can't find correct data from configuration file...")
			return false
        	end
        	local consume = {{ type = co_type,id = co_id,value = re_value }}

        	local respond = cell.sendReward(pid,nil,consume,Command.REASON_CONSUME_TYPE_PLYAERPROPERTY_SET,0,0)

        	if respond == nil or respond.result ~= Command.RET_SUCCESS then
                	log.error( "fail to modify property, coin or gold or otherthing not enough")
               		return false
        	end
		return true	
	else
		log.warning("there is no data in configuration file...")
		return false
	end
end

local function modifyProperty(pid,type,tab)
	local index = tab[1]
	local value = tab[2]
        local pro = getPlayerProperty(pid)
        if pro[type] then
		print('index='..index,'value='..value)		
		if value == 0 then	-- 卸下
			print("---------------------------------卸下...")
			updataPlayerPropertyData(pid,type,index,0)
		else
			local res = itemsCost(pid,type,index,value)
	                if not res then
        	                log.warning(string.format("cost error",index))
                	        return false
                	end
                	updataPlayerPropertyData(pid,type,index,value)
		end	
		Player[pid][type].in_db = true
	else
	 	pro[type] = {pid = pid,type = type, inta = 0,intb = 0,intc = 0,stra = '' ,in_db = false}
		print('index='..index,'value='..value)		
                local res = itemsCost(pid,type,index,value)
                if not res then
                        log.warning(string.format("index = %d no cost",index))
                        return false
                end
		updataPlayerPropertyData(pid,type,index,value)                
	        Player[pid][type].in_db = false
        end
        if not PlayerDB.SyncData(pro[type]) then
                return false
        else
                local amf = {}
		local tmp = Player[pid][type]
                table.insert(amf,type)
		table.insert(amf,tmp.inta)
		table.insert(amf,tmp.intb)
		table.insert(amf,tmp.intc)
		table.insert(amf,tmp.stra)
                return amf
        end
end

local function modifyProperty2(pid,type,tab)
	local index = tab[1]
        local value = tab[2]
        local pro = getPlayerProperty(pid)
	if pro[type] then
                print('type='..type, 'index='..index,'value='..value)
		updataPlayerPropertyData(pid,type,index,0)
	else
		pro[type] = {pid = pid,type = type, inta = 0,intb = 0,intc = 0,stra = '' ,in_db = false}
		print('index='..index,'value='..value)
		updataPlayerPropertyData(pid,type,index,value)
	end
	if not PlayerDB.SyncData(pro[type]) then
                return false
	end
	return true

end

-------------------------------------------------- interface  --------------------------------------
local function onQueryPlayerProperty(conn,pid,request)	--查询
	local cmd  = Command.C_PLAYERPROPERTY_QUERY_RESPOND  
	local sn   = request[1]
	local obj_id  = request[2]
	local types = request[3]
	print('=============start query:',obj_id)
	if type(obj_id) ~= 'number' then
                        log.warning("param 2th type is not number")
                        return conn:sendClientRespond(cmd, pid, {sn, Command.RET_PARAM_ERROR})
	end
	local ret = nil
	if obj_id ~= pid then
		if type(types) ~= 'table' then
                	log.warning("param 3th type is not number")
                	return conn:sendClientRespond(cmd, pid, {sn, Command.RET_PARAM_ERROR})
        	end
		ret = query_player_property(obj_id,types)
		return conn:sendClientRespond(cmd,pid,{ sn,ret and Command.RET_SUCCESS or Command.RET_ERROR,obj_id,ret })
	else
		ret = query_playerself_property(pid)
		return conn:sendClientRespond(cmd,pid,{ sn,ret and Command.RET_SUCCESS or Command.RET_ERROR,pid,ret })
	end
end

local function onAdminQueryPlayerProperty(conn, channel, request)
	local cmd = Command.S_PLAYERPROPERTY_QUERY_RESPOND;
	local proto = "QueryPlayerPropertyRespond";

	if channel ~= 0 then
		log.error(id .. "Fail to `S_PLAYERPROPERTY_QUERY_REQUEST`, channel ~= 0")
		sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_PREMISSIONS});
		return;
	end

	local obj_id = request.pid
	local types = request.types
	local ret = query_player_property(obj_id,types)
	if not ret then
		return sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_ERROR});
	end

	return sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_ERROR, data = ret});
end

local function onModifyPlayerProperty(conn,pid,request) -- 修改
	local cmd     = Command.C_PLAYERPROPERTY_MODIFY_RESPOND 
	local sn      = request[1]
	local _type   = request[2]
	local tab     = request[3]
	local boo     = request[4]
	print('=============start modify:')
	if type(_type) ~= 'number' then
                log.warning("param 2th type is not number")
                return conn:sendClientRespond(cmd, pid, {sn, Command.RET_PARAM_ERROR})
        end
	if type(tab) ~= 'table' then
		log.warning("param 3th type is not table")
                return conn:sendClientRespond(cmd, pid, {sn, Command.RET_PARAM_ERROR})
	end

	print('tab[1]='..tab[1],'tab[2]='..tab[2])
	if boo then
		local ret = modifyProperty2(pid,_type,tab)
		return conn:sendClientRespond(cmd,pid,{sn,ret and Command.RET_SUCCESS or Command.RET_ERROR,pid})
	else
		local ret = modifyProperty(pid,_type,tab)				
		return conn:sendClientRespond(cmd,pid,{sn,ret and Command.RET_SUCCESS or Command.RET_ERROR,pid,ret})
	end
end

local function onAdminModifyPlayerProperty(conn, channel, request)
	local cmd = Command.S_PLAYERPROPERTY_MODIFY_RESPOND;
	local proto = "aGameRespond";

	if channel ~= 0 then
		log.error(id .. "Fail to `S_PLAYERPROPERTY_MODIFY_REQUEST`, channel ~= 0")
		sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_PREMISSIONS});
		return;
	end

	local pid = request.pid
	local _type = request.typa
	local tab = request.tab 
	local ret = modifyProperty(pid,_type,tab)	
	if not ret then
		return sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_ERROR});
	end

	return sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_SUCCESS});
end

local function saveMWHJProperty(pid,type,tab)
        local index = tab[1]
        local value = tab[2]
        local pro = getPlayerProperty(pid)
        if pro[type] then
                print('type='..type, 'index='..index,'value='..value)
                updataPlayerPropertyData(pid,type,index,value)
        else
                pro[type] = {pid = pid,type = type, inta = 0,intb = 0,intc = 0,stra = '' ,in_db = false}
                print('index='..index,'value='..value)
                updataPlayerPropertyData(pid,type,index,value)
        end
        if not PlayerDB.SyncData(pro[type]) then
                return false
        end
        return true

end

local function openMWHJProperty(pid,type,tab)
	local index = tab[1]
        local value = tab[2]
        local pro = getPlayerProperty(pid)
        if pro[type] then
                print('-------------------111')
		local res = itemsCost(pid,type,index,value)
                if not res then
                	log.warning(string.format("cost error",index))
                        return false
                end
                updataPlayerPropertyData(pid,type,index,value)
                Player[pid][type].in_db = true
        else
                print('-----------------------222')
                local res = itemsCost(pid,type,index,value)
                if not res then
                        log.warning(string.format("index = %d no cost",index))
                        return false
                end
		pro[type] = {pid = pid,type = type, inta = 0,intb = 0,intc = 0,stra = '' ,in_db = false}
                updataPlayerPropertyData(pid,type,index,value)
        end
        
	if PlayerDB.SyncData(pro[type]) then
		return true
	else
		return false
	end	
end

local function onSaveMWHJData(conn,pid,request)
	local cmd     = Command.C_MWHJ_PROPERTY_MODIFY_RESPOND
        local sn      = request[1]
        local _type   = request[2]
        local tab     = request[3]
        local boo     = request[4]
        print('=============start modify:')
        if type(_type) ~= 'number' then
                log.warning("param 2th type is not number")
                return conn:sendClientRespond(cmd, pid, {sn, Command.RET_PARAM_ERROR})
        end
        if type(tab) ~= 'table' then
                log.warning("param 3th type is not table")
                return conn:sendClientRespond(cmd, pid, {sn, Command.RET_PARAM_ERROR})
        end

        print('tab[1]='..tab[1],'tab[2]='..tab[2])
	
	local ret = nil
        if not boo then
                print('----------------存档')
                ret = saveMWHJProperty(pid,_type,tab)
        else
                print('----------------开启')
                ret = openMWHJProperty(pid,_type,tab)
        end

	return conn:sendClientRespond(cmd,pid,{sn,ret and Command.RET_SUCCESS or Command.RET_ERROR})
end

local function onQueryMWHJData(conn,pid,request)
	local cmd  = Command.C_MWHJ_PROPERTY_QUERY_RESPOND
        local sn   = request[1]
        local obj_id  = request[2]
        local types = request[3]
        print('=============start query:',obj_id,pid)
        if type(obj_id) ~= 'number' then
                        log.warning("param 2th type is not number")
                        return conn:sendClientRespond(cmd, pid, {sn, Command.RET_PARAM_ERROR})
        end
	local ret = query_playerself_property(pid)
	return conn:sendClientRespond(cmd,pid,{ sn,ret and Command.RET_SUCCESS or Command.RET_ERROR,pid,ret })
end

local PlayerProperty = {}
function PlayerProperty.RegisterCommand(service)
	service:on(Command.C_PLAYERPROPERTY_QUERY_REQUEST,onQueryPlayerProperty)
	service:on(Command.C_PLAYERPROPERTY_MODIFY_REQUEST,onModifyPlayerProperty)

	service:on(Command.C_MWHJ_PROPERTY_QUERY_REQUEST,onQueryMWHJData)
        service:on(Command.C_MWHJ_PROPERTY_MODIFY_REQUEST,onSaveMWHJData)

	service:on(Command.S_PLAYERPROPERTY_QUERY_REQUEST, "QueryPlayerPropertyRequest", onAdminQueryPlayerProperty)
	service:on(Command.S_PLAYERPROPERTY_MODIFY_REQUEST, "ModifyPlayerPropertyRequest", onAdminModifyPlayerProperty)
end

return PlayerProperty

