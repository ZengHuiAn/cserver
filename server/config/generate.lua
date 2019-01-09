function parseLine(line, keys)
	if string.sub(line, 1, 1) ==  '#' then
		return nil;
	end

	local pos = 1;
	local row = {};
	local cur = "";
	for i = 1,string.len(line) 
	do
		local byte = string.sub(line, i, i);
		if byte == '\t' or byte == ' ' or byte == '\r' or byte == '\n' or byte == ',' then
			if keys == nil or keys[pos] == nil then
				row[pos] = cur;
			else
				row[keys[pos]] = cur;
			end
			pos = pos+1;
			cur = "";
		else
			cur = cur .. byte;
		end
	end

	if string.len(cur) > 0 then
		if keys == nil or keys[pos] == nil then
			row[pos] = cur;
		else
			row[keys[pos]] = cur;
		end
	end
	return row;
end

function parseFile(name, keys)
	print("read file " .. name);
	local file = io.open(name, "r");
	local matrix = {};

	while true
	do
		local line=file:read("*l");
		if line == nil then
			break;
		end

		local row = parseLine(line, keys);
		if row then
			matrix[table.maxn(matrix) + 1] = row;
		end
	end
	return matrix;
end

function dumpMatrix(matrix)
	for index, row in ipairs(matrix)
	do
		for key,value in pairs(row)
		do
			print("", key, value);
		end
		print("-----");
	end
end


function  GenerateBuilding()
	print("GenerateBuilding");

	local matrix=parseFile("./building/building.txt", {"id", "Name", "Image", "Type", "Rate", "Depend", "MaxLevel"})

	print("WriteFile ./building/building.xml");
	local file = io.open("./building/building.xml", "w");
	file:write(string.format("%c%c%c", 0xEF, 0xBB, 0xBF));
	file:write("<Buildings> <!-- 建筑配置表 -->\n");
	for index, row in ipairs(matrix)
	do
		file:write(string.format("  <Building id=\"%s\">\n", row.id));
		file:write(string.format("    <Name>%s</Name> <!-- 名称 -->\n", row.Name));
		file:write(string.format("    <Images>\n"));
		file:write(string.format("      <Image level=\"1\">resource/icon/building/building_%s.png</Image> <!-- 图标 -->\n", row.Image));
		file:write(string.format("    </Images>\n"));
		file:write(string.format("    <Rate>%s</Rate> <!-- 消耗比率 -->\n", row.Rate));
		file:write(string.format("    <Type>%s</Type> <!-- 类别 -->\n", row.Type));
		file:write(string.format("    <MaxLevel>%s</MaxLevel> <!-- 最大等级 -->\n", row.MaxLevel));
		file:write(string.format("    <Depend>%s</Depend> <!-- 出现需要官府等级 -->\n", row.Depend));
		file:write(string.format("  </Building>\n"));
	end
	file:write("</Buildings>\n")
	file:close()
	print("");
end


function WriteLine(file, row, key, desc, sep)
	if (row[key] == "0") then
		return;
	else
		file:write(string.format("%s<%s>%s</%s> <!-- %s -->\n", sep, key, row[key], key, desc));
	end
end

function  GenerateBuildingUpgrade()
	print("GenerateBuildingUpgrade");

	local matrix=parseFile("./building/upgrade.txt", {"level", "Coin", "Cooldown", "Prosperity", "Exp"});
	--dumpMatrix(matrix);

	print("WriteFile ./building/upgrade.xml");
	local file = io.open("./building/upgrade.xml", "w");

	file:write(string.format("%c%c%c", 0xEF, 0xBB, 0xBF));
	file:write(string.format("<BuildingUpgrade> <!-- 建筑升级基础配置表 -->\n"));
	for index, row in ipairs(matrix)
	do
		file:write(string.format("  <Level level=\"%s\">\n", row.level));
		file:write(string.format("    <Cost>\n"));
		WriteLine(file, row, "Coin", "铜币", "      ");
		WriteLine(file, row, "Cooldown", "cd", "      ");
		file:write(string.format("    </Cost>\n"));
		WriteLine(file, row, "Prosperity", "提供繁荣度", "    ");
		WriteLine(file, row, "Exp", "提供经验", "    ");
		file:write(string.format("  </Level>\n"));
	end
	file:write(string.format("</BuildingUpgrade>\n"));
	file:close()
	print("");
end

function  GenerateBuildingDefense()
	print("GenerateBuildingDefense");

	local matrix=parseFile("./building/defense.txt", {"id", "Name", "Image", "Target", "Hurt", "Cost"});
	--dumpMatrix(matrix);

	print("WriteFile ./building/defense.xml");
	local file = io.open("./building/defense.xml", "w");

	file:write(string.format("%c%c%c", 0xEF, 0xBB, 0xBF));
	file:write(string.format("<Defenses> <!-- 城防配置表 -->\n"));
	for index, row in ipairs(matrix)
	do
		file:write(string.format("  <Defense id=\"%s\">\n", row.id));
		file:write(string.format("    <Name>%s</Name> <!-- 名称 -->\n", row.Name));
		file:write(string.format("    <Image>resource/icon/building/defense_%s.png</Image> <!-- 图标 -->\n", row.Image));
		file:write(string.format("    <Target>%s</Target> <!-- 攻击目标 -->\n", row.Target));
		file:write(string.format("    <Hurt>%s</Hurt> <!-- 伤害 -->\n", row.Hurt));
		file:write(string.format("    <Cost>%s</Cost> <!-- 价格-->\n", row.Cost));
		file:write(string.format("    <Desc>这是城防%s</Desc> <!-- 价格-->\n", row.Name));
		file:write(string.format("  </Defense>\n"));
	end
	file:write(string.format("</Defenses>\n"));
	file:close()
	print("");
end

