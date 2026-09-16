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
local string_sub = string.sub
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

--- Copy table shallowly.
---@param source? table Source table to copy.
---@return table result Shallow copy result.
local function shallow_copy(source)
	local result = {}
	if source then
		for key, value in pairs(source) do
			result[key] = value
		end
	end
	return result
end

--- Copy array values.
---@param source? table Source array to copy.
---@return table result Copied array table.
local function array_copy(source)
	local result = {}
	if source then
		for i = 1, #source do
			result[i] = source[i]
		end
	end
	return result
end

--- Merge source into target.
---@param target table Target table to extend.
---@param source? table Source table to merge.
---@return table target Merged target table.
local function merge_into(target, source)
	if source then
		for key, value in pairs(source) do
			target[key] = value
		end
	end
	return target
end

--- Check for array shape.
---@param value table Value to test.
---@return boolean result True when value is array.
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

--- Append array values.
---@param target table Target array table.
---@param source table Source array table.
local function append_array(target, source)
	local offset = #target
	for i = 1, #source do
		target[offset + i] = source[i]
	end
end

--- Assert value type.
---@param value any Value to check.
---@param expected string Expected type name.
---@param name? string Value name for error.
---@return any value Checked value.
local function assert_type(value, expected, name)
	if type(value) ~= expected then
		return error((name or "value") .. " must be " .. expected .. ", got " .. type(value), 3)
	end
	return value
end

--- Check for method.
---@param object? table Object to inspect.
---@param name string Method name to find.
---@return boolean result True when method exists.
local function has_method(object, name)
	if not object then
		return false
	end
	return type(object[name]) == "function"
end

--- Find first available method.
---@param object? table Object to inspect.
---@param names table Method names to try.
---@return string? name First found method name.
local function first_method(object, names)
	for i = 1, #names do
		local name = names[i]
		if has_method(object, name) then
			return name
		end
	end
	return nil
end

--- Trim surrounding whitespace.
---@param value string String value to trim.
---@return string trimmed Trimmed string value.
local function trim(value)
	return (string_gsub(value, "^%s*(.-)%s*$", "%1"))
end

--- Check SQL identifier safety.
---@param value string Value to test.
---@return boolean result True when safe identifier.
local function is_identifier(value)
	return type(value) == "string"
		and string_match(value, "^[A-Za-z_][A-Za-z0-9_]*$") ~= nil
end

--- Quote single-quoted string.
---@param value string String value to quote.
---@return string quoted Quoted string literal.
local function quote_single(value)
	return "'" .. (string_gsub(value, "'", "''")) .. "'"
end

--- Normalize query parameters.
---@param params? table Input parameters table.
---@return table params Normalized parameters table.
local function normalize_params(params)
	if params == nil then
		return {}
	end

	if is_array(params) then
		return params
	end

	return params
end

--- Build prefixed error message.
---@param prefix string Error prefix string.
---@param err? any Original error value.
---@return string message Formatted error message.
local function traceback_error(prefix, err)
	if err == nil then
		return prefix
	end
	return prefix .. ": " .. tostring(err)
end

----------------------------------------------------------------------
-- Errors
----------------------------------------------------------------------

--- Structured database error.
---@class SQLORM.Error
---@field kind string Error kind name.
---@field message string Error message text.
---@field context? any Error context data.
local Error = {}
Error.__index = Error

--- Create new error.
---@param kind? string Error kind name.
---@param message? string Error message text.
---@param context? any Error context data.
---@return SQLORM.Error err New error object.
function Error:new(kind, message, context)
	return setmetatable({
		kind = kind or "Error",
		message = message or "",
		context = context,
	}, self)
end

--- Format error as string.
---@return string text Formatted error text.
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

--- SQL dialect for quoting and placeholders.
---@class SQLORM.Dialect
---@field name string Dialect name key.
---@field placeholder_style string Placeholder style name.
---@field features table Capability flags table.
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

--- Create new dialect.
---@param options? table Dialect options table.
---@return SQLORM.Dialect dialect New dialect instance.
function Dialect:new(options)
	local object = shallow_copy(options)
	object.features = shallow_copy(self.features)
	if options and options.features then
		merge_into(object.features, options.features)
	end
	return setmetatable(object, self)
end

--- Quote SQL identifier.
---@param identifier string Identifier to quote.
---@return string quoted Quoted identifier string.
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

--- Render bind placeholder.
---@param index integer Parameter index number.
---@return string placeholder Placeholder string.
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

--- Quote literal for debugging.
---@param value? any Lua value to quote.
---@return string literal Quoted literal string.
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

--- Render LIMIT OFFSET clause.
---@param limit? integer Row limit count.
---@param offset? integer Row offset count.
---@return string clause Limit clause string.
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

--- Get concat operator.
---@return string operator Concat operator string.
function Dialect:concat_operator()
	return "||"
end

--- Render case-insensitive LIKE.
---@param left string Left expression string.
---@param right string Right expression string.
---@return string clause LIKE clause string.
function Dialect:case_insensitive_like(left, right)
	return left .. " LIKE " .. right
end

--- Get current timestamp expression.
---@return string expr Timestamp expression string.
function Dialect:now_expression()
	return "CURRENT_TIMESTAMP"
end

--- Get autoincrement SQL fragment.
---@return string sql Autoincrement SQL fragment.
function Dialect:auto_increment_sql()
	return ""
end

--- Render boolean literal.
---@param value boolean Boolean value to render.
---@return string literal Boolean literal string.
function Dialect:boolean_sql(value)
	return value and "TRUE" or "FALSE"
end

--- Render RETURNING clause.
---@param columns? table Column names list.
---@return string clause Returning clause string.
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

--- Render upsert clause.
---@param conflict_columns table Conflict column names.
---@param assignments table Column assignments list.
---@return string clause Upsert clause string.
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

--- Quote SQLite identifier.
---@param identifier string Identifier to quote.
---@return string quoted Quoted identifier string.
function SQLiteDialect:quote_identifier(identifier)
	if identifier == "*" then
		return "*"
	end
	return Dialect.quote_identifier(self, identifier)
end

--- Get SQLite autoincrement SQL.
---@return string sql Autoincrement SQL fragment.
function SQLiteDialect:auto_increment_sql()
	return " AUTOINCREMENT"
end

--- Render SQLite boolean.
---@param value boolean Boolean value to render.
---@return string literal Boolean literal string.
function SQLiteDialect:boolean_sql(value)
	return value and "1" or "0"
end

--- Render SQLite upsert clause.
---@param conflict_columns table Conflict column names.
---@param assignments table Column assignments list.
---@return string clause Upsert clause string.
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

--- Get Postgres concat operator.
---@return string operator Concat operator string.
function PostgreSQLDialect:concat_operator()
	return "||"
end

--- Render Postgres ILIKE clause.
---@param left string Left expression string.
---@param right string Right expression string.
---@return string clause ILIKE clause string.
function PostgreSQLDialect:case_insensitive_like(left, right)
	return left .. " ILIKE " .. right
end

--- Render Postgres upsert clause.
---@param conflict_columns table Conflict column names.
---@param assignments table Column assignments list.
---@return string clause Upsert clause string.
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

--- Quote MySQL identifier.
---@param identifier string Identifier to quote.
---@return string quoted Quoted identifier string.
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

--- Render MySQL upsert clause.
---@param conflict_columns? table Conflict columns (unused).
---@param assignments table Column assignments list.
---@return string clause Upsert clause string.
function MySQLDialect:render_upsert(conflict_columns, assignments)
	local updates = {}
	for i = 1, #assignments do
		local column = assignments[i][1]
		updates[i] = self:quote_identifier(column) .. " = VALUES(" .. self:quote_identifier(column) .. ")"
	end
	return " ON DUPLICATE KEY UPDATE " .. table_concat(updates, ", ")
end

--- SpacetimeDB SQL dialect.<br>
--- SpacetimeDB speaks a restricted Postgres-flavored subset (see sql-parser crate):<br>
--- SELECT / INSERT / UPDATE / DELETE only, no DDL via SQL, no BEGIN/COMMIT.<br>
--- Supported WHERE: AND / OR plus = <> < > <= >= against literals and :sender.<br>
--- No generic bind parameters on the server (only :sender); the adapter interpolates.<br>
--- SELECT supports * / t.* / columns / COUNT(*) AS alias, INNER JOIN ON col = col,<br>
--- CROSS JOIN, LIMIT <INTEGER>. No OFFSET, DISTINCT, GROUP BY, HAVING, ORDER BY,<br>
--- LEFT / RIGHT JOIN, LIKE / ILIKE / BETWEEN / IN / IS NULL / EXISTS / NOT.<br>
--- Identifiers are case-sensitive, dot-namespaced and double-quoted like Postgres.<br>
--- Tables are defined in module code, not via CREATE TABLE; reducers are atomic.
---@class SQLORM.SpacetimedbDialect : SQLORM.Dialect
local SpacetimeDBDialect = setmetatable({}, { __index = Dialect })
SpacetimeDBDialect.name = "spacetimedb"
SpacetimeDBDialect.placeholder_style = "question"
SpacetimeDBDialect.features = {
	returning = false,
	upsert = false,
	ilike = false,
	nulls_order = false,
}

