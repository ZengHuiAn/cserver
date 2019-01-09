local BinaryConfig = require "BinaryConfig"
local database = require "database"
local cell = require "cell"
local bas64 = require "base64"
local Command = require "Command"
local Scheduler = require "Scheduler"
require "BackyardConfig"
local StableTime = require "StableTime"
local get_begin_time_of_day = StableTime.get_begin_time_of_day

local DZ_BEGIN_TIME = 0
local DZ_END_TIME   = 24 * 3600
local MAX_EXPAND_BUILD_COUNT = 6
local MAX_SHOPNAME_LENGTH = 100

local BACKYARD_DB_MODIFYNAME  = 1
local BACKYARD_DB_EXPANDCOUNT = 2
local BACKYARD_DB_DZCOUNT     = 3

local BACKYARDDIANZAN_DB_COUNT = 1
local HOUR_1 = 3600
--------------------------------- load database -----------------------------------------------------------
local BackyardData = {}	
local DzCount      = {}
local FurniturePos = {}
local Furniture = {}
local FairySlot = {}
local Fairy = {}
local function isOverdueDz(time)	-- 点赞的时间是否过期
	if loop.now() > get_begin_time_of_day(time) + DZ_END_TIME then
		return true
	end
	return false
end

local function loadFairySlot()
	local success ,result = database.query("select pid,roomid,sid,unlockstatus,fairyuuid,unix_timestamp(addtime) as addtime from backyard_fairy_slot")
	if success and #result > 0 then
		for i = 1, #result, 1 do
                        local row = result[i]
			FairySlot[row.pid] = FairySlot[row.pid] or {}
			FairySlot[row.pid][row.roomid] = FairySlot[row.pid][row.roomid] or {}
			FairySlot[row.pid][row.roomid][row.sid] = { status = row.unlockstatus,fairyuuid = row.fairyuuid,addtime = row.addtime, is_db = true }
		end
	end

end

loadFairySlot()
----------------------------------------------------------- database --------------------------------------------
local BackyardDB = {} 	-- 后宫数据库
local DianzanDB = {}    -- 点赞数据库
local FurniturePosDB = {}-- 家具位置
local FurnitureDB = {}	-- 拥有家具数目
local FairySlotDB = {}  -- 妖精培养槽
local FairyDB = {} 	-- 玩家妖精好感度
function BackyardDB.Select(pid)
	if type(pid) ~= "number" then
                log.warning("In_PlayerDB_Select: param error, pid is not number.")
                return nil
        end

        local ok, result = database.query("select pid, byname, expandcount, dzcount from backyard where pid = %d;", pid)
        if ok and #result > 0 then
                return result[1]
        else
                --log.info(string.format("In_PlayerDB_Select: select backyard failed, %d not exist.", pid))
                return nil
        end
end

function BackyardDB.Insert(info)
	if type(info) ~= "table" then
		log.warning("In_BackyardDB_Insert: param error, info is not table.")
		return false
	end
        local ok = database.update("insert into backyard(pid,roomid,byname,expandcount,dzcount) values(%d,%d,'%s',%d,%d);",info.pid,info.roomid,info.byname,info.expandcount,info.dzcount)
        if not ok then
                return false
        end
	return ok
end

function BackyardDB.SyncData(byInfo,update_type)
        if type(byInfo) ~= "table" and type(update_type) ~= "number" then
                return false
        end
	if not byInfo.is_db then
		if BackyardDB.Insert(byInfo) then
                	byInfo.is_db = true
			return true
                end
	end
	if update_type == BACKYARD_DB_MODIFYNAME then
		local ok = database.update("update backyard set byname = '%s' where pid = %d and roomid = %d;",byInfo.byname,byInfo.pid,byInfo.roomid)
        	if not ok then
			return false
        	end
	elseif update_type == BACKYARD_DB_EXPANDCOUNT then
		local ok = database.update("update backyard set expandcount = %d where pid = %d and roomid = %d;",byInfo.expandcount,byInfo.pid,byInfo.roomid)
                if not ok then
			return false
                end
	elseif update_type == BACKYARD_DB_DZCOUNT then	
		local ok = database.update("update backyard set dzcount = %d where pid = %d and roomid = %d;",byInfo.dzcount,byInfo.pid,byInfo.roomid)
		if not ok then
			return false
                end
	end
	return true
end

function DianzanDB.Insert(info)
	if type(info) ~= "table" then
                return false
        end
	print(info.pid,info.roomid,info.fid,info.count,info.dztime)	
        local ok = database.update("insert into backyard_dz_count(pid,roomid,fid,dzcount,dztime) values(%d,%d,%d,%d,from_unixtime_s(%d));",info.pid,info.roomid,info.fid,info.count,info.dztime)
        if not ok then
                return false
        end
        return ok
