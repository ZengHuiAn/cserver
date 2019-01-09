local story_triggerConf = nil
local Story_Conf = nil

local function FillStoryList(Conf, list)
	if not Conf then
		return list
	end

	list = list or {}
	list[#list + 1] = Conf

	return FillStoryList(Story_Conf[Conf.next_id], list)
end
local function InitStoryConf( ... )
	if Story_Conf == nil then
		Story_Conf = LoadDatabaseWithKey("story", "story_id");
	end
end

local function GetStoryConf(id)
	if Story_Conf == nil then
		Story_Conf = LoadDatabaseWithKey("story", "story_id");
	end
	if Story_Conf[id] ~= nil then
	    Story_Conf[id].role1=Story_Conf[id].role
	    Story_Conf[id].role1_posX=Story_Conf[id].role_posX
	    Story_Conf[id].role1_posY=Story_Conf[id].role_posY
	    Story_Conf[id].role1_exit_type=Story_Conf[id].role_exit_type
	    Story_Conf[id].role1_size=Story_Conf[id].role_size
	    Story_Conf[id].role1_action=Story_Conf[id].action
	    Story_Conf[id].role1_move_type=Story_Conf[id].role_move_type
	    Story_Conf[id].role1_effect_point=Story_Conf[id].role_effect_point
	    Story_Conf[id].role1_effect_name=Story_Conf[id].role_effect_name
	    Story_Conf[id].role1_look_point=Story_Conf[id].role_look_point
	    Story_Conf[id].role1_look_name=Story_Conf[id].role_look_name
	    Story_Conf[id].role1_is_turn=Story_Conf[id].is_turn
	    Story_Conf[id].role1_enter_type=Story_Conf[id].role_enter_type
    end
	return Story_Conf[id]
end
local StoryConf_old = nil
local function GetStoryConf_old(id)
	if StoryConf_old == nil then
		StoryConf_old = LoadDatabaseWithKey("story", "next_id");
	end
	if StoryConf_old[id] ~= nil then
	    StoryConf_old[id].role1=StoryConf_old[id].role
	    StoryConf_old[id].role1_posX=StoryConf_old[id].role_posX
	    StoryConf_old[id].role1_posY=StoryConf_old[id].role_posY
	    StoryConf_old[id].role1_exit_type=StoryConf_old[id].role_exit_type
	    StoryConf_old[id].role1_size=StoryConf_old[id].role_size
	    StoryConf_old[id].role1_action=StoryConf_old[id].action
	    StoryConf_old[id].role1_move_type=StoryConf_old[id].role_move_type
	    StoryConf_old[id].role1_effect_point=StoryConf_old[id].role_effect_point
	    StoryConf_old[id].role1_effect_name=StoryConf_old[id].role_effect_name
	    StoryConf_old[id].role1_look_point=StoryConf_old[id].role_look_point
	    StoryConf_old[id].role1_look_name=StoryConf_old[id].role_look_name
	    StoryConf_old[id].role1_is_turn=StoryConf_old[id].is_turn
	    StoryConf_old[id].role1_enter_type=StoryConf_old[id].role_enter_type
    end
	return StoryConf_old[id]
end
local function GetStoryTriggerConf(id)
	if story_triggerConf == nil then
		story_triggerConf = {}
		DATABASE.ForEach("story_trigger", function(row)
			story_triggerConf[row.id] = GetStoryConf(row.story_id)
		end)
	end
	return story_triggerConf[id]
end

local _last_story_data;
local function ChangeStoryData(data)
	_last_story_data = data;
	if _last_story_data then
		DispatchEvent("STORYFRAME_CONTENT_CHANGE", _last_story_data);
	end
end

local function GetStoryData(data)
	return _last_story_data;
end

local function ShowStory(_id,_Fun,_state, _closeFunc)
	_Fun = _Fun and coroutine.wrap(_Fun);
	local data = {id = _id,Function = _Fun,state = _state, onClose = _closeFunc};

	local _p = UnityEngine.GameObject.FindWithTag("UGUIGuideRoot") or UnityEngine.GameObject.FindWithTag("UGUIRootTop")
	if not _p then
		_p = UnityEngine.GameObject.FindWithTag("UGUIRoot")
	end
	
	local StoryFrame = DialogStack.GetPref_list("StoryFrame")
	if StoryFrame then
		if StoryFrame.gameObject then
			StoryFrame:SetActive(true)
		end
		ChangeStoryData(data);
	else
		DialogStack.PushPref("StoryFrame", data, _p)
	end
end

--[[
local function ChangeStory()
	local StoryFrame = DialogStack.GetPref_list("StoryFrame")
    if StoryFrame then
        if StoryFrame.gameObject then
            StoryFrame:SetActive(true)
        end
	DispatchEvent("STORYFRAME_CONTENT_CHANGE", {id = _id,Function = _Fun,state = _state});
end
--]]

return {
	GetStoryTriggerConf = GetStoryTriggerConf,
	GetStoryConf = GetStoryConf,
	InitStoryConf = InitStoryConf,
	GetStoryConf_old = GetStoryConf_old,
	ShowStory = ShowStory,
	GetStoryData = GetStoryData,
	ChangeStoryData = ChangeStoryData,
}