function  GenerateCityUpgrade()
	print("GenerateCityUpgrade");

	local matrix=parseFile("./city/upgrade.txt", {"level", "GuanfuMaxLevel", "FarmSize", "Prosperity"})
	--dumpMatrix(matrix);

	print("WriteFile ./city/upgrade.xml");
	local file = io.open("./city/upgrade.xml", "w");

	file:write(string.format("%c%c%c", 0xEF, 0xBB, 0xBF));
	file:write(string.format("<CityUpgrade> <!-- 城市升级配置表 -->\n"));
	for index, row in ipairs(matrix)
	do
		file:write(string.format("  <Level level =\"%s\">\n", row.level));
		file:write(string.format("    <Condition> <!-- 依赖条件-->\n"));
		file:write(string.format("      <Prosperity>%s</Prosperity> <!-- 繁荣度 -->\n", row.Prosperity));
		file:write(string.format("    </Condition>\n"));
		file:write(string.format("    <GuanfuMaxLevel>%s</GuanfuMaxLevel><!-- 官府最大等级 -->\n", row.GuanfuMaxLevel));
		file:write(string.format("    <FarmSize>%s</FarmSize> <!-- 势力范围 -->\n", row.FarmSize));
		file:write(string.format("  </Level>\n"));
	end
	file:write(string.format("</CityUpgrade>\n"));
	file:close()
	print("");
end


function translate_color(color)
	local colorID = {
		White = 1,
		Green = 2,
		Blue = 3,
		Yellow = 4,
		Purple = 5,
		Red = 6
	};

	if  colorID[color] == nil
	then
		return 1;
	else
		return colorID[color];
	end
end

function GenerateEquipTemplate()
	print("GenerateEquipTemplate");

	local dir="equip";
	local name="equip_template"

	local matrix=parseFile("./" .. dir .. "/" .. name .. ".txt",
			{"id", "Name", "Image", "Type", "Color", "MinLevel",
			"MeleeAttack", "RangeAttack", "MeleeDefense", "RangeDefense",
			"Soldier", "CostRate", "Price", "Desc"});

	print("WriteFile ./" .. dir .. "/" .. name .. ".xml");
	local file = io.open("./" .. dir .. "/" .. name .. ".xml", "w");

	file:write(string.format("%c%c%c", 0xEF, 0xBB, 0xBF));
	file:write(string.format("<EquipTemplate> <!-- 装备模版 -->\n"));
	for index, row in ipairs(matrix)
	do
		row.Color = translate_color(row.Color);

		file:write(string.format("  <Equip id=\"%s\">\n", row.id));
		file:write(string.format("    <Name>%s</Name>  <!-- 名称 -->\n", row.Name));
		file:write(string.format("    <Image>resource/icon/equip/equip_%s.png</Image>  <!-- 图标 -->\n", row.Image));
		file:write(string.format("    <Type>%s</Type> <!-- 类型 -->\n", row.Type));
		file:write(string.format("    <Color>%d</Color> <!-- 品质 -->\n", row.Color));
		WriteLine(file, row, "MinLevel", "装备需求等级", "    ");
		WriteLine(file, row, "MeleeAttack", "近攻", "    ");
		WriteLine(file, row, "RangeAttack", "远攻", "    ");
		WriteLine(file, row, "MeleeDefense", "近防", "    ");
		WriteLine(file, row, "RangeDefense", "远防", "    ");
		WriteLine(file, row, "Soldier", "兵力", "    ");
		file:write(string.format("    <CostRate>%s</CostRate> <!-- 升级消耗系数 -->\n", row.CostRate));
		file:write(string.format("    <PriceBuy>%s</PriceBuy> <!-- 购买价格 -->\n", row.Price));
		file:write(string.format("    <PriceSale>%s</PriceSale> <!-- 出售价格 -->\n", row.Price));
		file:write(string.format("    <Desc>%s</Desc> <!-- 描述 -->\n", row.Desc));
		file:write(string.format("  </Equip>\n"));
	end
	file:write(string.format("</EquipTemplate>\n"));
	file:close()
	print("");

end

function GenerateGemTemplate()
	print("GenerateGemTemplate");

	local dir="equip";
	local name="gem_template"

	local matrix=parseFile("./" .. dir .. "/" .. name .. ".txt",
			{"id", "Name", "Image", "Color", "Type", "Level",
			"MeleeAttack", "RangeAttack", "MeleeDefense", "RangeDefense",
			"Soldier", "Price"});

	print("WriteFile ./" .. dir .. "/" .. name .. ".xml");
	local file = io.open("./" .. dir .. "/" .. name .. ".xml", "w");

	file:write(string.format("%c%c%c", 0xEF, 0xBB, 0xBF));
	file:write(string.format("<GemTemplate> <!-- 宝石模版 -->\n"));
	for index, row in ipairs(matrix)
	do
		row.Color = translate_color(row.Color);

		file:write(string.format("  <Gem id=\"%s\">\n", row.id));
		file:write(string.format("    <Name>%s</Name>  <!-- 名称 -->\n", row.Name));
		file:write(string.format("    <Image>resource/icon/gem/gem_%s.png</Image>  <!-- 图标 -->\n", row.Image));
		file:write(string.format("    <Type>%s</Type> <!-- 类型 -->\n", row.Type));
		file:write(string.format("    <Color>%d</Color> <!-- 品质 -->\n", row.Color));
		WriteLine(file, row, "MeleeAttack", "近攻", "    ");
		WriteLine(file, row, "RangeAttack", "远攻", "    ");
		WriteLine(file, row, "MeleeDefense", "近防", "    ");
		WriteLine(file, row, "RangeDefense", "远防", "    ");
		WriteLine(file, row, "Soldier", "兵力", "    ");
		file:write(string.format("    <PriceBuy>%s</PriceBuy> <!-- 购买价格 -->\n", row.Price));
		file:write(string.format("    <PriceSale>%s</PriceSale> <!-- 出售价格 -->\n", row.Price));
		file:write(string.format("  </Gem>\n"));
	end
	file:write(string.format("</GemTemplate>\n"));
	file:close()
	print("");

end

function GenerateEquipUpgrade()
	print("GenerateEquipUpgrade");

	local dir="equip";
	local name="upgrade"

	local matrix=parseFile("./" .. dir .. "/" .. name .. ".txt",
			{"level", "Cost"});

	print("WriteFile ./" .. dir .. "/" .. name .. ".xml");
	local file = io.open("./" .. dir .. "/" .. name .. ".xml", "w");

	file:write(string.format("%c%c%c", 0xEF, 0xBB, 0xBF));
	file:write(string.format("<EquipUpgrade> <!-- 装备升级基础表 -->\n"));
	for _, row in ipairs(matrix)
	do
		file:write(string.format("  <Level level=\"%s\">\n", row.level));
		file:write(string.format("    <Cost>%s</Cost> <!-- 消耗铜币数量 -->\n", row.Cost));
		file:write(string.format("  </Level>\n"));
	end
	file:write(string.format("</EquipUpgrade>\n"));
	file:close()
	print("");

