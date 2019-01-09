function parseLine(line)
	local row = {};
	local cur = "";
	for i = 1,string.len(line) 
	do
		local byte = string.sub(line, i, i);
		if byte == '\t' or byte == ' ' or byte == '\r' or byte == '\n' then
			row[table.maxn(row) + 1] = cur;
			cur = "";
		else
			cur = cur .. byte;
		end
	end

	if string.len(cur) > 0 then
		row[table.maxn(row) + 1] = cur;
	end
	return row;
end

function parseFile(name)
	print("read file " .. name);
	local file = io.open(name, "r");
	local matrix = {};

	local line=file:read("*l");
	local keys = parseLine(line);

	while true
	do
		line=file:read("*l");
		if line == nil or line == "" or string.byte(line) == "#" then
			break
		end

		local row = parseLine(line);
		local krow = {};
		for k, v in ipairs(row) 
		do
			krow[keys[k]] = v;
		end

		matrix[table.maxn(matrix) + 1] = krow;
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

propertyMatrix = parseFile("./soldier_property.txt")
skillMatrix = parseFile("./soldier_skill.txt")
attackMatrix = parseFile("./soldier_matrix.txt");
hitMatrix = parseFile("./soldier_hit.txt");
blockMatrix = parseFile("./soldier_block.txt");
critMatrix = parseFile("./soldier_crit.txt");

local output = nil

-- 技能
soldierSkill = {}
output = io.open("soldierSkill.xml", "w");
output:write("<?xml version=\"1.0\" encoding=\"utf-8\"?>\n");
output:write("<?xml-stylesheet type=\"text/xsl\" href=\"soldierSkill.xsl\"?>\n");
output:write("\n");

output:write("<SoldierSkills>\n");

for index, skill in ipairs(skillMatrix)
do
	local id = skill["兵种技能ID"];
	skill["兵种技能ID"] = nil;
	soldierSkill[id] = skill;

	output:write(string.format("\t<Skill id = \"%d\">\n", id));
	--<Property name="兵种类型">1</Property>
	output:write(string.format("\t\t<Name>%s</Name>\n", skill["兵种技能名称"]));
	output:write(string.format("\t\t<SoldierType>%s</SoldierType>\n", skill["兵种类型"]));
	output:write(string.format("\t\t<TargetType>%s</TargetType>\n", skill["目标兵种"]));
	output:write(string.format("\t\t<HurtIncrease>%s</HurtIncrease>\n", skill["伤害增幅（%）"]));
	output:write(string.format("\t\t<HurtReduce>%s</HurtReduce>\n", skill["伤害减免（%）"]));
	output:write(string.format("\t\t<Desc>%s</Desc>\n", skill["技能说明"]));
	output:write(string.format("\t</Skill>\n"));
end

output:write("</SoldierSkills>\n");
output:close();

-- 相克（伤害)
soldierMatrix = {}
for index, attack in ipairs(attackMatrix)
do
	local st = attack["0"] + 0;

	if soldierMatrix[st] == nil then
		soldierMatrix[st] = {};
	end

	for key, value in pairs(attack)
	do
		local tt = key + 0;
		local v = value + 0;
		if soldierMatrix[st][tt] == nil then
			soldierMatrix[st][tt] = {};
		end
		soldierMatrix[st][tt].attack = v;
	end
end
-- 相克 (命中)
for index, attack in ipairs(hitMatrix)
do
	local st = attack["0"] + 0;

	if soldierMatrix[st] == nil then
		soldierMatrix[st] = {};
	end
	for key, value in pairs(attack)
	do
		local tt = key + 0;
		local v = value + 0;
		if soldierMatrix[st][tt] == nil then
			soldierMatrix[st][tt] = {};
		end
		soldierMatrix[st][tt].hit = v;
	end
end

-- 相克 (格挡)
for index, attack in ipairs(blockMatrix)
do
	local st = attack["0"] + 0;

	if soldierMatrix[st] == nil then
		soldierMatrix[st] = {};
	end
	for key, value in pairs(attack)
	do
		local tt = key + 0;
		local v = value + 0;
		if soldierMatrix[st][tt] == nil then
			soldierMatrix[st][tt] = {};
		end
		soldierMatrix[st][tt].block = v;
	end
end

-- 相克 (暴击)
for index, attack in ipairs(critMatrix)
do
	local st = attack["0"] + 0;

	if soldierMatrix[st] == nil then
		soldierMatrix[st] = {};
	end
	for key, value in pairs(attack)
	do
		local tt = key + 0;
		local v = value + 0;
		if soldierMatrix[st][tt] == nil then
			soldierMatrix[st][tt] = {};
		end
		soldierMatrix[st][tt].crit = v;
	end
end

