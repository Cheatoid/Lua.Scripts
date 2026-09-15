-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- SQL/Database abstraction with query builder and object-relational mapping for LuaJIT/5.1+

--[[
OVERVIEW
--------
SQLORM is a deliberately driver-agnostic database toolkit. It has four layers:

  Application
      |
      v
  ORM / Repository
      |
      v
  Query Builder + Query Compiler + Query Executor
      |
      v
  Connection -> Driver Adapter -> User's SQL library
                         ^
                         |
                     SQL Dialect

The library does NOT require a particular SQLite, SpacetimeDB, PostgreSQL, MySQL,
or Garry's Mod database binding. A small structural adapter is enough.

DESIGN / SOLID
--------------
The design follows SOLID where those principles provide useful boundaries:

S - Single Responsibility
    * Query stores fluent query state.
    * QueryCompiler renders query state into parameterized SQL.
    * QueryExecutor executes compiled queries.
    * DriverAdapter translates a concrete Lua DB API into the small driver
      contract understood by Connection.
    * Dialects own SQL-engine syntax differences.
    * Field owns field conversion and validation policy.
    * ModelMeta owns model metadata/configuration and acts as a small facade.
    * ModelInstance owns entity state and dirty tracking.
    * Relation is relationship configuration; relationship loading remains in
      model services/facades.

O - Open/Closed
    New dialects and driver bindings can be registered or adapted without
    modifying the query builder, ORM, or Connection implementation.

L - Liskov Substitution
    Dialects, adapters, expressions, and other loose-interface implementations
    are interchangeable as long as they honor their documented contracts.
    No implementation is allowed to require capabilities its interface does
    not promise.

I - Interface Segregation
    There is no giant database interface. Driver clients need only execute,
    query, and optionally prepare/close. Expressions only need to_sql().
    Dialects expose focused SQL-rendering capabilities.

D - Dependency Inversion
    Query/ORM code depends on Connection/Dialect/driver capabilities, not on
    sqlite3, LuaSQL, a GMod SQL API, or another concrete implementation.

"LOOSE INTERFACES"
-------------------
Lua does not require nominal interfaces for this design. SQLORM therefore uses
structural/capability checks. For example, an expression is anything exposing:

    value:to_sql(context) -> sql

A driver can be a table OR userdata and may expose any of these common methods:

    execute(sql, params) -> result, error
    exec(sql, params)    -> result, error
    run(sql, params)     -> result, error
    query(sql, params)   -> rows, error
    fetch_all(...)       -> rows, error
    select(...)          -> rows, error
    prepare(sql)         -> statement, error   -- optional
    close()              -> result, error      -- optional

SQLORM.Driver / DriverAdapter normalizes these names.

SECURITY
--------
Normal query values are always bound parameters. Identifiers are quoted and
validated. Raw SQL exists intentionally, but is explicitly named `raw()` and
should only be used with trusted SQL fragments.

SQLORM.interpolate_for_debug() is for logging/debugging only. Its output MUST
NEVER be sent to the database as an execution string.

QUERY BUILDER
-------------
    local q = db:select("id", "name")
        :from("users")
        :where({ active = true })
        :where("age", 18, ">=")
        :order_by_desc("id")
        :limit(25)

    local sql, params = q:to_sql()
    local rows, err = q:all()

Expressions:

    DB.op.eq(value)
    DB.op.ne(value)
    DB.op.gt(value)
    DB.op.gte(value)
    DB.op.lt(value)
    DB.op.lte(value)
    DB.op.like(value)
    DB.op.ilike(value)
    DB.op.between(low, high)
    DB.op.in_(values)
    DB.op.not_in(values)
    DB.op.is_null()
    DB.op.not_null()
    DB.op.and_(...)
    DB.op.or_(...)
    DB.op.not_(expression)
    DB.op.exists(query)

ORM
---
    local User = DB.Model.define("User", "users", {
        id = DB.field.integer({
            primary = true,
            auto_increment = true,
        }),
        name = DB.field.text({ not_null = true }),
        age = DB.field.integer(),
    })

    User:bind(db)

    local user = User:create({ name = "Alice", age = 30 })
    user.age = 31
    user:save()

    local adults = User:query()
        :where({ age = DB.op.gte(18) })
        :order_by("name")
        :all()

Relationships:

    User:belongs_to("team", Team, { foreign_key = "team_id" })
    Team:has_many("users", User, { foreign_key = "team_id" })
    User:has_one("profile", Profile, { foreign_key = "user_id" })
    User:many_to_many("roles", Role, {
        pivot_table = "user_roles",
        pivot_foreign_key = "user_id",
        pivot_related_key = "role_id",
    })

DRIVER EXAMPLE
--------------
A database library that already looks like this:

    driver:execute(sql, params)
    driver:query(sql, params)

can be passed directly:

    local db = DB.open(driver, { dialect = "sqlite" })

For a function-based API:

    local driver = DB.function_driver(
        function(sql, params) ... end,
        function(sql, params) ... end
    )

CUSTOM DIALECT
--------------
A dialect is a small object whose methods can be inherited from Dialect through
normal Lua metatables, or supplied by any compatible table:

    local MyDialect = setmetatable({
        name = "mydb",
        placeholder_style = "numbered_dollar",
        features = { returning = true, upsert = true },
    }, { __index = DB.Dialect })

    function MyDialect:render_upsert(conflicts, assignments)
        -- return engine-specific SQL
    end

    DB.register_dialect("mydb", MyDialect)

TESTABILITY
-----------
Because the Connection and driver boundaries are injected, unit tests can use a
small in-memory fake:

    local fake = DB.function_driver(
        function(sql, params) return { affected_rows = 1 } end,
        function(sql, params) return {} end
    )

No real database is required to test query generation or ORM behavior.
]]

-- Localized global functions for better performance
local assert = assert
local error = error
local getmetatable = getmetatable
local next = next
local pairs = pairs
local pcall = pcall
local setmetatable = setmetatable
local tonumber = tonumber
local tostring = tostring
local type = type
local math_floor = math.floor
local string_format = string.format
local string_gmatch = string.gmatch
local string_gsub = string.gsub
local string_lower = string.lower
local string_match = string.match
local string_upper = string.upper
local table_concat = table.concat
local table_sort = table.sort
local table_unpack = table.unpack or unpack

local SQLORM = {}

----------------------------------------------------------------------
-- Public architecture / loose interfaces
----------------------------------------------------------------------

--- SQLORM intentionally uses structural interfaces instead of inheritance.
--- A compatible object only needs to expose the capability used by its client.
---
--- Driver capabilities:
--- * execute(sql, params) -> result, error
--- * query(sql, params) -> rows, error
--- * prepare(sql) -> statement, error (optional)
--- * close() -> result, error (optional)
---
--- Dialect capabilities:
--- * quote_identifier(name) -> string
--- * placeholder(index) -> string
--- * limit_offset(limit, offset) -> string
--- * render_returning(columns) -> string
--- * render_upsert(columns, assignments) -> string
---
--- Expression capability:
--- * to_sql(context) -> sql, optional additional parameters
---
--- This deliberately favors small client-facing contracts over one universal
--- interface, which keeps adapters easy to implement and test.

----------------------------------------------------------------------
-- Utilities
----------------------------------------------------------------------

local function shallow_copy(source)
	local result = {}
	if source then
		for key, value in pairs(source) do
			result[key] = value
		end
	end
	return result
end

local function array_copy(source)
	local result = {}
	if source then
		for i = 1, #source do
			result[i] = source[i]
		end
	end
	return result
end

local function merge_into(target, source)
	if source then
		for key, value in pairs(source) do
			target[key] = value
		end
	end
	return target
end

local function is_array(value)
	if type(value) ~= "table" then
		return false
	end

	local count = 0
	for key in pairs(value) do
		if type(key) ~= "number" or key < 1 or key ~= math_floor(key) then
			return false
		end
		count = count + 1
	end

	return count == #value
end

local function append_array(target, source)
	local offset = #target
	for i = 1, #source do
		target[offset + i] = source[i]
	end
end

local function assert_type(value, expected, name)
	if type(value) ~= expected then
		return error((name or "value") .. " must be " .. expected .. ", got " .. type(value), 3)
	end
	return value
end

local function has_method(object, name)
	if not object then
		return false
	end
	return type(object[name]) == "function"
end

local function first_method(object, names)
	for i = 1, #names do
		local name = names[i]
		if has_method(object, name) then
			return name
		end
	end
	return nil
end

local function trim(value)
	return (string_gsub(value, "^%s*(.-)%s*$", "%1"))
end

local function is_identifier(value)
	return type(value) == "string"
		and string_match(value, "^[A-Za-z_][A-Za-z0-9_]*$") ~= nil
end

local function quote_single(value)
	return "'" .. (string_gsub(value, "'", "''")) .. "'"
end

local function normalize_params(params)
	if params == nil then
		return {}
	end

	if is_array(params) then
		return params
	end

	return params
end

local function traceback_error(prefix, err)
	if err == nil then
		return prefix
	end
	return prefix .. ": " .. tostring(err)
end

----------------------------------------------------------------------
-- Errors
----------------------------------------------------------------------

local Error = {}
Error.__index = Error

function Error:new(kind, message, context)
	return setmetatable({
		kind = kind or "Error",
		message = message or "",
		context = context,
	}, self)
end

function Error:__tostring()
	if self.context then
		return string_format("%s: %s (%s)", self.kind, self.message, tostring(self.context))
	end
	return self.kind .. ": " .. self.message
end

SQLORM.Error = Error

SQLORM.errors = {
	Error = Error,
	Driver = function(message, context) return Error:new("DriverError", message, context) end,
	Query = function(message, context) return Error:new("QueryError", message, context) end,
	ORM = function(message, context) return Error:new("ORMError", message, context) end,
	Transaction = function(message, context) return Error:new("TransactionError", message, context) end,
	Validation = function(message, context) return Error:new("ValidationError", message, context) end,
}

----------------------------------------------------------------------
-- Dialects
----------------------------------------------------------------------

---@class SQLORM.Dialect
---@field name string
---@field placeholder_style string
---@field features table
local Dialect = {}
Dialect.__index = Dialect
Dialect.name = "generic"
Dialect.placeholder_style = "question"
Dialect.features = {
	returning = false,
	upsert = false,
	ilike = false,
	nulls_order = false,
}

function Dialect:new(options)
	local object = shallow_copy(options)
	object.features = shallow_copy(self.features)
	if options and options.features then
		merge_into(object.features, options.features)
	end
	return setmetatable(object, self)
end