end

function GenerateHeroTemplate()
	print("GenerateHeroTemplate");

	local dir="hero";
	local name="template"

	local matrix=parseFile("./" .. dir .. "/" .. name .. ".txt",
			{"id", "Name", "GetType", "GetValue", "Image", "Color", "Country",
				"Leadership", "Force", "Intelligence",
				"Bu", "Gong", "Qiang", "Qi", "Tou",
				"Skill", "Hit", "Dodge", "Block", "v1", "Crit", "v2", "Desc"});

	print("WriteFile ./" .. dir .. "/" .. name .. ".xml");
	local file = io.open("./" .. dir .. "/" .. name .. ".xml", "w");

	file:write(string.format("%c%c%c", 0xEF, 0xBB, 0xBF));
	file:write(string.format("<HeroTemplate> <!-- 武将模版 -->\n"));
	for _,row in ipairs(matrix)
	do
		row.Color = translate_color(row.Color);
		file:write(string.format("  <Hero id=\"%s\">\n", row.id));
		file:write(string.format("    <Name>%s</Name>  <!-- 名字 -->\n", row.Name));
		file:write(string.format("    <Images> <!-- 图标 -->\n"));
		file:write(string.format("      <Image name=\"head\" url=\"./resource/icon/zm_head_%s.png\"/>\n", row.Image));
		file:write(string.format("      <Image name=\"headSmall\" url=\"./resource/icon/xl_head_%s.png\"/>\n", row.Image));
		file:write(string.format("	    <Image name=\"headBackground\" url=\"./resource/icon/wj_head_%s.png\"/>\n", row.Image));
		file:write(string.format("    </Images>\n"));
		file:write(string.format("    <Get type = \"%s\">%s</Get>\n", row.GetType, row.GetValue));
		file:write(string.format("    <Color>%s</Color> <!-- 品质 -->\n", row.Color));
		file:write(string.format("    <Country>%s</Country> <!-- 国家 -->\n", row.Country));
		file:write(string.format("    <Leadership>%s</Leadership> <!-- 统帅 -->\n", row.Leadership));
		file:write(string.format("    <Force>%s</Force> <!-- 武力 -->\n", row.Force));
		file:write(string.format("    <Intelligence>%s</Intelligence> <!-- 智力 -->\n", row.Intelligence));
		file:write(string.format("    <Skills> <!-- 技能 -->\n"));
		file:write(string.format("	 <Skill>%s</Skill>\n", row.Skill));
		file:write(string.format("    </Skills>\n"));
		file:write(string.format("    <Adapts> <!-- 适性 -->\n"));
		if not (row.Bu == "0" ) then
		file:write(string.format("      <Adapt id=\"710100\">%s</Adapt>\n", row.Bu));
		end
		if not (row.Gong == "0" ) then
		file:write(string.format("      <Adapt id=\"710200\">%s</Adapt>\n", row.Gong));
		end
		if not (row.Qiang == "0" ) then
		file:write(string.format("      <Adapt id=\"710300\">%s</Adapt>\n", row.Qiang));
		end
		if not (row.Qi == "0" ) then
		file:write(string.format("      <Adapt id=\"710400\">%s</Adapt>\n", row.Qi));
		end
		if not (row.Tou == "0" ) then
		file:write(string.format("      <Adapt id=\"710500\">%s</Adapt>\n", row.Tou));
		end
		file:write(string.format("    </Adapts>\n"));

		-- TODO: remove
		WriteLine(file, row, "Hit", "命中", "    ");
		WriteLine(file, row, "Dodge", "闪躲", "    ");
		WriteLine(file, row, "Block", "格挡", "    ");
		WriteLine(file, row, "Crit", "暴击", "    ");

		if row.Desc == nil or row.Desc == "" then
			row.Desc = "这是三国非著名武将" .. row.Name;
		end
		file:write(string.format("    <Desc>%s</Desc> <!-- 描述 -->\n", row.Desc));
		file:write(string.format("  </Hero>\n"));
	end
	file:write(string.format("</HeroTemplate>\n"));

	file:close()
	print("");

end

function GenerateHeroTitle()
	print("GenerateHeroTitle");

	local dir="hero";
	local name="title"

	local matrix= parseFile("./" .. dir .. "/" .. name .. ".txt",
			{"id", "Name", "Image", "Level", "KingTitle", "Soldier"});

	print("WriteFile ./" .. dir .. "/" .. name .. ".xml");
	local file = io.open("./" .. dir .. "/" .. name .. ".xml", "w");

	file:write(string.format("%c%c%c", 0xEF, 0xBB, 0xBF));
	file:write(string.format("<HeroTitles> <!-- 武将官职 -->\n"));
	for _, row in ipairs(matrix)
	do
		file:write(string.format("  <Title id=\"%s\">\n", row.id));
		file:write(string.format("    <Name>%s</Name> <!-- 名字 -->\n", row.Name));
		file:write(string.format("    <Image>resource/icon/hero/title_%s.png</Image> <!-- 图标 -->\n", row.Image));
		file:write(string.format("    <Condition> <!-- 依赖条件-->\n"));
		WriteLine(file, row, "Level", "等级", "      ");
		WriteLine(file, row, "KingTitle", "君主官职", "      ");
		file:write(string.format("    </Condition>\n"));
		file:write(string.format("    <Soldier>%s</Soldier> <!-- 兵力 -->\n", row.Soldier));
		file:write(string.format("  </Title>\n"));
	end
	file:write(string.format("</HeroTitles>\n"));

	file:close()
	print("");
end

function GenerateHeroUpgrade()
	print("GenerateHeroUpgrade");

	local dir="hero";
	local name="upgrade"

	local matrix= parseFile("./" .. dir .. "/" .. name .. ".txt",
			{"level", "Exp", "MaxGrow"});

	print("WriteFile ./" .. dir .. "/" .. name .. ".xml");
	local file = io.open("./" .. dir .. "/" .. name .. ".xml", "w");

	file:write(string.format("%c%c%c", 0xEF, 0xBB, 0xBF));
	file:write(string.format("<HeroUpgrade> <!-- 武将升级表 -->\n"));
	for _,row in ipairs(matrix)
	do
		file:write(string.format("  <Level level=\"%s\">\n", row.level));
		file:write(string.format("    <Condition>\n"));
		file:write(string.format("      <Exp>%s</Exp> <!-- 经验 -->\n", row.Exp));
		file:write(string.format("    </Condition>\n"));
		file:write(string.format("    <MaxGrow>%s</MaxGrow> <!-- 最大潜能 -->\n", row.MaxGrow));
		file:write(string.format("  </Level>\n"));
	end
	file:write(string.format("</HeroUpgrade>\n"));
	file:close()
	print("");
