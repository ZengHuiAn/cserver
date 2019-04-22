#!/usr/bin/env lua

package.cpath=package.cpath .. ";../lib/?.so";
package.path =package.path  .. ";../lib/?.lua";

require "mysql"
require "printtb"
require "protobuf"

local g_mysql_handle = mysql.open(
        "172.16.3.97",
        "root",
        "123456",
        "aGameMobileConfig_sgk",
        3306);

if g_mysql_handle == nil then
        print("fail to connect to mysql sercver")
        os.exit(1)
end

local success = mysql.command(g_mysql_handle, "set names utf8");

local function query(sql)
        if g_mysql_handle == nil then
                return false;
        end
        local success, reply = mysql.command(g_mysql_handle, sql);
        return success, reply;
end

local function joint_sql(tb, name, discard)
        if discard then
                for k, v in pairs(discard) do
                        for sub_k, sub_v in pairs(tb) do
                                if v == sub_v.Field then
                                        table.remove(tb, sub_k);
                                        break;
                                end
                        end
                end
        end
        local sql = "SELECT ";
        local len = 1;
        local size = #tb;
        for k, v in pairs(tb) do
				local Type = string.gsub(v.Type, "%(.*", "");

                if v.FieldAlias and v.FieldAlias ~= v.Field then
                        sql = sql .. v.FieldAlias;
                else
				        if Type == "timestamp" or Type == "datetime" then
							sql = sql .. "unix_timestamp(`" .. v.Field .. "`) as `" .. v.Field .. "`";
				        elseif Type == "time" then
							sql = sql .. "TIME_TO_SEC(`" .. v.Field .. "`) as `" .. v.Field .. "`";
						else
							sql = sql .. "`" .. v.Field .. "`";
				        end
                end
                if len < size then
                        sql = sql .. ","
                end
                len = len + 1;
        end
        sql = sql .. " FROM " .. name .. ";";
        return sql;
end

local function write_xml(tb, name, values, path)
	local file = io.open(path .. "/" .. name .. ".xml", "w");
	file:write("<Root>\n");
        for k, v in pairs(values) do
                for sub_k, sub_v in pairs(v) do
                        file:write(string.format("    <Item>\n"));
                        for tb_k, tb_v in pairs(tb) do
                                file:write(string.format("        <%s>%s</%s>\n", tb_v.Field, tostring(sub_v[tb_v.Field] or 0), tb_v.Field));
                        end
                        file:write(string.format("    </Item>\n"));
                end
        end
        file:write("</Root>\n");
	file:close();
end

local function write_bin(tb, name, values, path)
	os.execute ("mkdir -pv " .. path);
	local file = io.open(path .. "/" .. name .. ".pb", "w");
    assert(file, path .. "/" .. name .. ".pb");
	local cfg = { rows = {} };
	for k, v in pairs(values) do
                for sub_k, sub_v in pairs(v) do
			table.insert(cfg.rows, sub_v);
                end
        end

	local proto = protobuf.encode("com.agame.config." .. name, cfg);
    file:write(proto);
	file:close();
end

local function parse_table(tb_name, alias, discard)
		print('parse_table', tb_name);
        local ok, result = query(string.format("DESC %s;", tb_name));
        if not ok then
                print(string.format("parse tb %s fail", tb_name));
                return;
        end

        if discard then
                for k, v in pairs(discard) do
                        for sub_k, sub_v in pairs(result) do
                                if v == sub_v.Field then
                                        table.remove(result, sub_k);
                                        break;
                                end
                        end
                end
        end

        if alias then
                for k, v in pairs(result) do
                        v.FieldAlias = v.Field;
                        for alias_k, alias_v in pairs(alias) do
                                if v.Field == alias_v.real then
                                        v.FieldAlias = alias_v.alias;
                                end
                        end
                end
        end
        return result;
end

