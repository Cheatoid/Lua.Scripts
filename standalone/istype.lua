-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Simple type-checking functions for convenience

-- Localized type function for better performance
local type = type

local isnone
do
	local select, HASH = select, "#"
	--- Checks if no arguments were passed.
	---@param ... any Variadic arguments.
	---@return boolean isnone `true` if no arguments were passed, `false` otherwise.
	function isnone(...)
		return 0 == select(HASH, ...)
	end
end

local iscallable
do
	local getmetatable = getmetatable
	--- Checks if a value is callable (function or has `__call` metamethod).
	---@param v any The value to check.
	---@return boolean iscallable `true` if the value is callable, `false` otherwise.
	function iscallable(v)
		local func = "function"
		if type(v) ~= func then
			local mt = getmetatable(v)
			return mt and type(mt.__call) == func
		end
		return true
	end
end

local isinteger
do
	local math_modf, num = math.modf, "number"
	--- Checks if a value is an integer (whole number).
	---@param v any The value to check.
	---@return boolean isinteger `true` if the value is an integer, `false` otherwise.
	function isinteger(v)
		return type(v) == num and v == v and v == (math_modf(v))
	end
end

--- Checks if a value is nil.
---@param v any The value to check.
---@return boolean isnil `true` if the `v` is `nil`, `false` otherwise.
local function isnil(v)
	return type(v) == "nil"
end

--- Checks if a value is a boolean.
---@param v any The value to check.
---@return boolean isboolean `true` if the `v` is `boolean`, `false` otherwise.
local function isboolean(v)
	return type(v) == "boolean"
end

--- Checks if a value is a number.
---@param v any The value to check.
---@return boolean isnumber `true` if the `v` is `number`, `false` otherwise.
local function isnumber(v)
	return type(v) == "number"
end

--- Checks if a value is a string.
---@param v any The value to check.
---@return boolean isstring `true` if the `v` is `string`, `false` otherwise.
local function isstring(v)
	return type(v) == "string"
end

--- Checks if a value is a table.
---@param v any The value to check.
---@return boolean istable `true` if the `v` is `table`, `false` otherwise.
local function istable(v)
	return type(v) == "table"
end

--- Checks if a value is a function.
---@param v any The value to check.
---@return boolean isfunction `true` if the `v` is `function`, `false` otherwise.
local function isfunction(v)
	return type(v) == "function"
end

--- Checks if a value is a thread.
---@param v any The value to check.
---@return boolean isthread `true` if the `v` is `thread`, `false` otherwise.
local function isthread(v)
	return type(v) == "thread"
end

--- Checks if a value is userdata.
---@param v any The value to check.
---@return boolean isuserdata `true` if the `v` is `userdata`, `false` otherwise.
local function isuserdata(v)
	return type(v) == "userdata"
end

-- Export
return {
	isnone = isnone,
	iscallable = iscallable,
	isinteger = isinteger,
	isnil = isnil,
	isboolean = isboolean,
	isnumber = isnumber,
	isstring = isstring,
	istable = istable,
	isfunction = isfunction,
	isthread = isthread,
	isuserdata = isuserdata,
}