end

function GenerateKingTitle()
	print("GenerateKingTitle");

	local dir="king";
	local name="title"

	local matrix= parseFile("./" .. dir .. "/" .. name .. ".txt",
			{"id", "Name", "Image", "Level", "Prestige", "Salary", "Assistant", "Hurt"});

	print("WriteFile ./" .. dir .. "/" .. name .. ".xml");
	local file = io.open("./" .. dir .. "/" .. name .. ".xml", "w");

	file:write(string.format("%c%c%c", 0xEF, 0xBB, 0xBF));
	file:write(string.format("<KingTitles> <!-- 君主晋升表 -->\n"));
	for _,row in ipairs(matrix)
	do
		file:write(string.format("  <Title id=\"%s\">\n", row.id));
		file:write(string.format("    <Name>%s</Name> <!-- 名字 -->\n", row.Name));
		file:write(string.format("    <Image>resource/icon/king/title_%s.png</Image> <!-- 图标 -->\n", row.Image));
		file:write(string.format("    <Condition> <!-- 依赖条件-->\n"));
		WriteLine(file, row, "Level", "等级", "      ");
		WriteLine(file, row, "Prestige", "威望", "      ");
		file:write(string.format("    </Condition>\n"));
		file:write(string.format("    <Salary>%s</Salary> <!-- 俸禄 -->\n", row.Salary));
		WriteLine(file, row, "Assistant", "属臣数量", "      ");
		WriteLine(file, row, "Hurt", "伤害加成%", "      ");
		file:write(string.format("  </Title>\n"));
	end
	file:write(string.format("</KingTitles>\n"));

	file:close()
	print("");
end

function GenerateKingUpgrade()
	print("GenerateKingUpgrade");

	local dir="king";
	local name="upgrade"

	local matrix= parseFile("./" .. dir .. "/" .. name .. ".txt",
			{"Level", "Exp", "Strategy", "Soldier"});

	print("WriteFile ./" .. dir .. "/" .. name .. ".xml");
	local file = io.open("./" .. dir .. "/" .. name .. ".xml", "w");

	file:write(string.format("%c%c%c", 0xEF, 0xBB, 0xBF));
	file:write(string.format("<KingUpgrade> <!-- 君主升级表 -->\n"));
	for _,row in ipairs(matrix)
	do
		file:write(string.format("  <Level level =\"%s\">\n", row.Level));
		file:write(string.format("    <Condition> <!-- 依赖条件-->\n"));
		file:write(string.format("      <Exp>%s</Exp> <!-- 经验 -->\n", row.Exp));
		file:write(string.format("    </Condition>\n"));
		file:write(string.format("    <Strategy>%s</Strategy> <!-- 策略值 -->\n", row.Strategy));
		file:write(string.format("    <Soldier>%s</Soldier> <!-- 统兵上限 -->\n", row.Soldier));
		file:write(string.format("  </Level>\n"));
	end
	file:write(string.format("</KingUpgrade>\n"));

	file:close()
	print("");
end

function GenerateTechnology()
	print("GenerateTechnology");

	local dir="technology";
	local name="technology"

	local matrix= parseFile("./" .. dir .. "/" .. name .. ".txt",
			{"id", "Name", "Image", "Type", "TechBuildingLevel", 
			"UpgradeBuildingType", "UpgradeBuildingLevel", "CostRate", "Value", "Desc", "MaxLevel"});

	print("WriteFile ./" .. dir .. "/" .. name .. ".xml");
	local file = io.open("./" .. dir .. "/" .. name .. ".xml", "w");

	file:write(string.format("%c%c%c", 0xEF, 0xBB, 0xBF));
	file:write(string.format("<Technolgys> <!-- 科技表 -->\n"));
	for _, row in ipairs(matrix)
	do
		file:write(string.format("  <Technology id=\"%s\">\n", row.id));
		file:write(string.format("    <Name>%s</Name> <!-- 名字 -->\n", row.Name));
		file:write(string.format("    <Image>resource/icon/technology/%s.png</Image> <!-- 图标 -->\n", row.Image));
		file:write(string.format("    <Type>%s</Type> <!-- 类型 -->\n", row.Type));
		file:write(string.format("    <MaxLevel>%s</MaxLevel> <!-- 最大等级 -->\n", row.MaxLevel));
		file:write(string.format("    <CostRate>%s</CostRate> <!-- 消耗比率 -->\n", row.CostRate));
		file:write(string.format("    <TechBuildingLevel>%s</TechBuildingLevel> <!-- 开放书院等级 -->\n", row.TechBuildingLevel));
		file:write(string.format("    <Upgrade>\n"));
		file:write(string.format("      <BuildingType>%s</BuildingType>  <!-- 升级依赖建筑 -->\n", row.UpgradeBuildingType));
		file:write(string.format("      <BuildingLevel>%s</BuildingLevel><!-- 每升一级依赖建筑等级 -->\n", row.UpgradeBuildingLevel));
		file:write(string.format("    </Upgrade>\n"));
		WriteLine(file, row, "Value", "功能数值", "    ");
		file:write(string.format("    <Desc>%s</Desc> <!-- 描述 -->\n", row.Desc));
		file:write(string.format("  </Technology>\n"));
	end
	file:write(string.format("</Technolgys>\n"));
	file:close()
	print("");
end