end

function DianzanDB.Select(pid,roomid,fid)
	if type(pid) ~= "number" or type(fid) ~= "number" or type(roomid) ~= "number" then
                return nil
        end

        local ok, result = database.query("select pid,roomid,fid,dzcount,unix_timestamp(dztime) as dztime from backyard_dz_count where pid = %d and roomid = %d and fid = %d;", pid,roomid,fid)
        if ok and #result > 0 then
                return result[1]
        else
                return nil
        end

end

function DianzanDB.SyncData(info)
     	if type(info) ~= "table"  then
                return false
        end
	print(info.count,info.dztime,info.pid,info.roomid,info.fid)
	if info.is_db then
                local ok = database.update("update backyard_dz_count set dzcount = %d,dztime = from_unixtime_s(%d)  where pid = %d and roomid = %d and fid = %d;",info.count,info.dztime,info.pid,info.roomid,info.fid) 
		if ok then
                        return true
                end
        else
		if DianzanDB.Insert(info) then
			info.is_db = true
			return true
		end
        end
	return false
end

function FurniturePosDB.Select(pid,roomid,aid)
	if type(pid) ~= "number" or type(roomid) ~= "number"  then
		return false
	end
	if not aid then
		local ok, result = database.query("select pid, roomid,aid,furid,posid,direction from backyard_furniture_info where pid = %d and roomid = %d;", pid,roomid)
        	if ok and #result > 0 then
                	return result
        	else
                	return nil
        	end
	else
		if type(aid) ~= "number" then
			return false
		end
		local ok, result = database.query("select pid, roomid,aid,furid,posid ,direction from backyard_furniture_info where pid = %d and roomid = %d and aid = %d;", pid,roomid,aid)
        	if ok and #result > 0 then
                	return result[1]
       		 else
                	return nil
        	end			
	end


end

function FurniturePosDB.Insert(furInfo)
	
	local posid = 0
	local ok = database.update("insert into backyard_furniture_info(pid,roomid,furid,posid,direction) values(%d,%d,%d,%d,%d);",furInfo.pid,furInfo.roomid,furInfo.furid,furInfo.posid,furInfo.direction)
	if not ok then
		return nil
	end
	
	return database.last_id()
end

function FurniturePosDB.SyncData(FurInfo)
	if type(FurInfo) ~= "table" then
                return false
        end
	if FurInfo.is_db then
        	local ok = database.update("update backyard_furniture_info set posid = %d ,direction = %d ,furid = %d where pid = %d and roomid = %d and aid = %d; ",FurInfo.posid,FurInfo.direction,FurInfo.furid,FurInfo.pid,FurInfo.roomid,FurInfo.aid )
        	if not ok then
			return false
        	end
	else
		local res = FurniturePosDB.Insert(FurInfo)
		if res then
			FurInfo.is_db = true
			return true  -- FurniturePosDB.Insert(FurInfo)
		end
	end

	return true
end

function FurniturePosDB.Delete(aid)
	if type(aid) ~= "number" then
		return false
	end
	local res = database.update("delete from backyard_furniture_info where aid = %d;",aid)
	if not res then
		return false
	end
	return true
end

function FairySlotDB.Select(pid,roomid,sid)
	if type(pid) ~= "number" or type(roomid) ~= "number" then
		return false
	end
	if not sid then
		local ok,result = database.update("select pid,roomid,sid,unlockstatus,fairyuuid,unix_timestamp(addtime) as addtime from backyard_fairy_slot where pid = %d and roomid = %d;",pid,roomid)
        	if ok and #result > 0 then
                	return result
       	 	end
	else
		local ok,result = database.update("select pid,roomid,sid,unlockstatus,fairyuuid,unix_timestamp(addtime) as addtime  from backyard_fairy_slot where pid = %d and roomid = %d and sid = %d;",pid,roomid,sid)
		if ok and #result > 0 then
                	return result[1]
		end
	end
	return false
end

function FairySlotDB.Insert(info)
	if type(info) ~= "table" then
		return false
	end
	local ok = database.update("insert into backyard_fairy_slot(pid,roomid,sid,unlockstatus,fairyuuid,addtime) values(%d,%d,%d,%d,%d,from_unixtime_s(%d));",info.pid,info.roomid,info.sid,info.status,info.fairyuuid,info.addtime)
	if not ok then
		return false
	end
	return true
end

function FairySlotDB.Update(info)
	if type(info) ~= "table" then
                return false
        end
	print('见鬼了---------------------:',info.status,info.fairyuuid,info.addtime,info.pid,info.roomid,info.sid)
	if info.is_db then
		local ok = database.update("update backyard_fairy_slot set unlockstatus = %d , fairyuuid = %d , addtime = from_unixtime_s(%d) where pid = %d and roomid = %d and sid = %d;",info.status,info.fairyuuid,info.addtime,info.pid,info.roomid,info.sid)
		if not ok then
                        return false
                end
	else
		FairySlotDB.Insert(info)
		info.is_db = true
	end
	
	return true
