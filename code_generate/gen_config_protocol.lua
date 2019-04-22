#!../bin/server 

package.cpath=package.cpath .. ";../lib/?.so";
package.path =package.path  .. ";../lib/?.lua";

--require "ServiceManager"
--require "loop"
require "printtb"
--require "XMLConfig"
require "mysql"

local db_config_table = dofile("../etc/db_config_table.lua");

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

function query(sql)
	if g_mysql_handle == nil then
		return false;
	end

	local success, reply = mysql.command(g_mysql_handle, sql);
	return success, reply;
end


local function transfrom_type(value)
	local Type = value.Type;
	Type = string.gsub(Type, "%(.*", "");
	if Type == "int" then
		return "int32";
	elseif Type == "bigint" then
		return "int64";
	elseif Type == "varchar" then
		return "string";
	elseif Type == "timestamp" or Type == "datetime" or Type == "time" then
		return "int32";
	elseif Type == "float" or Type == "double" then
		return "float";
	else
		print(string.format("!!!! [%s]", Type));
		--return Type
	end

	return value.Type;
end


local function WRITE(file, fmt, ...) 
	file:write(string.format(fmt .. "\n", ...));
end

local function int32Reader(file, filed)
	WRITE(file, "        item->%s = pbc_rmessage_integer(row, \"%s\", 0, 0);", filed, filed);
end


local function int64Reader(file, filed)
	WRITE(file, "        item->%s = pbc_rmessage_int64(row, \"%s\", 0);", filed, filed);
end

local function stringReader(file, filed)
	WRITE(file, "        item->%s = memory ? agSC_get(pbc_rmessage_string(row, \"%s\", 0, 0), 0) : pbc_rmessage_string(row, \"%s\", 0, 0);", filed, filed, filed);
end

local function floatReader(file, filed)
	WRITE(file, "        item->%s = (float)pbc_rmessage_real(row, \"%s\", 0);", filed, filed);
end

local reader = {
	['int32']  = int32Reader,
	['int64']  = int64Reader,
	['string'] = stringReader,
	['float']  = floatReader,
}


local function foreachCol(info, tb, cb)
	for key, value in pairs(tb) do
		local ignore = false;
		for _, v in ipairs(info[4] or {}) do
			if v == value.Field then
				ignore = true;
				break;
			end
		end

		if not ignore then
			cb(key, value);
		end
	end
end


local function create_proto(info, tb, file)
	name = info[1][1];

	WRITE(file, "message %s {", name)
	WRITE(file, "    message Row {\n")
	local index = 1;

	foreachCol(info, tb,function(key, value)
		WRITE(file, "        optional %s %s = %d;", transfrom_type(value), value.Field, index)
		index = index + 1;
	end);

	WRITE(file, "    }\n")
	WRITE(file, "    repeated Row rows = 1;\n")
	WRITE(file, "}\n")
	WRITE(file, "\n")
end

local function create_header(info, tb)
	name = info[1][1];

	local file = io.open(string.format("db_config/TABLE_%s.h", name), "w");

	WRITE(file, "#ifndef __CONFIG_%s_H_", name)
	WRITE(file, "#define __CONFIG_%s_H_", name)
	WRITE(file, "")
	WRITE(file, "struct %s {", name)

	foreachCol(info, tb,function(key, value)
		WRITE(file, "    %s %s;", transfrom_type(value), value.Field)
	end)

	WRITE(file, "};", name)
	WRITE(file, "")
	WRITE(file, "#endif")
	file:close();
end

local function create_c_file(info, tb)
	name = info[1][1];

	local file = io.open(string.format("db_config/TABLE_%s.LOADER.h", name), "w");

	-- WRITE(file, "#include \"%s_struct_gen.h\"", name)
	-- WRITE(file, "#include \"logic_config.h\"", name)
	-- WRITE(file, "#include \"pbc_int64.h\"", name)
	-- WRITE(file, "#include \"stringCache.h\"", name)
	-- WRITE(file, "")

	-- {{"config_ability_pool"},                    nil,        "./config/equip/",      nil},

	WRITE(file, "static int foreach_row_of_%s(int (*cb)(struct %s *), int memory) {", name, name);
	WRITE(file, "    LOAD_PROTOBUF_CONFIG_BEGIN(\"../etc/%s/%s.pb\", \"com.agame.config.%s\");", info[3], name, name);
	WRITE(file, "    int i, n = pbc_rmessage_size(msg, \"rows\");");
	WRITE(file, "    for (i = 0; i < n; i++) {");
	WRITE(file, "        struct pbc_rmessage * row = pbc_rmessage_message(msg, \"rows\", i);");
	WRITE(file, "        struct %s stack_item;", name);
	WRITE(file, "        struct %s * item = memory ? LOGIC_CONFIG_ALLOC(%s, 1) : &stack_item;", name, name);

	foreachCol(info, tb,function(key, value)
		local t = transfrom_type(value);
		if reader[t] then
			reader[t](file, value.Field);
		else
			print('unknown field type', value.Field, name);
		end
        end)

	WRITE(file, "        if (cb(item) != 0) {")
	WRITE(file, "            return -1;");
	WRITE(file, "        }");
	WRITE(file, "    }");
	WRITE(file, "    LOAD_PROTOBUF_CONFIG_END(buf, msg);");
	WRITE(file, "    return 0;");
	WRITE(file, "}")
	WRITE(file, "")
	
	file:close();
end

local function run()
	local file = io.open("../protocol/config.proto", "w");
	if not file then
		print("open config.proto fail");
	end

	file:write("package com.agame.config;\n\n");

	for _, info in pairs(db_config_table) do
		local sql = "DESC ".. info[1][1] .. ";";
		local ok, result = query(sql);
		if ok then
			create_proto(info, result, file);
			create_header(info, result);
			create_c_file(info, result);
		else
			print(string.format("query table %s fail.", info[1][1]));
		end
	end
	io.close(file);
end

run();

os.exit(0)