function GenerateTechnologyUpgrade()
	print("GenerateTechnologyUpgrade");

	local dir="technology";
	local name="upgrade"

	local matrix= parseFile("./" .. dir .. "/" .. name .. ".txt",
			{"level", "Zhan", "Bing", "Zheng"});

	print("WriteFile ./" .. dir .. "/" .. name .. ".xml");
	local file = io.open("./" .. dir .. "/" .. name .. ".xml", "w");

	file:write(string.format("%c%c%c", 0xEF, 0xBB, 0xBF));
	file:write(string.format("<TechnolgyUpgrade> <!-- 科技升级消耗表 -->\n"));
	for _,row in ipairs(matrix)
	do
	file:write(string.format("  <Level level=\"%s\">\n", row.level));
	file:write(string.format("    <Cost type=\"520100\">%s</Cost>  <!-- 战法消耗 -->\n", row.Zhan));
	file:write(string.format("    <Cost type=\"520200\">%s</Cost>  <!-- 兵法消耗 -->\n", row.Bing));
	file:write(string.format("    <Cost type=\"520300\">%s</Cost>  <!-- 政法消耗 -->\n", row.Zheng));
	file:write(string.format("  </Level>\n"));
	end
	file:write(string.format("</TechnolgyUpgrade>\n"));
	file:close()
	print("");
end

function GenerateSoldierProperty()
	print("GenerateSoldierProperty");

	local dir="soldier";
	local name="property"

	local matrix= parseFile("./" .. dir .. "/" .. name .. ".txt",
			{"id", "type", "level", "Name", "Image",
			"MeleeAttack", "RangeAttack", "MeleeDefense", "RangeDefense",
			"Health", "Move", "Range", "Speed",
			"Hit", "Dodge", "Block", "v1", "Crit", "v2", "Skill1", "Skill2"});

	print("WriteFile ./" .. dir .. "/" .. name .. ".xml");
	local file = io.open("./" .. dir .. "/" .. name .. ".xml", "w");

	local soldiers = {};
	for _, row in ipairs(matrix)
	do
		local t = row.type; -- + 0;
		if soldiers[t] == nil then
			soldiers[t] = {};
		end

		local l =  row.level + 0;
		soldiers[t][l]= {};
		soldiers[t][l] = row;
	end

	soldier_desc = {};
	soldier_desc[710100] = {"步", 520201};
	soldier_desc[710200] = {"弓", 520202};
	soldier_desc[710300] = {"枪", 520203};
	soldier_desc[710400] = {"骑", 520204};
	soldier_desc[710500] = {"器", 520205};

	file:write(string.format("%c%c%c", 0xEF, 0xBB, 0xBF));
	file:write("<Soldiers>\n");
	for t,ls in pairs(soldiers)
	do
		local st = t + 0;
		file:write(string.format("  <Soldier type=\"%s\" name=\"%s\" tech=\"%d\">\n", t, soldier_desc[st][1], soldier_desc[st][2]));
		for l,row in pairs(ls)
		do
			file:write(string.format("    <Level level=\"%s\">\n", row.level));
			file:write(string.format("      <Name>%s</Name> <!-- 名称 -->\n", row.Name));
			file:write(string.format("      <MeleeAttack>%s</MeleeAttack> <!-- 近攻 -->\n", row.MeleeAttack));
			file:write(string.format("      <RangeAttack>%s</RangeAttack> <!-- 远攻 -->\n", row.RangeAttack));
			file:write(string.format("      <MeleeDefense>%s</MeleeDefense> <!-- 近防 -->\n", row.MeleeDefense));
			file:write(string.format("      <RangeDefense>%s</RangeDefense> <!-- 远防 -->\n", row.RangeDefense));
			file:write(string.format("      <Health>%s</Health> <!-- 生命 -->\n", row.Health));
			file:write(string.format("      <Move>%s</Move> <!-- 移动格数 -->\n", row.Move));
			file:write(string.format("      <Range>1</Range> <!-- 攻击范围 -->\n", row.Range));
			file:write(string.format("      <Speed>50</Speed> <!-- 速度 -->\n", row.Speed));
			file:write(string.format("      <Hit>90</Hit> <!-- 命中 -->\n", row.Hit));
			file:write(string.format("      <Dodge>0</Dodge> <!-- 闪避 -->\n", row.Dodge));
			file:write(string.format("      <Block>20</Block> <!-- 格挡 -->\n", row.Block));
			file:write(string.format("      <Crit>5</Crit> <!-- 暴击 -->\n", row.Crit));
			file:write(string.format("      <Skills> <!-- 技能 -->\n"));
			if not (row.Skill1 == "0") then
			file:write(string.format("        <id>%s</id>\n", row.Skill1));
			end
			if not (row.Skill2 == "0") then
			file:write(string.format("        <id>%s</id>\n", row.Skill2));
			end
			file:write(string.format("      </Skills>\n"));
			file:write(string.format("      <Images> <!-- 图标 -->\n"));
			file:write(string.format("        <Small>./resource/soldier/%s_small.png</Small>\n", row.Image));
			file:write(string.format("        <Large>./resource/soldier/%s_large.png</Large>\n", row.Image));
			file:write(string.format("      </Images>\n"));
			file:write(string.format("    </Level>\n"));
		end
		file:write(string.format("  </Soldier>\n"));
	end
	file:write("</Soldiers>\n");
	file:close()
	print("");
end

function GenerateSoldierSkill()
	print("GenerateSoldierSkill");

	local dir="soldier";
	local name="skill"

	local matrix= parseFile("./" .. dir .. "/" .. name .. ".txt",
		{"id", "SoldierType", "Name", "Image", "TargetType", "HurtIncrease", "HurtReduce", "Desc"});
		

	print("WriteFile ./" .. dir .. "/" .. name .. ".xml");
	local file = io.open("./" .. dir .. "/" .. name .. ".xml", "w");

	file:write(string.format("%c%c%c", 0xEF, 0xBB, 0xBF));
	file:write("<SoldierSkills>\n");
	for _,row in ipairs(matrix)
	do
		file:write(string.format("  <Skill id = \"%s\">\n", row.id));
		file:write(string.format("    <Name>%s</Name> <!-- 名称 -->\n", row.Name));
		file:write(string.format("    <Image>resource/icon/soldier/skill_%s.png</Image> <!-- 图标 -->\n", row.Image));
		file:write(string.format("    <SoldierType>%s</SoldierType> <!-- 适用兵种 -->\n", row.SoldierType));
		if not (row.TargetType == "0") then
		file:write(string.format("    <TargetType>%s</TargetType> <!-- 目标兵种 -->\n", row.TargetType));
		end
		file:write(string.format("    <HurtIncrease>%s</HurtIncrease> <!-- 伤害增加 -->\n", row.HurtIncrease));
		file:write(string.format("    <HurtReduce>%s</HurtReduce> <!-- 伤害减少 -->\n", row.HurtReduce));
		file:write(string.format("    <Desc>%s</Desc> <!-- 描述 -->\n", row.Desc));
		file:write(string.format("  </Skill>\n"));
	end
	file:write("</SoldierSkills>\n");

	file:close()
	print("");