end

function FairyDB.Select(pid,fairyuuid)
	if type(pid) ~= "number" or type(fairyuuid) ~= "number" then
		return false
	end
	local ok,result = database.update("select pid,fairyuuid,goodfeel from backyard_fairy where pid = %d and fairyuuid = %d;",pid,fairyuuid)
        if ok and #result > 0 then
                return result[1]
        else
                return nil
        end
	
end

function FairyDB.Insert(info)
	if type(info) ~= "table" then
                return false
        end
        local ok = database.update("insert into backyard_fairy (pid,fairyuuid,goodfeel) values(%d,%d,%d);",info.pid,info.fairyuuid,info.goodfeel)
        if not ok then
                return false
        end
        return true
end

function FairyDB.Update(info)
	if type(info) ~= "table" then
                return false
        end

        if info.is_db then
		local ok = database.update("update backyard_fairy set goodfeel = %d where pid = %d and fairyuuid = %d;",info.goodfeel,info.pid,info.fairyuuid)
                if not ok then
                        return false
                end
        else
                FairyDB.Insert(info)
                info.is_db = true
        end

        return true

end

---------------------------------------------------logic function-------------------------------------------------------
local function getBackyard(pid,roomid)
	BackyardData[pid] = BackyardData[pid] or {}
	if not BackyardData[pid][roomid] then
		local backyard = BackyardDB.Select(pid,roomid) 	
		if not backyard then
			BackyardData[pid][roomid] = { pid = pid,roomid = roomid, byname = "" ,expandcount = 0,dzcount = 0,is_db = false }
		else
			BackyardData[pid][roomid] = { pid = pid, roomid = roomid,byname =  backyard.byname ,expandcount = backyard.expandcount,dzcount = backyard.dzcount,is_db = true}
		end
	end
	return BackyardData[pid][roomid]
end

local function getDZBackyard(pid,fid,roomid)
	print('竞争。。。')

	DzCount[pid] = DzCount[pid] or {}
	DzCount[pid][fid] = DzCount[pid][fid] or {}
	if not DzCount[pid][fid][roomid] then
		local dz = DianzanDB.Select(pid,roomid,fid)
		if not dz then
			print('精忠报国。。。')
			DzCount[pid][fid][roomid] = { count = 0,dztime = 0 ,is_db = false }
		else
			DzCount[pid][fid][roomid] = { count = dz.dzcount,dztime = dz.dztime,is_db = true }
		end
	end	
	return DzCount[pid][fid][roomid]
end

local function getFurnitureInfo(pid,roomid,aid)
	FurniturePos[pid] = FurniturePos[pid] or {}
	FurniturePos[pid][roomid] = FurniturePos[pid][roomid] or {}
	if not FurniturePos[pid][roomid][aid] then
		local furdb = FurniturePosDB.Select(pid,roomid,aid)
		if not furdb then
			FurniturePos[pid][roomid][aid] = { furid = 0,posid = 0, direction = 0 ,is_db = false }
			-- return false
		else
			FurniturePos[pid][roomid][aid] = { furid = furdb.furid, posid = furdb.posid,direction = furdb.direction,is_db = true}
		end
	end
	return FurniturePos[pid][roomid][aid]
end

local function getFurnitureInfoEnterBackyard(pid,roomid)
	FurniturePos[pid] = FurniturePos[pid] or {}
----[[
	if not FurniturePos[pid][roomid] then
		FurniturePos[pid][roomid] = {}
		local furs = FurniturePosDB.Select(pid,roomid)
		if furs then
			FurniturePos[pid][roomid] = {}
			for _,v in pairs(furs) do
				print('-----',v.aid,   v.furid,v.posid,v.direction)
				FurniturePos[pid][roomid][v.aid] = { furid = v.furid,posid = v.posid,direction = v.direction }
			end
		end
	end
	return FurniturePos[pid][roomid]	--]]
end

local function getFurniture(pid,furid)
	Furniture[pid] = Furniture[pid] or {} 
	local tmp = Furniture[pid]
	if not tmp[furid] then
		local fur = FurnitureDB.Select(pid,furid)
		if not fur then
			tmp[furid] = {pid = pid, furid = furid, count = 0,is_db = false }
		else
			tmp[furid] = { pid = fur.pid, furid = fur.furid, count = fur.count,is_db = true }
		end
	end
	return tmp[furid]
end

