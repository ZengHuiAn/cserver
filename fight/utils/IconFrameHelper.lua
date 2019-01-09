local GetModule = require "module.GetModule"
local IconFrameHelper = {}
function IconFrameHelper.Item(data,parent,pos,scale)
	local type = data.type or 41
	local ItemClone =CS.UnityEngine.GameObject.Instantiate(SGK.ResourcesManager.Load("prefabs/ItemIcon"))
	if parent then
		ItemClone.transform:SetParent(parent.gameObject.transform,false);
		ItemClone.transform.localPosition = pos and Vector3(pos.x,pos.y,pos.z) or  Vector3(0,0,0)
		ItemClone.transform.localScale = scale and Vector3(scale,scale,scale) or Vector3(1,1,1)
	end
	local ItemIconView = SGK.UIReference.Setup(ItemClone)
	IconFrameHelper.UpdateItem(data,ItemIconView,parent)
	--ItemIconView.OnPointerDown = ItemIconView[SGK.ItemIcon].OnPointerDown
	return ItemIconView
end

function IconFrameHelper.UpdateItem(data,ItemIconView,parent)
	local id = data.id or 10000
	local type = data.type or 41
	local count = data.count or 0
	local showDetail = data.showDetail or false
	local ShowItemName = data.ShowItemName or false
	local getType= data.GetType or 0 --默认0 不显示（1必得2概率）
	local func=data.func
	if ItemIconView then
		local _cfg=GetModule.ItemHelper.Get(type,id,nil,count)
		ItemIconView[SGK.ItemIcon]:SetInfo(setmetatable({func=func},{__index=_cfg}))
		ItemIconView[SGK.ItemIcon].showDetail = showDetail
		ItemIconView[SGK.ItemIcon].ShowNameText = ShowItemName
		ItemIconView[SGK.ItemIcon].GetType=getType;
	end
end

function IconFrameHelper.Equip(data,parent,pos,scale)
	local ItemClone =CS.UnityEngine.GameObject.Instantiate(SGK.ResourcesManager.Load("prefabs/EquipIcon"))
	if parent then
		ItemClone.transform:SetParent(parent.gameObject.transform,false);
		ItemClone.transform.localPosition =pos or  Vector3(0,0,0)
		ItemClone.transform.localScale =scale or Vector3(1,1,1)
	end
	local ItemIconView = SGK.UIReference.Setup(ItemClone)
	IconFrameHelper.UpdateEquip(data,ItemIconView,parent)
	return ItemIconView
end

function IconFrameHelper.UpdateEquip(data,ItemIconView,parent)
	local uuid = data.uuid
	local showDetail = data.showDetail or false
	local getType= data.GetType or 0 --默认0 不显示（1必得2概率）
	local func=data.func
	if ItemIconView then
		local _equip = GetModule.EquipmentModule.GetByUUID(uuid)     
		if _equip then
			IconItem=_Icon.EquipIcon
			Icon=_Icon.EquipIcon[SGK.EquipIcon]

			if not type then
				if equipmentConfig.EquipmentTab(_equip.id) then
					type = utils.ItemHelper.TYPE.EQUIPMENT
				elseif equipmentConfig.InscriptioncustomCfg(_equip.id) then
					type = utils.ItemHelper.TYPE.INSCRIPTION
				end
			end
			ItemIconView[SGK.EquipIcon]:SetInfo(setmetatable({ItemType=type},{__index=_equip}))
			ItemIconView[SGK.EquipIcon].showDetail = showDetail
			ItemIconView[SGK.EquipIcon].GetType=getType;
		else
			ERROR_LOG("equip cfg is nil,uuid",uuid)             
		end	
	end
end

function IconFrameHelper.Hero(data,parent,pos,scale)
	local CharacterClone = CS.UnityEngine.GameObject.Instantiate(SGK.ResourcesManager.Load("prefabs/CharacterIcon"))
	if parent then
		CharacterClone.transform:SetParent(parent.gameObject.transform,false);
		CharacterClone.transform.localPosition = pos and Vector3(pos.x,pos.y,pos.z) or  Vector3(0,0,0)
		CharacterClone.transform.localScale = scale and Vector3(scale,scale,scale) or Vector3(1,1,1)
	end
	local CharacterIconView = SGK.UIReference.Setup(CharacterClone)
	IconFrameHelper.UpdateHero(data,CharacterIconView,parent)
	return CharacterIconView
end

function IconFrameHelper.UpdateHero(data,CharacterIconView,parent)
	local icon = data.icon or 11000
	local level = data.level or	0
	local quality = data.quality or 0
	local star = data.star or 0
	-- local vip = data.vip or 0
	local showDetail = data.showDetail or false
	local getType= data.GetType or 0 --默认0 不显示（1必得2概率）
	local sex = data.sex or -1
	local headFrame = data.headFrame or ""
	local func=data.func
	if data.pid then
		if module.playerModule.IsDataExist(data.pid) then
			local player=module.playerModule.Get(data.pid);
			CharacterIconView[SGK.CharacterIcon]:SetInfo(setmetatable({func=func},{__index=player}),true)
		else
			module.playerModule.Get(data.pid,function ( ... )
				if CharacterIconView.gameObject and utils.SGKTools.GameObject_null(CharacterIconView) == false then
					local player=module.playerModule.Get(data.pid);
					CharacterIconView[SGK.CharacterIcon]:SetInfo(setmetatable({func=func},{__index=player}),true)
				end
			end)
		end
	else
		CharacterIconView[SGK.CharacterIcon]:SetInfo({func=func,icon=icon,level=level,quality=quality,star=star},false)
	end
	if CharacterIconView.gameObject and utils.SGKTools.GameObject_null(CharacterIconView) == false then
		CharacterIconView[SGK.CharacterIcon].sex = sex
		CharacterIconView[SGK.CharacterIcon].headFrame = headFrame
		CharacterIconView[SGK.CharacterIcon].showDetail = showDetail
		CharacterIconView[SGK.CharacterIcon].GetType=getType;
	end
end


return IconFrameHelper