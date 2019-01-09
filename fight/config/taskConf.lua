local quest_menu_list = nil
local function Getquest_menu(id)
	if not quest_menu_list then
		quest_menu_list = {}
		DATABASE.ForEach("quest_menu", function(row)
			if not quest_menu_list[row.id] then
				quest_menu_list[row.id] = {}
			end
			quest_menu_list[row.id][#quest_menu_list[row.id]+1] = row
		end)
	end
	return quest_menu_list[id]
end
return{
	Getquest_menu = Getquest_menu,
}