local function getFairySlot(pid,roomid,sid)
	FairySlot[pid] = FairySlot[pid] or {} 
	FairySlot[pid][roomid] = FairySlot[pid][roomid] or {}
	if not FairySlot[pid][roomid][sid] then
		local slot = FairySlotDB.Select(pid,roomid,sid)
		if not slot then
			----[[
			if sid == 1 or sid == 2 then
				FairySlot[pid][roomid][sid] = { pid = pid,roomid = roomid,sid = sid, status = 1,fairyuuid = 0,addtime = 0,is_db = false }
			else
				FairySlot[pid][roomid][sid] = { pid = pid,roomid = roomid,sid = sid,status = 0,fairyuuid = 0,addtime = 0,is_db = false }
			end
			--]]
		else
			FairySlot[pid][roomid][sid] = {pid = pid,roomid = roomid,sid = sid, status = slot.unlockstatus,fairyuuid = slot.fairyuuid,addtime = slot.addtime,is_db = true }
		end
	end
	return FairySlot[pid][roomid][sid]
end

local function getFairySlots(pid,roomid)
	FairySlot[pid] = FairySlot[pid] or {}
        if not FairySlot[pid][roomid] then
                FairySlot[pid][roomid] = {}
                local slots = FairySlotDB.Select(pid,roomid)
                if slots then
                        for _,v in ipairs(slots) do
				FairySlot[pid][roomid][v.sid] = { status = v.status,fairyuuid = v.fairyuuid,addtime = v.addtime, is_db = true}
                        end
                end
        end

        return FairySlot[pid][roomid]
end

local function getFairy(pid,fairyuuid)
	Fairy[pid] = Fairy[pid] or {}
	if not Fairy[pid][fairyuuid] then
		local fairy = FairyDB.Select(pid,fairyuuid)
		if not fairy then
			Fairy[pid][fairyuuid] = { pid = pid,fairyuuid = fairyuuid ,goodfeel = 0 ,is_db = false }
		else
			Fairy[pid][fairyuuid] = { pid = pid,fairyuuid = fairyuuid,goodfeel = fairy.goodfeel,is_db = true }
		end
	end

	return Fairy[pid][fairyuuid] 
end

local function modifyBackyardName(pid,roomid,name)
	local player = getBackyard(pid,roomid)
	if not player then
		log.info(string.format("there is no player %d and create failed.",pid))
		return false
	end
	BackyardData[pid][roomid].byname = name;
	return BackyardDB.SyncData(BackyardData[pid][roomid],BACKYARD_DB_MODIFYNAME)
end

local function expandBackyardBuild(pid,roomid)
	local backyard = getBackyard(pid,roomid)
	if not backyard then
		log.info(string.format("there is no player %d and create failed.",pid))
		return false
        end
	if backyard.expandcount >= MAX_EXPAND_BUILD_COUNT then
		log.warning("expandcount is out of max count...")
		return false
	end

        backyard.expandcount = backyard.expandcount + 1

	local index = backyard.expandcount
	local expand_cfg = GetExpandfieldConsume(index)	
	local co_type  = expand_cfg.consume_item_type
	local co_id    = expand_cfg.consume_item_id
	local co_value = expand_cfg.consume_item_value

	if not co_type or not co_id or not co_value then
                        log.warning("can't find correct data from configuration file...")
                        return false
	end
	local consume = {{ type = co_type,id = co_id,value = re_value }}
	local respond = cell.sendReward(pid,nil,consume,Command.REASON_BACKYARD_EXPANDBUILD,0,0)
	if respond == nil or respond.result ~= Command.RET_SUCCESS then
        	log.error( "fail to modify property, coin or gold or otherthing not enough")
		return false
        end

	return BackyardDB.SyncData(backyard,BACKYARD_DB_EXPANDCOUNT)
end

local function hadDzBackyardforFriend(pid,fid,roomid)
	print('---------------------',pid,fid,roomid)
        local dz = getDZBackyard(pid,fid,roomid)	
	if dz.dztime ~= 0 then
		if isOverdueDz(dz.dztime) then
                	dz.count = 0
        	end
	end
        if dz.count >= 1 then
		log.warning("you have dianzan for the friend today...")
        	return false
	end
	-- 给朋友点赞	
	dz.count = dz.count  + 1
        dz.dztime = loop.now()

	local tmp = {pid = pid,roomid = roomid,fid = fid,count = dz.count,dztime = dz.dztime,is_db = dz.is_db}
	
	
	print('~~~~~~~~~~~~~~~~~1')
        DianzanDB.SyncData(tmp)
	print('~~~~~~~~~~~~~~~~~2')
	-- 被点赞的朋友点赞次数加1
	local backyard = getBackyard(fid,roomid)
        if not backyard then
		log.info("dianzan count is failed to add ....")
                return false
        end
	backyard.dzcount = backyard.dzcount + 1
	print('~~~~~~~~~~~~~~~~~3')
	return BackyardDB.SyncData(backyard,BACKYARD_DB_DZCOUNT)