end

function GenerateSoldierHurtMatrix()
	print("GenerateSoldierHurtMatrix");

	local dir="soldier";
	local name="hurt_matrix"

	local matrix= parseFile("./" .. dir .. "/" .. name .. ".txt");

	local keys = matrix[1];

	print("WriteFile ./" .. dir .. "/" .. name .. ".xml");
	local file = io.open("./" .. dir .. "/" .. name .. ".xml", "w");

	file:write(string.format("%c%c%c", 0xEF, 0xBB, 0xBF));
	file:write("<SoldierHurtMatrix>\n");
	for line,row in ipairs(matrix)
	do
		if line > 1 then
			for f, v in ipairs(row) 
			do
				if f == 1 then
					file:write(string.format("  <Soldier type=\"%s\">\n", v));
				else 
					if not (v == "0") then
						file:write(string.format("    <Target type=\"%s\">%s</Target>\n", keys[f], v));
					end
				end
			end
			file:write(string.format("  </Soldier>\n"));
		end
	end
	file:write("</SoldierHurtMatrix>\n");

	file:close()
	print("");
end

function GenerateSoldierHitMatrix()
	print("GenerateSoldierHitMatrix");

	local dir="soldier";
	local name="hit_matrix"

	local matrix= parseFile("./" .. dir .. "/" .. name .. ".txt");

	local keys = matrix[1];

	print("WriteFile ./" .. dir .. "/" .. name .. ".xml");
	local file = io.open("./" .. dir .. "/" .. name .. ".xml", "w");

	file:write(string.format("%c%c%c", 0xEF, 0xBB, 0xBF));
	file:write("<SoldierHitMatrix>\n");
	for line,row in ipairs(matrix)
	do
		if line > 1 then
			for f, v in ipairs(row) 
			do
				if f == 1 then
					file:write(string.format("  <Soldier type=\"%s\">\n", v));
				else 
					if not (v == "0") then
						file:write(string.format("    <Target type=\"%s\">%s</Target>\n", keys[f], v));
					end
				end
			end
			file:write(string.format("  </Soldier>\n"));
		end
	end
	file:write("</SoldierHitMatrix>\n");

	file:close()
	print("");
end

function GenerateSoldierBlockMatrix()
	print("GenerateSoldierBlockMatrix");

	local dir="soldier";
	local name="block_matrix"

	local matrix= parseFile("./" .. dir .. "/" .. name .. ".txt");

	local keys = matrix[1];

	print("WriteFile ./" .. dir .. "/" .. name .. ".xml");
	local file = io.open("./" .. dir .. "/" .. name .. ".xml", "w");

	file:write(string.format("%c%c%c", 0xEF, 0xBB, 0xBF));
	file:write("<SoldierBlockMatrix>\n");
	for line,row in ipairs(matrix)
	do
		if line > 1 then
			for f, v in ipairs(row) 
			do
				if f == 1 then
					file:write(string.format("  <Soldier type=\"%s\">\n", v));
				else 
					if not (v == "0") then
						file:write(string.format("    <Target type=\"%s\">%s</Target>\n", keys[f], v));
					end
				end
			end
			file:write(string.format("  </Soldier>\n"));
		end
	end
	file:write("</SoldierBlockMatrix>\n");

	file:close()
	print("");
end

function GenerateSoldierCritMatrix()
	print("GenerateSoldierCirtMatrix");

	local dir="soldier";
	local name="crit_matrix"

	local matrix= parseFile("./" .. dir .. "/" .. name .. ".txt");

	local keys = matrix[1];

	print("WriteFile ./" .. dir .. "/" .. name .. ".xml");
	local file = io.open("./" .. dir .. "/" .. name .. ".xml", "w");

	file:write(string.format("%c%c%c", 0xEF, 0xBB, 0xBF));
	file:write("<SoldierCirtMatrix>\n");
	for line,row in ipairs(matrix)
	do
		if line > 1 then
			for f, v in ipairs(row) 
			do
				if f == 1 then
					file:write(string.format("  <Soldier type=\"%s\">\n", v));
				else 
					if not (v == "0") then
						file:write(string.format("    <Target type=\"%s\">%s</Target>\n", keys[f], v));
					end
				end
			end
			file:write(string.format("  </Soldier>\n"));
		end
	end
	file:write("</SoldierCirtMatrix>\n");

	file:close()
	print("");
end