--- Render SpacetimeDB LIMIT clause (OFFSET unsupported and ignored).
---@param limit? integer Row limit count.
---@param offset? integer Row offset count (ignored).
---@return string clause Limit clause string.
function SpacetimeDBDialect:limit_offset(limit, offset)
	if limit == nil then
		return ""
	end
	return " LIMIT " .. tostring(limit)
end

--- Render SpacetimeDB boolean literal.
---@param value boolean Boolean value to render.
---@return string literal Boolean literal string.
function SpacetimeDBDialect:boolean_sql(value)
	return value and "TRUE" or "FALSE"
end

--- Render SpacetimeDB upsert clause (unsupported, always empty).
---@param conflict_columns? table Conflict columns (unused).
---@param assignments? table Column assignments list (unused).
---@return string clause Empty string.
function SpacetimeDBDialect:render_upsert(conflict_columns, assignments)
	return ""
end

local Dialects = {
	generic = Dialect,
	sqlite = SQLiteDialect,
	postgresql = PostgreSQLDialect,
	postgres = PostgreSQLDialect,
	mysql = MySQLDialect,
	mariadb = MySQLDialect,
	spacetimedb = SpacetimeDBDialect,
	spacetime = SpacetimeDBDialect,
	stdb = SpacetimeDBDialect,
}

--- Register custom dialect.
---@param name string Dialect name key.
---@param prototype table Dialect prototype table.
function SQLORM.register_dialect(name, prototype)
	assert_type(name, "string", "dialect name")
	assert_type(prototype, "table", "dialect")
	Dialects[string_lower(name)] = prototype
end

--- Resolve dialect instance.
---@param value? any Dialect name or object.
---@return SQLORM.Dialect dialect Resolved dialect instance.
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
	spacetime = function() return dialect_factory("spacetimedb") end,
	stdb = function() return dialect_factory("spacetimedb") end,
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

--- SQL expression wrapper.
---@class SQLORM.Expr
---@field render function Render callback function.
local Expr = {}
Expr.__index = Expr

--- Create new expression.
---@param renderer function Render callback function.
---@return SQLORM.Expr expr New expression object.
function Expr:new(renderer)
	return setmetatable({ render = renderer }, self)
end

--- Check expression marker.
---@return boolean result Always true marker.
function Expr:is_expression()
	return true
end

--- Render expression SQL.
---@param context table Query context object.
---@return string sql Rendered SQL fragment.
---@return table? params Additional bound params.
function Expr:to_sql(context)
	return self.render(context)
end

--- Wrap render function.
---@param renderer function Render callback function.
---@return SQLORM.Expr expr New expression object.
local function expr(renderer)
	return Expr:new(renderer)
end

local OP = {}

--- Create raw SQL expression.
---@param sql string Trusted SQL fragment.
---@param params? table Bound parameters list.
---@return SQLORM.Expr expr Raw expression object.
function OP.raw(sql, params)
	assert_type(sql, "string", "raw SQL")
	local values = params or {}
	return expr(function()
		return sql, values
	end)
end

--- Build equality expression.
---@param value any Value to compare.
---@return SQLORM.Expr expr Equality expression.
function OP.eq(value)
	return expr(function(ctx)
		local p = ctx:add_param(value)
		return "= " .. p
	end)
end

--- Build inequality expression.
---@param value any Value to compare.
---@return SQLORM.Expr expr Inequality expression.
function OP.ne(value)
	return expr(function(ctx)
		local p = ctx:add_param(value)
		return "<> " .. p
	end)
end

--- Build greater-than expression.
---@param value any Value to compare.
---@return SQLORM.Expr expr Comparison expression.
function OP.gt(value)
	return expr(function(ctx)
		return "> " .. ctx:add_param(value)
	end)
end

--- Build greater-or-equal expression.
---@param value any Value to compare.
---@return SQLORM.Expr expr Comparison expression.
function OP.gte(value)
	return expr(function(ctx)
		return ">= " .. ctx:add_param(value)
	end)
end

--- Build less-than expression.
---@param value any Value to compare.
---@return SQLORM.Expr expr Comparison expression.
function OP.lt(value)
	return expr(function(ctx)
		return "< " .. ctx:add_param(value)
	end)
end

--- Build less-or-equal expression.
---@param value any Value to compare.
---@return SQLORM.Expr expr Comparison expression.
function OP.lte(value)
	return expr(function(ctx)
		return "<= " .. ctx:add_param(value)
	end)
end

--- Build LIKE expression.
---@param value any Pattern value to match.
---@return SQLORM.Expr expr LIKE expression.
function OP.like(value)
	return expr(function(ctx)
		return "LIKE " .. ctx:add_param(value)
	end)
end

--- Build case-insensitive LIKE.
---@param value any Pattern value to match.
---@return SQLORM.Expr expr ILIKE expression.
function OP.ilike(value)
	return expr(function(ctx)
		return ctx.dialect:case_insensitive_like("", ctx:add_param(value)):sub(2)
	end)
end

--- Build BETWEEN expression.
---@param low any Low bound value.
---@param high any High bound value.
---@return SQLORM.Expr expr BETWEEN expression.
function OP.between(low, high)
	return expr(function(ctx)
		return "BETWEEN " .. ctx:add_param(low) .. " AND " .. ctx:add_param(high)
	end)
end

--- Build IN expression.
---@param values table Value list or subquery.
---@return SQLORM.Expr expr IN expression.
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

--- Build NOT IN expression.
---@param values table Value list or subquery.
---@return SQLORM.Expr expr NOT IN expression.
function OP.not_in(values)
	local inner = OP.in_(values)
	return expr(function(ctx)
		local sql = inner:to_sql(ctx)
		return "NOT " .. sql
	end)
end

--- Build IS NULL expression.
---@return SQLORM.Expr expr Null test expression.
function OP.is_null()
	return expr(function() return "IS NULL" end)
end

--- Build IS NOT NULL expression.
---@return SQLORM.Expr expr Not-null expression.
function OP.not_null()
	return expr(function() return "IS NOT NULL" end)
end

--- Build boolean true test.
---@return SQLORM.Expr expr True test expression.
function OP.is_true()
	return expr(function(ctx)
		return "= " .. ctx.dialect:boolean_sql(true)
	end)
end

--- Build boolean false test.
---@return SQLORM.Expr expr False test expression.
function OP.is_false()
	return expr(function(ctx)
		return "= " .. ctx.dialect:boolean_sql(false)
	end)
end

--- Combine expressions with AND.
---@param ... any Expression operands list.
---@return SQLORM.Expr expr AND expression.
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

--- Combine expressions with OR.
---@param ... any Expression operands list.
---@return SQLORM.Expr expr OR expression.
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

--- Negate expression.
---@param value table Expression to negate.
---@return SQLORM.Expr expr Negated expression.
function OP.not_(value)
	return expr(function(ctx)
		return "NOT (" .. value:to_sql(ctx) .. ")"
	end)
end

--- Build EXISTS expression.
---@param query table Subquery to test.
---@return SQLORM.Expr expr EXISTS expression.
function OP.exists(query)
	return expr(function(ctx)
		local sql = query:to_sql(ctx)
		return "EXISTS (" .. sql .. ")"
	end)
end

--- Build NOT EXISTS expression.
---@param query table Subquery to test.
---@return SQLORM.Expr expr NOT EXISTS expression.
function OP.not_exists(query)
	return expr(function(ctx)
		return "NOT EXISTS (" .. query:to_sql(ctx) .. ")"
	end)
end

--- Build ascending order spec.
---@param column string Column name to sort.
---@return table order Order specification table.
function OP.asc(column)
	return { column = column, direction = "ASC" }
end

--- Build descending order spec.
---@param column string Column name to sort.
---@return table order Order specification table.
function OP.desc(column)
	return { column = column, direction = "DESC" }
end

SQLORM.op = OP
SQLORM.raw = OP.raw

----------------------------------------------------------------------
-- Query context
----------------------------------------------------------------------

--- Query compilation context.
---@class SQLORM.QueryContext
---@field dialect SQLORM.Dialect Dialect for rendering.
---@field params table Bound parameters list.
local QueryContext = {}
QueryContext.__index = QueryContext

--- Create query context.
---@param dialect SQLORM.Dialect Dialect for rendering.
---@return SQLORM.QueryContext ctx New context object.
function QueryContext:new(dialect)
	return setmetatable({ dialect = dialect, params = {} }, self)
end