end

local function acquireFurniture(pid,furid,count)
	local fur = getFurniture(pid,furid)
	if not fur then
		log.info("get furniture failed...")
		return false
	end
	fur.count = fur.count +  count
	local tFur = { pid = pid ,furid = furid ,count = fur.count, is_db = fur.is_db }
	Furniture.SyncData(tFur)		
	return true
end

local function deleleFurniture(pid,furid)   -- 此处为删除家具(出售、兑换等)(玩家拥有多个同样家具需要考虑个数 TODO) (暂时删除所有相同家具)
	if not Furniture[pid] then
                log.warning("paramter pid is error.")
                return false
        end
        if not Furniture[pid][furid] then
                log.info(string.format("there is no furid %d.",furid))
                return false
        end

	Furniture[pid][furid] = nil
       	local tFur = { pid = pid,furid = furid }
        FurnitureDB.Delete(tFur)
end

local function saveFurniturePos(pid,roomid,furInfo)   -- 保存家具位置
	local amf = {}
	for _,v in ipairs(furInfo) do
		local _aid   = v[1]
		local _furid = v[2]
		local _posid = v[3]
		local _dir   = v[4]
		print('------------------',_aid,_furid,_posid,_dir)
		if _posid ~= 0 then
			if _aid == 0 then
                   		local tmp = { pid = pid ,roomid = roomid, furid = _furid,posid = _posid,direction = _dir }
                        	local aid = FurniturePosDB.Insert(tmp)
                       		local furpos = getFurnitureInfo(pid,roomid,aid)
                        	if not furpos then
                                	log.warning("there is no this aid ...")
                                	return false
                        	end
                        	furpos = { furid = _furid,posid = _posid,direction = _dir,is_db = furpos.is_db}
                        	table.insert(amf,aid)
                	else
                        	local furpos = getFurnitureInfo(pid,roomid,_aid)
                        	if not furpos then
                                	log.warning("there is no this aid ...")
                                	return false
                        	end
                        	furpos.furid     = _furid
                        	furpos.posid     = _posid
				furpos.direction = _dir	
                        	local tmp = {pid = pid ,roomid = roomid,aid = _aid, furid = _furid,posid = _posid,direction = _dir,is_db = furpos.is_db}
                        	local ret = FurniturePosDB.SyncData(tmp)
                        	if not ret then
                                	log.warning("SyncData err...")
                                	return false
                        	end
                        	table.insert(amf,_aid)
                	end			
		else
			if _aid == 0 then
				log.warning("v[1] is invalid number...")
				return false
			end

			if FurniturePos[pid] and FurniturePos[pid][roomid] and FurniturePos[pid][roomid][_aid] then
				FurniturePos[pid][roomid][_aid] = nil
			end
			local ret = FurniturePosDB.Delete(_aid)
			if not ret then
                        	log.warning("Delete err...")
                                return false
                        end
		end	
	end
	return amf
end

local function clearFurniture(pid,roomid)   -- 清空某一房间的家具
	if not FurniturePos[pid] then
		log.warning("paramter pid is error.")
		return false
	end
	if not FurniturePos[pid][roomid] then
		log.warning("paramter roomid is error.")
                return false
	end
	for _,v in pairs(FurniturePos[pid][roomid]) do
		v.posid = 0
		local tFur = { pid,roomid,v.aid,v.furid,v.posid,v.direction,v.is_db}
    		local ret = FurniturePosDB.SyncData(tFur)
		if not ret then
			log.warning("SyncData failure...")
			return false
		end
	end
	return true
end

-------------------------------------------------------------
local function environmentComfort(suit_id,count,sum)   -- 环境舒适度计算(包括家具本身舒适度+家具套装额外加成)
	local rate = 0
        local n = 4 * math.ceil(count/4)
	if n == 0 then
		return 0
	end
	local comfort_cfg = GetComfortable(suit_id,n)
        if not comfort_cfg then
		log.warning('no find in configure file...')
		return false
        end
        rate = comfort_cfg.increase_number/10000
	return sum * (1 +  rate)
end

local SUITCOUNT = 4
local function  comfortableSum(pid,roomid)	--环境舒适度总和
	local comfort = 0
	local suit = {}
	for i = 1,SUITCOUNT,1 do
		table.insert(suit,{ count = 0,sum = 0 })		-- suit[i]  表示配置里的对应套装id
	end
	local furnitures = getFurnitureInfoEnterBackyard(pid,roomid)
	for _,v in pairs(furnitures) do	-- id:套装的id
		local fur_cfg = GetFurniture(v.furid) 
		for id,s in ipairs(suit) do
			if fur_cfg.belong_suit == id then
				s.count = s.count + 1
	                        s.sum   = s.sum + fur_cfg.comfort_value
			end
		end
	end
	for i = 1,SUITCOUNT,1 do
		comfort = comfort + environmentComfort(i,suit[i].count,suit[i].sum)
	end
	return comfort