function Dialect:quote_identifier(identifier)
	assert_type(identifier, "string", "identifier")

	-- Qualified paths are quoted component-by-component.
	local parts = {}
	for part in string_gmatch(identifier, "[^%.]+") do
		if not is_identifier(part) and part ~= "*" then
			return error("unsafe SQL identifier: " .. identifier, 3)
		end
		if part == "*" then
			parts[#parts + 1] = part
		else
			parts[#parts + 1] = '"' .. string_gsub(part, '"', '""') .. '"'
		end
	end
	return table_concat(parts, ".")
end

function Dialect:placeholder(index)
	if self.placeholder_style == "numbered_dollar" then
		return "$" .. tostring(index)
	end
	if self.placeholder_style == "numbered_colon" then
		return ":" .. tostring(index)
	end
	if self.placeholder_style == "at" then
		return "@p" .. tostring(index)
	end
	return "?"
end

function Dialect:quote_literal(value)
	if value == nil then
		return "NULL"
	end
	if type(value) == "boolean" then
		return value and "TRUE" or "FALSE"
	end
	if type(value) == "number" then
		return tostring(value)
	end
	if type(value) == "string" then
		return quote_single(value)
	end
	return error("cannot quote Lua value of type " .. type(value), 3)
end

function Dialect:limit_offset(limit, offset)
	local sql = ""
	if limit ~= nil then
		sql = sql .. " LIMIT " .. tostring(limit)
	end
	if offset ~= nil then
		sql = sql .. " OFFSET " .. tostring(offset)
	end
	return sql
end

function Dialect:concat_operator()
	return "||"
end

function Dialect:case_insensitive_like(left, right)
	return left .. " LIKE " .. right
end

function Dialect:now_expression()
	return "CURRENT_TIMESTAMP"
end

function Dialect:auto_increment_sql()
	return ""
end

function Dialect:boolean_sql(value)
	return value and "TRUE" or "FALSE"
end

function Dialect:render_returning(columns)
	if not self.features.returning or not columns or #columns == 0 then
		return ""
	end

	local rendered = {}
	for i = 1, #columns do
		rendered[i] = self:quote_identifier(columns[i])
	end
	return " RETURNING " .. table_concat(rendered, ", ")
end

function Dialect:render_upsert(conflict_columns, assignments)
	return ""
end

local GenericDialect = setmetatable({}, { __index = Dialect })
GenericDialect.name = "generic"
GenericDialect.placeholder_style = "question"

local SQLiteDialect = setmetatable({}, { __index = Dialect })
SQLiteDialect.name = "sqlite"
SQLiteDialect.placeholder_style = "question"
SQLiteDialect.features = {
	returning = true,
	upsert = true,
	ilike = false,
	nulls_order = false,
}

function SQLiteDialect:quote_identifier(identifier)
	if identifier == "*" then
		return "*"
	end
	return Dialect.quote_identifier(self, identifier)
end

function SQLiteDialect:auto_increment_sql()
	return " AUTOINCREMENT"
end

function SQLiteDialect:boolean_sql(value)
	return value and "1" or "0"
end

function SQLiteDialect:render_upsert(conflict_columns, assignments)
	local columns = {}
	for i = 1, #conflict_columns do
		columns[i] = self:quote_identifier(conflict_columns[i])
	end

	local updates = {}
	for i = 1, #assignments do
		updates[i] = self:quote_identifier(assignments[i][1]) .. " = " .. assignments[i][2]
	end

	return " ON CONFLICT (" .. table_concat(columns, ", ") .. ") DO UPDATE SET " .. table_concat(updates, ", ")
end

local PostgreSQLDialect = setmetatable({}, { __index = Dialect })
PostgreSQLDialect.name = "postgresql"
PostgreSQLDialect.placeholder_style = "numbered_dollar"
PostgreSQLDialect.features = {
	returning = true,
	upsert = true,
	ilike = true,
	nulls_order = true,
}

function PostgreSQLDialect:concat_operator()
	return "||"
end

function PostgreSQLDialect:case_insensitive_like(left, right)
	return left .. " ILIKE " .. right
end

function PostgreSQLDialect:render_upsert(conflict_columns, assignments)
	local columns = {}
	for i = 1, #conflict_columns do
		columns[i] = self:quote_identifier(conflict_columns[i])
	end

	local updates = {}
	for i = 1, #assignments do
		updates[i] = self:quote_identifier(assignments[i][1]) .. " = " .. assignments[i][2]
	end

	return " ON CONFLICT (" .. table_concat(columns, ", ") .. ") DO UPDATE SET " .. table_concat(updates, ", ")
end

local MySQLDialect = setmetatable({}, { __index = Dialect })
MySQLDialect.name = "mysql"
MySQLDialect.placeholder_style = "question"
MySQLDialect.features = {
	returning = false,
	upsert = true,
	ilike = false,
	nulls_order = false,
}

function MySQLDialect:quote_identifier(identifier)
	assert_type(identifier, "string", "identifier")
	local parts = {}
	for part in string_gmatch(identifier, "[^%.]+") do
		if not is_identifier(part) and part ~= "*" then
			return error("unsafe SQL identifier: " .. identifier, 3)
		end
		if part == "*" then
			parts[#parts + 1] = part
		else
			parts[#parts + 1] = "`" .. string_gsub(part, "`", "``") .. "`"
		end
	end
	return table_concat(parts, ".")
end

function MySQLDialect:render_upsert(conflict_columns, assignments)
	local updates = {}
	for i = 1, #assignments do
		local column = assignments[i][1]
		updates[i] = self:quote_identifier(column) .. " = VALUES(" .. self:quote_identifier(column) .. ")"
	end
	return " ON DUPLICATE KEY UPDATE " .. table_concat(updates, ", ")
end

local Dialects = {
	generic = Dialect,
	sqlite = SQLiteDialect,
	postgresql = PostgreSQLDialect,
	postgres = PostgreSQLDialect,
	mysql = MySQLDialect,
	mariadb = MySQLDialect,
}

function SQLORM.register_dialect(name, prototype)
	assert_type(name, "string", "dialect name")
	assert_type(prototype, "table", "dialect")
	Dialects[string_lower(name)] = prototype
end

local function dialect_factory(value)
	if value == nil then
		return setmetatable({}, { __index = GenericDialect })
	end

	if type(value) == "string" then
		local prototype = Dialects[string_lower(value)]
		if not prototype then
			return error("unknown SQL dialect: " .. value, 2)
		end
		return setmetatable({}, { __index = prototype })
	end

	return value
end

-- Callable namespace: SQLORM.dialect("sqlite") and SQLORM.dialect.sqlite() are both valid in Lua 5.1
SQLORM.dialect = setmetatable({
	generic = function() return dialect_factory("generic") end,
	spacetimedb = function() return dialect_factory("spacetimedb") end,
	sqlite = function() return dialect_factory("sqlite") end,
	postgresql = function() return dialect_factory("postgresql") end,
	postgres = function() return dialect_factory("postgresql") end,
	mysql = function() return dialect_factory("mysql") end,
	mariadb = function() return dialect_factory("mariadb") end,
}, {
	__call = function(_, value)
		return dialect_factory(value)
	end,
})

----------------------------------------------------------------------
-- SQL expressions / operators
----------------------------------------------------------------------

local Expr = {}
Expr.__index = Expr

function Expr:new(renderer)
	return setmetatable({ render = renderer }, self)
end

function Expr:is_expression()
	return true
end

function Expr:to_sql(context)
	return self.render(context)
end

local function expr(renderer)
	return Expr:new(renderer)
end

local OP = {}

function OP.raw(sql, params)
	assert_type(sql, "string", "raw SQL")
	local values = params or {}
	return expr(function()
		return sql, values
	end)
end

function OP.eq(value)
	return expr(function(ctx)
		local p = ctx:add_param(value)
		return "= " .. p
	end)
end

function OP.ne(value)
	return expr(function(ctx)
		local p = ctx:add_param(value)
		return "<> " .. p
	end)
end

function OP.gt(value)
	return expr(function(ctx)
		return "> " .. ctx:add_param(value)
	end)
end

function OP.gte(value)
	return expr(function(ctx)
		return ">= " .. ctx:add_param(value)
	end)
end

function OP.lt(value)
	return expr(function(ctx)
		return "< " .. ctx:add_param(value)
	end)
end

function OP.lte(value)
	return expr(function(ctx)
		return "<= " .. ctx:add_param(value)
	end)
end

function OP.like(value)
	return expr(function(ctx)
		return "LIKE " .. ctx:add_param(value)
	end)
end

function OP.ilike(value)
	return expr(function(ctx)
		return ctx.dialect:case_insensitive_like("", ctx:add_param(value)):sub(2)
	end)
end

function OP.between(low, high)
	return expr(function(ctx)
		return "BETWEEN " .. ctx:add_param(low) .. " AND " .. ctx:add_param(high)
	end)
end

function OP.in_(values)
	assert_type(values, "table", "IN values")
	return expr(function(ctx)
		-- A query object is treated as a correlated/non-correlated subquery;
		-- an ordinary array is expanded into bound parameters.
		if has_method(values, "to_sql") then
			return "IN (" .. values:to_sql(ctx) .. ")"
		end
		if #values == 0 then
			return "IN (NULL)"
		end
		local placeholders = {}
		for i = 1, #values do
			placeholders[i] = ctx:add_param(values[i])
		end
		return "IN (" .. table_concat(placeholders, ", ") .. ")"
	end)
end

function OP.not_in(values)
	local inner = OP.in_(values)
	return expr(function(ctx)
		local sql = inner:to_sql(ctx)
		return "NOT " .. sql
	end)
end

function OP.is_null()
	return expr(function() return "IS NULL" end)
end

function OP.not_null()
	return expr(function() return "IS NOT NULL" end)
end

function OP.is_true()
	return expr(function(ctx)
		return "= " .. ctx.dialect:boolean_sql(true)
	end)
end

function OP.is_false()
	return expr(function(ctx)
		return "= " .. ctx.dialect:boolean_sql(false)
	end)
end

function OP.and_(...)
	local args = { ... }
	return expr(function(ctx)
		local parts = {}
		for i = 1, #args do
			local item = args[i]
			local sql = item:to_sql(ctx)
			parts[#parts + 1] = "(" .. sql .. ")"
		end
		return table_concat(parts, " AND ")
	end)
end

function OP.or_(...)
	local args = { ... }
	return expr(function(ctx)
		local parts = {}
		for i = 1, #args do
			parts[#parts + 1] = "(" .. args[i]:to_sql(ctx) .. ")"
		end
		return table_concat(parts, " OR ")
	end)
end

function OP.not_(value)
	return expr(function(ctx)
		return "NOT (" .. value:to_sql(ctx) .. ")"
	end)
end

function OP.exists(query)
	return expr(function(ctx)
		local sql = query:to_sql(ctx)
		return "EXISTS (" .. sql .. ")"
	end)
end

function OP.not_exists(query)
	return expr(function(ctx)
		return "NOT EXISTS (" .. query:to_sql(ctx) .. ")"
	end)
end

function OP.asc(column)
	return { column = column, direction = "ASC" }
end

function OP.desc(column)
	return { column = column, direction = "DESC" }
end

SQLORM.op = OP
SQLORM.raw = OP.raw

----------------------------------------------------------------------
-- Query context
----------------------------------------------------------------------

local QueryContext = {}
QueryContext.__index = QueryContext

function QueryContext:new(dialect)
	return setmetatable({ dialect = dialect, params = {} }, self)
end

function QueryContext:add_param(value)
	self.params[#self.params + 1] = value
	return self.dialect:placeholder(#self.params)
end

function QueryContext:expression(value)
	if type(value) == "table" and has_method(value, "to_sql") then
		return value:to_sql(self)
	elseif type(value) == "table" and value.__raw_sql then
		return value.sql
	end

	return self:add_param(value)
end

----------------------------------------------------------------------
-- Query Builder
----------------------------------------------------------------------

-- Forward declarations: the compiler is defined before the rendering helpers
-- but invoked only after module initialization has completed.
local render_column
local render_table
local render_assignment_key

--- SQL compiler.
---
--- Responsibility: transform an immutable-in-practice Query state into SQL
--- plus bound parameters. It does not execute SQL and has no driver dependency.
--- This separation keeps SQL generation independently testable and allows a
--- different compiler to be introduced without changing query execution.
local QueryCompiler = {}
QueryCompiler.__index = QueryCompiler

function QueryCompiler:new(query)
	return setmetatable({ query = query }, self)
end

--- Compile a query into parameterized SQL.
---@param parent_context? table Internal compilation context for subqueries.
---@return string sql
---@return table params
function QueryCompiler:compile(parent_context)
	local query = self.query
	local ctx = parent_context or QueryContext:new(query.dialect)
	local sql

	if query.query_type == "select" then
		local columns = {}
		if #query.selects == 0 then
			columns[1] = "*"
		else
			for i = 1, #query.selects do
				local value = query.selects[i]
				if type(value) == "table" and value.alias then
					local expression = value.expression
					local expression_sql
					if type(expression) == "string" then
						expression_sql = query.dialect:quote_identifier(expression)
					else
						expression_sql = expression:to_sql(ctx)
					end
					columns[#columns + 1] = expression_sql .. " AS " .. query.dialect:quote_identifier(value.alias)
				elseif type(value) == "table" and has_method(value, "to_sql") then
					columns[#columns + 1] = value:to_sql(ctx)
				else
					columns[#columns + 1] = render_column(query.dialect, value)
				end
			end
		end

		sql = "SELECT " .. (query.distinct_flag and "DISTINCT " or "") .. table_concat(columns, ", ")
		sql = sql .. " FROM " .. render_table(query.dialect, query.table)
	elseif query.query_type == "insert" then
		assert(#query.values > 0, "insert requires values")
		local first = query.values[1]
		local columns = {}
		for key in pairs(first) do columns[#columns + 1] = key end
		table_sort(columns)

		local rendered_columns = {}
		for i = 1, #columns do rendered_columns[i] = render_assignment_key(query.dialect, columns[i]) end

		local rows = {}
		for row_i = 1, #query.values do
			local row = query.values[row_i]
			local placeholders = {}
			for i = 1, #columns do placeholders[i] = ctx:add_param(row[columns[i]]) end
			rows[#rows + 1] = "(" .. table_concat(placeholders, ", ") .. ")"
		end

		sql = "INSERT INTO " .. render_table(query.dialect, query.table)
			.. " (" .. table_concat(rendered_columns, ", ") .. ") VALUES " .. table_concat(rows, ", ")

		if query.conflict and query.dialect.features.upsert then
			local assignments = {}
			for key in pairs(first) do
				assignments[#assignments + 1] = { key, "EXCLUDED." .. query.dialect:quote_identifier(key) }
			end
			table_sort(assignments, function(a, b) return a[1] < b[1] end)
			sql = sql .. query.dialect:render_upsert(query.conflict.columns, assignments)
		elseif query.conflict then
			return error("dialect does not support upsert", 2)
		end

		sql = sql .. query.dialect:render_returning(query.returning)
	elseif query.query_type == "update" then
		local assignments = {}
		for key, value in pairs(query.updates) do assignments[#assignments + 1] = { key, value } end
		assert(#assignments > 0, "update requires values")
		table_sort(assignments, function(a, b) return a[1] < b[1] end)

		local parts = {}
		for i = 1, #assignments do
			local key, value = assignments[i][1], assignments[i][2]
			local rendered
			if type(value) == "table" and has_method(value, "to_sql") then
				rendered = value:to_sql(ctx)
			else
				rendered = ctx:add_param(value)
			end
			parts[#parts + 1] = render_assignment_key(query.dialect, key) .. " = " .. rendered
		end

		sql = "UPDATE " .. render_table(query.dialect, query.table) .. " SET " .. table_concat(parts, ", ")
		sql = sql .. self:render_where(ctx)
		sql = sql .. query.dialect:limit_offset(query.limit_value, query.offset_value)
		sql = sql .. query.dialect:render_returning(query.returning)
	elseif query.query_type == "delete" then
		sql = "DELETE FROM " .. render_table(query.dialect, query.table)
		sql = sql .. self:render_where(ctx)
		sql = sql .. query.dialect:limit_offset(query.limit_value, query.offset_value)
	elseif query.query_type == "raw" then
		return query.table, normalize_params(query.raw_params)
	else
		return error("unknown query type: " .. tostring(query.query_type), 2)
	end

	if query.query_type == "select" then
		for i = 1, #query.joins do
			local join = query.joins[i]
			sql = sql .. " " .. join.kind .. " JOIN " .. render_table(query.dialect, join.table)
			if join.kind ~= "CROSS" then
				sql = sql ..
					" ON " ..
					query.dialect:quote_identifier(join.left) ..
					" " .. join.operator .. " " .. query.dialect:quote_identifier(join.right)
			end
		end

		sql = sql .. self:render_where(ctx)
		if #query.groups > 0 then
			local groups = {}
			for i = 1, #query.groups do groups[i] = query.dialect:quote_identifier(query.groups[i]) end
			sql = sql .. " GROUP BY " .. table_concat(groups, ", ")
		end
		if #query.havings > 0 then
			local havings = {}
			for i = 1, #query.havings do havings[i] = query.havings[i]:to_sql(ctx) end
			sql = sql .. " HAVING " .. table_concat(havings, " AND ")
		end
		if #query.orders > 0 then
			local orders = {}
			for i = 1, #query.orders do
				local order = query.orders[i]
				local column = order.column
				local rendered = type(column) == "table" and has_method(column, "to_sql") and column:to_sql(ctx) or
					query.dialect:quote_identifier(column)
				local direction = string_upper(order.direction or "ASC")
				if direction ~= "ASC" and direction ~= "DESC" then
					return error(
						"invalid order direction: " .. tostring(direction), 2)
				end
				orders[i] = rendered .. " " .. direction
			end
			sql = sql .. " ORDER BY " .. table_concat(orders, ", ")
		end
		sql = sql .. query.dialect:limit_offset(query.limit_value, query.offset_value)
	end

	query._built = { sql, ctx.params }
	return sql, ctx.params
end

function QueryCompiler:render_where(ctx)
	local query = self.query
	if #query.wheres == 0 then return "" end
	local parts = {}
	for i = 1, #query.wheres do
		local value = query.wheres[i]
		if type(value) == "table" and has_method(value, "to_sql") then
			parts[i] = value:to_sql(ctx)
		else
			return error("invalid WHERE expression at index " .. tostring(i), 2)
		end
	end
	return " WHERE " .. table_concat(parts, " AND ")
end

--- Fluent SQL query.
---@class SQLORM.Query
---@field connection SQLORM.Connection
---@field dialect SQLORM.Dialect
---@field query_type string
local Query = {}
Query.__index = Query

function Query:new(connection, query_type, table_name)
	return setmetatable({
		connection = connection,
		dialect = connection.dialect,
		query_type = query_type,
		table = table_name,
		selects = {},
		joins = {},
		wheres = {},
		groups = {},
		havings = {},
		orders = {},
		values = {},
		updates = {},
		set_clauses = {},
		distinct_flag = false,
		limit_value = nil,
		offset_value = nil,
		returning = {},
		conflict = nil,
		_built = nil,
	}, self)
end

function Query:clone()
	local copy = setmetatable({}, getmetatable(self))
	for key, value in pairs(self) do
		if key == "selects" or key == "joins" or key == "wheres" or key == "groups"
			or key == "havings" or key == "orders" or key == "values" or key == "updates"
			or key == "set_clauses" or key == "returning" then
			copy[key] = array_copy(value)
		elseif key == "_built" then
			copy[key] = nil
		else
			copy[key] = value
		end
	end
	return copy
end

function Query:select(...)
	local args = { ... }
	for i = 1, #args do
		local value = args[i]
		if type(value) == "table" then
			for j = 1, #value do
				self.selects[#self.selects + 1] = value[j]
			end
		else
			self.selects[#self.selects + 1] = value
		end
	end
	return self
end

function Query:distinct(value)
	self.distinct_flag = value ~= false
	return self
end

function Query:from(table_name, alias)
	self.table = { name = table_name, alias = alias }
	return self
end

function Query:join(table_name, left, operator, right, kind)
	self.joins[#self.joins + 1] = {
		kind = string_upper(kind or "INNER"),
		table = table_name,
		left = left,
		operator = operator or "=",
		right = right,
	}
	return self
end

function Query:left_join(table_name, left, operator, right)
	return self:join(table_name, left, operator, right, "LEFT")
end

function Query:right_join(table_name, left, operator, right)
	return self:join(table_name, left, operator, right, "RIGHT")
end

function Query:cross_join(table_name)
	self.joins[#self.joins + 1] = { kind = "CROSS", table = table_name }
	return self
end

function Query:where(column_or_expression, value, operator)
	if type(column_or_expression) == "table" and has_method(column_or_expression, "to_sql") then
		self.wheres[#self.wheres + 1] = column_or_expression
		return self
	end

	if type(column_or_expression) == "table" and value == nil and operator == nil then
		for column, condition in pairs(column_or_expression) do
			if type(condition) == "table" and has_method(condition, "to_sql") then
				self.wheres[#self.wheres + 1] = expr(function(ctx)
					return self.dialect:quote_identifier(column) .. " " .. condition:to_sql(ctx)
				end)
			elseif condition == nil then
				self.wheres[#self.wheres + 1] = expr(function(ctx)
					return self.dialect:quote_identifier(column) .. " IS NULL"
				end)
			else
				self.wheres[#self.wheres + 1] = expr(function(ctx)
					return self.dialect:quote_identifier(column) .. " = " .. ctx:add_param(condition)
				end)
			end
		end
		return self
	end

	local op_value = operator or "="
	if value == nil then
		if op_value == "=" then
			self.wheres[#self.wheres + 1] = expr(function(ctx)
				return self.dialect:quote_identifier(column_or_expression) .. " IS NULL"
			end)
		else
			self.wheres[#self.wheres + 1] = expr(function(ctx)
				return self.dialect:quote_identifier(column_or_expression) .. " IS NOT NULL"
			end)
		end
	else
		self.wheres[#self.wheres + 1] = expr(function(ctx)
			return self.dialect:quote_identifier(column_or_expression) .. " " .. op_value .. " " .. ctx:add_param(value)
		end)
	end
	return self
end

function Query:or_where(expression)
	if #self.wheres == 0 then
		return self:where(expression)
	end

	local previous = array_copy(self.wheres)
	self.wheres = {
		OP.or_(previous[#previous], expression),
	}

	-- Preserve all earlier predicates by nesting them.
	if #previous > 1 then
		self.wheres[1] = OP.or_(OP.and_(table_unpack(previous)), expression)
	end
	return self
end

function Query:where_not(expression)
	return self:where(OP.not_(expression))
end

function Query:where_in(column, values)
	return self:where(expr(function(ctx)
		return self.dialect:quote_identifier(column) .. " " .. OP.in_(values):to_sql(ctx)
	end))
end

function Query:where_not_in(column, values)
	return self:where(expr(function(ctx)
		return self.dialect:quote_identifier(column) .. " " .. OP.not_in(values):to_sql(ctx)
	end))
end

function Query:where_null(column)
	return self:where(expr(function()
		return self.dialect:quote_identifier(column) .. " IS NULL"
	end))
end

function Query:where_not_null(column)
	return self:where(expr(function()
		return self.dialect:quote_identifier(column) .. " IS NOT NULL"
	end))
end

function Query:group_by(...)
	local args = { ... }
	for i = 1, #args do
		self.groups[#self.groups + 1] = args[i]
	end
	return self
end

function Query:having(expression)
	self.havings[#self.havings + 1] = expression
	return self
end

function Query:order_by(column_or_order, direction)
	if type(column_or_order) == "table" then
		if column_or_order.column then
			self.orders[#self.orders + 1] = column_or_order
		else
			for i = 1, #column_or_order do
				self:order_by(column_or_order[i])
			end
		end
	else
		self.orders[#self.orders + 1] = {
			column = column_or_order,
			direction = string_upper(direction or "ASC"),
		}
	end
	return self
end

function Query:order_by_asc(column)
	return self:order_by(column, "ASC")
end

function Query:order_by_desc(column)
	return self:order_by(column, "DESC")
end

function Query:limit(value)
	value = tonumber(value)
	if not value or value < 0 or value ~= math_floor(value) then
		return error("limit must be a non-negative integer", 2)
	end
	self.limit_value = value
	return self
end

function Query:offset(value)
	value = tonumber(value)
	if not value or value < 0 or value ~= math_floor(value) then
		return error("offset must be a non-negative integer", 2)
	end
	self.offset_value = value
	return self
end

function Query:paginate(page, per_page)
	page = tonumber(page) or 1
	per_page = tonumber(per_page) or 25
	if page < 1 then page = 1 end
	if per_page < 1 then per_page = 1 end
	return self:limit(per_page):offset((page - 1) * per_page)
end

function Query:set(values)
	assert_type(values, "table", "update values")
	self.updates = values
	return self
end

function Query:values_insert(values)
	if values[1] ~= nil and type(values[1]) == "table" then
		self.values = values
	else
		self.values = { values }
	end
	return self
end

function Query:returning_columns(...)
	local args = { ... }
	for i = 1, #args do
		if type(args[i]) == "table" then
			for j = 1, #args[i] do
				self.returning[#self.returning + 1] = args[i][j]
			end
		else
			self.returning[#self.returning + 1] = args[i]
		end
	end
	return self
end

function Query:on_conflict(columns, assignments)
	self.conflict = {
		columns = columns,
		assignments = assignments,
	}
	return self
end

render_column = function(dialect, column)
	if type(column) == "table" and has_method(column, "to_sql") then
		return column
	elseif column == "*" then
		return "*"
	end
	return dialect:quote_identifier(column)
end

render_table = function(dialect, value)
	if type(value) == "table" then
		local sql = dialect:quote_identifier(value.name)
		if value.alias then
			sql = sql .. " AS " .. dialect:quote_identifier(value.alias)
		end
		return sql
	end
	return dialect:quote_identifier(value)
end

render_assignment_key = function(dialect, key)
	if is_identifier(key) then
		return dialect:quote_identifier(key)
	end
	return dialect:quote_identifier(key)
end

--- Compile this query through the injected SQL compiler policy.
---@param parent_context? table
---@return string sql
---@return table params
function Query:to_sql(parent_context)
	return QueryCompiler:new(self):compile(parent_context)
end

--- Query execution service.<br>
--- Responsibility: execute already-constructed Query objects against a Connection. It knows nothing about SQL rendering details.
local QueryExecutor = {}
QueryExecutor.__index = QueryExecutor

function QueryExecutor:new(connection)
	return setmetatable({ connection = connection }, self)
end

function QueryExecutor:prepare(query)
	local sql, params = query:to_sql()
	return self.connection:prepare(sql, params)
end

function QueryExecutor:execute(query)
	local sql, params = query:to_sql()
	return self.connection:execute(sql, params)
end

function QueryExecutor:all(query)
	local sql, params = query:to_sql()
	local result, err
	if query.query_type == "select" then
		result, err = self.connection:query(sql, params)
	else
		result, err = self.connection:execute(sql, params)
	end
	if err ~= nil then return nil, err end
	return result or {}
end

function Query:prepare()
	return QueryExecutor:new(self.connection):prepare(self)
end

function Query:execute()
	return QueryExecutor:new(self.connection):execute(self)
end

function Query:run()
	return self:execute()
end

function Query:all()
	return QueryExecutor:new(self.connection):all(self)
end

function Query:first()
	self:limit(1)
	local rows, err = self:all()
	if not rows then return nil, err end
	return rows[1]
end

function Query:value(column)
	self:select(column)
	local row, err = self:first()
	if not row then return nil, err end
	return row[column]
end

function Query:count(column)
	local old_select = self.selects
	self.selects = {}
	local expression = "COUNT(" ..
		(column and self.dialect:quote_identifier(column) or "*") .. ") AS " .. self.dialect:quote_identifier("count")
	self.selects[1] = expr(function() return expression end)
	local row, err = self:first()
	self.selects = old_select
	if not row then return nil, err end
	return tonumber(row.count or row["count"]) or 0
end

function Query:exists()
	local old_select = self.selects
	self.selects = {}
	self.selects[1] = expr(function() return "1" end)
	local row, err = self:first()
	self.selects = old_select
	if err then return nil, err end
	return row ~= nil
end

SQLORM.QueryCompiler = QueryCompiler
SQLORM.QueryExecutor = QueryExecutor

----------------------------------------------------------------------
-- Driver Adapter / Connection
----------------------------------------------------------------------

--- Adapter around an arbitrary Lua database binding.
---@class SQLORM.DriverAdapter
---@field raw table|userdata
---@field execute_method? string
---@field query_method? string
---@field prepare_method? string
local DriverAdapter = {}
DriverAdapter.__index = DriverAdapter

function DriverAdapter:new(driver, options)
	local driver_type = type(driver)
	if driver_type ~= "table" and driver_type ~= "userdata" then
		return error("driver must be a table or userdata, got " .. driver_type, 3)
	end
	local object = {
		raw = driver,
		options = options or {},
		execute_method = nil,
		query_method = nil,
		prepare_method = nil,
		close_method = nil,
	}

	object.execute_method = first_method(driver, {
		"execute", "exec", "run", "query_raw", "execute_query",
	})
	object.query_method = first_method(driver, {
		"query", "fetch_all", "select", "execute_query", "fetch",
	})
	object.prepare_method = first_method(driver, {
		"prepare", "prepare_statement",
	})
	object.close_method = first_method(driver, {
		"close", "disconnect",
	})

	if not object.execute_method and not object.query_method then
		return error("driver must provide execute/exec/run or query/fetch_all/select", 3)
	end

	return setmetatable(object, self)
end

function DriverAdapter:execute(sql, params)
	local method = self.execute_method
	if not method then
		method = self.query_method
	end
	local fn = self.raw[method]
	local ok, result, err = pcall(fn, self.raw, sql, params or {})
	if not ok then
		return nil, Error:new("DriverError", tostring(result), { sql = sql, params = params })
	end
	if err ~= nil then
		return result, Error:new("DriverError", tostring(err), { sql = sql, params = params })
	end
	return result
end

function DriverAdapter:query(sql, params)
	local method = self.query_method or self.execute_method
	local fn = self.raw[method]
	local ok, result, err = pcall(fn, self.raw, sql, params or {})
	if not ok then
		return nil, Error:new("DriverError", tostring(result), { sql = sql, params = params })
	end
	if err ~= nil then
		return result, Error:new("DriverError", tostring(err), { sql = sql, params = params })
	end

	-- Normalize common driver result shapes.
	if result == nil then
		return {}
	end
	if type(result) == "table" then
		if result.rows then
			return result.rows
		elseif result.fetchall then
			local ok_fetch, rows = pcall(result.fetchall, result)
			if ok_fetch then return rows end
		end
	end
	return result
end

function DriverAdapter:prepare(sql)
	if not self.prepare_method then
		return nil, Error:new("DriverError", "driver does not support prepare()", { sql = sql })
	end

	local fn = self.raw[self.prepare_method]
	local ok, statement, err = pcall(fn, self.raw, sql)
	if not ok then
		return nil, Error:new("DriverError", tostring(statement), { sql = sql })
	end
	if err ~= nil then
		return nil, Error:new("DriverError", tostring(err), { sql = sql })
	end
	return statement
end

function DriverAdapter:close()
	if not self.close_method then
		return true
	end
	local ok, result, err = pcall(self.raw[self.close_method], self.raw)
	if not ok then
		return nil, Error:new("DriverError", tostring(result))
	end
	if err ~= nil then
		return nil, Error:new("DriverError", tostring(err))
	end
	return result ~= false
end

--- Database connection facade.
--- High-level code depends on this abstraction rather than on a concrete SQL
--- library, satisfying dependency inversion and making test doubles trivial.
---@class SQLORM.Connection
local Connection = {}
Connection.__index = Connection

function Connection:new(driver, options)
	options = options or {}
	local adapter = getmetatable(driver) == DriverAdapter and driver or DriverAdapter:new(driver, options)
	local dialect = options.dialect or options.engine or "generic"
	dialect = SQLORM.dialect(dialect)

	return setmetatable({
		driver = adapter,
		dialect = dialect,
		options = options,
		transaction_depth = 0,
		transaction_failed = false,
		last_insert_id = nil,
	}, self)
end

function Connection:execute(sql, params)
	local result, err = self.driver:execute(sql, normalize_params(params))
	if err then
		return nil, err
	end

	if type(result) == "table" then
		if result.last_insert_id ~= nil then
			self.last_insert_id = result.last_insert_id
		elseif result.insert_id ~= nil then
			self.last_insert_id = result.insert_id
		end
	end
	return result
end

function Connection:query(sql, params)
	return self.driver:query(sql, normalize_params(params))
end

function Connection:prepare(sql, params)
	-- A native prepared statement is preferred. If the driver has no prepare
	-- capability, return a portable statement facade that reuses execute().
	local statement, err = self.driver:prepare(sql)
	if not statement and self.driver.prepare_method then
		return nil, err
	end

	if statement then
		return setmetatable({ connection = self, raw = statement, sql = sql, default_params = params or {} }, {
			__index = function(object, key)
				if key == "execute" then
					return function(_, values)
						local raw = object.raw
						local execute = first_method(raw, { "execute", "run", "step" })
						if not execute then
							return nil, Error:new("DriverError", "prepared statement lacks execute/run/step")
						end
						local ok, result, call_err = pcall(raw[execute], raw,
							table_unpack(values or object.default_params))
						if not ok then
							return nil, Error:new("DriverError", tostring(result), { sql = object.sql })
						end
						if call_err ~= nil then
							return nil, Error:new("DriverError", tostring(call_err), { sql = object.sql })
						end
						return result
					end
				elseif key == "reset" then
					return function()
						local reset = first_method(raw, { "reset", "clear_parameters" })
						if reset then
							return raw[reset](raw)
						end
						return true
					end
				elseif key == "close" then
					return function()
						local close = first_method(raw, { "close", "finalize" })
						if close then
							return raw[close](raw)
						end
						return true
					end
				end
			end,
		})
	end

	return setmetatable({
		connection = self,
		sql = sql,
		default_params = params or {},
	}, {
		__index = function(object, key)
			if key == "execute" then
				return function(_, values)
					return object.connection:execute(object.sql, values or object.default_params)
				end
			end
		end,
	})
end

function Connection:transaction(fn)
	assert_type(fn, "function", "transaction callback")

	if self.transaction_depth > 0 then
		self.transaction_depth = self.transaction_depth + 1
		local ok, result, err = pcall(fn, self)
		self.transaction_depth = self.transaction_depth - 1
		if not ok then
			self.transaction_failed = true
			return nil, Error:new("TransactionError", tostring(result))
		end
		if err ~= nil then
			self.transaction_failed = true
			return result, err
		end
		return result
	end

	self.transaction_depth = 1
	self.transaction_failed = false

	local begin_result, begin_err = self:execute("BEGIN")
	if begin_err then
		self.transaction_depth = 0
		return nil, Error:new("TransactionError", tostring(begin_err))
	end

	local ok, result, callback_err = pcall(fn, self)
	if not ok then
		self:execute("ROLLBACK")
		self.transaction_depth = 0
		return nil, Error:new("TransactionError", tostring(result))
	end

	if callback_err ~= nil or self.transaction_failed then
		self:execute("ROLLBACK")
		self.transaction_depth = 0
		return result, callback_err or Error:new("TransactionError", "transaction marked failed")
	end

	local commit_result, commit_err = self:execute("COMMIT")
	self.transaction_depth = 0
	if commit_err then
		self:execute("ROLLBACK")
		return nil, Error:new("TransactionError", tostring(commit_err))
	end
	return result, nil
end

function Connection:mark_transaction_failed()
	if self.transaction_depth > 0 then
		self.transaction_failed = true
	end
end

function Connection:query_builder()
	return setmetatable({ connection = self }, {
		__index = function(object, key)
			if key == "select" then
				return function(_, ...) return Query:new(object.connection, "select"):select(...) end
			elseif key == "insert" then
				return function(_, table_name) return Query:new(object.connection, "insert", table_name) end
			elseif key == "update" then
				return function(_, table_name) return Query:new(object.connection, "update", table_name) end
			elseif key == "delete" then
				return function(_, table_name) return Query:new(object.connection, "delete", table_name) end
			elseif key == "raw" then
				return function(_, sql, params)
					local query = Query:new(object.connection, "raw", sql)
					query.raw_params = params
					return query
				end
			end
		end,
	})
end

function Connection:select(...)
	return Query:new(self, "select"):select(...)
end

function Connection:insert(table_name, values)
	return Query:new(self, "insert", table_name):values_insert(values)
end

function Connection:update(table_name, values)
	return Query:new(self, "update", table_name):set(values)
end

function Connection:delete(table_name)
	return Query:new(self, "delete", table_name)
end

function Connection:raw(sql, params)
	local query = Query:new(self, "raw", sql)
	query.raw_params = params
	return query
end

function Connection:close()
	return self.driver:close()
end

---@param driver table|userdata
---@param options? table
---@return SQLORM.Connection
function SQLORM.open(driver, options)
	return Connection:new(driver, options)
end

SQLORM.Connection = Connection
SQLORM.Dialect = Dialect
SQLORM.interfaces = {
	---@diagnostic disable-next-line: undefined-field
	driver = { "execute", "query" },
	dialect = { "quote_identifier", "placeholder", "limit_offset", "render_returning", "render_upsert" },
	expression = { "to_sql" },
}
SQLORM.DriverAdapter = DriverAdapter
SQLORM.Query = Query
SQLORM.Dialect = Dialect
SQLORM.Expr = Expr

----------------------------------------------------------------------
-- Field definitions
----------------------------------------------------------------------

--- ORM field metadata and conversion/validation policy.
---@class SQLORM.Field
local Field = {}
Field.__index = Field

function Field:new(kind, options)
	options = options or {}
	local object = shallow_copy(options)
	object.kind = kind or object.kind or "text"
	object.name = object.name or options.column
	object.primary = options.primary == true
	object.nullable = options.nullable ~= false and options.not_null ~= true and not object.primary
	object.not_null = options.not_null == true or object.primary
	object.unique = options.unique == true
	object.auto_increment = options.auto_increment == true
	object.default = options.default
	object.has_default = options.default ~= nil
	object.references = options.references
	object.converter = options.converter
	object.validator = options.validator
	object.read = options.read
	object.write = options.write
	return setmetatable(object, self)
end

function Field:convert_from_database(value, model)
	if self.read then
		return self.read(value, model, self)
	end
	return value
end

function Field:convert_to_database(value, model)
	if self.write then
		return self.write(value, model, self)
	end
	if self.converter then
		if type(self.converter) == "table" and type(self.converter.to_database) == "function" then
			return self.converter:to_database(value, model, self)
		end
	end
	return value
end

function Field:validate(value, model)
	if value == nil and self.not_null and not self.has_default and not self.auto_increment then
		return nil, "field '" .. tostring(self.name) .. "' is required"
	end
	if self.validator then
		local ok, result = pcall(self.validator, value, model, self)
		if not ok then
			return nil, result
		end
		if result == false then
			return nil, "validation failed for field '" .. tostring(self.name) .. "'"
		elseif type(result) == "string" then
			return nil, result
		end
	end
	return true
end

local function field_factory(kind)
	return function(options)
		return Field:new(kind, options)
	end
end

SQLORM.Field = Field
SQLORM.field = {
	any = field_factory("any"),
	text = field_factory("text"),
	string = field_factory("text"),
	integer = field_factory("integer"),
	int = field_factory("integer"),
	real = field_factory("real"),
	float = field_factory("real"),
	boolean = field_factory("boolean"),
	bool = field_factory("boolean"),
	blob = field_factory("blob"),
	date = field_factory("date"),
	datetime = field_factory("datetime"),
	json = field_factory("json"),
}

----------------------------------------------------------------------
-- Model metadata
----------------------------------------------------------------------

--- ORM model metadata/factory facade. Persistence and relationship work are delegated to focused services while this object owns model configuration.
---@class SQLORM.ModelMeta
local ModelMeta = {}
ModelMeta.__index = ModelMeta

function ModelMeta:new(name, table_name, fields, options)
	options = options or {}
	local object = {
		name = name or table_name,
		table = table_name,
		fields = {},
		field_order = {},
		primary_key = nil,
		connection = nil,
		options = options,
		relations = {},
		scopes = {},
		callbacks = {},
		identity_map = {},
	}

	for key, definition in pairs(fields or {}) do
		local field
		if getmetatable(definition) == Field then
			field = definition
		else
			field = Field:new(type(definition) == "string" and definition or (definition and definition.kind) or "text",
				definition)
		end
		field.name = key
		object.fields[key] = field
		object.field_order[#object.field_order + 1] = key
		if field.primary then
			object.primary_key = key
		end
	end

	table_sort(object.field_order)
	object.primary_key = object.primary_key or options.primary_key or "id"

	return setmetatable(object, self)
end

function ModelMeta:bind(connection)
	self.connection = connection
	return self
end

function ModelMeta:field(name)
	return self.fields[name]
end

function ModelMeta:has_field(name)
	return self.fields[name] ~= nil
end

function ModelMeta:qualified_table(alias)
	if alias then
		return self.connection.dialect:quote_identifier(self.table) ..
			" AS " .. self.connection.dialect:quote_identifier(alias)
	end
	return self.connection.dialect:quote_identifier(self.table)
end

----------------------------------------------------------------------
-- Model instance
----------------------------------------------------------------------

--- ORM entity state/value object.
---@class SQLORM.ModelInstance
local ModelInstance = {}
ModelInstance.__index = ModelInstance

function ModelInstance:new(meta, values, persisted)
	local object = {
		_meta = meta,
		_data = {},
		_original = {},
		_dirty = {},
		_persisted = persisted ~= false,
		_relations = {},
		_errors = nil,
	}

	for key in pairs(meta.fields) do
		local value = values and values[key]
		object._data[key] = value
		object._original[key] = value
	end

	if values then
		for key, value in pairs(values) do
			if not meta.fields[key] then
				object._data[key] = value
			end
		end
	end

	if persisted == false then
		for key in pairs(object._data) do
			object._dirty[key] = true
		end
	end

	return setmetatable(object, self)
end

function ModelInstance:__index(key)
	local method = ModelInstance[key]
	if method then
		return method
	end

	local field = self._meta.fields[key]
	if field then
		return self:get(key)
	end

	if self._relations[key] ~= nil then
		return self._relations[key]
	end

	return rawget(self, key)
end

function ModelInstance:__newindex(key, value)
	if self._meta.fields[key] then
		self:set(key, value)
	elseif self._meta.relations[key] then
		self._relations[key] = value
	else
		rawset(self, key, value)
	end
end

function ModelInstance:__tostring()
	local pk = self:get(self._meta.primary_key)
	return string_format("%s<%s>", self._meta.name, tostring(pk))
end

function ModelInstance:get(key, default)
	local value = self._data[key]
	if value == nil then
		return default
	end

	local field = self._meta.fields[key]
	if field then
		return field:convert_from_database(value, self)
	end
	return value
end

function ModelInstance:set(key, value)
	local field = self._meta.fields[key]
	if not field then
		return error("unknown field '" .. tostring(key) .. "' on " .. self._meta.name, 2)
	end

	local old = self._data[key]
	local written = field:convert_to_database(value, self)
	self._data[key] = written
	if old ~= written then
		self._dirty[key] = true
	else
		self._dirty[key] = nil
	end
	return self
end

function ModelInstance:fill(values)
	for key, value in pairs(values or {}) do
		if self._meta.fields[key] then
			self:set(key, value)
		elseif self._meta.options.strict_fill then
			return error("unknown fill field '" .. tostring(key) .. "'", 2)
		end
	end
	return self
end

function ModelInstance:to_table(options)
	options = options or {}
	local result = {}
	for key in pairs(self._data) do
		if not self._meta.fields[key] or options.fields == nil or options.fields[key] then
			result[key] = self:get(key)
		end
	end
	return result
end

function ModelInstance:dirty(field)
	if field then
		return self._dirty[field] == true
	end
	for key in pairs(self._dirty) do
		if self._dirty[key] then
			return true
		end
	end
	return false
end

function ModelInstance:dirty_fields()
	local result = {}
	for key in pairs(self._dirty) do
		if self._dirty[key] then
			result[#result + 1] = key
		end
	end
	table_sort(result)
	return result
end

function ModelInstance:is_new()
	return not self._persisted
end

function ModelInstance:exists()
	return self._persisted
end

function ModelInstance:errors()
	return self._errors
end

function ModelInstance:validate()
	local errors = {}
	for name, field in pairs(self._meta.fields) do
		local ok, err = field:validate(self._data[name], self)
		if not ok then
			errors[name] = err
		end
	end

	self._errors = next(errors) and errors or nil
	if self._errors then
		return false, self._errors
	end
	return true
end

function ModelInstance:reload()
	local pk = self:get(self._meta.primary_key)
	if pk == nil then
		return nil, Error:new("ORMError", "cannot reload a model without a primary key")
	end

	local fresh, err = self._meta:query():where(self._meta.primary_key, pk):first()
	if not fresh then
		return nil, err or Error:new("ORMError", "record no longer exists")
	end

	for key, value in pairs(fresh._data) do
		self._data[key] = value
		self._original[key] = value
	end
	self._dirty = {}
	self._relations = {}
	return self
end

function ModelInstance:delete()
	return self._meta:delete_instance(self)
end

function ModelInstance:save(options)
	return self._meta:save_instance(self, options)
end

function ModelInstance:refresh()
	return self:reload()
end

----------------------------------------------------------------------
-- ORM Query wrapper
----------------------------------------------------------------------

local ModelQuery = {}
ModelQuery.__index = ModelQuery

function ModelQuery:new(meta, query)
	return setmetatable({ model = meta, query = query }, self)
end

function ModelQuery:clone()
	return ModelQuery:new(self.model, self.query:clone())
end

function ModelQuery:where(column_or_expression, value, operator)
	self.query:where(column_or_expression, value, operator)
	return self
end

function ModelQuery:or_where(expression)
	self.query:or_where(expression)
	return self
end

function ModelQuery:where_not(expression)
	self.query:where_not(expression)
	return self
end

function ModelQuery:where_in(column, values)
	self.query:where_in(column, values)
	return self
end

function ModelQuery:where_not_in(column, values)
	self.query:where_not_in(column, values)
	return self
end

function ModelQuery:where_null(column)
	self.query:where_null(column)
	return self
end

function ModelQuery:where_not_null(column)
	self.query:where_not_null(column)
	return self
end

function ModelQuery:where_id(id)
	return self:where(self.model.primary_key, id)
end

function ModelQuery:select(...)
	self.query.selects = {}
	self.query:select(...)
	return self
end

function ModelQuery:distinct(value)
	self.query:distinct(value)
	return self
end

function ModelQuery:join(table_name, left, operator, right, kind)
	self.query:join(table_name, left, operator, right, kind)
	return self
end

function ModelQuery:left_join(table_name, left, operator, right)
	self.query:left_join(table_name, left, operator, right)
	return self
end

function ModelQuery:group_by(...)
	self.query:group_by(...)
	return self
end

function ModelQuery:having(expression)
	self.query:having(expression)
	return self
end

function ModelQuery:order_by(column, direction)
	self.query:order_by(column, direction)
	return self
end

function ModelQuery:order_by_desc(column)
	self.query:order_by_desc(column)
	return self
end

function ModelQuery:order_by_asc(column)
	self.query:order_by_asc(column)
	return self
end

function ModelQuery:limit(value)
	self.query:limit(value)
	return self
end

function ModelQuery:offset(value)
	self.query:offset(value)
	return self
end

function ModelQuery:paginate(page, per_page)
	self.query:paginate(page, per_page)
	return self
end

function ModelQuery:to_sql()
	return self.query:to_sql()
end

function ModelQuery:all()
	local rows, err = self.query:all()
	if not rows then
		return nil, err
	end

	local models = {}
	for i = 1, #rows do
		models[i] = self.model:hydrate(rows[i], true)
	end
	return self:load_relations(models)
end

function ModelQuery:first()
	local row, err = self.query:first()
	if not row then
		return nil, err
	end
	return self.model:hydrate(row, true)
end

function ModelQuery:find(id)
	return self:where_id(id):first()
end

function ModelQuery:count()
	return self.query:count()
end

function ModelQuery:exists()
	return self.query:exists()
end

function ModelQuery:delete()
	return self.query:execute()
end

function ModelQuery:update(values)
	local update = Query:new(self.model.connection, "update", self.model.table)
	update:set(values)
	update.wheres = self.query.wheres
	update.limit_value = self.query.limit_value
	update.offset_value = self.query.offset_value
	return update:execute()
end

function ModelQuery:with(relation)
	self._with = self._with or {}
	self._with[#self._with + 1] = relation
	return self
end

function ModelQuery:load_relations(models)
	local names = self._with
	if not names or #names == 0 or #models == 0 then
		return models
	end

	for i = 1, #names do
		self.model:preload_relation(models, names[i])
	end
	return models
end

----------------------------------------------------------------------
-- Relationships
----------------------------------------------------------------------

--- Relationship definition. Loading policy is supplied by ModelMeta rather
--- than embedded into the relation object, keeping the relation a value object.
---@class SQLORM.Relation
local Relation = {}
Relation.__index = Relation

function Relation:new(kind, target, options)
	options = options or {}
	return setmetatable({
		kind = kind,
		target = target,
		foreign_key = options.foreign_key,
		local_key = options.local_key,
		pivot_table = options.pivot_table,
		pivot_foreign_key = options.pivot_foreign_key,
		pivot_related_key = options.pivot_related_key,
		relation_name = options.name,
	}, self)
end

local function relation_factory(kind)
	return function(target, options)
		return Relation:new(kind, target, options)
	end
end

SQLORM.relation = {
	belongs_to = relation_factory("belongs_to"),
	has_one = relation_factory("has_one"),
	has_many = relation_factory("has_many"),
	many_to_many = relation_factory("many_to_many"),
}
SQLORM.Relation = Relation

local function default_foreign_key(model, local_key)
	return string_lower(model.name) .. "_" .. string_lower(local_key or model.primary_key)
end

function ModelMeta:relation(name, definition)
	definition.relation_name = name
	self.relations[name] = definition
	return self
end

function ModelMeta:belongs_to(name, target, options)
	options = options or {}
	options.foreign_key = options.foreign_key or string_lower(name) .. "_id"
	options.local_key = options.local_key or self.fields[options.foreign_key] and options.foreign_key or self
		.primary_key
	return self:relation(name, Relation:new("belongs_to", target, options))
end

function ModelMeta:has_many(name, target, options)
	options = options or {}
	options.local_key = options.local_key or self.primary_key
	options.foreign_key = options.foreign_key or default_foreign_key(self, options.local_key)
	return self:relation(name, Relation:new("has_many", target, options))
end

function ModelMeta:has_one(name, target, options)
	options = options or {}
	options.local_key = options.local_key or self.primary_key
	options.foreign_key = options.foreign_key or default_foreign_key(self, options.local_key)
	return self:relation(name, Relation:new("has_one", target, options))
end

function ModelMeta:many_to_many(name, target, options)
	options = options or {}
	options.pivot_table = assert(options.pivot_table, "many_to_many requires pivot_table")
	options.pivot_foreign_key = options.pivot_foreign_key or default_foreign_key(self, self.primary_key)
	options.pivot_related_key = options.pivot_related_key or default_foreign_key(target, target.primary_key)
	options.local_key = options.local_key or self.primary_key
	options.foreign_key = options.foreign_key or target.primary_key
	return self:relation(name, Relation:new("many_to_many", target, options))
end

function ModelMeta:relation_query(instance, relation)
	local target = relation.target
	assert(target.connection, "related model is not bound to a connection")

	if relation.kind == "belongs_to" then
		local foreign_value = instance:get(relation.foreign_key)
		if foreign_value == nil then
			return target:query():where(target.primary_key, nil)
		end
		return target:query():where(relation.local_key or target.primary_key, foreign_value)
	elseif relation.kind == "has_many" or relation.kind == "has_one" then
		local local_value = instance:get(relation.local_key or self.primary_key)
		return target:query():where(relation.foreign_key, local_value)
	elseif relation.kind == "many_to_many" then
		local local_value = instance:get(relation.local_key or self.primary_key)
		local pivot = relation.pivot_table
		local target_key = relation.foreign_key or target.primary_key
		local pivot_related = relation.pivot_related_key
		local subquery = target.connection:select(target.connection.dialect:quote_identifier(pivot_related))
			:from(pivot)
			:where(relation.pivot_foreign_key, local_value)

		return target:query()
			:where_in(target_key, subquery)
	end

	return error("unknown relationship kind: " .. tostring(relation.kind), 2)
end

function ModelMeta:load_relation(instance, name)
	local relation = self.relations[name]
	if not relation then
		return nil, Error:new("ORMError", "unknown relation '" .. tostring(name) .. "'")
	end

	local query = self:relation_query(instance, relation)
	local value, err
	if relation.kind == "has_one" or relation.kind == "belongs_to" then
		value, err = query:first()
	else
		value, err = query:all()
	end

	if err then
		return nil, err
	end
	instance._relations[name] = value
	return value
end

function ModelMeta:preload_relation(instances, name)
	local relation = self.relations[name]
	if not relation then
		return nil, Error:new("ORMError", "unknown relation '" .. tostring(name) .. "'")
	end

	if relation.kind == "belongs_to" then
		local foreign_values = {}
		local seen = {}
		for i = 1, #instances do
			local value = instances[i]:get(relation.foreign_key)
			if value ~= nil and not seen[value] then
				seen[value] = true
				foreign_values[#foreign_values + 1] = value
			end
		end
		if #foreign_values == 0 then return instances end

		local rows, err = relation.target:query():where_in(relation.local_key or relation.target.primary_key,
			foreign_values):all()
		if not rows then return nil, err end
		local lookup = {}
		for i = 1, #rows do
			lookup[rows[i]:get(relation.local_key or relation.target.primary_key)] = rows[i]
		end
		for i = 1, #instances do
			instances[i]._relations[name] = lookup[instances[i]:get(relation.foreign_key)]
		end
		return instances
	end

	local local_values = {}
	local seen = {}
	for i = 1, #instances do
		local value = instances[i]:get(relation.local_key or self.primary_key)
		if value ~= nil and not seen[value] then
			seen[value] = true
			local_values[#local_values + 1] = value
		end
	end
	if #local_values == 0 then return instances end

	local children, err
	if relation.kind == "many_to_many" then
		children, err = self:_preload_many_to_many(instances, relation, local_values)
	else
		children, err = relation.target:query():where_in(relation.foreign_key, local_values):all()
	end
	if not children then return nil, err end

	local grouped = {}
	for i = 1, #children do
		local child = children[i]
		local key = relation.kind == "many_to_many"
			and child._data.__sqlorm_pivot_local
			or child:get(relation.foreign_key)
		grouped[key] = grouped[key] or {}
		grouped[key][#grouped[key] + 1] = child
	end

	for i = 1, #instances do
		local key = instances[i]:get(relation.local_key or self.primary_key)
		if relation.kind == "has_one" then
			instances[i]._relations[name] = grouped[key] and grouped[key][1] or nil
		else
			instances[i]._relations[name] = grouped[key] or {}
		end
	end

	return instances
end

function ModelMeta:_preload_many_to_many(instances, relation, local_values)
	local dialect = self.connection.dialect
	local pivot = dialect:quote_identifier(relation.pivot_table)
	local target_table = dialect:quote_identifier(relation.target.table)
	local target_pk = dialect:quote_identifier(relation.target.primary_key)
	local pivot_local = dialect:quote_identifier(relation.pivot_foreign_key)
	local pivot_related = dialect:quote_identifier(relation.pivot_related_key)

	local placeholders = {}
	local params = {}
	for i = 1, #local_values do
		params[#params + 1] = local_values[i]
		placeholders[i] = dialect:placeholder(#params)
	end

	local local_alias = dialect:quote_identifier("__sqlorm_pivot_local")
	local sql = "SELECT " .. target_table .. ".*, " .. pivot .. "." .. pivot_local
		.. " AS " .. local_alias
		.. " FROM " .. target_table
		.. " INNER JOIN " .. pivot
		.. " ON " .. target_table .. "." .. target_pk
		.. " = " .. pivot .. "." .. pivot_related
		.. " WHERE " .. pivot .. "." .. pivot_local
		.. " IN (" .. table_concat(placeholders, ", ") .. ")"

	local rows, err = self.connection:query(sql, params)
	if not rows then return nil, err end

	local models = {}
	for i = 1, #rows do
		local row = rows[i]
		local pivot_value = row["__sqlorm_pivot_local"]
		local model = relation.target:hydrate(row, true)
		model._data.__sqlorm_pivot_local = pivot_value
		models[i] = model
	end

	return models
end

----------------------------------------------------------------------
-- Model metadata CRUD / schema
----------------------------------------------------------------------

function ModelMeta:query()
	assert(self.connection, "model is not bound to a connection")
	local query = Query:new(self.connection, "select", self.table):select("*")
	return ModelQuery:new(self, query)
end

function ModelMeta:new_instance(values)
	return ModelInstance:new(self, values or {}, false)
end

function ModelMeta:hydrate(row, persisted)
	local pk = row[self.primary_key]
	if pk ~= nil and self.options.identity_map ~= false then
		local cached = self.identity_map[pk]
		if cached then
			for key, value in pairs(row) do
				if self.fields[key] then
					cached._data[key] = value
				end
			end
			return cached
		end
	end

	local instance = ModelInstance:new(self, row, persisted ~= false)
	if pk ~= nil and self.options.identity_map ~= false then
		self.identity_map[pk] = instance
	end
	return instance
end

function ModelMeta:create(values, options)
	local instance = self:new_instance(values)
	local ok, err = self:save_instance(instance, options)
	if not ok then
		return nil, err
	end
	return instance
end

function ModelMeta:find(id)
	return self:query():find(id)
end

function ModelMeta:find_or_fail(id)
	local model, err = self:find(id)
	if not model then
		return nil, err or Error:new("ORMError", "record not found")
	end
	return model
end

function ModelMeta:all()
	return self:query():all()
end

function ModelMeta:where(column_or_expression, value, operator)
	return self:query():where(column_or_expression, value, operator)
end

function ModelMeta:count(conditions)
	local query = self:query()
	if conditions then query:where(conditions) end
	return query:count()
end

function ModelMeta:exists(conditions)
	local query = self:query()
	if conditions then query:where(conditions) end
	return query:exists()
end

function ModelMeta:delete_where(conditions)
	local query = Query:new(self.connection, "delete", self.table)
	if conditions then query:where(conditions) end
	return query:execute()
end

function ModelMeta:save_instance(instance, options)
	options = options or {}
	local valid, validation_errors = instance:validate()
	if not valid and options.validate ~= false then
		return nil, Error:new("ValidationError", "model validation failed", validation_errors)
	end

	local callbacks = self.callbacks
	if not instance._persisted and callbacks.before_create then
		local ok, err = callbacks.before_create(instance)
		if ok == false then return nil, err end
	end
	if instance._persisted and callbacks.before_update then
		local ok, err = callbacks.before_update(instance)
		if ok == false then return nil, err end
	end
	if callbacks.before_save then
		local ok, err = callbacks.before_save(instance)
		if ok == false then return nil, err end
	end

	local pk_name = self.primary_key
	local pk_field = self.fields[pk_name]
	local pk_value = instance:get(pk_name)

	if not instance._persisted then
		local insert_values = {}
		for name, field in pairs(self.fields) do
			local value = instance._data[name]
			if value ~= nil or (field.has_default and options.include_default_values) then
				insert_values[name] = field:convert_to_database(value, instance)
			end
		end

		local query = Query:new(self.connection, "insert", self.table):values_insert(insert_values)
		if self.connection.dialect.features.returning and pk_field then
			query:returning_columns(pk_name)
		end

		local result, err = query:execute()
		if err then return nil, err end

		local inserted_id = self.connection.last_insert_id
		if type(result) == "table" and result[1] and result[1][pk_name] ~= nil then
			inserted_id = result[1][pk_name]
		elseif type(result) == "table" and result[pk_name] ~= nil then
			inserted_id = result[pk_name]
		end

		if pk_field and pk_value == nil and inserted_id ~= nil then
			instance._data[pk_name] = inserted_id
		end

		instance._persisted = true
		for name, value in pairs(instance._data) do
			instance._original[name] = value
			instance._dirty[name] = nil
		end

		if instance._data[pk_name] ~= nil and self.options.identity_map ~= false then
			self.identity_map[instance._data[pk_name]] = instance
		end

		if callbacks.after_create then callbacks.after_create(instance) end
	else
		local dirty = instance:dirty_fields()
		if #dirty > 0 then
			local updates = {}
			for i = 1, #dirty do
				local name = dirty[i]
				if name ~= pk_name then
					updates[name] = self.fields[name]:convert_to_database(instance._data[name], instance)
				end
			end

			if next(updates) then
				local query = Query:new(self.connection, "update", self.table):set(updates)
					:where(pk_name, pk_value)
				local result, err = query:execute()
				if err then return nil, err end
			end

			for name, value in pairs(instance._data) do
				instance._original[name] = value
				instance._dirty[name] = nil
			end
		end

		if callbacks.after_update then callbacks.after_update(instance) end
	end

	if callbacks.after_save then callbacks.after_save(instance) end
	return true
end

function ModelMeta:delete_instance(instance)
	local pk = instance:get(self.primary_key)
	if pk == nil then
		return nil, Error:new("ORMError", "cannot delete a model without a primary key")
	end

	if self.callbacks.before_delete then
		local ok, err = self.callbacks.before_delete(instance)
		if ok == false then return nil, err end
	end

	local result, err = Query:new(self.connection, "delete", self.table)
		:where(self.primary_key, pk)
		:execute()
	if err then return nil, err end

	instance._persisted = false
	self.identity_map[pk] = nil

	if self.callbacks.after_delete then
		self.callbacks.after_delete(instance)
	end
	return result or true
end

function ModelMeta:on(event, callback)
	self.callbacks[event] = callback
	return self
end

function ModelMeta:scope(name, callback)
	self.scopes[name] = callback
	return self
end

function ModelMeta:use_scope(query, name, ...)
	local callback = self.scopes[name]
	if not callback then
		return error("unknown model scope '" .. tostring(name) .. "'", 2)
	end
	return callback(query, ...)
end

----------------------------------------------------------------------
-- Schema generation / migrations
----------------------------------------------------------------------

---@class SQLORM.Schema
local Schema = {}
Schema.__index = Schema

function Schema:new(connection)
	return setmetatable({ connection = connection }, self)
end

function Schema:type_sql(field)
	local dialect = self.connection.dialect
	local type_name
	if field.kind == "integer" then
		type_name = "INTEGER"
	elseif field.kind == "real" then
		type_name = "REAL"
	elseif field.kind == "boolean" then
		type_name = dialect.name == "mysql" and "BOOLEAN" or "INTEGER"
	elseif field.kind == "blob" then
		type_name = dialect.name == "mysql" and "BLOB" or "BLOB"
	elseif field.kind == "date" then
		type_name = "DATE"
	elseif field.kind == "datetime" then
		type_name = dialect.name == "postgresql" and "TIMESTAMP" or "DATETIME"
	elseif field.kind == "json" then
		type_name = dialect.name == "postgresql" and "JSONB" or "TEXT"
	else
		type_name = "TEXT"
	end

	local sql = type_name
	if field.primary then
		sql = sql .. " PRIMARY KEY"
		if field.auto_increment and dialect.name == "sqlite" then
			sql = sql .. dialect:auto_increment_sql()
		elseif field.auto_increment and dialect.name == "mysql" then
			sql = sql .. " AUTO_INCREMENT"
		elseif field.auto_increment and dialect.name == "postgresql" then
			-- Best-effort serial mapping happens below through declaration.
		end
	end

	if field.not_null and not field.primary then
		sql = sql .. " NOT NULL"
	end
	if field.unique and not field.primary then
		sql = sql .. " UNIQUE"
	end
	if field.has_default then
		if type(field.default) == "function" then
			sql = sql .. " DEFAULT " .. tostring(field.default(self.connection.dialect))
		else
			sql = sql .. " DEFAULT " .. dialect:quote_literal(field.default)
		end
	end
	return sql
end

function Schema:create_table(meta, options)
	options = options or {}
	local dialect = self.connection.dialect
	local columns = {}
	for i = 1, #meta.field_order do
		local name = meta.field_order[i]
		local field = meta.fields[name]
		local declaration
		if field.auto_increment and field.primary and dialect.name == "postgresql" and field.kind == "integer" then
			declaration = "SERIAL PRIMARY KEY"
		else
			declaration = self:type_sql(field)
		end
		columns[#columns + 1] = dialect:quote_identifier(name) .. " " .. declaration
	end

	local sql = "CREATE TABLE " .. (options.if_not_exists and "IF NOT EXISTS " or "")
		.. dialect:quote_identifier(meta.table)
		.. " (" .. table_concat(columns, ", ") .. ")"
	return self.connection:execute(sql)
end

function Schema:drop_table(meta, options)
	options = options or {}
	local sql = "DROP TABLE " .. (options.if_exists and "IF EXISTS " or "")
		.. self.connection.dialect:quote_identifier(meta.table)
	return self.connection:execute(sql)
end

function Schema:truncate(meta)
	local sql
	if self.connection.dialect.name == "sqlite" then
		sql = "DELETE FROM " .. self.connection.dialect:quote_identifier(meta.table)
	else
		sql = "TRUNCATE TABLE " .. self.connection.dialect:quote_identifier(meta.table)
	end
	return self.connection:execute(sql)
end

SQLORM.Schema = Schema

----------------------------------------------------------------------
-- Model factory
----------------------------------------------------------------------

---@param name string
---@param table_name string
---@param fields table<string, SQLORM.Field|table|string>
---@param options? table
---@return SQLORM.ModelMeta
function SQLORM.model_class(name, table_name, fields, options)
	return ModelMeta:new(name, table_name, fields, options)
end

SQLORM.Model = {
	define = SQLORM.model_class,
	Meta = ModelMeta,
	Instance = ModelInstance,
}

----------------------------------------------------------------------
-- Convenience model configuration for loose interface integration
----------------------------------------------------------------------

function SQLORM.bind_model(model, connection)
	if has_method(model, "bind") then
		return model:bind(connection)
	end

	-- Loose interface fallback: any table with a plausible metadata layout can
	-- be bound without inheriting from ModelMeta.
	model.connection = connection
	return model
end

function SQLORM.is_driver(value)
	return type(value) == "table"
		and (has_method(value, "execute") or has_method(value, "exec") or has_method(value, "query"))
end

function SQLORM.is_connection(value)
	return type(value) == "table"
		and has_method(value, "execute")
		and has_method(value, "query")
		and value.dialect ~= nil
end

function SQLORM.is_query(value)
	return type(value) == "table" and has_method(value, "to_sql") and has_method(value, "execute")
end

----------------------------------------------------------------------
-- Identifier helpers / query fragments
----------------------------------------------------------------------

function SQLORM.identifier(name)
	assert_type(name, "string", "identifier")
	return expr(function(ctx)
		return ctx.dialect:quote_identifier(name)
	end)
end

function SQLORM.column(name, alias)
	return expr(function(ctx)
		local sql = ctx.dialect:quote_identifier(name)
		if alias then
			sql = sql .. " AS " .. ctx.dialect:quote_identifier(alias)
		end
		return sql
	end)
end

local function function_expression(name, ...)
	assert_type(name, "string", "function name")
	local args = { ... }
	return expr(function(ctx)
		local rendered = {}
		for i = 1, #args do
			local argument = args[i]
			if type(argument) == "table" and has_method(argument, "to_sql") then
				rendered[i] = argument:to_sql(ctx)
			elseif argument == "*" then
				rendered[i] = "*"
			else
				rendered[i] = ctx.dialect:quote_identifier(argument)
			end
		end
		return string_upper(name) .. "(" .. table_concat(rendered, ", ") .. ")"
	end)
end

SQLORM.fn = setmetatable({
	count = function(column) return function_expression("COUNT", column or "*") end,
	sum = function(column) return function_expression("SUM", column) end,
	avg = function(column) return function_expression("AVG", column) end,
	min = function(column) return function_expression("MIN", column) end,
	max = function(column) return function_expression("MAX", column) end,
}, {
	__call = function(_, name, ...)
		return function_expression(name, ...)
	end,
})

function SQLORM.alias(expression, alias)
	return {
		expression = expression,
		alias = alias,
	}
end

----------------------------------------------------------------------
-- Transactions helper
----------------------------------------------------------------------

---@param connection SQLORM.Connection
---@param callback fun(connection: SQLORM.Connection): any
---@return any result, any error
function SQLORM.transaction(connection, callback)
	assert(SQLORM.is_connection(connection), "expected SQLORM connection")
	return connection:transaction(callback)
end

----------------------------------------------------------------------
-- Debugging / SQL inspection
----------------------------------------------------------------------

function SQLORM.interpolate_for_debug(connection_or_dialect, sql, params)
	local dialect = connection_or_dialect.dialect or connection_or_dialect
	local result = sql
	local index = 0

	-- Debug-only interpolation. Never use this for execution.
	local function replace_question()
		index = index + 1
		return dialect:quote_literal(params[index])
	end

	if dialect.placeholder_style == "question" then
		result = string_gsub(result, "?", replace_question)
	else
		for i = #params, 1, -1 do
			local placeholder = dialect:placeholder(i)
			result = string_gsub(result, "%$?" .. tostring(i), dialect:quote_literal(params[i]))
			result = string_gsub(result, ":" .. tostring(i), dialect:quote_literal(params[i]))
		end
	end
	return result
end

function SQLORM.inspect_query(query)
	local sql, params = query:to_sql()
	return {
		sql = sql,
		params = array_copy(params),
	}
end

----------------------------------------------------------------------
-- Simple migrations runner
----------------------------------------------------------------------

---@class SQLORM.MigrationRunner
local MigrationRunner = {}
MigrationRunner.__index = MigrationRunner

function MigrationRunner:new(connection, table_name)
	return setmetatable({ connection = connection, table = table_name or "schema_migrations" }, self)
end

function MigrationRunner:ensure_table()
	local dialect = self.connection.dialect
	local sql = "CREATE TABLE IF NOT EXISTS " .. dialect:quote_identifier(self.table)
		.. " (" .. dialect:quote_identifier("id") .. " INTEGER PRIMARY KEY, "
		.. dialect:quote_identifier("name") .. " TEXT NOT NULL UNIQUE)"
	return self.connection:execute(sql)
end

function MigrationRunner:has(name)
	local row, err = self.connection:select("id"):from(self.table):where("name", name):first()
	if err then return nil, err end
	return row ~= nil
end

function MigrationRunner:mark(name)
	return self.connection:insert(self.table, { name = name }):execute()
end

function MigrationRunner:run(migrations)
	local ok, err = self:ensure_table()
	if err then return nil, err end

	for i = 1, #migrations do
		local migration = migrations[i]
		local name = migration.name or tostring(i)
		local applied, check_err = self:has(name)
		if check_err then return nil, check_err end
		if not applied then
			local result, tx_err = self.connection:transaction(function(connection)
				if migration.up then
					local success, callback_err = migration.up(connection)
					if success == false then
						return error(callback_err or "migration failed")
					end
				end
				local marked, mark_err = self:mark(name)
				if mark_err then return error(mark_err) end
				return marked
			end)
			if tx_err then return nil, tx_err end
		end
	end
	return true
end

function MigrationRunner:rollback_last(migrations)
	local row, err = self.connection:select("id", "name")
		:from(self.table)
		:order_by_desc("id")
		:first()
	if err then return nil, err end
	if not row then return false end

	local selected
	for i = 1, #migrations do
		local migration = migrations[i]
		if (migration.name or tostring(i)) == row.name then
			selected = migration
			break
		end
	end
	if not selected then
		return nil, Error:new("ORMError", "migration definition not found: " .. tostring(row.name))
	end

	local success, tx_err = self.connection:transaction(function(connection)
		if selected.down then
			local down_ok, down_err = selected.down(connection)
			if down_ok == false then
				return error(down_err or "migration rollback failed")
			end
		end
		local result, delete_err = connection:delete(self.table):where("id", row.id):execute()
		if delete_err then return error(delete_err) end
		return result
	end)
	if tx_err then return nil, tx_err end
	return success
end

SQLORM.MigrationRunner = MigrationRunner

----------------------------------------------------------------------
-- Driver shims for popular loose APIs
----------------------------------------------------------------------

function SQLORM.wrap(driver, options)
	if getmetatable(driver) == DriverAdapter then
		return Connection:new(driver, options)
	end
	return Connection:new(driver, options)
end

function SQLORM.adapter(driver, options)
	return DriverAdapter:new(driver, options)
end

-- Build a loose-interface adapter around a plain function table.
function SQLORM.function_driver(execute_fn, query_fn, close_fn)
	assert_type(execute_fn, "function", "execute function")
	return {
		execute = function(_, sql, params)
			return execute_fn(sql, params)
		end,
		query = function(_, sql, params)
			if query_fn then
				return query_fn(sql, params)
			end
			return execute_fn(sql, params)
		end,
		close = function(_)
			if close_fn then
				return close_fn()
			end
			return true
		end,
	}
end

----------------------------------------------------------------------
-- Optional DAO / Repository layer
----------------------------------------------------------------------

---@class SQLORM.Repository
local Repository = {}
Repository.__index = Repository

function Repository:new(model)
	return setmetatable({ model = model }, self)
end

function Repository:find(id)
	return self.model:find(id)
end

function Repository:get(id)
	local result, err = self:find(id)
	if not result then
		return nil, err or Error:new("ORMError", "entity not found")
	end
	return result
end

function Repository:all()
	return self.model:all()
end

function Repository:find_by(values)
	return self.model:query():where(values):first()
end

function Repository:filter(values)
	return self.model:query():where(values)
end

function Repository:create(values)
	return self.model:create(values)
end

function Repository:delete(id)
	return self.model:delete_where({ [self.model.primary_key] = id })
end

function Repository:count(values)
	return self.model:count(values)
end

SQLORM.Repository = Repository

---@param model SQLORM.ModelMeta
---@return SQLORM.Repository
function SQLORM.repository(model)
	return Repository:new(model)
end

----------------------------------------------------------------------
-- Exports and compatibility aliases
----------------------------------------------------------------------

SQLORM.Connection = Connection
SQLORM.Driver = DriverAdapter
SQLORM.ModelMeta = ModelMeta
SQLORM.ModelInstance = ModelInstance
SQLORM.ModelQuery = ModelQuery

-- Short aliases useful in application code.
SQLORM.db = SQLORM.open
SQLORM.connect = SQLORM.open
SQLORM.define_model = SQLORM.model_class

-- Export
return SQLORM