function run(names, alias, path, discard)
        if type(names) == type({}) then
                --坑爹的策划把结构相同内容不同的数据存了N张表, 将N张结构相同仅数据表名不同的表的数据加载写入同一个xml文件
                local xml_tb = {};
                local name = names[1];--只以第一个名字作为最终使用的名字
                local tb = parse_table(names[1], alias, discard);--同上
                for k, v in pairs(names) do
                        local t = parse_table(v, alias, discard);
                        local sql = joint_sql(t, v, discard);
                        local ok, result = query(sql);
                        if ok then
                                table.insert(xml_tb, result);
                        else
                                print("execute sql error, sql: ", sql);
                                os.exit(1);
                        end
                end
                write_bin(tb, name, xml_tb, path);
				write_xml(tb, name, xml_tb, path);
        else
                local tb = parse_table(names, alias, discard);
                local sql = joint_sql(tb, names, discard);
                local ok, result = query(sql);
                if ok then
                        write_bin(tb, names, {result}, path);
                        write_xml(tb, names, {result}, path);
                else
                        print("execute sql error, sql: ", sql);
                        os.exit(1);
                end
        end
end

local db_config_table = dofile("db_config_table.lua")


local function loadProtocol(file)
        local f = io.open(file, "rb")
        local protocol = f:read("*a")
        f:close()
        protobuf.register(protocol)
end

loadProtocol("../protocol/config.pb");

for _, v in ipairs(db_config_table) do
	run(v[1], v[2], v[3], v[4]);
end
--[[
--      表名                                    字段别名    路径                    过滤字段
run("config_ability_pool",                      nil,        "./config/equip/",      nil);
run("config_battle_config",                     nil,        "./config/fight/",      {"desc", "sound"});
run("config_chapter_config",                    nil,        "./config/fight/",      {"name", "background"});
run("config_common",                            nil,        "./config/hero/",       {"desc"});
run("config_config",                            nil,        "./config/hero/",       {"info"});
run("config_equipment",                         nil,        "./config/equip/",      {"name", "info", "icon"});
run("config_equipment_lev",                     nil,        "./config/equip/",      nil);
run("config_inscription",                       nil,        "./config/equip/",      {"name", "icon", "info"});
run("config_item",                              nil,        "./config/item/",       {"name", "info"});
run("config_level_up",                          nil,        "./config/hero/",       nil);
run("config_npc",                               nil,        "./config/fight/",      {"name", "icon"});
run("config_npc_property_config",               nil,        "./config/fight/",      nil);
run("config_pve_fight_config",                  nil,        "./config/fight/",      {"scene_name", "scene_bg_id", "music", "boss_music"});
run("config_role",                              nil,        "./config/hero/",       {"name", "icon"});
run("config_star_up",                           nil,        "./config/hero/",       nil);
run("config_wave_config",                       nil,        "./config/fight/",      nil);
run("config_weapon",                            nil,        "./config/hero/",       {"name", "icon"});
run("config_star_reward",                       nil,        "./config/fight/",      {"name", "icon"});
run("config_pet",                               nil,        "./config/hero/",       {"icon"});
run("config_parameter",                         nil,        "./config/hero/",       {"name", "showType", "desc", "PropertyFormula"});
run("config_skill",                             nil,        "./config/hero/",       {"icon", "name", "desc", "check_script", });

--结构相同, 保存到同一份配置
run({"config_weapon_evo", "config_role_evo"},   nil,        "./config/hero/",      nil);
run({"config_weapon_lev", "config_role_lev"},   nil,        "./config/hero/",      nil);
run({"config_skill_tree", "config_talent"},     nil,        "./config/hero/",      {"name", "desc"});
run({"config_role_star", "config_weapon_star"}, nil,        "./config/hero/",      {"name", "desc"});

--部分字段需要取别名
local alias = {
        [1] = {alias = "UNIX_TIMESTAMP(act_time) as act_time", real = "act_time"},
        [2] = {alias = "UNIX_TIMESTAMP(end_time) as end_time", real = "end_time"},
};
run("config_fight_reward",              alias,      "./config/fight/",      nil);
--]]

os.exit(0)