end

local goodfeelSpeed = GetGoodfeelSpeed()
local function notify(cmd, pid, msg)
        local agent = Agent.Get(pid);
        if agent then
                agent:Notify({cmd, msg});
        end
end

Scheduler.Register(function(now)
	if not goodfeelSpeed then return end
	for pid,v1 in pairs(FairySlot) do
		for roomid,v2 in pairs(v1) do
			for sid,slot in pairs(v2) do
				if slot.fairyuuid > 0 and (now - slot.addtime) % 3600 == 0 then                                 		   -- 一小时更新一次
					local tmp_time = math.ceil((now - slot.addtime)/3600)
					local basic_Goodfeel = tmp_time * goodfeelSpeed.basic_inc   					   -- 基础好感度
					local scene_Goodfeel = goodfeelSpeed.comfort_coefficient * comfortableSum(pid,roomid) * tmp_time   -- 场景好感度
					local sum_Goodfeel = math.ceil(basic_Goodfeel + scene_Goodfeel)
                                        local fairy = getFairy(pid,slot.fairyuuid)
                                       	fairy.goodfeel = sum_Goodfeel
					print('通知：','sum_Goodfeel = '..sum_Goodfeel,'basic_Goodfeel = '..basic_Goodfeel,'scene_Goodfeel = '..scene_Goodfeel)
                                        FairyDB.Update(fairy)
           				        			
					notify(Command.NOTIFY_BACKYARD_FAIRY_GOODFEEL,pid,{0,Command.RET_SUCCESS,slot.fairyuuid,sum_Goodfeel})
                                end				
			end
		end
	end
end)

local goodFeelSolt = {}
local function unlockGoodfeelSlot(pid,roomid,sid)
	local tmpslot = getFairySlot(pid,roomid,sid)
        if not tmpslot then
                return false
        end
	
	-- 消耗
	local slot_cfg = GetGoodfeelConsume(sid - 2)
	local co_type  = slot_cfg.consume_item_type
        local co_id    = slot_cfg.consume_item_id
        local co_value = slot_cfg.consume_item_value	
	if not co_type or not co_id or not co_value then
        	log.warning("can't find correct data from configuration file...")
                return false
        end
        local consume = {{ type = co_type,id = co_id,value = re_value }}
        local respond = cell.sendReward(pid,nil,consume,Command.REASON_BACKYARD_UNLOCKSLOT,0,0)
        if respond == nil or respond.result ~= Command.RET_SUCCESS then
                log.error( "coin or gold or otherthing not enough...")
                return false
        end	
		
	tmpslot.status = 1
	tmpslot.fairyuuid = 0
	tmpslot.addtime = 0
	print('unlockGoodfeelSlot----------------------')	
	return FairySlotDB.Update(tmpslot)
end

------------------------------------------------interface function----------------------------------------------------------------
local function onModifyBackyardName(conn,pid,request)	-- 修改名字
	local cmd = Command.C_BACKYARD_MODIFYNAME_RESPOND
	local sn   = request[1]
        local roomid = request[2]
	local name = request[3]
	
	if type(roomid) ~= 'number' then
		log.info(string.format("The 1th parameter is not number"))
		return conn:sendClientRespond(cmd,pid,{sn,Command.RET_PARAM_ERROR})
	end
	
	if #name > MAX_SHOPNAME_LENGTH and type(name) ~= 'string' then
		log.info(string.format("The name parameter exceeds is error"))
                return conn:sendClientRespond(cmd,pid,{sn,Command.RET_PARAM_ERROR})
        end
	print("----------------------modify name...")
	local ret = modifyBackyardName(pid,roomid,name)
        return conn:sendClientRespond(cmd,pid,{sn,ret and Command.RET_SUCCESS or Command.RET_ERROR} )	
end

local function onExpandBackyardBuild(conn,pid,request)	-- 扩建
	local cmd = Command.C_BACKYARD_EXPANDBUILD_RESPOND
	local sn = request[1]
	local roomid = request[2]
	if type(roomid) ~= 'number' then
                log.info(string.format("The 1th parameter is not number"))
                return conn:sendClientRespond(cmd,pid,{sn,Command.RET_PARAM_ERROR})
        end
	
       	print("------------start expand...")
	local ret = expandBackyardBuild(pid,roomid)
        return conn:sendClientRespond(cmd,pid,{sn,ret and Command.RET_SUCCESS or  Command.RET_ERROR})	
end

