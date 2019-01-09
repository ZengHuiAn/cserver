local redis = redis;
local string = string;
local pairs = pairs;
local print = print;
local table = table;
local tonumber = tonumber;
local error = error;
local log = log;
local error = error;
local setmetatable = setmetatable;
local assert = assert;

local mysql = require ("mysql")
-- local DatabaseConfig = require "DatabaseConfig"
local XMLConfig = require "XMLConfig"
local Scheduler = require "Scheduler"

module "database"

local DatabaseConfig = {
	game = { 
		name   = "GameDB",
		host   = XMLConfig.Database.Game.host   and XMLConfig.Database.Game.host["@text"] or "localhost",
		port   = XMLConfig.Database.Game.port   and tonumber(XMLConfig.Database.Game.port["@text"]) or 3306,
		user   = XMLConfig.Database.Game.user["@text"],
		passwd = XMLConfig.Database.Game.passwd and XMLConfig.Database.Game.passwd["@text"] or nil,
		db     = XMLConfig.Database.Game.db     and XMLConfig.Database.Game.db["@text"] or nil,
		socket = XMLConfig.Database.Game.socket and XMLConfig.Database.Game.socket["@text"] or nil,
	},

	account = {
		name   = "AccountDB",
		host   = XMLConfig.Database.Account.host    and XMLConfig.Database.Account.host["@text"] or "localhost",
		port   = XMLConfig.Database.Account.port    and tonumber(XMLConfig.Database.Account.port["@text"]) or 3306,
		user   = XMLConfig.Database.Account.user["@text"],
		passwd = XMLConfig.Database.Account.passwd  and XMLConfig.Database.Account.passwd["@text"] or nil,
		db     = XMLConfig.Database.Account.db      and XMLConfig.Database.Account.db["@text"] or nil,
		socket = XMLConfig.Database.Account.socket  and XMLConfig.Database.Account.socket["@text"] or nil,
	},
};

local next_id = 0;
local function nextID()
	next_id = next_id + 1;
	return next_id;
end

local all = {};

local DatabaseClass = {};
function DatabaseClass.Open(config)
	log.debug(string.format("[DATABAE] connect to mysql %s", config.name or config.host));
	local conn = mysql.open(
		config.host,
		config.user,
		config.passwd,
		config.db,
		config.port,
		config.socket);

	if conn == nil then
		log.warning(string.format("\tfailed"));
		return;
	end

	mysql.command(conn, "set names utf8");

	local id = nextID();
	local t = {
		id     = id,
		config = config,
		name   = config.name or ("DataBase" .. id),
		_conn  = conn
	};
	return setmetatable(t, {__index = DatabaseClass});
end

function DatabaseClass:command(sql)
	if self._conn == nil then
		return false;
	end

	log.debug(string.format('[DATABASE] <%s,%d> SQL [%s]', self.name, self.id, sql));
	local success, reply = mysql.command(self._conn, sql);
	if not success then
		log.warning(string.format("[DATABASE] <%s,%d> SQL [%s] faield: %s", self.name, self.id, sql, reply));
	end
	return success, reply;
end

function DatabaseClass:tick()
	if self._conn then
		local success, respond = mysql.command(self._conn, "select 1");
		if not success then
			mysql.close(self._conn);
			self._conn =nil
		end
	end
	if not self._conn then
		log.debug(string.format("[%s] conn is nil", self.name))
		local db =DatabaseClass.Open(self.config)
		if db then
			self._conn = db._conn;
		else
			log.debug(string.format("[%s] db is nil", self.name))
		end
	end
end

function DatabaseClass:query(...)
	return self:command(string.format(...));
end

function DatabaseClass:update(...)
--	log.debug(...)
	return self:command(string.format(...));
end

function DatabaseClass:last_id()
	return mysql.last_id(self._conn);
end

function DatabaseClass:error()
	return msyql.error(self._conn);
end

function DatabaseClass:errno()
	return mysql.errno(self._conn);
end

--[[
function tick()
	for _, db in pairs(all) do
		db:tick();
	end
end
--]]

Scheduler.New(function(now)
	for _, db in pairs(all) do
		db:tick();
	end
end);

function Get(name)
	if DatabaseConfig[name] == nil then
		return;
	end

	if DatabaseConfig[name].conn == nil then
		local db = DatabaseClass.Open(DatabaseConfig[name]);
		if db then
			DatabaseConfig[name].conn = db;
			all[db.id] = db;
		end
	end
	return DatabaseConfig[name].conn;
end


function command(...)
	return Get("game"):command(...);
end

function query(...)
	return Get("game"):query(...);
end

function update(...)
	return Get("game"):update(...);
end

function last_id()
	return Get("game"):last_id();
end

function error()
	return Get("game"):error()
end

function errno()
	return Get("game"):errno();
end

function NewDatabase(config)
	if nil == config then
		return nil
	end
	log.debug(string.format("[DATABAE] connect to mysql %s", config.name or config.host));
	local conn = mysql.open(
		config.host,
		config.user,
		config.passwd,
		config.db,
		config.port,
		config.socket);

	if conn == nil then
		log.warning(string.format("\tfailed"));
		return;
	end

	mysql.command(conn, "set names utf8");

	local id = nextID();
	local t = {
		id     = id,
		config = config,
		name   = config.name or ("DataBase" .. id),
		_conn  = conn
	};
	setmetatable(t, {__index = DatabaseClass});
	return t
end

gamedb = Get("game");
assert(gamedb);