function GenerateStoryArmy()
	print("GenerateStoryArmy");

	local dir="story";
	local name="army"

	local matrix= parseFile("./" .. dir .. "/" .. name .. ".txt",
		{"id",  "pos", "Name", "Level", "Image", "meleeAttack", "rangeAttack", "meleeDefense", "rangeDefense",
		"soldierType", "soldierLevel", "Adapt", "Skill", "Hit", "Dodge", "Block", "v1", "Crit", "v2", 
		"HurtIncBu", "HurtIncGong", "HurtIncQiang", "HurtIncQi", "HurtIncTou",
		"HurtDecBu",  "HurtDecGong",  "HurtDecQiang",  "HurtDecQi", "HurtDecTou"});

	print("WriteFile ./" .. dir .. "/" .. name .. ".xml");
	local file = io.open("./" .. dir .. "/" .. name .. ".xml", "w");

	local troops = {};
	for k,v in pairs(matrix) do
		local id = v.id + 0;
		local pos = v.pos + 0;

		if troops[id] == nil then
			troops[id] = {};
		end

		troops[id][pos] = v;
	end

	file:write(string.format("%c%c%c", 0xEF, 0xBB, 0xBF));
	file:write("<StoryArmyGroups> <!-- 战斗部队配置 -->\n");
	for tid,armys in pairs(troops)
	do
		file:write(string.format("  <ArmyGroup id=\"%s\"> <!-- 部队 -->\n", tid))
		for aid, army in pairs(armys) do
			file:write(string.format("    <Army pos=\"%s\">\n", aid));
			file:write(string.format("      <Hero> <!-- 武将 -->\n"))
			file:write(string.format("        <Name>%s</Name> <!-- 名字-->\n", army.Name));
			file:write(string.format("        <Level>%s</Level> <!-- 等级 -->\n", army.Level));
			file:write(string.format("        <Image>%s</Image> <!-- 图像 -->\n", army.Image));
			file:write(string.format("        <meleeAttack>%s</meleeAttack> <!-- 近攻 -->\n", army.meleeAttack));
			file:write(string.format("        <rangeAttack>%s</rangeAttack> <!-- 远攻 -->\n", army.rangeAttack));
			file:write(string.format("        <meleeDefense>%s</meleeDefense> <!-- 近防 -->\n", army.meleeDefense));
			file:write(string.format("        <rangeDefense>%s</rangeDefense> <!-- 远防 -->\n", army.rangeDefense));
			file:write(string.format("        <Adapt>%s</Adapt> <!-- 适性 -->\n", army.Adapt));
			file:write(string.format("        <Skill>%s</Skill> <!-- 技能 -->\n", army.Skill));
			file:write(string.format("      </Hero>\n"));
			file:write(string.format("      <Soldier> <!-- 兵 -->\n"));
			file:write(string.format("        <Type>%s</Type> <!-- 类型 -->\n", army.soldierType));
			file:write(string.format("        <Level>%s</Level> <!-- 等级 -->\n", army.soldierLevel));
			file:write(string.format("      </Soldier>\n"));
			-- [[ TODO: remove
			file:write(string.format("      <Hit>%s</Hit> <!-- 额外命中 -->\n", army.Hit));
			file:write(string.format("      <Dodge>%s</Dodge> <!-- 额外闪避 -->\n", army.Dodge));
			file:write(string.format("      <Block>%s</Block> <!-- 额外格挡 -->\n", army.Block));
			file:write(string.format("      <Crit>%s</Crit> <!-- 额外暴击 -->\n", army.Crit));
			file:write(string.format("      <Fixs> <!-- 针对不同兵种伤害增减 -->\n"));
			file:write(string.format("        <Fix type=\"%d\"> \n", 710100));
			file:write(string.format("          <HurtIncerase>%s</HurtIncerase>\n", army.HurtIncBu));
			file:write(string.format("          <HurtReduce>%s</HurtReduce>\n",     army.HurtDecBu));
			file:write(string.format("        </Fix>\n"));
			file:write(string.format("        <Fix type=\"%d\">\n", 710200));
			file:write(string.format("          <HurtIncerase>%s</HurtIncerase>\n", army.HurtIncGong));
			file:write(string.format("          <HurtReduce>%s</HurtReduce>\n",     army.HurtDecGong));
			file:write(string.format("        </Fix>\n"));
			file:write(string.format("        <Fix type=\"%d\">\n", 710300));
			file:write(string.format("          <HurtIncerase>%s</HurtIncerase>\n", army.HurtIncQiang));
			file:write(string.format("          <HurtReduce>%s</HurtReduce>\n",     army.HurtDecQiang));
			file:write(string.format("        </Fix>\n"));
			file:write(string.format("        <Fix type=\"%d\">\n", 710400));
			file:write(string.format("          <HurtIncerase>%s</HurtIncerase>\n", army.HurtIncQi));
			file:write(string.format("          <HurtReduce>%s</HurtReduce>\n",     army.HurtDecQi));
			file:write(string.format("        </Fix>\n"));
			file:write(string.format("        <Fix type=\"%d\">\n", 710500));
			file:write(string.format("          <HurtIncerase>%s</HurtIncerase>\n", army.HurtIncTou));
			file:write(string.format("          <HurtReduce>%s</HurtReduce>\n",     army.HurtDecTou));
			file:write(string.format("        </Fix>\n"));
			file:write(string.format("      </Fixs>\n"));
			-- ]]
			file:write(string.format("    </Army>\n"));
		end
		file:write("  </ArmyGroup>\n")
	end
	file:write("</StoryArmyGroups>\n");

	file:close()
	print("");
end