local function onDZBackyardforFriends(conn,pid,request) --点赞
	local cmd = Command.C_BACKYARD_DIANZAN_RESPOND
	local sn = request[1]
	local fid = request[2]
	local roomid = request[3]
	if type(fid) ~= 'number' or type(roomid) ~= 'number' then
		log.info("parameter is not number")
		return conn:sendClientRespond(cmd,pid,{sn,Command.RET_PARAM_ERROR})
	end
	print("------------------start dianzan...")
	local ret =  hadDzBackyardforFriend(pid,fid,roomid)
	return conn:sendClientRespond(cmd,pid,{sn,ret and Command.RET_SUCCESS or  Command.RET_ERROR})	
end

local function onSaveFurniturePos(conn,pid,request) --保存家具位置
	local cmd = Command.C_BACKYARD_EXPANDBUILD_RESPOND
	local sn   = request[1]
	local roomid = request[2]
	local furInfo = request[3]
	print("=============Save Furniture:")	
	if type(roomid) ~= 'number' then
		log.warning("the 2th parameter is not number...")
		return conn:sendClientRespond(cmd,pid,{sn,Command.RET_PARAM_ERROR})
	end
	if type(furInfo) ~= 'table' then
		log.warning("the 3th parameter is not table...")
                return conn:sendClientRespond(cmd,pid,{sn,Command.RET_PARAM_ERROR})
	end
	local furaids = saveFurniturePos(pid,roomid,furInfo)	
        return conn:sendClientRespond(cmd,pid,{sn,furaids and Command.RET_SUCCESS or Command.RET_ERROR,furaids })	
end

local function onClearFurniture(conn,pid,request) --清除场地中的家具
	local cmd = Command.C_BACKYARD_CLEARFURNITURE_RESPOND
	local sn   = request[1]
	local roomid = request[2]	
	if type(roomid) ~= 'number' then
                log.warning("the 2th parameter is not number...")
                return conn:sendClientRespond(cmd,pid,{sn,Command.RET_PARAM_ERROR})
        end
	local ret = clearFurniture(pid,roomid)
	return conn:sendClientRespond(cmd,pid,{sn,ret and Command.RET_SUCCESS or Command.RET_ERROR })
end

local function getBackyardInfo(pid,roomid)
	local amf = {}
	local furs_amf = {}
	local backyard_amf = {}
	local fairyslot = {}
	print('*************** ',pid,roomid)
	local furs = getFurnitureInfoEnterBackyard(pid,roomid)
	if furs then
		for aid,v in pairs(furs) do
			if v then
				print('---------------------------------',aid,v.furid,v.posid,v.direction)
        	        	table.insert(furs_amf,{aid,v.furid,v.posid,v.direction})
			end
		end
	end
	local backyard = getBackyard(pid,roomid)
	if not backyard then
		log.warning("there is no backyard...")
		return false
	end

	local slots = getFairySlots(pid,roomid)
	for sid,v in pairs(slots) do
		print('========== ',sid,v.status,v.fairyuuid,v.addtime)
		table.insert(fairyslot,{sid,v.status,v.fairyuuid,v.addtime})
	end
	
	print('$$$$$$$$$$$ ',backyard.byname, backyard.expandcount, backyard.dzcount)
	
	table.insert(amf, { backyard.byname, backyard.expandcount, backyard.dzcount } )
	table.insert(amf,furs_amf)
	table.insert(amf,fairyslot)
	
	return amf
end

local function onEnterBackyard(conn,pid,request)
	local cmd = Command.C_BACKYARD_ENTERBACKYARD_RESPOND
	local sn = request[1]
	local playerid = request[2]
	local roomid = request[3]
	if type(playerid) ~= 'number' or type(roomid) ~= 'number' then
		log.warning("the parameters is not number...")
		return conn:sendClientRespond(cmd,playerid,{sn,Command.RET_PARAM_ERROR})
	end
	print("------------------enter into backyard...")
	print("=====================pid = "..pid,"playerid = "..playerid)
	local ret = getBackyardInfo(playerid,roomid)
	
	return conn:sendClientRespond(cmd,pid,{sn,ret and Command.RET_SUCCESS or Command.RET_ERROR,ret })
end

local function addFairytoSlot(pid,roomid,sid,fairyuuid)
	local slot = getFairySlot(pid,roomid,sid)
	if not slot then
		return false
	end
	slot.fairyuuid = fairyuuid
	slot.addtime = loop.now()

	print('status = '.. slot.status)
	
	print('addFairytoSlot-------------------------')	
	if not FairySlotDB.Update(slot) then
		log.warning("update error...")
		return false
	end
	return slot.addtime
end

local function removeFairyfromSlot(pid,roomid,sid)
	local slot = getFairySlot(pid,roomid,sid)
	
	if slot.status == 0 or slot.fairyuuid == 0 then
		log.warning('slot not open or no fairy in this slot...')
		return false
	end
	slot.fairyuuid = 0
	slot.addtime = 0

	print('removeFairyfromSlot----------------------')	
	return FairySlotDB.Update(slot) 	