for st, v in ipairs(soldierMatrix)
do
	for tt, value in ipairs(v)
	do
		print(st, tt, ":", value.attack, value.hit, value.block, value.crit);
	end
end

-- 属性
soldierProperty = {};
for idx, row in ipairs(propertyMatrix)
do
	local st = row["兵种"] + 0;
	local sl = row["级别"] + 0;
	if st == 0 or sl == 0 then
		print("error soldier type or level : " .. st .. ":" .. sl);
		return;
	end
	row["兵种"] = nil;
	row["级别"] = nil;

	if soldierProperty[st] == nil then
		soldierProperty[st] = {};
	end
	soldierProperty[st][sl] = row;
end

output=io.open("soldierProperty.xml", "w")
output:write("<?xml version=\"1.0\" encoding=\"utf-8\"?>\n");
output:write("<?xml-stylesheet type=\"text/xsl\" href=\"soldierProperty.xsl\"?>\n");
output:write("\n");

output:write("<Soldiers>\n");
for st, soldier in ipairs(soldierProperty)
do
	output:write(string.format("\t<Soldier id=\"%d\">\n", st));
	for level, property in ipairs(soldier)
	do
		output:write(string.format("\t\t<Level level=\"%d\">\n", level));
		output:write(string.format("\t\t\t<Name>%s</Name>\n", property["名称"]));
		output:write(string.format("\t\t\t<Attack>%d</Attack>\n", property["近攻"] + property["远攻"]));
		output:write(string.format("\t\t\t<MeleeDefense>%s</MeleeDefense>\n", property["近防"]));
		output:write(string.format("\t\t\t<RemoteDefense>%s</RemoteDefense>\n", property["远防"]));
		output:write(string.format("\t\t\t<Health>%s</Health>\n", property["生命"]));
		output:write(string.format("\t\t\t<Move>%s</Move>\n", property["移动"]));
		output:write(string.format("\t\t\t<Range>%s</Range>\n", property["射程"]));
		output:write(string.format("\t\t\t<Speed>%s</Speed>\n", property["速度"]));
		output:write(string.format("\t\t\t<Hit>%s</Hit>\n", property["命中"]));
		output:write(string.format("\t\t\t<Dodge>%s</Dodge>\n", property["闪避"]));
		output:write(string.format("\t\t\t<Block>%s</Block>\n", property["格挡"]));
		--output:write(string.format("\t\t\t<XXX>%s</XXX>\n", property["破击"]));
		output:write(string.format("\t\t\t<Crit>%s</Crit>\n", property["暴击"]));
		--output:write(string.format("\t\t\t<XXX>%s</XXX>\n", property["韧性"]));
		output:write(string.format("\t\t\t<Skills>\n"));
		output:write(string.format("\t\t\t<id>%s</id>\n", property["技能1"]));
		output:write(string.format("\t\t\t<id>%s</id>\n", property["技能2"]));
		output:write(string.format("\t\t\t</Skills>\n"));
		output:write(string.format("\t\t\t<Images>\n"));
		output:write(string.format("\t\t\t\t<Small>./resource/soldier/%s_small.png</Small>\n", property["形象"]));
		output:write(string.format("\t\t\t\t<Large>./resource/soldier/%s_large.png</Large>\n", property["形象"]));
		output:write(string.format("\t\t\t</Images>\n"));
		output:write(string.format("\t\t</Level>\n"));
	end
	
	output:write(string.format("\t</Soldier>\n"));
end
output:write("</Soldiers>\n");
output:close();


-- 相克
output=io.open("soldierMatrix.xml", "w")
output:write("<?xml version=\"1.0\" encoding=\"utf-8\"?>\n");
output:write("<?xml-stylesheet type=\"text/xsl\" href=\"soldierMatrix.xsl\"?>\n");
output:write("\n");
output:write("<SoldierMatrix>\n");
for st, soldier in ipairs(soldierProperty)
do
	output:write(string.format("\t<Soldier type=\"%d\">\n", st));
	for tt, value in ipairs(soldierMatrix[st])
	do
		output:write(string.format("\t\t<Matrix target = \"%d\">\n", tt));
		output:write(string.format("\t\t\t<Attack>%d</Attack>\n", value.attack));
		output:write(string.format("\t\t\t<Hit>%d</Hit>\n", value.hit));
		--output:write(string.format("\t\t\t<Dodge>%d</Dodge>\n", value.dodge));
		output:write(string.format("\t\t\t<Block>%d</Block>\n", value.block));
		output:write(string.format("\t\t\t<Crit>%d</Crit>\n", value.crit));
		output:write(string.format("\t\t</Matrix>\n"));
	end
	output:write(string.format("\t</Soldier>\n"));
end
output:write("</SoldierMatrix>\n");
output:close();