function GenerateStoryBattle()
	print("GenerateStoryBattle");

	local dir="story";
	local name="battle"

	local matrix= parseFile("./" .. dir .. "/" .. name .. ".txt",
			{"battleID", "fightID", "ArmyGroup", "Name", "SoldierCount", 
			"Depend1", "Depend2", "Exclude", "Image", "Level", "Type", "Limit",
			"Exp", "Prestige", "EquipID", "EquipRate", "HeroID", "HeroRate",
			"CityDefPos", "CityDefUse", "CityDefHP", "Desc"});

	print("WriteFile ./" .. dir .. "/" .. name .. ".xml");
	local file = io.open("./" .. dir .. "/" .. name .. ".xml", "w");

	local battles = {};
	for k,v in pairs(matrix) do
		local bid = v.battleID + 0;
		local fid = v.fightID + 0;

		if battles[bid] == nil then
			battles[bid] = {};
		end
		battles[bid][fid] = v;
	end

	file:write(string.format("%c%c%c", 0xEF, 0xBB, 0xBF));
	file:write("<StoryBattles> <!-- 剧情配置 -->\n");
	for bid,battle in pairs(battles)
	do
		file:write(string.format("  <Battle id=\"%d\"> <!-- 战役 -->\n", bid))
		for fid, fight in pairs(battle) do
			file:write(string.format("    <Fight id=\"%d\"> <!-- 战斗 -->\n", fid));
			file:write(string.format("      <ArmyGroup>%s</ArmyGroup> <!-- 部队 -->\n", fight.ArmyGroup));
			file:write(string.format("      <Name>%s</Name>   <!-- 名字 -->\n", fight.Name));
			file:write(string.format("      <Images>\n"));
			file:write(string.format("        <Army>resource/battle/army_%s.png</Army> <!-- 地图上部队图片 -->\n", fight.Image));
			file:write(string.format("        <Head>resource/battle/head_%s.png</Head> <!-- 头像图片 -->\n", fight.Image));
			file:write(string.format("      </Images>\n"));
			file:write(string.format("      <Type>%s</Type>   <!-- 类型 -->\n", fight.Type));
			file:write(string.format("      <Level>%s</Level> <!-- 等级 -->\n", fight.Level));
			file:write(string.format("      <SoldierCount>%s</SoldierCount> <!-- 士兵数量 -->\n", fight.SoldierCount));
			file:write(string.format("      <Depends>\n"));
			if (fight.Depend1 + 0) > 0 then
			file:write(string.format("        <Depend>%s</Depend> <!-- 依赖战斗ID -->\n", fight.Depend1));
			end
			if (fight.Depend2 + 0) > 0 then
			file:write(string.format("        <Depend>%s</Depend>\n", fight.Depend2));
			end
			file:write(string.format("      </Depends>\n"));
			if (fight.Exclude  + 0) > 0 then
			file:write(string.format("      <Exclude>%s</Exclude> <!-- 互斥战斗ID -->\n", fight.Exclude));
			end
			file:write(string.format("      <Limit>%s</Limit>     <!-- 每天战斗次数 -->\n", fight.Limit));
			file:write(string.format("      <Reward> <!-- 奖励 -->\n"));
			WriteLine(file, fight, "Exp", "君主经验", "        ")
			--file:write(string.format("        <Exp>%s</Exp>      <!-- 君主经验 -->\n", fight.Exp));
			WriteLine(file, fight, "Prestige", "军功", "        ")
			--file:write(string.format("        <Prestige>%s</Prestige> <!-- 军功 -->\n", fight.Prestige));
			if (fight.EquipID + 0) > 0 then
			file:write(string.format("        <EquipID>%s</EquipID> <!-- 装备 -->\n", fight.EquipID));
			file:write(string.format("        <EquipRate>%s</EquipRate> <!-- 装备掉落几率 -->\n", fight.EquipRate));
			end
			if (fight.HeroID + 0) > 0 then
			file:write(string.format("        <HeroID>%s</HeroID> <!-- 武将 -->\n", fight.HeroID));
			file:write(string.format("        <HeroRate>%s</HeroRate> <!-- 武将掉落几率 -->\n", fight.HeroRate));
			end
			file:write(string.format("      </Reward>\n"));

			-- [[ TODO: remove
			if (fight.CityDefUse + 0) > 0 then
			file:write(string.format("      <CityDefense> <!-- 城防 -->\n"));
			file:write(string.format("        <Position>%s</Position> <!-- 城防位置 11 左  12 右-->\n", fight.CityDefPos));
			file:write(string.format("        <Use>%s</Use> <!-- 每次攻击城防使用数量 -->\n", fight.CityDefUse));
			file:write(string.format("        <HP>%s</HP> <!-- 城防耐久 -->\n", fight.CityDefHP));
			file:write(string.format("      </CityDefense>\n"));
			end
			-- ]]
			file:write(string.format("      <Desc>%s</Desc> <!-- 剧情描述 -->\n", fight.Desc));
			file:write(string.format("    </Fight>\n"));
		end
		file:write("  </Battle>\n")
	end
	file:write("</StoryBattles>\n");

	file:close()
	print("");
end

function GenerateStoryMap()
	print("GenerateStoryMap");

	local dir="story";
	local name="map"

	local matrix= parseFile("./" .. dir .. "/" .. name .. ".txt",
		{"mapID", "battleID", "Name", 
		"DependBattle1", "DependBattle2", "ExcludeBattle", "DependFight",
		"FinalItem", "FinalFight", "TimeLine"});

	print("WriteFile ./" .. dir .. "/" .. name .. ".xml");
	local file = io.open("./" .. dir .. "/" .. name .. ".xml", "w");

	local maps = {};
	for k,v in pairs(matrix) do
		local mid = v.mapID + 0;
		local bid = v.battleID + 0;

		if maps[mid] == nil then
			maps[mid] = {};
		end
		maps[mid][bid] = v;
	end

	file:write(string.format("%c%c%c", 0xEF, 0xBB, 0xBF));
	file:write("<StoryMaps> <!-- 剧情配置 -->\n");
	for mid,map in pairs(maps)
	do
		file:write(string.format("  <Map id=\"%d\"> <!-- 地图 -->\n", mid))
		for bid, battle in pairs(map) do
			file:write(string.format("    <Battle id=\"%d\"> <!-- 战斗 -->\n", bid));
			file:write(string.format("      <Name>%s</Name>   <!-- 名字 -->\n", battle.Name));
			file:write(string.format("      <Depends>\n"));
			if (battle.DependBattle1 + 0) > 0 then
			file:write(string.format("        <Battle>%s</Battle> <!-- 依赖战役ID -->\n", battle.DependBattle1));
			end
			if (battle.DependBattle2 + 0) > 0 then
			file:write(string.format("        <Battle>%s</Battle> <!-- 依赖战役ID -->\n", battle.DependBattle2));
			end
			if (battle.DependFight + 0) > 0 then
			file:write(string.format("        <Fight>%s</Fight> <!-- 依赖战斗ID -->\n", battle.DependFight));
			end
			file:write(string.format("      </Depends>\n"));
			if (battle.ExcludeBattle + 0) > 0 then
			file:write(string.format("      <Exclude>%s</Exclude> <!-- 互斥战役ID -->\n", battle.ExcludeBattle));
			end
			if (battle.FinalItem + 0 ) > 0 then
			file:write(string.format("      <FinalItem>%s</FinalItem> <!-- 通关奖励道具-->\n", battle.FinalItem));
			end
			file:write(string.format("      <FinalFight>%s</FinalFight> <!-- 通关战斗 -->\n", battle.FinalFight));
			file:write(string.format("      <TimeLine>%s</TimeLine>   <!-- 时期 -->\n", battle.TimeLine));
			file:write(string.format("    </Battle>\n"));
		end
		file:write("  </Map>\n")
	end
	file:write("</StoryMaps>\n");

	file:close()
	print("");
end



GenerateBuilding()
GenerateBuildingUpgrade()
GenerateBuildingDefense()

GenerateCityUpgrade()

GenerateEquipTemplate()
GenerateGemTemplate()

GenerateEquipUpgrade()

GenerateHeroTemplate()
GenerateHeroTitle()
GenerateHeroUpgrade()

GenerateKingTitle()
GenerateKingUpgrade()

GenerateTechnology()
GenerateTechnologyUpgrade()

GenerateSoldierProperty()
GenerateSoldierSkill()
GenerateSoldierHurtMatrix()
GenerateSoldierHitMatrix()
GenerateSoldierBlockMatrix()
GenerateSoldierCritMatrix()

GenerateStoryArmy()
GenerateStoryBattle()
GenerateStoryMap()