end

local function onUnlockGoodfeelSlot(conn,pid,request)		-- 解锁培养槽
	local cmd = Command.C_BACKYARD_UNLOCKGOODFEELSLOT_RESPOND
	local sn = request[1]
	local roomid = request[2]
	local sid = request[3]	-- 槽位的id
	
	if type(roomid) ~= 'number' or type(sid) ~= 'number' then
		log.warning("the 2th parameter is not number...")
                return conn:sendClientRespond(cmd,pid,{sn,Command.RET_PARAM_ERROR})
	end

	print('-------------------start unlock slot:')
	local ret = unlockGoodfeelSlot(pid,roomid,sid)
	return conn:sendClientRespond(cmd,pid,{sn,ret and Command.RET_SUCCESS or Command.RET_ERROR })
end

local function onAddFairytoSlot(conn,pid,request)		-- 妖精加入培养槽
	local cmd = Command.C_BACKYARD_ADDFAIRYTOSLOT_RESPOND
	local sn = request[1]
	local roomid = request[2]
        local sid    = request[3]
	local fairyuuid    = request[4]
        if type(roomid) ~= 'number' or type(sid) ~= 'number' or type(fairyuuid) ~= 'number' then
                log.warning("parameter is not number...")
                return conn:sendClientRespond(cmd,pid,{sn,Command.RET_PARAM_ERROR})
        end
	print('---------------------start add fairy:')
        local ret = addFairytoSlot(pid,roomid,sid,fairyuuid)

        return conn:sendClientRespond(cmd,pid,{sn,ret and Command.RET_SUCCESS or Command.RET_ERROR,ret })
		
end

local function onRemoveFairyfromSlot(conn,pid,request)
	local cmd = Command.C_BACKYARD_REMOVEFAIRYFROMSLOT_RESPOND
	local sn = request[1]
        local roomid = request[2]
        local sid    = request[3]
	
	if type(roomid) ~= 'number' or type(sid) ~= 'number' then
		log.warning("parameter is not number...")
                return conn:sendClientRespond(cmd,pid,{sn,Command.RET_PARAM_ERROR})
	end

	print('---------------------start remove fairy:')	
	if not removeFairyfromSlot(pid,roomid,sid) then
		log.warning("remove fairy error...")	
		return conn:sendClientRespond(cmd,pid,{sn, Command.RET_ERROR})
	end

	return conn:sendClientRespond(cmd,pid,{sn,Command.RET_SUCCESS})

end

local function onQueryFairyGoodfeel(conn,pid,request)
	local cmd = Command.C_BACKYARD_QUERYFAIRYGOODFEEL_RESPOND
	local sn = request[1]
	local uuid = request[2]
	
	if type(uuid) ~= "number" then
		log.warning("parameter is not number...")
                return conn:sendClientRespond(cmd,pid,{sn,Command.RET_PARAM_ERROR})
	end
	
	print("-----------------start query goodfeel:")	

	local fairy = getFairy(pid,uuid)
	return conn:sendClientRespond(cmd,pid,{sn,Command.RET_SUCCESS,fairy.goodfeel})		
end

local Backyard = {}
function Backyard.RegisterCommand(service)
	service:on(Command.C_BACKYARD_MODIFYNAME_REQUEST,onModifyBackyardName)           -- 修改后宫昵称
	service:on(Command.C_BACKYARD_DIANZAN_REQUEST,onDZBackyardforFriends)      	 -- 后宫点赞
	service:on(Command.C_BACKYARD_EXPANDBUILD_REQUEST,onExpandBackyardBuild)  	 -- 扩建场地
	service:on(Command.C_BACKYARD_HOLDFURNITURE_REQUEST,onSaveFurniturePos) 	 -- 保存家具位置 ==>最多可以放置多少个家具
	service:on(Command.C_BACKYARD_ENTERBACKYARD_REQUEST,onEnterBackyard)		 -- 进入后宫

	service:on(Command.C_BACKYARD_UNLOCKGOODFEELSLOT_REQUEST,onUnlockGoodfeelSlot)   -- 开启妖精培养槽
	service:on(Command.C_BACKYARD_ADDFAIRYTOSLOT_REQUEST,onAddFairytoSlot)	  	 -- 妖精放置培养槽
	service:on(Command.C_BACKYARD_REMOVEFAIRYFROMSLOT_REQUEST,onRemoveFairyfromSlot) -- 卸下妖精
	service:on(Command.C_BACKYARD_QUERYFAIRYGOODFEEL_REQUEST,onQueryFairyGoodfeel)   -- 查询妖精好感度
end
return Backyard