--- Add bound parameter.
---@param value any Value to bind.
---@return string placeholder Placeholder string.
function QueryContext:add_param(value)
	self.params[#self.params + 1] = value
	return self.dialect:placeholder(#self.params)
end

--- Render value or expression.
---@param value any Value to render.
---@return string sql Rendered SQL fragment.
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

-- Forward declarations: the compiler is defined before the rendering helpers,
-- but invoked only after module initialization has completed.
local render_column
local render_table
local render_assignment_key

--- SQL compiler.<br>
--- Responsibility: transform an immutable-in-practice Query state into SQL plus bound parameters.<br>
--- It does not execute SQL and has no driver dependency.<br>
--- This separation keeps SQL generation independently testable and allows a different compiler to be introduced without changing query execution.
---@class SQLORM.QueryCompiler
---@field query SQLORM.Query Query to compile.
local QueryCompiler = {}
QueryCompiler.__index = QueryCompiler

--- Create query compiler.
---@param query SQLORM.Query Query to compile.
---@return SQLORM.QueryCompiler compiler New compiler instance.
function QueryCompiler:new(query)
	return setmetatable({ query = query }, self)
end

--- Compile a query into parameterized SQL.
---@param parent_context? table Internal compilation context for subqueries.
---@return string sql Compiled SQL string.
---@return table params Bound parameters list.
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

--- Render WHERE clause.
---@param ctx table Query context object.
---@return string clause WHERE clause string.
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
---@field connection SQLORM.Connection Owning connection object.
---@field dialect SQLORM.Dialect Dialect for rendering.
---@field query_type string Query type name.
local Query = {}
Query.__index = Query

--- Create new query.
---@param connection SQLORM.Connection Owning connection object.
---@param query_type string Query type name.
---@param table_name? string Table name or clause.
---@return SQLORM.Query query New query instance.
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

--- Clone query state.
---@return SQLORM.Query clone Cloned query instance.
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

--- Add select columns.
---@param ... any Column names or expressions.
---@return SQLORM.Query self Query for chaining.
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

--- Toggle distinct flag.
---@param value? boolean Distinct flag value.
---@return SQLORM.Query self Query for chaining.
function Query:distinct(value)
	self.distinct_flag = value ~= false
	return self
end

--- Set query source table.
---@param table_name string Table name string.
---@param alias? string Table alias name.
---@return SQLORM.Query self Query for chaining.
function Query:from(table_name, alias)
	self.table = { name = table_name, alias = alias }
	return self
end

--- Add JOIN clause.
---@param table_name string Joined table name.
---@param left string Left column name.
---@param operator? string Join operator string.
---@param right string Right column name.
---@param kind? string Join kind name.
---@return SQLORM.Query self Query for chaining.
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

--- Add LEFT JOIN clause.
---@param table_name string Joined table name.
---@param left string Left column name.
---@param operator? string Join operator string.
---@param right string Right column name.
---@return SQLORM.Query self Query for chaining.
function Query:left_join(table_name, left, operator, right)
	return self:join(table_name, left, operator, right, "LEFT")
end

--- Add RIGHT JOIN clause.
---@param table_name string Joined table name.
---@param left string Left column name.
---@param operator? string Join operator string.
---@param right string Right column name.
---@return SQLORM.Query self Query for chaining.
function Query:right_join(table_name, left, operator, right)
	return self:join(table_name, left, operator, right, "RIGHT")
end

--- Add CROSS JOIN clause.
---@param table_name string Joined table name.
---@return SQLORM.Query self Query for chaining.
function Query:cross_join(table_name)
	self.joins[#self.joins + 1] = { kind = "CROSS", table = table_name }
	return self
end

--- Add WHERE condition.
---@param column_or_expression any Column name or expression.
---@param value? any Value to compare.
---@param operator? string Comparison operator string.
---@return SQLORM.Query self Query for chaining.
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

--- Add OR WHERE condition.
---@param expression table Expression to add.
---@return SQLORM.Query self Query for chaining.
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

--- Add negated condition.
---@param expression table Expression to negate.
---@return SQLORM.Query self Query for chaining.
function Query:where_not(expression)
	return self:where(OP.not_(expression))
end

--- Add WHERE IN condition.
---@param column string Column name string.
---@param values table Value list or subquery.
---@return SQLORM.Query self Query for chaining.
function Query:where_in(column, values)
	return self:where(expr(function(ctx)
		return self.dialect:quote_identifier(column) .. " " .. OP.in_(values):to_sql(ctx)
	end))
end

--- Add WHERE NOT IN condition.
---@param column string Column name string.
---@param values table Value list or subquery.
---@return SQLORM.Query self Query for chaining.
function Query:where_not_in(column, values)
	return self:where(expr(function(ctx)
		return self.dialect:quote_identifier(column) .. " " .. OP.not_in(values):to_sql(ctx)
	end))
end

--- Add WHERE NULL condition.
---@param column string Column name string.
---@return SQLORM.Query self Query for chaining.
function Query:where_null(column)
	return self:where(expr(function()
		return self.dialect:quote_identifier(column) .. " IS NULL"
	end))
end

--- Add WHERE NOT NULL condition.
---@param column string Column name string.
---@return SQLORM.Query self Query for chaining.
function Query:where_not_null(column)
	return self:where(expr(function()
		return self.dialect:quote_identifier(column) .. " IS NOT NULL"
	end))
end

--- Add GROUP BY columns.
---@param ... any Grouping column names.
---@return SQLORM.Query self Query for chaining.
function Query:group_by(...)
	local args = { ... }
	for i = 1, #args do
		self.groups[#self.groups + 1] = args[i]
	end
	return self
end

--- Add HAVING expression.
---@param expression table Having expression object.
---@return SQLORM.Query self Query for chaining.
function Query:having(expression)
	self.havings[#self.havings + 1] = expression
	return self
end

--- Add ORDER BY clause.
---@param column_or_order any Column name or order spec.
---@param direction? string Sort direction string.
---@return SQLORM.Query self Query for chaining.
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

--- Add ascending order.
---@param column string Column name string.
---@return SQLORM.Query self Query for chaining.
function Query:order_by_asc(column)
	return self:order_by(column, "ASC")
end

--- Add descending order.
---@param column string Column name string.
---@return SQLORM.Query self Query for chaining.
function Query:order_by_desc(column)
	return self:order_by(column, "DESC")
end

--- Set result limit.
---@param value integer Row limit count.
---@return SQLORM.Query self Query for chaining.
function Query:limit(value)
	value = tonumber(value)
	if not value or value < 0 or value ~= math_floor(value) then
		return error("limit must be a non-negative integer", 2)
	end
	self.limit_value = value
	return self
end

--- Set result offset.
---@param value integer Row offset count.
---@return SQLORM.Query self Query for chaining.
function Query:offset(value)
	value = tonumber(value)
	if not value or value < 0 or value ~= math_floor(value) then
		return error("offset must be a non-negative integer", 2)
	end
	self.offset_value = value
	return self
end

--- Apply pagination window.
---@param page? integer Page number (default 1).
---@param per_page? integer Rows per page (default 25).
---@return SQLORM.Query self Query for chaining.
function Query:paginate(page, per_page)
	page = tonumber(page) or 1
	per_page = tonumber(per_page) or 25
	if page < 1 then page = 1 end
	if per_page < 1 then per_page = 1 end
	return self:limit(per_page):offset((page - 1) * per_page)
end

--- Set update values.
---@param values table Column values table.
---@return SQLORM.Query self Query for chaining.
function Query:set(values)
	assert_type(values, "table", "update values")
	self.updates = values
	return self
end

--- Set insert values.
---@param values table Row values table.
---@return SQLORM.Query self Query for chaining.
function Query:values_insert(values)
	if values[1] ~= nil and type(values[1]) == "table" then
		self.values = values
	else
		self.values = { values }
	end
	return self
end

--- Add RETURNING columns.
---@param ... any Returning column names.
---@return SQLORM.Query self Query for chaining.
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

--- Set conflict handling.
---@param columns table Conflict column names.
---@param assignments? table Update assignments list.
---@return SQLORM.Query self Query for chaining.
function Query:on_conflict(columns, assignments)
	self.conflict = {
		columns = columns,
		assignments = assignments,
	}
	return self
end

--- Render column reference.
---@param dialect SQLORM.Dialect Dialect for quoting.
---@param column any Column name or expression.
---@return any rendered Rendered column SQL.
render_column = function(dialect, column)
	if type(column) == "table" and has_method(column, "to_sql") then
		return column
	elseif column == "*" then
		return "*"
	end
	return dialect:quote_identifier(column)
end

--- Render table reference.
---@param dialect SQLORM.Dialect Dialect for quoting.
---@param value any Table name or aliased table.
---@return string sql Rendered table SQL.
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

--- Render assignment key.
---@param dialect SQLORM.Dialect Dialect for quoting.
---@param key string Column key name.
---@return string quoted Quoted column name.
render_assignment_key = function(dialect, key)
	if is_identifier(key) then
		return dialect:quote_identifier(key)
	end
	return dialect:quote_identifier(key)
end

--- Compile this query through the injected SQL compiler policy.
---@param parent_context? table Internal compilation context for subqueries.
---@return string sql Compiled SQL string.
---@return table params Bound parameters list.
function Query:to_sql(parent_context)
	return QueryCompiler:new(self):compile(parent_context)
end

--- Query execution service.<br>
--- Responsibility: execute already-constructed Query objects against a Connection. It knows nothing about SQL rendering details.
---@class SQLORM.QueryExecutor
---@field connection SQLORM.Connection Owning connection object.
local QueryExecutor = {}
QueryExecutor.__index = QueryExecutor

--- Create query executor.
---@param connection SQLORM.Connection Owning connection object.
---@return SQLORM.QueryExecutor executor New executor instance.
function QueryExecutor:new(connection)
	return setmetatable({ connection = connection }, self)
end

--- Prepare query statement.
---@param query SQLORM.Query Query to prepare.
---@return any statement Prepared statement object.
---@return any err Error object on failure.
function QueryExecutor:prepare(query)
	local sql, params = query:to_sql()
	return self.connection:prepare(sql, params)
end

--- Execute query.
---@param query SQLORM.Query Query to execute.
---@return any result Execution result object.
---@return any err Error object on failure.
function QueryExecutor:execute(query)
	local sql, params = query:to_sql()
	return self.connection:execute(sql, params)
end

--- Fetch all rows.
---@param query SQLORM.Query Query to run.
---@return table? rows Result rows list.
---@return any err Error object on failure.
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

--- Prepare this query.
---@return any statement Prepared statement object.
---@return any err Error object on failure.
function Query:prepare()
	return QueryExecutor:new(self.connection):prepare(self)
end

--- Execute this query.
---@return any result Execution result object.
---@return any err Error object on failure.
function Query:execute()
	return QueryExecutor:new(self.connection):execute(self)
end

--- Run this query.
---@return any result Execution result object.
---@return any err Error object on failure.
function Query:run()
	return self:execute()
end

--- Fetch all rows.
---@return table? rows Result rows list.
---@return any err Error object on failure.
function Query:all()
	return QueryExecutor:new(self.connection):all(self)
end

--- Fetch first row.
---@return table? row First result row.
---@return any err Error object on failure.
function Query:first()
	self:limit(1)
	local rows, err = self:all()
	if not rows then return nil, err end
	return rows[1]
end

--- Fetch single column value.
---@param column string Column name string.
---@return any value Column value.
---@return any err Error object on failure.
function Query:value(column)
	self:select(column)
	local row, err = self:first()
	if not row then return nil, err end
	return row[column]
end

--- Count matching rows.
---@param column? string Column to count.
---@return integer? count Matching row count.
---@return any err Error object on failure.
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

--- Check row existence.
---@return boolean? exists True when row exists.
---@return any err Error object on failure.
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
---@field raw table|userdata Raw driver object.
---@field execute_method? string Execute method name.
---@field query_method? string Query method name.
---@field prepare_method? string Prepare method name.
---@field close_method? string Close method name.
---@field options table Adapter options table.
local DriverAdapter = {}
DriverAdapter.__index = DriverAdapter

--- Create driver adapter.
---@param driver table|userdata Raw driver object.
---@param options? table Adapter options table.
---@return SQLORM.DriverAdapter adapter New adapter instance.
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

--- Execute SQL statement.
---@param sql string SQL string to execute.
---@param params? table Bound parameters list.
---@return any result Driver result object.
---@return any err Error object on failure.
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

--- Query result rows.
---@param sql string SQL string to run.
---@param params? table Bound parameters list.
---@return table? rows Result rows list.
---@return any err Error object on failure.
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

--- Prepare SQL statement.
---@param sql string SQL string to prepare.
---@return any statement Prepared statement object.
---@return any err Error object on failure.
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

--- Close driver connection.
---@return boolean ok True on success.
---@return any err Error object on failure.
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

--- Database connection facade.<br>
--- High-level code depends on this abstraction rather than on a concrete SQL
--- library, satisfying dependency inversion and making test doubles trivial.
---@class SQLORM.Connection
---@field driver SQLORM.DriverAdapter Normalized driver adapter.
---@field dialect SQLORM.Dialect Active SQL dialect.
---@field options table Connection options table.
---@field transaction_depth integer Nested transaction depth.
---@field transaction_failed boolean True when transaction failed.
---@field last_insert_id integer? Last insert row id.
local Connection = {}
Connection.__index = Connection

--- Create new connection.
---@param driver table|userdata Raw driver or adapter.
---@param options? table Connection options table.
---@return SQLORM.Connection connection New connection instance.
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

--- Execute SQL statement.
---@param sql string SQL string to execute.
---@param params? table Bound parameters list.
---@return any result Execution result object.
---@return any err Error object on failure.
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

--- Query result rows.
---@param sql string SQL string to run.
---@param params? table Bound parameters list.
---@return table? rows Result rows list.
---@return any err Error object on failure.
function Connection:query(sql, params)
	return self.driver:query(sql, normalize_params(params))
end

--- Prepare SQL statement.
---@param sql string SQL string to prepare.
---@param params? table Default parameters table.
---@return table statement Statement facade object.
---@return any err Error object on failure.
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

--- Run transaction callback.<br>
--- SpacetimeDB has no BEGIN/COMMIT via SQL (reducers are atomic); for that
--- dialect the callback runs directly with depth tracking and no SQL wrapper.
---@param fn function Transaction callback function.
---@return any result Callback result value.
---@return any err Error object on failure.
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

	local is_spacetimedb = self.dialect ~= nil and self.dialect.name == "spacetimedb"

	local begin_err = nil
	if not is_spacetimedb then
		local _, err = self:execute("BEGIN")
		begin_err = err
	end
	if begin_err then
		self.transaction_depth = 0
		return nil, Error:new("TransactionError", tostring(begin_err))
	end

	local ok, result, callback_err = pcall(fn, self)
	if not ok then
		if not is_spacetimedb then
			self:execute("ROLLBACK")
		end
		self.transaction_depth = 0
		return nil, Error:new("TransactionError", tostring(result))
	end

	if callback_err ~= nil or self.transaction_failed then
		if not is_spacetimedb then
			self:execute("ROLLBACK")
		end
		self.transaction_depth = 0
		return result, callback_err or Error:new("TransactionError", "transaction marked failed")
	end

	if is_spacetimedb then
		self.transaction_depth = 0
		return result, nil
	end

	local _, commit_err = self:execute("COMMIT")
	self.transaction_depth = 0
	if commit_err then
		self:execute("ROLLBACK")
		return nil, Error:new("TransactionError", tostring(commit_err))
	end
	return result, nil
end

--- Mark transaction failed.
function Connection:mark_transaction_failed()
	if self.transaction_depth > 0 then
		self.transaction_failed = true
	end
end

--- Get query builder.
---@return table builder Query builder proxy.
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

--- Start select query.
---@param ... any Column names list.
---@return SQLORM.Query query New select query.
function Connection:select(...)
	return Query:new(self, "select"):select(...)
end

--- Start insert query.
---@param table_name string Target table name.
---@param values table Row values table.
---@return SQLORM.Query query New insert query.
function Connection:insert(table_name, values)
	return Query:new(self, "insert", table_name):values_insert(values)
end

--- Start update query.
---@param table_name string Target table name.
---@param values table Update values table.
---@return SQLORM.Query query New update query.
function Connection:update(table_name, values)
	return Query:new(self, "update", table_name):set(values)
end

--- Start delete query.
---@param table_name string Target table name.
---@return SQLORM.Query query New delete query.
function Connection:delete(table_name)
	return Query:new(self, "delete", table_name)
end

--- Create raw query.
---@param sql string Raw SQL string.
---@param params? table Bound parameters list.
---@return SQLORM.Query query New raw query.
function Connection:raw(sql, params)
	local query = Query:new(self, "raw", sql)
	query.raw_params = params
	return query
end

--- Close connection.
---@return boolean ok True on success.
---@return any err Error object on failure.
function Connection:close()
	return self.driver:close()
end

--- Open database connection.
---@param driver table|userdata Raw driver or adapter object.
---@param options? table Connection options table.
---@return SQLORM.Connection connection New connection instance.
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
---@field kind string Field kind name.
---@field name string? Field name string.
---@field primary boolean True when primary key.
---@field nullable boolean True when nullable.
---@field not_null boolean True when NOT NULL.
---@field unique boolean True when unique.
---@field auto_increment boolean True when autoincrement.
---@field default any Default value.
---@field has_default boolean True when default exists.
local Field = {}
Field.__index = Field

--- Create new field.
---@param kind? string Field kind name.
---@param options? table Field options table.
---@return SQLORM.Field field New field instance.
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

--- Convert database value.
---@param value? any Raw database value.
---@param model? table Owning model instance.
---@return any value Converted value.
function Field:convert_from_database(value, model)
	if self.read then
		return self.read(value, model, self)
	end
	return value
end

--- Convert value for database.
---@param value? any Model value to store.
---@param model? table Owning model instance.
---@return any value Database value.
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

--- Validate field value.
---@param value? any Value to validate.
---@param model? table Owning model instance.
---@return boolean? ok True when valid.
---@return string? err Error message on failure.
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

--- Create field factory.
---@param kind string Field kind name.
---@return function factory Field factory function.
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

--- ORM model metadata/factory facade.<br>
--- Persistence and relationship work are delegated to focused services while this object owns model configuration.
---@class SQLORM.ModelMeta
---@field name string Model name string.
---@field table string Database table name.
---@field fields table Field definitions table.
---@field primary_key string Primary key field name.
---@field connection SQLORM.Connection? Bound connection object.
---@field relations table Relation definitions table.
local ModelMeta = {}
ModelMeta.__index = ModelMeta

--- Create model metadata.
---@param name? string Model name string.
---@param table_name string Database table name.
---@param fields? table Field definitions table.
---@param options? table Model options table.
---@return SQLORM.ModelMeta meta New metadata instance.
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

--- Bind model to connection.
---@param connection SQLORM.Connection Connection to use.
---@return SQLORM.ModelMeta self Metadata for chaining.
function ModelMeta:bind(connection)
	self.connection = connection
	return self
end

--- Get field definition.
---@param name string Field name string.
---@return SQLORM.Field? field Field definition or nil.
function ModelMeta:field(name)
	return self.fields[name]
end

--- Check field existence.
---@param name string Field name string.
---@return boolean exists True when field exists.
function ModelMeta:has_field(name)
	return self.fields[name] ~= nil
end

--- Get qualified table name.
---@param alias? string Table alias name.
---@return string sql Quoted table SQL.
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
---@field _meta SQLORM.ModelMeta Owning metadata object.
---@field _data table Current field values.
---@field _original table Original field values.
---@field _dirty table Dirty field flags.
---@field _persisted boolean True when persisted.
local ModelInstance = {}
ModelInstance.__index = ModelInstance

--- Create model instance.
---@param meta SQLORM.ModelMeta Owning metadata object.
---@param values? table Initial values table.
---@param persisted? boolean Persisted flag value.
---@return SQLORM.ModelInstance instance New instance object.
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

--- Resolve instance field.
---@param key string Field key name.
---@return any value Field or method value.
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

--- Assign instance field.
---@param key string Field key name.
---@param value any Value to assign.
function ModelInstance:__newindex(key, value)
	if self._meta.fields[key] then
		self:set(key, value)
	elseif self._meta.relations[key] then
		self._relations[key] = value
	else
		rawset(self, key, value)
	end
end

--- Format instance string.
---@return string text Instance description text.
function ModelInstance:__tostring()
	local pk = self:get(self._meta.primary_key)
	return string_format("%s<%s>", self._meta.name, tostring(pk))
end

--- Get field value.
---@param key string Field key name.
---@param default? any Default value fallback.
---@return any value Field value.
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

--- Set field value.
---@param key string Field key name.
---@param value any Value to assign.
---@return SQLORM.ModelInstance self Instance for chaining.
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

--- Fill multiple fields.
---@param values table Values table to assign.
---@return SQLORM.ModelInstance self Instance for chaining.
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

--- Export to plain table.
---@param options? table Export options table.
---@return table data Plain data table.
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

--- Check dirty state.
---@param field? string Field name to check.
---@return boolean dirty True when dirty.
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

--- List dirty fields.
---@return table fields Dirty field names.
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

--- Check new record.
---@return boolean isnew True when unpersisted.
function ModelInstance:is_new()
	return not self._persisted
end

--- Check persisted state.
---@return boolean exists True when persisted.
function ModelInstance:exists()
	return self._persisted
end

--- Get validation errors.
---@return table? errors Validation errors table.
function ModelInstance:errors()
	return self._errors
end

--- Validate instance fields.
---@return boolean ok True when valid.
---@return table? errors Validation errors table.
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

--- Reload from database.
---@return SQLORM.ModelInstance? instance Reloaded instance object.
---@return any err Error object on failure.
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

--- Delete this record.
---@return any result Delete result object.
---@return any err Error object on failure.
function ModelInstance:delete()
	return self._meta:delete_instance(self)
end

--- Save this record.
---@param options? table Save options table.
---@return boolean? ok True on success.
---@return any err Error object on failure.
function ModelInstance:save(options)
	return self._meta:save_instance(self, options)
end

--- Refresh from database.
---@return SQLORM.ModelInstance? instance Refreshed instance object.
---@return any err Error object on failure.
function ModelInstance:refresh()
	return self:reload()
end

----------------------------------------------------------------------
-- ORM Query wrapper
----------------------------------------------------------------------

--- Model-aware query wrapper.
---@class SQLORM.ModelQuery
---@field model SQLORM.ModelMeta Owning metadata object.
---@field query SQLORM.Query Base query object.
local ModelQuery = {}
ModelQuery.__index = ModelQuery

--- Create model query.
---@param meta SQLORM.ModelMeta Owning metadata object.
---@param query SQLORM.Query Base query object.
---@return SQLORM.ModelQuery wrapper New wrapper instance.
function ModelQuery:new(meta, query)
	return setmetatable({ model = meta, query = query }, self)
end

--- Clone model query.
---@return SQLORM.ModelQuery clone Cloned wrapper instance.
function ModelQuery:clone()
	return ModelQuery:new(self.model, self.query:clone())
end

--- Add WHERE condition.
---@param column_or_expression any Column name or expression.
---@param value? any Value to compare.
---@param operator? string Comparison operator string.
---@return SQLORM.ModelQuery self Wrapper for chaining.
function ModelQuery:where(column_or_expression, value, operator)
	self.query:where(column_or_expression, value, operator)
	return self
end

--- Add OR condition.
---@param expression table Expression to add.
---@return SQLORM.ModelQuery self Wrapper for chaining.
function ModelQuery:or_where(expression)
	self.query:or_where(expression)
	return self
end

--- Add negated condition.
---@param expression table Expression to negate.
---@return SQLORM.ModelQuery self Wrapper for chaining.
function ModelQuery:where_not(expression)
	self.query:where_not(expression)
	return self
end

--- Add WHERE IN.
---@param column string Column name string.
---@param values table Value list or subquery.
---@return SQLORM.ModelQuery self Wrapper for chaining.
function ModelQuery:where_in(column, values)
	self.query:where_in(column, values)
	return self
end

--- Add WHERE NOT IN.
---@param column string Column name string.
---@param values table Value list or subquery.
---@return SQLORM.ModelQuery self Wrapper for chaining.
function ModelQuery:where_not_in(column, values)
	self.query:where_not_in(column, values)
	return self
end

--- Add WHERE NULL.
---@param column string Column name string.
---@return SQLORM.ModelQuery self Wrapper for chaining.
function ModelQuery:where_null(column)
	self.query:where_null(column)
	return self
end

--- Add WHERE NOT NULL.
---@param column string Column name string.
---@return SQLORM.ModelQuery self Wrapper for chaining.
function ModelQuery:where_not_null(column)
	self.query:where_not_null(column)
	return self
end

--- Filter by primary key.
---@param id any Primary key value.
---@return SQLORM.ModelQuery self Wrapper for chaining.
function ModelQuery:where_id(id)
	return self:where(self.model.primary_key, id)
end

--- Set select columns.
---@param ... any Column names list.
---@return SQLORM.ModelQuery self Wrapper for chaining.
function ModelQuery:select(...)
	self.query.selects = {}
	self.query:select(...)
	return self
end

--- Toggle distinct flag.
---@param value? boolean Distinct flag value.
---@return SQLORM.ModelQuery self Wrapper for chaining.
function ModelQuery:distinct(value)
	self.query:distinct(value)
	return self
end

--- Add JOIN clause.
---@param table_name string Joined table name.
---@param left string Left column name.
---@param operator? string Join operator string.
---@param right string Right column name.
---@param kind? string Join kind name.
---@return SQLORM.ModelQuery self Wrapper for chaining.
function ModelQuery:join(table_name, left, operator, right, kind)
	self.query:join(table_name, left, operator, right, kind)
	return self
end

--- Add LEFT JOIN.
---@param table_name string Joined table name.
---@param left string Left column name.
---@param operator? string Join operator string.
---@param right string Right column name.
---@return SQLORM.ModelQuery self Wrapper for chaining.
function ModelQuery:left_join(table_name, left, operator, right)
	self.query:left_join(table_name, left, operator, right)
	return self
end

--- Add GROUP BY.
---@param ... any Grouping columns list.
---@return SQLORM.ModelQuery self Wrapper for chaining.
function ModelQuery:group_by(...)
	self.query:group_by(...)
	return self
end

--- Add HAVING expression.
---@param expression table Having expression object.
---@return SQLORM.ModelQuery self Wrapper for chaining.
function ModelQuery:having(expression)
	self.query:having(expression)
	return self
end

--- Add ORDER BY.
---@param column string Column name string.
---@param direction? string Sort direction string.
---@return SQLORM.ModelQuery self Wrapper for chaining.
function ModelQuery:order_by(column, direction)
	self.query:order_by(column, direction)
	return self
end

--- Add descending order.
---@param column string Column name string.
---@return SQLORM.ModelQuery self Wrapper for chaining.
function ModelQuery:order_by_desc(column)
	self.query:order_by_desc(column)
	return self
end

--- Add ascending order.
---@param column string Column name string.
---@return SQLORM.ModelQuery self Wrapper for chaining.
function ModelQuery:order_by_asc(column)
	self.query:order_by_asc(column)
	return self
end

--- Set result limit.
---@param value integer Row limit count.
---@return SQLORM.ModelQuery self Wrapper for chaining.
function ModelQuery:limit(value)
	self.query:limit(value)
	return self
end

--- Set result offset.
---@param value integer Row offset count.
---@return SQLORM.ModelQuery self Wrapper for chaining.
function ModelQuery:offset(value)
	self.query:offset(value)
	return self
end

--- Apply pagination.
---@param page? integer Page number value.
---@param per_page? integer Rows per page value.
---@return SQLORM.ModelQuery self Wrapper for chaining.
function ModelQuery:paginate(page, per_page)
	self.query:paginate(page, per_page)
	return self
end

--- Compile to SQL.
---@return string sql Compiled SQL string.
---@return table params Bound parameters list.
function ModelQuery:to_sql()
	return self.query:to_sql()
end

--- Fetch all models.
---@return table? models Model instances list.
---@return any err Error object on failure.
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

--- Fetch first model.
---@return SQLORM.ModelInstance? model First model or nil.
---@return any err Error object on failure.
function ModelQuery:first()
	local row, err = self.query:first()
	if not row then
		return nil, err
	end
	return self.model:hydrate(row, true)
end

--- Find by primary key.
---@param id any Primary key value.
---@return SQLORM.ModelInstance? model Found model or nil.
---@return any err Error object on failure.
function ModelQuery:find(id)
	return self:where_id(id):first()
end

--- Count matching models.
---@return integer? count Matching count value.
---@return any err Error object on failure.
function ModelQuery:count()
	return self.query:count()
end

--- Check model existence.
---@return boolean? exists True when found.
---@return any err Error object on failure.
function ModelQuery:exists()
	return self.query:exists()
end

--- Delete matching rows.
---@return any result Delete result object.
---@return any err Error object on failure.
function ModelQuery:delete()
	return self.query:execute()
end

--- Update matching rows.
---@param values table Update values table.
---@return any result Update result object.
---@return any err Error object on failure.
function ModelQuery:update(values)
	local update = Query:new(self.model.connection, "update", self.model.table)
	update:set(values)
	update.wheres = self.query.wheres
	update.limit_value = self.query.limit_value
	update.offset_value = self.query.offset_value
	return update:execute()
end

--- Eager-load relation.
---@param relation string Relation name string.
---@return SQLORM.ModelQuery self Wrapper for chaining.
function ModelQuery:with(relation)
	self._with = self._with or {}
	self._with[#self._with + 1] = relation
	return self
end

--- Preload relations.
---@param models table Model instances list.
---@return table models Models with relations.
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

--- Relationship definition.<br>
--- Loading policy is supplied by ModelMeta rather than embedded into the relation object, keeping the relation a value object.
---@class SQLORM.Relation
---@field kind string Relation kind name.
---@field target table Target model object.
---@field foreign_key string? Foreign key name.
---@field local_key string? Local key name.
---@field pivot_table string? Pivot table name.
local Relation = {}
Relation.__index = Relation

--- Create relation definition.
---@param kind string Relation kind name.
---@param target table Target model object.
---@param options? table Relation options table.
---@return SQLORM.Relation relation New relation object.
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

--- Create relation factory.
---@param kind string Relation kind name.
---@return function factory Relation factory function.
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

--- Build default foreign key.
---@param model table Model metadata object.
---@param local_key? string Local key name.
---@return string key Foreign key name.
local function default_foreign_key(model, local_key)
	return string_lower(model.name) .. "_" .. string_lower(local_key or model.primary_key)
end

--- Define named relation.
---@param name string Relation name string.
---@param definition table Relation definition object.
---@return SQLORM.ModelMeta self Metadata for chaining.
function ModelMeta:relation(name, definition)
	definition.relation_name = name
	self.relations[name] = definition
	return self
end

--- Define belongs-to relation.
---@param name string Relation name string.
---@param target table Target model object.
---@param options? table Relation options table.
---@return SQLORM.ModelMeta self Metadata for chaining.
function ModelMeta:belongs_to(name, target, options)
	options = options or {}
	options.foreign_key = options.foreign_key or string_lower(name) .. "_id"
	options.local_key = options.local_key or self.fields[options.foreign_key] and options.foreign_key or self
		.primary_key
	return self:relation(name, Relation:new("belongs_to", target, options))
end

--- Define has-many relation.
---@param name string Relation name string.
---@param target table Target model object.
---@param options? table Relation options table.
---@return SQLORM.ModelMeta self Metadata for chaining.
function ModelMeta:has_many(name, target, options)
	options = options or {}
	options.local_key = options.local_key or self.primary_key
	options.foreign_key = options.foreign_key or default_foreign_key(self, options.local_key)
	return self:relation(name, Relation:new("has_many", target, options))
end

--- Define has-one relation.
---@param name string Relation name string.
---@param target table Target model object.
---@param options? table Relation options table.
---@return SQLORM.ModelMeta self Metadata for chaining.
function ModelMeta:has_one(name, target, options)
	options = options or {}
	options.local_key = options.local_key or self.primary_key
	options.foreign_key = options.foreign_key or default_foreign_key(self, options.local_key)
	return self:relation(name, Relation:new("has_one", target, options))
end

--- Define many-to-many relation.
---@param name string Relation name string.
---@param target table Target model object.
---@param options? table Relation options table.
---@return SQLORM.ModelMeta self Metadata for chaining.
function ModelMeta:many_to_many(name, target, options)
	options = options or {}
	options.pivot_table = assert(options.pivot_table, "many_to_many requires pivot_table")
	options.pivot_foreign_key = options.pivot_foreign_key or default_foreign_key(self, self.primary_key)
	options.pivot_related_key = options.pivot_related_key or default_foreign_key(target, target.primary_key)
	options.local_key = options.local_key or self.primary_key
	options.foreign_key = options.foreign_key or target.primary_key
	return self:relation(name, Relation:new("many_to_many", target, options))
end

--- Build relation query.
---@param instance table Source instance object.
---@param relation table Relation definition object.
---@return SQLORM.ModelQuery query Relation query object.
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

--- Load single relation.
---@param instance table Source instance object.
---@param name string Relation name string.
---@return any value Loaded relation value.
---@return any err Error object on failure.
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

--- Preload relation for list.
---@param instances table Instance list table.
---@param name string Relation name string.
---@return table? instances Preloaded instances list.
---@return any err Error object on failure.
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

--- Preload many-to-many rows.
---@param instances table Instance list table.
---@param relation table Relation definition object.
---@param local_values table Local key values.
---@return table? models Child models list.
---@return any err Error object on failure.
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

--- Start model query.
---@return SQLORM.ModelQuery query New model query.
function ModelMeta:query()
	assert(self.connection, "model is not bound to a connection")
	local query = Query:new(self.connection, "select", self.table):select("*")
	return ModelQuery:new(self, query)
end

--- Build new instance.
---@param values? table Initial values table.
---@return SQLORM.ModelInstance instance New instance object.
function ModelMeta:new_instance(values)
	return ModelInstance:new(self, values or {}, false)
end

--- Hydrate row to model.
---@param row table Database row table.
---@param persisted? boolean Persisted flag value.
---@return SQLORM.ModelInstance instance Hydrated instance object.
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

--- Create and save record.
---@param values table Initial values table.
---@param options? table Save options table.
---@return SQLORM.ModelInstance? instance Created instance object.
---@return any err Error object on failure.
function ModelMeta:create(values, options)
	local instance = self:new_instance(values)
	local ok, err = self:save_instance(instance, options)
	if not ok then
		return nil, err
	end
	return instance
end

--- Find by primary key.
---@param id any Primary key value.
---@return SQLORM.ModelInstance? model Found model or nil.
---@return any err Error object on failure.
function ModelMeta:find(id)
	return self:query():find(id)
end

--- Find or return error.
---@param id any Primary key value.
---@return SQLORM.ModelInstance? model Found model or nil.
---@return any err Error object on failure.
function ModelMeta:find_or_fail(id)
	local model, err = self:find(id)
	if not model then
		return nil, err or Error:new("ORMError", "record not found")
	end
	return model
end

--- Fetch all records.
---@return table? models All model instances.
---@return any err Error object on failure.
function ModelMeta:all()
	return self:query():all()
end

--- Filter by condition.
---@param column_or_expression any Column name or expression.
---@param value? any Value to compare.
---@param operator? string Comparison operator string.
---@return SQLORM.ModelQuery query Model query object.
function ModelMeta:where(column_or_expression, value, operator)
	return self:query():where(column_or_expression, value, operator)
end

--- Count matching records.
---@param conditions? table Filter conditions table.
---@return integer? count Matching count value.
---@return any err Error object on failure.
function ModelMeta:count(conditions)
	local query = self:query()
	if conditions then query:where(conditions) end
	return query:count()
end

--- Check record existence.
---@param conditions? table Filter conditions table.
---@return boolean? exists True when found.
---@return any err Error object on failure.
function ModelMeta:exists(conditions)
	local query = self:query()
	if conditions then query:where(conditions) end
	return query:exists()
end

--- Delete matching records.
---@param conditions? table Filter conditions table.
---@return any result Delete result object.
---@return any err Error object on failure.
function ModelMeta:delete_where(conditions)
	local query = Query:new(self.connection, "delete", self.table)
	if conditions then query:where(conditions) end
	return query:execute()
end

--- Persist instance state.
---@param instance table Instance to save.
---@param options? table Save options table.
---@return boolean? ok True on success.
---@return any err Error object on failure.
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

--- Delete instance record.
---@param instance table Instance to delete.
---@return any result Delete result object.
---@return any err Error object on failure.
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

--- Register model callback.
---@param event string Callback event name.
---@param callback function Callback function.
---@return SQLORM.ModelMeta self Metadata for chaining.
function ModelMeta:on(event, callback)
	self.callbacks[event] = callback
	return self
end

--- Define query scope.
---@param name string Scope name string.
---@param callback function Scope callback function.
---@return SQLORM.ModelMeta self Metadata for chaining.
function ModelMeta:scope(name, callback)
	self.scopes[name] = callback
	return self
end

--- Apply query scope.
---@param query table Query to extend.
---@param name string Scope name string.
---@param ... any Scope arguments list.
---@return any result Scope result value.
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

--- Schema helper for table management.
---@class SQLORM.Schema
---@field connection SQLORM.Connection Owning connection object.
local Schema = {}
Schema.__index = Schema

--- Create schema helper.
---@param connection SQLORM.Connection Owning connection object.
---@return SQLORM.Schema schema New schema object.
function Schema:new(connection)
	return setmetatable({ connection = connection }, self)
end

--- Render column type SQL.<br>
--- SpacetimeDB DDL is unsupported (tables live in module code); mapping is
--- informational for inspect/create_table which errors for that dialect.
---@param field table Field definition object.
---@return string sql Column type SQL.
function Schema:type_sql(field)
	local dialect = self.connection.dialect
	local type_name
	if field.kind == "integer" then
		type_name = "INTEGER"
	elseif field.kind == "real" then
		type_name = "REAL"
	elseif field.kind == "boolean" then
		type_name = (dialect.name == "mysql" or dialect.name == "spacetimedb") and "BOOLEAN" or "INTEGER"
	elseif field.kind == "blob" then
		type_name = dialect.name == "mysql" and "BLOB" or "BLOB"
	elseif field.kind == "date" then
		type_name = "DATE"
	elseif field.kind == "datetime" then
		type_name = (dialect.name == "postgresql" or dialect.name == "spacetimedb") and "TIMESTAMP" or "DATETIME"
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

--- Create model table.<br>
--- SpacetimeDB tables are defined in module code, not via SQL DDL.
---@param meta table Model metadata object.
---@param options? table Create options table.
---@return any result Execution result object.
---@return any err Error object on failure.
function Schema:create_table(meta, options)
	options = options or {}
	local dialect = self.connection.dialect
	if dialect.name == "spacetimedb" then
		return nil, Error:new("QueryError", "spacetimedb: CREATE TABLE unsupported, define tables in module code")
	end
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

--- Drop model table.<br>
--- SpacetimeDB tables are defined in module code, not via SQL DDL.
---@param meta table Model metadata object.
---@param options? table Drop options table.
---@return any result Execution result object.
---@return any err Error object on failure.
function Schema:drop_table(meta, options)
	options = options or {}
	if self.connection.dialect.name == "spacetimedb" then
		return nil, Error:new("QueryError", "spacetimedb: DROP TABLE unsupported, define tables in module code")
	end
	local sql = "DROP TABLE " .. (options.if_exists and "IF EXISTS " or "")
		.. self.connection.dialect:quote_identifier(meta.table)
	return self.connection:execute(sql)
end

--- Truncate model table.<br>
--- SpacetimeDB has no TRUNCATE; DELETE FROM is supported and used instead.
---@param meta table Model metadata object.
---@return any result Execution result object.
---@return any err Error object on failure.
function Schema:truncate(meta)
	local sql
	if self.connection.dialect.name == "sqlite" or self.connection.dialect.name == "spacetimedb" then
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

--- Create model class.
---@param name string Model name string.
---@param table_name string Database table name.
---@param fields table Field definitions table.
---@param options? table Model options table.
---@return SQLORM.ModelMeta meta New metadata instance.
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

--- Bind model to connection.
---@param model table Model object to bind.
---@param connection SQLORM.Connection Connection to use.
---@return table model Bound model object.
function SQLORM.bind_model(model, connection)
	if has_method(model, "bind") then
		return model:bind(connection)
	end

	-- Loose interface fallback: any table with a plausible metadata layout can
	-- be bound without inheriting from ModelMeta.
	model.connection = connection
	return model
end

--- Check driver shape.
---@param value any Value to test.
---@return boolean result True when driver-like.
function SQLORM.is_driver(value)
	return type(value) == "table"
		and (has_method(value, "execute") or has_method(value, "exec") or has_method(value, "query"))
end

--- Check connection shape.
---@param value any Value to test.
---@return boolean result True when connection-like.
function SQLORM.is_connection(value)
	return type(value) == "table"
		and has_method(value, "execute")
		and has_method(value, "query")
		and value.dialect ~= nil
end

--- Check query shape.
---@param value any Value to test.
---@return boolean result True when query-like.
function SQLORM.is_query(value)
	return type(value) == "table" and has_method(value, "to_sql") and has_method(value, "execute")
end

----------------------------------------------------------------------
-- Identifier helpers / query fragments
----------------------------------------------------------------------

--- Create identifier expression.
---@param name string Identifier name string.
---@return SQLORM.Expr expr Identifier expression.
function SQLORM.identifier(name)
	assert_type(name, "string", "identifier")
	return expr(function(ctx)
		return ctx.dialect:quote_identifier(name)
	end)
end

--- Create column expression.
---@param name string Column name string.
---@param alias? string Column alias name.
---@return SQLORM.Expr expr Column expression.
function SQLORM.column(name, alias)
	return expr(function(ctx)
		local sql = ctx.dialect:quote_identifier(name)
		if alias then
			sql = sql .. " AS " .. ctx.dialect:quote_identifier(alias)
		end
		return sql
	end)
end

--- Build function expression.
---@param name string Function name string.
---@param ... any Function arguments list.
---@return SQLORM.Expr expr Function expression.
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

--- Create aliased expression.
---@param expression any Expression to alias.
---@param alias string Alias name string.
---@return table aliased Aliased expression table.
function SQLORM.alias(expression, alias)
	return {
		expression = expression,
		alias = alias,
	}
end

----------------------------------------------------------------------
-- Transactions helper
----------------------------------------------------------------------

--- Run transaction helper.
---@param connection SQLORM.Connection Connection to use.
---@param callback function Transaction callback function.
---@return any result Callback result value.
---@return any err Error object on failure.
function SQLORM.transaction(connection, callback)
	assert(SQLORM.is_connection(connection), "expected SQLORM connection")
	return connection:transaction(callback)
end

----------------------------------------------------------------------
-- Debugging / SQL inspection
----------------------------------------------------------------------

--- Interpolate SQL for debugging.
---@param connection_or_dialect any Connection or dialect object.
---@param sql string SQL string to fill.
---@param params? table Bound parameters list.
---@return string sql Interpolated SQL string.
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

--- Inspect compiled query.
---@param query table Query to inspect.
---@return table info Query info table.
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

--- Migration runner for schema versioning.
---@class SQLORM.MigrationRunner
---@field connection SQLORM.Connection Owning connection object.
---@field table string Migration table name.
local MigrationRunner = {}
MigrationRunner.__index = MigrationRunner

--- Create migration runner.
---@param connection SQLORM.Connection Owning connection object.
---@param table_name? string Migration table name.
---@return SQLORM.MigrationRunner runner New runner instance.
function MigrationRunner:new(connection, table_name)
	return setmetatable({ connection = connection, table = table_name or "schema_migrations" }, self)
end

--- Ensure migration table.
---@return any result Execution result object.
---@return any err Error object on failure.
function MigrationRunner:ensure_table()
	local dialect = self.connection.dialect
	local sql = "CREATE TABLE IF NOT EXISTS " .. dialect:quote_identifier(self.table)
		.. " (" .. dialect:quote_identifier("id") .. " INTEGER PRIMARY KEY, "
		.. dialect:quote_identifier("name") .. " TEXT NOT NULL UNIQUE)"
	return self.connection:execute(sql)
end

--- Check migration applied.
---@param name string Migration name string.
---@return boolean? applied True when applied.
---@return any err Error object on failure.
function MigrationRunner:has(name)
	local row, err = self.connection:select("id"):from(self.table):where("name", name):first()
	if err then return nil, err end
	return row ~= nil
end

--- Mark migration applied.
---@param name string Migration name string.
---@return any result Execution result object.
---@return any err Error object on failure.
function MigrationRunner:mark(name)
	return self.connection:insert(self.table, { name = name }):execute()
end

--- Run pending migrations.
---@param migrations table Migration list table.
---@return boolean? ok True on success.
---@return any err Error object on failure.
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

--- Rollback last migration.
---@param migrations table Migration list table.
---@return any result Rollback result object.
---@return any err Error object on failure.
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

--- Wrap driver as connection.
---@param driver table|userdata Raw driver object.
---@param options? table Connection options table.
---@return SQLORM.Connection connection New connection instance.
function SQLORM.wrap(driver, options)
	if getmetatable(driver) == DriverAdapter then
		return Connection:new(driver, options)
	end
	return Connection:new(driver, options)
end

--- Create driver adapter.
---@param driver table|userdata Raw driver object.
---@param options? table Adapter options table.
---@return SQLORM.DriverAdapter adapter New adapter instance.
function SQLORM.adapter(driver, options)
	return DriverAdapter:new(driver, options)
end

--- Build loose-interface adapter around plain function table.<br>
--- Build function driver.
---@param execute_fn function Execute callback function.
---@param query_fn? function Query callback function.
---@param close_fn? function Close callback function.
---@return table driver Driver shim table.
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

--- Interpolate question-mark placeholders for SpacetimeDB.<br>
--- SpacetimeDB server understands literals plus :sender only, so bind values
--- must be inlined with dialect quoting before sending. Placeholders inside
--- single-quoted string literals are skipped.
---@param dialect table Dialect for quoting.
---@param sql string SQL string with placeholders.
---@param params? table Bound parameters list.
---@return string? final_sql Interpolated SQL string or nil on error.
---@return string? err Error message on failure.
local function spacetimedb_interpolate(dialect, sql, params)
	params = params or {}
	local out = {}
	local index = 0
	local count = #params
	local i = 1
	local length = #sql
	while i <= length do
		local char = string_sub(sql, i, i)
		if char == "'" then
			-- Copy single-quoted literal verbatim, honouring '' escape.
			out[#out + 1] = char
			i = i + 1
			while i <= length do
				local inner = string_sub(sql, i, i)
				out[#out + 1] = inner
				if inner == "'" then
					if string_sub(sql, i + 1, i + 1) == "'" then
						out[#out + 1] = "'"
						i = i + 2
					else
						i = i + 1
						break
					end
				else
					i = i + 1
				end
			end
		elseif char == "?" then
			index = index + 1
			if index > count then
				return nil, "spacetimedb: not enough parameters for placeholders"
			end
			local ok, quoted = pcall(function(value) return dialect:quote_literal(value) end, params[index])
			if not ok then
				return nil, "spacetimedb: cannot quote parameter " .. tostring(index) .. ": " .. tostring(quoted)
			end
			out[#out + 1] = quoted
			i = i + 1
		else
			out[#out + 1] = char
			i = i + 1
		end
	end
	if index < count then
		return nil, "spacetimedb: too many parameters for placeholders"
	end
	return table_concat(out)
end

--- Normalize SpacetimeDB result rows to an array.
---@param result any Raw driver result.
---@return any rows Normalized rows value.
local function spacetimedb_normalize_rows(result)
	if type(result) ~= "table" then
		return result
	end
	if result.rows ~= nil and type(result.rows) == "table" then
		return result.rows
	end
	if result.data ~= nil and type(result.data) == "table" then
		return result.data
	end
	if result.result ~= nil and type(result.result) == "table" then
		return result.result
	end
	return result
end

--- Build SpacetimeDB driver shim with parameter interpolation.<br>
--- Accepts either a raw driver table/userdata or plain functions. Functions
--- receive the final interpolated SQL string (no params table). Table drivers
--- may expose execute/exec/run/sql/execute_sql/query/fetch_all/select/query_sql.
---@param driver table|userdata|function Raw driver object or execute function.
---@param query_fn_or_options? table|function Query callback or options table.
---@param close_fn? function Close callback function.
---@return table driver Driver shim table.
function SQLORM.spacetimedb_driver(driver_or_execute_fn, query_fn_or_options, close_fn)
	local execute_fn = nil
	local query_fn = nil
	local close_function = nil
	local raw = nil
	local raw_execute = nil
	local raw_query = nil
	local raw_close = nil

	if type(driver_or_execute_fn) == "function" then
		execute_fn = driver_or_execute_fn
		if type(query_fn_or_options) == "function" then
			query_fn = query_fn_or_options
			close_function = close_fn
		elseif query_fn_or_options ~= nil then
			assert_type(query_fn_or_options, "table", "options")
			close_function = close_fn
		end
	else
		raw = driver_or_execute_fn
		local raw_type = type(raw)
		if raw_type ~= "table" and raw_type ~= "userdata" then
			return error("spacetimedb driver must be a table, userdata or function, got " .. raw_type, 2)
		end
		if query_fn_or_options ~= nil then
			assert_type(query_fn_or_options, "table", "options")
		end
		raw_execute = first_method(raw, { "execute", "exec", "run", "sql", "execute_sql", "query_raw", "execute_query" })
		raw_query = first_method(raw, { "query", "fetch_all", "select", "sql", "query_sql", "execute_query", "fetch" })
		raw_close = first_method(raw, { "close", "disconnect" })
		if not raw_execute and not raw_query then
			return error("spacetimedb driver must provide execute/exec/run/sql or query/fetch_all/select", 2)
		end
	end

	local dialect = SQLORM.dialect("spacetimedb")
	local shim = { _spacetimedb_shim = true }

	shim.execute = function(_, sql, params)
		local final_sql, interpolate_err = spacetimedb_interpolate(dialect, sql, params or {})
		if not final_sql then
			return nil, interpolate_err
		end
		if execute_fn then
			local ok, result, err = pcall(execute_fn, final_sql)
			if not ok then
				return nil, tostring(result)
			end
			return result, err
		end
		local method = raw_execute or raw_query
		local ok, result, err = pcall(raw[method], raw, final_sql, {})
		if not ok then
			return nil, tostring(result)
		end
		return result, err
	end

	shim.query = function(_, sql, params)
		local final_sql, interpolate_err = spacetimedb_interpolate(dialect, sql, params or {})
		if not final_sql then
			return nil, interpolate_err
		end
		local result, err
		if query_fn then
			local ok
			ok, result, err = pcall(query_fn, final_sql)
			if not ok then
				return nil, tostring(result)
			end
		elseif execute_fn then
			local ok
			ok, result, err = pcall(execute_fn, final_sql)
			if not ok then
				return nil, tostring(result)
			end
		else
			local method = raw_query or raw_execute
			local ok
			ok, result, err = pcall(raw[method], raw, final_sql, {})
			if not ok then
				return nil, tostring(result)
			end
		end
		if err ~= nil then
			return result, err
		end
		if result == nil then
			return {}
		end
		return spacetimedb_normalize_rows(result)
	end

	shim.close = function(_)
		if close_function then
			return close_function()
		end
		if execute_fn then
			return true
		end
		if raw_close then
			local ok, result, err = pcall(raw[raw_close], raw)
			if not ok then
				return nil, tostring(result)
			end
			if err ~= nil then
				return result, err
			end
			return result ~= false
		end
		return true
	end

	return shim
end

--- Open SpacetimeDB connection (dialect forced to spacetimedb).<br>
--- Wraps the driver with parameter interpolation unless already wrapped.
---@param driver table|userdata|function Raw driver, shim or execute function.
---@param options? table Connection options table.
---@return SQLORM.Connection connection New connection instance.
function SQLORM.spacetimedb(driver, options)
	options = shallow_copy(options or {})
	options.dialect = "spacetimedb"
	if type(driver) == "table" and driver._spacetimedb_shim then
		return SQLORM.open(driver, options)
	end
	if getmetatable(driver) == DriverAdapter then
		return SQLORM.open(SQLORM.spacetimedb_driver(driver.raw, nil), options)
	end
	return SQLORM.open(SQLORM.spacetimedb_driver(driver, nil), options)
end

----------------------------------------------------------------------
-- Optional DAO / Repository layer
----------------------------------------------------------------------

--- Repository for model persistence.
---@class SQLORM.Repository
---@field model SQLORM.ModelMeta Model metadata object.
local Repository = {}
Repository.__index = Repository

--- Create repository.
---@param model SQLORM.ModelMeta Model metadata object.
---@return SQLORM.Repository repo New repository instance.
function Repository:new(model)
	return setmetatable({ model = model }, self)
end

--- Find by primary key.
---@param id any Primary key value.
---@return SQLORM.ModelInstance? model Found model or nil.
---@return any err Error object on failure.
function Repository:find(id)
	return self.model:find(id)
end

--- Get by primary key.
---@param id any Primary key value.
---@return SQLORM.ModelInstance? model Found model or nil.
---@return any err Error object on failure.
function Repository:get(id)
	local result, err = self:find(id)
	if not result then
		return nil, err or Error:new("ORMError", "entity not found")
	end
	return result
end

--- Fetch all entities.
---@return table? models All model instances.
---@return any err Error object on failure.
function Repository:all()
	return self.model:all()
end

--- Find by values.
---@param values table Filter values table.
---@return SQLORM.ModelInstance? model Found model or nil.
---@return any err Error object on failure.
function Repository:find_by(values)
	return self.model:query():where(values):first()
end

--- Filter by values.
---@param values table Filter values table.
---@return SQLORM.ModelQuery query Model query object.
function Repository:filter(values)
	return self.model:query():where(values)
end

--- Create new entity.
---@param values table Initial values table.
---@return SQLORM.ModelInstance? model Created model or nil.
---@return any err Error object on failure.
function Repository:create(values)
	return self.model:create(values)
end

--- Delete by primary key.
---@param id any Primary key value.
---@return any result Delete result object.
---@return any err Error object on failure.
function Repository:delete(id)
	return self.model:delete_where({ [self.model.primary_key] = id })
end

--- Count matching entities.
---@param values? table Filter values table.
---@return integer? count Matching count value.
---@return any err Error object on failure.
function Repository:count(values)
	return self.model:count(values)
end

SQLORM.Repository = Repository

--- Create repository instance.
---@param model SQLORM.ModelMeta Model metadata object.
---@return SQLORM.Repository repo New repository instance.
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
