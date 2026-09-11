-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Localized builtins for performance
--local assert            = assert
local error             = error
local getmetatable      = getmetatable
local pcall             = pcall
local rawget            = rawget
local rawset            = rawset
local select            = select
local setmetatable      = setmetatable
local tonumber          = tonumber
local tostring          = tostring
local type              = type
--local xpcall            = xpcall
local math_modf         = math.modf
local string_format     = string.format
local string_find       = string.find
local string_match      = string.match
local table_concat      = table.concat
local table_insert      = table.insert
local table_pack        = table.pack or function(...) return { ..., n = select("#", ...) } end
local table_remove      = table.remove
local table_unpack      = table.unpack or unpack

-- Import dependencies
--local detected_runtime  = require("../standalone/detect_runtime")()
local bitwise           = require "../standalone/bitwise"
local to_string_literal = require("../standalone/to_string_literal").to_string_literal

--- Small stack-based VM with a Lua-C-API-like stack surface.<br>
--- Provides a simple stack-based virtual machine with an API similar to Lua's C API.
--- Supports bytecode compilation, execution, and a Lua-like stack manipulation interface.
---@class StackVM
---@field TNIL integer Type constant for nil (0)
---@field TBOOLEAN integer Type constant for boolean (1)
---@field TNUMBER integer Type constant for number (3)
---@field TSTRING integer Type constant for string (4)
---@field TTABLE integer Type constant for table (5)
---@field TFUNCTION integer Type constant for function (6)
---@field TUSERDATA integer Type constant for userdata (7)
---@field TTHREAD integer Type constant for thread (8)
---@field OP table Opcode constants table
local StackVM           = {}

--[[
	API surface (subset):
		StackVM.new(maxstack)
		L:gettop(), L:settop(idx), L:pop(n)
		L:pushnil(), L:pushboolean(b), L:pushnumber(n), L:pushstring(s)
		L:pushvalue(idx)
		L:type(idx), L:typename(t)
		L:tonumber(idx), L:tostring(idx), L:toboolean(idx)
		L:checktype(idx, t), L:checknumber(idx), L:checkstring(idx)

	VM:
		StackVM.compile(chunk) -> proto
		StackVM.run(L, proto, opts?) -> ok, err

	Chunk format:
		{ code = { {op="PUSHK", 1}, ... }, k = { ... }, }
		Or use StackVM.asm() helper for labels.
]]

-- Public type constants (similar to Lua's LUA_T*)
StackVM.TNIL      = 0
StackVM.TBOOLEAN  = 1
StackVM.TNUMBER   = 3
StackVM.TSTRING   = 4
StackVM.TTABLE    = 5
StackVM.TFUNCTION = 6
StackVM.TUSERDATA = 7
StackVM.TTHREAD   = 8

----------------------------------------------------------------------
-- TValue: Tagged Value representation
----------------------------------------------------------------------

local TValue      = {}
TValue.__index    = TValue

-- Type name lookup
local TYPENAMES   = {
	[StackVM.TNIL]      = "nil",
	[StackVM.TBOOLEAN]  = "boolean",
	[StackVM.TNUMBER]   = "number",
	[StackVM.TSTRING]   = "string",
	[StackVM.TTABLE]    = "table",
	[StackVM.TFUNCTION] = "function",
	[StackVM.TUSERDATA] = "userdata",
	[StackVM.TTHREAD]   = "thread",
}

----------------------------------------------------------------------
-- Constructor helpers
----------------------------------------------------------------------

--- Create a nil TValue.<br>
--- Returns a TValue representing nil.
---@return TValue tval The nil TValue.
local function tnil() return setmetatable({ tag = StackVM.TNIL, value = nil }, TValue) end

--- Create a boolean TValue.<br>
--- Returns a TValue representing a boolean value.
---@param v any Value to convert to boolean (truthy/falsy).
---@return TValue tval The boolean TValue.
local function tbool(v) return setmetatable({ tag = StackVM.TBOOLEAN, value = not not v }, TValue) end

--- Create a number TValue.<br>
--- Returns a TValue representing a numeric value.
---@param v number The numeric value.
---@return TValue tval The number TValue.
local function tnumber(v) return setmetatable({ tag = StackVM.TNUMBER, value = v }, TValue) end

--- Create a string TValue.<br>
--- Returns a TValue representing a string value.
---@param v string The string value.
---@return TValue tval The string TValue.
local function tstring(v) return setmetatable({ tag = StackVM.TSTRING, value = v }, TValue) end

--- Create a table TValue.<br>
--- Returns a TValue representing a table value.
---@param v table The table value.
---@return TValue tval The table TValue.
local function ttable(v) return setmetatable({ tag = StackVM.TTABLE, value = v }, TValue) end

--- Create a function TValue.<br>
--- Returns a TValue representing a function value.
---@param v function The function value.
---@return TValue tval The function TValue.
local function tfunction(v) return setmetatable({ tag = StackVM.TFUNCTION, value = v }, TValue) end

--- Create a userdata TValue.<br>
--- Returns a TValue representing a userdata value.
---@param v any The userdata value.
---@return TValue tval The userdata TValue.
local function tuserdata(v) return setmetatable({ tag = StackVM.TUSERDATA, value = v }, TValue) end

--- Create a thread TValue.<br>
--- Returns a TValue representing a thread value.
---@param v any The thread value.
---@return TValue tval The thread TValue.
local function tthread(v) return setmetatable({ tag = StackVM.TTHREAD, value = v }, TValue) end

-- Type checking
--- Check if the value is nil.<br>
--- Returns true if the value is nil.
---@param self TValue The TValue instance.
---@return boolean is_nil True if value is nil.
function TValue:isnil() return self.tag == StackVM.TNIL end

--- Check if the value is a boolean.<br>
--- Returns true if the value is a boolean.
---@param self TValue The TValue instance.
---@return boolean is_boolean True if value is a boolean.
function TValue:isboolean() return self.tag == StackVM.TBOOLEAN end

--- Check if the value is a number.<br>
--- Returns true if the value is a number.
---@param self TValue The TValue instance.
---@return boolean is_number True if value is a number.
function TValue:isnumber() return self.tag == StackVM.TNUMBER end

--- Check if the value is a string.<br>
--- Returns true if the value is a string.
---@param self TValue The TValue instance.
---@return boolean is_string True if value is a string.
function TValue:isstring() return self.tag == StackVM.TSTRING end

--- Check if the value is a table.<br>
--- Returns true if the value is a table.
---@param self TValue The TValue instance.
---@return boolean is_table True if value is a table.
function TValue:istable() return self.tag == StackVM.TTABLE end

--- Check if the value is a function.<br>
--- Returns true if the value is a function.
---@param self TValue The TValue instance.
---@return boolean is_function True if value is a function.
function TValue:isfunction() return self.tag == StackVM.TFUNCTION end

--- Check if the value is userdata.<br>
--- Returns true if the value is userdata.
---@param self TValue The TValue instance.
---@return boolean is_userdata True if value is userdata.
function TValue:isuserdata() return self.tag == StackVM.TUSERDATA end

--- Check if the value is a thread.<br>
--- Returns true if the value is a thread.
---@param self TValue The TValue instance.
---@return boolean is_thread True if value is a thread.
function TValue:isthread() return self.tag == StackVM.TTHREAD end

--- Convert to Lua truthiness.<br>
--- Returns false for nil and false, true for all other values.<br>
--- Follows Lua's truthiness rules.
---@param self TValue The TValue instance.
---@return boolean truthy True if truthy, false if falsy.
function TValue:toboolean()
	if self.tag == StackVM.TNIL then return false end
	if self.tag == StackVM.TBOOLEAN then return self.value end
	return true
end

--- Get the type name of the value.<br>
--- Returns the string name of the type (e.g. "number", "string", "table").
---@param self TValue The TValue instance.
---@return string name The type name.
function TValue:typename()
	return TYPENAMES[self.tag] or "unknown"
end

-- String representation
local REPR_HANDLERS = {
	[StackVM.TNIL] = function(self) return "nil" end,
	[StackVM.TBOOLEAN] = function(self) return tostring(self.value) end,
	[StackVM.TNUMBER] = function(self) return tostring(self.value) end,
	[StackVM.TSTRING] = function(self) return to_string_literal(self.value) end,
	[StackVM.TTABLE] = function(self) return "table: " .. tostring(self.value) end,
	[StackVM.TFUNCTION] = function(self) return "function: " .. tostring(self.value) end,
	[StackVM.TUSERDATA] = function(self) return "userdata: " .. tostring(self.value) end,
	[StackVM.TTHREAD] = function(self) return "thread: " .. tostring(self.value) end,
}

--- Get string representation of the value.<br>
--- Returns a human-readable string representation of the value.<br>
--- Uses type-specific handlers for proper formatting.
---@param self TValue The TValue instance.
---@return string repr The string representation.
function TValue:repr()
	local handler = REPR_HANDLERS[self.tag]
	if handler then
		return handler(self)
	end
	return "unknown: " .. tostring(self.value)
end

--- Check if two values are equal.<br>
--- Returns true if the values are equal (same type and value).
---@param self TValue The TValue instance.
---@param other TValue The TValue to compare against.
---@return boolean equal True if values are equal.
function TValue:eq(other)
	if self.tag ~= other.tag then return false end
	if self.tag == StackVM.TNIL then return true end
	return self.value == other.value
end

--- Less than comparison.<br>
--- Returns true if the value is less than the other value.<br>
--- Both values must be numbers.
---@param self TValue The TValue instance.
---@param other TValue The TValue to compare against.
---@return boolean result True if self < other.
function TValue:lt(other)
	if not self:isnumber() or not other:isnumber() then
		return error("TValue:lt: both values must be numbers", 2)
	end
	return self.value < other.value
end

--- Less than or equal comparison.<br>
--- Returns true if the value is less than or equal to the other value.<br>
--- Both values must be numbers.
---@param self TValue The TValue instance.
---@param other TValue The TValue to compare against.
---@return boolean result True if self <= other.
function TValue:le(other)
	if not self:isnumber() or not other:isnumber() then
		return error("TValue:le: both values must be numbers", 2)
	end
	return self.value <= other.value
end

--- Greater than comparison.<br>
--- Returns true if the value is greater than the other value.<br>
--- Both values must be numbers.
---@param self TValue The TValue instance.
---@param other TValue The TValue to compare against.
---@return boolean result True if self > other.
function TValue:gt(other)
	if not self:isnumber() or not other:isnumber() then
		return error("TValue:gt: both values must be numbers", 2)
	end
	return self.value > other.value
end

--- Greater than or equal comparison.<br>
--- Returns true if the value is greater than or equal to the other value.<br>
--- Both values must be numbers.
---@param self TValue The TValue instance.
---@param other TValue The TValue to compare against.
---@return boolean result True if self >= other.
function TValue:ge(other)
	if not self:isnumber() or not other:isnumber() then
		return error("TValue:ge: both values must be numbers", 2)
	end
	return self.value >= other.value
end

--- Negate the value.<br>
--- Returns the arithmetic negation of the value.<br>
--- The value must be a number.
---@param self TValue The TValue instance.
---@return TValue result The negated TValue.
function TValue:neg()
	if not self:isnumber() then
		return error("TValue:neg: value must be a number", 2)
	end
	return tnumber(-self.value)
end

--- Add two values.<br>
--- Returns the sum of two number values.<br>
--- Both values must be numbers.
---@param self TValue The TValue instance.
---@param other TValue The TValue to add.
---@return TValue result The sum as a TValue.
function TValue:add(other)
	if not self:isnumber() or not other:isnumber() then
		return error("TValue:add: both values must be numbers", 2)
	end
	return tnumber(self.value + other.value)
end

--- Subtract two values.<br>
--- Returns the difference of two number values.<br>
--- Both values must be numbers.
---@param self TValue The TValue instance.
---@param other TValue The TValue to subtract.
---@return TValue result The difference as a TValue.
function TValue:sub(other)
	if not self:isnumber() or not other:isnumber() then
		return error("TValue:sub: both values must be numbers", 2)
	end
	return tnumber(self.value - other.value)
end

--- Multiply two values.<br>
--- Returns the product of two number values.<br>
--- Both values must be numbers.
---@param self TValue The TValue instance.
---@param other TValue The TValue to multiply.
---@return TValue result The product as a TValue.
function TValue:mul(other)
	if not self:isnumber() or not other:isnumber() then
		return error("TValue:mul: both values must be numbers", 2)
	end
	return tnumber(self.value * other.value)
end

--- Divide two values.<br>
--- Returns the quotient of two number values.<br>
--- Both values must be numbers. Division by zero raises an error.
---@param self TValue The TValue instance.
---@param other TValue The TValue to divide by.
---@return TValue result The quotient as a TValue.
function TValue:div(other)
	if not self:isnumber() or not other:isnumber() then
		return error("TValue:div: both values must be numbers", 2)
	end
	if other.value == 0 then
		return error("TValue:div: division by zero", 2)
	end
	return tnumber(self.value / other.value)
end

--- Modulo operation.<br>
--- Returns the remainder of division of two number values.<br>
--- Both values must be numbers.
---@param self TValue The TValue instance.
---@param other TValue The TValue to divide by.
---@return TValue result The remainder as a TValue.
function TValue:mod(other)
	if not self:isnumber() or not other:isnumber() then
		return error("TValue:mod: both values must be numbers", 2)
	end
	return tnumber(self.value % other.value)
end

--- Convert to number.<br>
--- Returns the numeric value if convertible, nil otherwise.<br>
--- Numbers return as-is, strings are converted, booleans become 1/0.
---@param self TValue The TValue instance.
---@return number? number The numeric value, or nil if not convertible.
function TValue:tonumber()
	if self.tag == StackVM.TNUMBER then
		return self.value
	end
	if self.tag == StackVM.TSTRING then
		return tonumber(self.value)
	end
	if self.tag == StackVM.TBOOLEAN then
		return self.value and 1 or 0
	end
	-- returns nil implicitly
end

--- Convert to string.<br>
--- Returns the string representation of the value.<br>
--- Uses type-specific handlers for proper formatting.
---@param self TValue The TValue instance.
---@return string str The string representation.
function TValue:tostring()
	local handler = TOSTRING_HANDLERS[self.tag]
	if handler then
		return handler(self)
	end
	return "unknown: " .. tostring(self.value)
end

-- String representation handlers
local TOSTRING_HANDLERS = {
	[StackVM.TNIL] = function(self) return "nil" end,
	[StackVM.TBOOLEAN] = function(self) return self.value and "true" or "false" end,
	[StackVM.TNUMBER] = function(self) return tostring(self.value) end,
	[StackVM.TSTRING] = function(self) return self.value end,
	[StackVM.TTABLE] = function(self) return "table: " .. tostring(self.value) end,
	[StackVM.TFUNCTION] = function(self) return "function: " .. tostring(self.value) end,
	[StackVM.TUSERDATA] = function(self) return "userdata: " .. tostring(self.value) end,
	[StackVM.TTHREAD] = function(self) return "thread: " .. tostring(self.value) end,
}

-- Create TValue from a raw Lua value
local AUTO_TVAL_HANDLERS = {
	["nil"] = function(v) return tnil() end,
	["boolean"] = function(v) return tbool(v) end,
	["number"] = function(v) return tnumber(v) end,
	["string"] = function(v) return tstring(v) end,
	["table"] = function(v) return ttable(v) end,
	["function"] = function(v) return tfunction(v) end,
	["thread"] = function(v) return tthread(v) end,
}

--- Create a TValue from a raw Lua value.<br>
--- Converts any Lua value to its corresponding TValue representation.<br>
--- Uses type-specific handlers for proper conversion.
---@param v any The Lua value to convert.
---@return TValue tval The TValue representation.
local function auto_tval(v)
	local t = type(v)
	local handler = AUTO_TVAL_HANDLERS[t]
	if handler then
		return handler(v)
	end
	return tuserdata(v)
end

-- Export TValue and constructor helpers
StackVM.TValue    = TValue
StackVM.tnil      = tnil
StackVM.tbool     = tbool
StackVM.tnumber   = tnumber
StackVM.tstring   = tstring
StackVM.ttable    = ttable
StackVM.tfunction = tfunction
StackVM.tuserdata = tuserdata
StackVM.tthread   = tthread
StackVM.auto_tval = auto_tval

local TYPE_MAP    = {
	["boolean"] = StackVM.TBOOLEAN,
	["number"] = StackVM.TNUMBER,
	["string"] = StackVM.TSTRING,
	["table"] = StackVM.TTABLE,
	["function"] = StackVM.TFUNCTION,
	["thread"] = StackVM.TTHREAD,
	["userdata"] = StackVM.TUSERDATA,
}

--- Get type constant from Lua value.<br>
--- Returns the StackVM type constant for a Lua value.<br>
--- Returns -1 for unknown types.
---@param v any The Lua value to check.
---@return integer type The type constant.
local function _typeid(v)
	if v == nil then return StackVM.TNIL end
	return TYPE_MAP[type(v)] or -1
end

----------------------------------------------------------------------
-- State + Stack API (Lua-C-API-like)
----------------------------------------------------------------------

--- Define the State class<br>
--- Represents a VM state with a stack, similar to lua_State in Lua's C API.<br>
--- Provides stack manipulation, type checking, and function calling capabilities.
---@class StackVM.State
---@field stack table The value stack
---@field top integer Current stack top index
---@field maxstack integer Maximum stack size
---@field globals table Global variable table
local State = {}
State.__index = State

--- Convert a stack index to absolute index.<br>
--- Converts negative indices (relative to top) to positive absolute indices.<br>
--- Positive indices are returned as-is.
---@param L table The State instance.
---@param idx number The stack index (negative values are relative to top).
---@return integer abs The absolute positive index.
local function _absindex(L, idx)
	if type(L) ~= "table" then
		return error("_absindex: L must be a table", 2)
	end
	if type(idx) ~= "number" then
		return error(string_format("_absindex: idx must be a number, got %s", type(idx)), 2)
	end
	if idx > 0 then return idx end
	-- Lua-like: -1 is top
	return L.top + idx + 1
end

--- Get a value from the stack at an index.<br>
--- Returns the value at the specified index, or nil if invalid.<br>
--- Uses absolute indexing internally.
---@param L table The State instance.
---@param idx number The stack index (negative values are relative to top).
---@return any value The value at the index, or nil if invalid.
local function _get(L, idx)
	if type(L) ~= "table" then
		return error("_get: L must be a table", 2)
	end
	if type(idx) ~= "number" then
		return error(string_format("_get: idx must be a number, got %s", type(idx)), 2)
	end
	local a = _absindex(L, idx)
	if a < 1 or a > L.top then return end
	return L.stack[a]
end

--- Set a value at a stack index.<br>
--- Sets the value at the specified index, extending the stack if necessary.<br>
--- Uses absolute indexing internally.
---@param L table The State instance.
---@param idx number The stack index (negative values are relative to top).
---@param v any The value to set.
local function _set(L, idx, v)
	if type(L) ~= "table" then
		return error("_set: L must be a table", 2)
	end
	if type(idx) ~= "number" then
		return error(string_format("_set: idx must be a number, got %s", type(idx)), 2)
	end
	local a = _absindex(L, idx)
	if a < 1 then
		return error(string_format("_set: invalid index %d", idx), 2)
	end
	if a > L.maxstack then
		return error(string_format("_set: stack overflow (maxstack=%d)", L.maxstack), 2)
	end
	L.stack[a] = v
	if a > L.top then L.top = a end
end

--- Check if pushing would cause stack overflow.<br>
--- Raises an error if the stack would exceed maxstack after pushing n elements.
---@param L table The State instance.
---@param n number Number of elements to push (default: 1).
local function _check_overflow(L, n)
	n = n or 1
	if type(L) ~= "table" then
		return error("_check_overflow: L must be a table", 3)
	end
	if type(n) ~= "number" then
		return error(string_format("_check_overflow: n must be a number, got %s", type(n)), 3)
	end
	if n < 0 then
		return error(string_format("_check_overflow: n must be >= 0, got %d", n), 3)
	end
	if L.top + n > L.maxstack then
		return error(string_format("stack overflow (top=%d maxstack=%d push=%d)", L.top, L.maxstack, n), 3)
	end
end

--- Check if popping would cause stack underflow.<br>
--- Raises an error if the stack doesn't have enough elements to pop n elements.
---@param L table The State instance.
---@param n number Number of elements to pop (default: 1).
local function _check_underflow(L, n)
	n = n or 1
	if type(L) ~= "table" then
		return error("_check_underflow: L must be a table", 3)
	end
	if type(n) ~= "number" then
		return error(string_format("_check_underflow: n must be a number, got %s", type(n)), 3)
	end
	if n < 0 then
		return error(string_format("_check_underflow: n must be >= 0, got %d", n), 3)
	end
	if L.top < n then
		return error(string_format("stack underflow (top=%d pop=%d)", L.top, n), 3)
	end
end

--- Create a new VM state instance.<br>
--- Initializes a new stack-based VM state with the specified maximum stack size.
---@param maxstack? integer Maximum stack size (default: 1024).
---@return StackVM.State state New VM state instance.
---@usage <br>
--- ```
--- local L = StackVM.new(256)
--- L:pushnumber(42)
--- print(L:gettop()) -- 1
--- ```
function StackVM.new(maxstack)
	maxstack = maxstack or 1024
	if type(maxstack) ~= "number" then
		return error(string_format("StackVM.new: maxstack must be a number, got %s", type(maxstack)), 2)
	end
	if maxstack < 1 then
		return error(string_format("StackVM.new: maxstack must be >= 1, got %d", maxstack), 2)
	end
	if maxstack > 1000000 then
		return error(string_format("StackVM.new: maxstack too large (%d > 1000000)", maxstack), 2)
	end
	return setmetatable({
		stack = {},
		top = 0,
		maxstack = maxstack,
		globals = {},
		hooks = {
			hook = nil,
			mask = "", -- "c" for call, "r" for return, "l" for line (instruction)
			count = 0,
			instruction_counter = 0,
		},
	}, State)
end

--- Return the current stack top index.<br>
--- Returns the index of the top element in the stack (0 if empty).
---@param self StackVM.State The State instance.
---@return integer top Current stack top index.
---@usage <br>
--- ```
--- L:pushnumber(42)
--- print(L:gettop()) -- 1
--- ```
function State.gettop(self)
	return self.top
end

--- Set the stack top to the specified index.<br>
--- Sets the stack top, filling with nil if growing or clearing if shrinking.<br>
--- Negative indices are relative to the current top (like Lua's lua_settop).
---@param self StackVM.State The State instance.
---@param idx integer New stack top index (negative values are relative to current top).
---@return StackVM.State self The State instance for chaining.
---@usage <br>
--- ```
--- L:pushnumber(1):pushnumber(2)
--- L:settop(0) -- clear stack
--- print(L:gettop()) -- 0
--- ```
function State.settop(self, idx)
	-- idx is absolute (>=0) like lua_settop; negative shrinks relative to current top
	if idx < 0 then
		idx = self.top + idx + 1
	end
	if idx < 0 then idx = 0 end
	if idx > self.maxstack then
		return error(string_format("stack overflow (settop %d > maxstack %d)", idx, self.maxstack), 2)
	end
	local s = self.stack
	-- nil out slots when shrinking (helps GC)
	for i = idx + 1, self.top do
		s[i] = nil
	end
	self.top = idx
	return self
end

--- Clear the entire stack.<br>
--- Removes all elements from the stack by setting the top to 0.<br>
--- Useful for resetting the VM state.
---@param self StackVM.State The State instance.
---@return StackVM.State self The State instance for chaining.
---@usage <br>
--- ```
--- L:pushnumber(1):pushnumber(2)
--- L:clear()
--- print(L:gettop()) -- 0
--- ```
function State.clear(self)
	return self:settop(0)
end

--- Dump the current stack contents.<br>
--- Returns a table containing all values on the stack for debugging.<br>
--- The returned table has indices 1 to top representing the stack positions.
---@param self StackVM.State The State instance.
---@return table contents Table with stack contents (1-indexed).
---@usage <br>
--- ```
--- L:pushnumber(1):pushstring("hello")
--- local contents = L:dump()
--- print(#contents) -- 2
--- print(contents[1]) -- 1
--- print(contents[2]) -- "hello"
--- ```
function State.dump(self)
	local contents = {}
	for i = 1, self.top do
		contents[i] = self.stack[i]
	end
	return contents
end

--- Reset the VM state to initial conditions.<br>
--- Clears the stack, resets the top, clears globals, and resets hooks.<br>
--- The maxstack value is preserved from the original constructor call.
---@param self StackVM.State The State instance.
---@return StackVM.State self The State instance for chaining.
---@usage <br>
--- ```
--- L:pushnumber(42)
--- L:register("x", 100)
--- L:reset()
--- print(L:gettop()) -- 0
--- print(L.globals.x) -- nil
--- ```
function State.reset(self)
	self.stack = {}
	self.top = 0
	self.globals = {}
	self.hooks = {
		hook = nil,
		mask = "",
		count = 0,
		instruction_counter = 0,
	}
	return self
end

--- Pop n elements from the stack.<br>
--- Removes the specified number of elements from the top of the stack.
---@param self StackVM.State The State instance.
---@param n? integer Number of elements to pop (default: 1).
---@return StackVM.State self The State instance for chaining.
---@usage <br>
--- ```
--- L:pushnumber(1):pushnumber(2):pushnumber(3)
--- L:pop(2)
--- print(L:gettop()) -- 1
--- ```
function State.pop(self, n)
	n = n or 1
	if type(n) ~= "number" then
		return error(string_format("State.pop: n must be a number, got %s", type(n)), 2)
	end
	_check_underflow(self, n)
	if n == 0 then return end
	self:settop(self.top - n)
	return self
end

--- Push a nil value onto the stack.<br>
--- Pushes a nil value onto the top of the stack.
---@param self StackVM.State The State instance.
---@return StackVM.State self The State instance for chaining.
---@usage <br>
--- ```
--- L:pushnil()
--- print(L:gettop()) -- 1
--- ```
function State.pushnil(self)
	_check_overflow(self, 1)
	self.top = self.top + 1
	self.stack[self.top] = nil
	return self
end

--- Push a boolean value onto the stack.<br>
--- Pushes a boolean value (true/false) onto the top of the stack.
---@param self StackVM.State The State instance.
---@param b boolean Boolean value to push.
---@return StackVM.State self The State instance for chaining.
---@usage <br>
--- ```
--- L:pushboolean(true)
--- print(L:toboolean(-1)) -- true
--- ```
function State.pushboolean(self, b)
	_check_overflow(self, 1)
	self.top = self.top + 1
	self.stack[self.top] = not not b
	return self
end

--- Push a number onto the stack.<br>
--- Pushes a numeric value onto the top of the stack.
---@param self StackVM.State The State instance.
---@param n number Number value to push.
---@return StackVM.State self The State instance for chaining.
---@usage <br>
--- ```
--- L:pushnumber(42)
--- print(L:tonumber(-1)) -- 42
--- ```
function State.pushnumber(self, n)
	if type(n) ~= "number" then
		return error(string_format("State.pushnumber: n must be a number, got %s", type(n)), 2)
	end
	_check_overflow(self, 1)
	self.top = self.top + 1
	self.stack[self.top] = n
	return self
end

--- Push a string onto the stack.<br>
--- Pushes a string value onto the top of the stack.
---@param self StackVM.State The State instance.
---@param s string String value to push.
---@return StackVM.State self The State instance for chaining.
---@usage <br>
--- ```
--- L:pushstring("hello")
--- print(L:tostring(-1)) -- "hello"
--- ```
function State.pushstring(self, s)
	if type(s) ~= "string" then
		return error(string_format("State.pushstring: s must be a string, got %s", type(s)), 2)
	end
	_check_overflow(self, 1)
	self.top = self.top + 1
	self.stack[self.top] = s
	return self
end

--- Push a copy of a stack element onto the top.<br>
--- Pushes a copy of the value at the specified index onto the top of the stack.
---@param self StackVM.State The State instance.
---@param idx integer Stack index to copy from (negative indices are relative to top).
---@return StackVM.State self The State instance for chaining.
---@usage <br>
--- ```
--- L:pushnumber(42)
--- L:pushvalue(-1) -- duplicate
--- print(L:gettop()) -- 2
--- ```
function State.pushvalue(self, idx)
	if type(idx) ~= "number" then
		return error(string_format("State.pushvalue: idx must be a number, got %s", type(idx)), 2)
	end
	_check_overflow(self, 1)
	local v = _get(self, idx)
	if v == nil then
		return error(string_format("State.pushvalue: invalid index %d", idx), 2)
	end
	self.top = self.top + 1
	self.stack[self.top] = v
	return self
end

--- Insert top element at specified index.<br>
--- Moves the top element to the specified position, shifting other elements up.
---@param self StackVM.State The State instance.
---@param idx integer Stack index to insert at (negative indices are relative to top).
---@return StackVM.State self The State instance for chaining.
---@usage <br>
--- ```
--- L:pushnumber(1):pushnumber(2):pushnumber(3)
--- L:insert(1)
--- ```
function State.insert(self, idx)
	if type(idx) ~= "number" then
		return error(string_format("State.insert: idx must be a number, got %s", type(idx)), 2)
	end
	_check_underflow(self, 1)
	-- like lua_insert: move top element to idx, shift up others
	local a = _absindex(self, idx)
	if a < 1 or a > self.top then
		return error(string_format("State.insert: invalid index %d (valid: 1-%d)", idx, self.top), 2)
	end
	local s = self.stack
	local v = s[self.top]
	for i = self.top, a + 1, -1 do
		s[i] = s[i - 1]
	end
	s[a] = v
	return self
end

--- Remove element at specified index.<br>
--- Removes the element at the specified position, shifting other elements down.
---@param self StackVM.State The State instance.
---@param idx integer Stack index to remove at (negative indices are relative to top).
---@return StackVM.State self The State instance for chaining.
---@usage <br>
--- ```
--- L:pushnumber(1):pushnumber(2):pushnumber(3)
--- L:remove(2)
--- ```
function State.remove(self, idx)
	if type(idx) ~= "number" then
		return error(string_format("State.remove: idx must be a number, got %s", type(idx)), 2)
	end
	_check_underflow(self, 1)
	-- like lua_remove
	local a = _absindex(self, idx)
	if a < 1 or a > self.top then
		return error(string_format("State.remove: invalid index %d (valid: 1-%d)", idx, self.top), 2)
	end
	local s = self.stack
	for i = a, self.top - 1 do
		s[i] = s[i + 1]
	end
	s[self.top] = nil
	self.top = self.top - 1
	return self
end

--- Replace element at index with top value.<br>
--- Pops the top element and places it at the specified index.
---@param self StackVM.State The State instance.
---@param idx integer Stack index to replace at (negative indices are relative to top).
---@return StackVM.State self The State instance for chaining.
---@usage <br>
--- ```
--- L:pushnumber(1):pushnumber(2):pushnumber(3)
--- L:replace(1)
--- ```
function State.replace(self, idx)
	if type(idx) ~= "number" then
		return error(string_format("State.replace: idx must be a number, got %s", type(idx)), 2)
	end
	_check_underflow(self, 1)
	-- like lua_replace: pop top into idx
	local a = _absindex(self, idx)
	if a < 1 or a > self.maxstack then
		return error(string_format("State.replace: invalid index %d (valid: 1-%d)", idx, self.maxstack), 2)
	end
	local s = self.stack
	local v = s[self.top]
	s[self.top] = nil
	self.top = self.top - 1
	s[a] = v
	if a > self.top then self.top = a end
	return self
end

--- Copy a value from one stack index to another.<br>
--- Copies the value at fromidx to toidx without modifying the source.
---@param self StackVM.State The State instance.
---@param fromidx integer Source stack index (negative indices are relative to top).
---@param toidx integer Destination stack index (negative indices are relative to top).
---@return StackVM.State self The State instance for chaining.
---@usage <br>
--- ```
--- L:pushnumber(42)
--- L:copy(-1, 1)
--- ```
function State.copy(self, fromidx, toidx)
	if type(fromidx) ~= "number" then
		return error(string_format("State.copy: fromidx must be a number, got %s", type(fromidx)), 2)
	end
	if type(toidx) ~= "number" then
		return error(string_format("State.copy: toidx must be a number, got %s", type(toidx)), 2)
	end
	local fa = _absindex(self, fromidx)
	local ta = _absindex(self, toidx)
	if fa < 1 or fa > self.top then
		return error(string_format("State.copy: invalid from index %d", fromidx), 2)
	end
	if ta < 1 or ta > self.maxstack then
		return error(string_format("State.copy: invalid to index %d", toidx), 2)
	end
	self.stack[ta] = self.stack[fa]
	if ta > self.top then self.top = ta end
	return self
end

--- Get the type of a stack element.<br>
--- Returns the type constant (StackVM.TNIL, StackVM.TNUMBER, etc.) of the value at the specified index.
---@param self StackVM.State The State instance.
---@param idx integer Stack index to check (negative indices are relative to top).
---@return integer type Type constant value.
---@usage <br>
--- ```
--- L:pushnumber(42)
--- print(L:type(-1)) -- StackVM.TNUMBER (3)
--- ```
function State.type(self, idx)
	if type(idx) ~= "number" then
		return error(string_format("State.type: idx must be a number, got %s", type(idx)), 2)
	end
	return _typeid(_get(self, idx))
end

--- Get the type name from a type constant.<br>
--- Converts a type constant to its string representation.
---@param self StackVM.State The State instance.
---@param t integer Type constant value.
---@return string name Type name as string.
---@usage <br>
--- ```
--- print(L:typename(StackVM.TNUMBER)) -- "number"
--- ```
function State.typename(self, t)
	if type(t) ~= "number" then
		return error(string_format("State.typename: t must be a number, got %s", type(t)), 2)
	end
	return TYPENAMES[t] or "unknown"
end

--- Convert stack element to number.<br>
--- Returns the value at the specified index as a number if possible.
---@param self StackVM.State The State instance.
---@param idx integer Stack index to convert (negative indices are relative to top).
---@return number? number The number value, or nil if not convertible.
---@usage <br>
--- ```
--- L:pushnumber(42)
--- print(L:tonumber(-1)) -- 42
--- ```
function State.tonumber(self, idx)
	if type(idx) ~= "number" then
		return error(string_format("State.tonumber: idx must be a number, got %s", type(idx)), 2)
	end
	local v = _get(self, idx)
	if v == nil then
		return error(string_format("State.tonumber: invalid index %d", idx), 2)
	end
	if type(v) == "number" then return v end
	if type(v) == "string" then return tonumber(v) end
	-- returns nil implicitly
end

--- Convert stack element to string.<br>
--- Returns the value at the specified index as a string if possible.
---@param self StackVM.State The State instance.
---@param idx integer Stack index to convert (negative indices are relative to top).
---@return string? string The string value, or nil if value is nil.
---@usage <br>
--- ```
--- L:pushstring("hello")
--- print(L:tostring(-1)) -- "hello"
--- ```
function State.tostring(self, idx)
	if type(idx) ~= "number" then
		return error(string_format("State.tostring: idx must be a number, got %s", type(idx)), 2)
	end
	local v = _get(self, idx)
	if v == nil then
		return error(string_format("State.tostring: invalid index %d", idx), 2)
	end
	return tostring(v)
end

--- Convert stack element to boolean.<br>
--- Returns the boolean value of the element at the specified index.
---@param self StackVM.State The State instance.
---@param idx integer Stack index to convert (negative indices are relative to top).
---@return boolean boolean Boolean value (false for nil/false, true otherwise).
---@usage <br>
--- ```
--- L:pushboolean(true)
--- print(L:toboolean(-1)) -- true
--- ```
function State.toboolean(self, idx)
	if type(idx) ~= "number" then
		return error(string_format("State.toboolean: idx must be a number, got %s", type(idx)), 2)
	end
	return not not _get(self, idx)
end

--- Convert a stack index to an absolute index.<br>
--- Converts negative indices (relative to top) to positive absolute indices.
---@param self StackVM.State The State instance.
---@param idx integer Stack index to convert (negative indices are relative to top).
---@return integer index Absolute positive index.
---@usage <br>
--- ```
--- L:pushnumber(1):pushnumber(2):pushnumber(3)
--- print(L:absindex(-1)) -- 3
--- print(L:absindex(-2)) -- 2
--- print(L:absindex(1))  -- 1
--- ```
function State.absindex(self, idx)
	if type(idx) ~= "number" then
		return error(string_format("State.absindex: idx must be a number, got %s", type(idx)), 2)
	end
	return _absindex(self, idx)
end

--- Get a value from the stack at an index without popping.<br>
--- Returns the value at the specified index without modifying the stack.
---@param self StackVM.State The State instance.
---@param idx integer Stack index to get from (negative indices are relative to top).
---@return any value The value at the index, or nil if invalid.
---@usage <br>
--- ```
--- L:pushnumber(42)
--- local v = L:get(-1)
--- print(v) -- 42
--- print(L:gettop()) -- 1 (unchanged)
--- ```
function State.get(self, idx)
	if type(idx) ~= "number" then
		return error(string_format("State.get: idx must be a number, got %s", type(idx)), 2)
	end
	return _get(self, idx)
end

--- Set a value at a stack index.<br>
--- Sets the value at the specified index, extending the stack if necessary.
---@param self StackVM.State The State instance.
---@param idx integer Stack index to set at (negative indices are relative to top).
---@param v any Value to set.
---@return StackVM.State self The State instance for chaining.
---@usage <br>
--- ```
--- L:pushnumber(42)
--- L:set(1, 100)
--- print(L:tonumber(1)) -- 100
--- ```
function State.set(self, idx, v)
	if type(idx) ~= "number" then
		return error(string_format("State.set: idx must be a number, got %s", type(idx)), 2)
	end
	_set(self, idx, v)
	return self
end

--- Check if stack element is nil.<br>
--- Returns true if the value at the specified index is nil.
---@param self StackVM.State The State instance.
---@param idx integer Stack index to check (negative indices are relative to top).
---@return boolean boolean True if value is nil.
function State.isnil(self, idx)
	if type(idx) ~= "number" then
		return error(string_format("State.isnil: idx must be a number, got %s", type(idx)), 2)
	end
	return _get(self, idx) == nil
end

--- Check if stack element is a boolean.<br>
--- Returns true if the value at the specified index is a boolean.
---@param self StackVM.State The State instance.
---@param idx integer Stack index to check (negative indices are relative to top).
---@return boolean boolean True if value is a boolean.
function State.isboolean(self, idx)
	if type(idx) ~= "number" then
		return error(string_format("State.isboolean: idx must be a number, got %s", type(idx)), 2)
	end
	return type(_get(self, idx)) == "boolean"
end

--- Check if stack element is a number.<br>
--- Returns true if the value at the specified index is a number.
---@param self StackVM.State The State instance.
---@param idx integer Stack index to check (negative indices are relative to top).
---@return boolean boolean True if value is a number.
function State.isnumber(self, idx)
	if type(idx) ~= "number" then
		return error(string_format("State.isnumber: idx must be a number, got %s", type(idx)), 2)
	end
	return type(_get(self, idx)) == "number"
end

--- Check if stack element is a string.<br>
--- Returns true if the value at the specified index is a string.
---@param self StackVM.State The State instance.
---@param idx integer Stack index to check (negative indices are relative to top).
---@return boolean boolean True if value is a string.
function State.isstring(self, idx)
	if type(idx) ~= "number" then
		return error(string_format("State.isstring: idx must be a number, got %s", type(idx)), 2)
	end
	return type(_get(self, idx)) == "string"
end

--- Check if stack element is a table.<br>
--- Returns true if the value at the specified index is a table.
---@param self StackVM.State The State instance.
---@param idx integer Stack index to check (negative indices are relative to top).
---@return boolean boolean True if value is a table.
function State.istable(self, idx)
	if type(idx) ~= "number" then
		return error(string_format("State.istable: idx must be a number, got %s", type(idx)), 2)
	end
	return type(_get(self, idx)) == "table"
end

--- Check if stack element is a function.<br>
--- Returns true if the value at the specified index is a function.
---@param self StackVM.State The State instance.
---@param idx integer Stack index to check (negative indices are relative to top).
---@return boolean boolean True if value is a function.
function State.isfunction(self, idx)
	if type(idx) ~= "number" then
		return error(string_format("State.isfunction: idx must be a number, got %s", type(idx)), 2)
	end
	return type(_get(self, idx)) == "function"
end

--- Check if stack element is a C function.<br>
--- Returns true if the value at the specified index is a C function (light C function).
---@param self StackVM.State The State instance.
---@param idx integer Stack index to check (negative indices are relative to top).
---@return boolean boolean True if value is a C function.
function State.iscfunction(self, idx)
	if type(idx) ~= "number" then
		return error(string_format("State.iscfunction: idx must be a number, got %s", type(idx)), 2)
	end
	local v = _get(self, idx)
	return type(v) == "function" and debug.getinfo(v, "S").what == "C"
end

--- Check if stack element is a userdata.<br>
--- Returns true if the value at the specified index is a userdata.
---@param self StackVM.State The State instance.
---@param idx integer Stack index to check (negative indices are relative to top).
---@return boolean boolean True if value is a userdata.
function State.isuserdata(self, idx)
	if type(idx) ~= "number" then
		return error(string_format("State.isuserdata: idx must be a number, got %s", type(idx)), 2)
	end
	return type(_get(self, idx)) == "userdata"
end

--- Check if stack element is a thread.<br>
--- Returns true if the value at the specified index is a thread.
---@param self StackVM.State The State instance.
---@param idx integer Stack index to check (negative indices are relative to top).
---@return boolean boolean True if value is a thread.
function State.isthread(self, idx)
	if type(idx) ~= "number" then
		return error(string_format("State.isthread: idx must be a number, got %s", type(idx)), 2)
	end
	return type(_get(self, idx)) == "thread"
end

--- Check if stack element is a number and return it.<br>
--- Returns the number at the specified index, or raises an error if not a number.
---@param self StackVM.State The State instance.
---@param idx integer Stack index to check (negative indices are relative to top).
---@return number number The number value.
---@usage <br>
--- ```
--- L:pushnumber(42)
--- local n = L:checknumber(-1)
--- ```
function State.checknumber(self, idx)
	if type(idx) ~= "number" then
		return error(string_format("State.checknumber: idx must be a number, got %s", type(idx)), 2)
	end
	local v = _get(self, idx)
	if type(v) ~= "number" then
		return error(string_format("State.checknumber: expected number at index %d, got %s", idx, type(v)), 2)
	end
	return v
end

--- Check if stack element is a string and return it.<br>
--- Returns the string at the specified index, or raises an error if not a string.
---@param self StackVM.State The State instance.
---@param idx integer Stack index to check (negative indices are relative to top).
---@return string string The string value.
---@usage <br>
--- ```
--- L:pushstring("hello")
--- local s = L:checkstring(-1)
--- ```
function State.checkstring(self, idx)
	if type(idx) ~= "number" then
		return error(string_format("State.checkstring: idx must be a number, got %s", type(idx)), 2)
	end
	local v = _get(self, idx)
	if type(v) ~= "string" then
		return error(string_format("State.checkstring: expected string at index %d, got %s", idx, type(v)), 2)
	end
	return v
end

--- Check if stack element is a boolean and return it.<br>
--- Returns the boolean at the specified index, or raises an error if not a boolean.
---@param self StackVM.State The State instance.
---@param idx integer Stack index to check (negative indices are relative to top).
---@return boolean boolean The boolean value.
---@usage <br>
--- ```
--- L:pushboolean(true)
--- local b = L:checkboolean(-1)
--- ```
function State.checkboolean(self, idx)
	if type(idx) ~= "number" then
		return error(string_format("State.checkboolean: idx must be a number, got %s", type(idx)), 2)
	end
	local v = _get(self, idx)
	if type(v) ~= "boolean" then
		return error(string_format("State.checkboolean: expected boolean at index %d, got %s", idx, type(v)), 2)
	end
	return v
end

--- Check if stack element is a table and return it.<br>
--- Returns the table at the specified index, or raises an error if not a table.
---@param self StackVM.State The State instance.
---@param idx integer Stack index to check (negative indices are relative to top).
---@return table table The table value.
---@usage <br>
--- ```
--- L:pushvalue(t)
--- local tab = L:checktable(-1)
--- ```
function State.checktable(self, idx)
	if type(idx) ~= "number" then
		return error(string_format("State.checktable: idx must be a number, got %s", type(idx)), 2)
	end
	local v = _get(self, idx)
	if type(v) ~= "table" then
		return error(string_format("State.checktable: expected table at index %d, got %s", idx, type(v)), 2)
	end
	return v
end

--- Check if stack element is a function and return it.<br>
--- Returns the function at the specified index, or raises an error if not a function.
---@param self StackVM.State The State instance.
---@param idx integer Stack index to check (negative indices are relative to top).
---@return function function The function value.
---@usage <br>
--- ```
--- L:pushcfunction(print)
--- local fn = L:checkfunction(-1)
--- ```
function State.checkfunction(self, idx)
	if type(idx) ~= "number" then
		return error(string_format("State.checkfunction: idx must be a number, got %s", type(idx)), 2)
	end
	local v = _get(self, idx)
	if type(v) ~= "function" then
		return error(string_format("State.checkfunction: expected C function at index %d, got %s", idx, type(v)), 2)
	end
	return v
end

--- Check if stack element is an integer and return it.<br>
--- Returns the integer at the specified index, or raises an error if not an integer.
---@param self StackVM.State The State instance.
---@param idx integer Stack index to check (negative indices are relative to top).
---@return integer integer The integer value.
---@usage <br>
--- ```
--- L:pushnumber(42)
--- local i = L:checkinteger(-1)
--- ```
function State.checkinteger(self, idx)
	if type(idx) ~= "number" then
		return error(string_format("State.checkinteger: idx must be a number, got %s", type(idx)), 2)
	end
	local v = _get(self, idx)
	if type(v) ~= "number" then
		return error(string_format("State.checkinteger: expected number at index %d, got %s", idx, type(v)), 2)
	end
	if v ~= math_modf(v) then
		return error(string_format("State.checkinteger: expected integer at index %d, got %f", idx, v), 2)
	end
	return v
end

--- Check if stack element is of a specific type.<br>
--- Raises an error if the value at the specified index is not of the expected type.
---@param self StackVM.State The State instance.
---@param idx integer Stack index to check (negative indices are relative to top).
---@param t string Expected type name (e.g. "number", "string", "boolean").
---@usage <br>
--- ```
--- L:pushnumber(42)
--- L:checktype(-1, "number")
--- ```
function State.checktype(self, idx, t)
	if type(idx) ~= "number" then
		return error(string_format("State.checktype: idx must be a number, got %s", type(idx)), 2)
	end
	if type(t) ~= "string" then
		return error(string_format("State.checktype: t must be a string, got %s", type(t)), 2)
	end
	local v = _get(self, idx)
	if type(v) ~= t then
		return error(string_format("State.checktype: expected %s at index %d, got %s", t, idx, type(v)), 2)
	end
end

--- Check if stack element is any value.<br>
--- Always returns the value, useful for consistency with other check* functions.
---@param self StackVM.State The State instance.
---@param idx integer Stack index to check (negative indices are relative to top).
---@return any value The value at the index.
---@usage <br>
--- ```
--- L:pushnumber(42)
--- local v = L:checkany(-1)
--- ```
function State.checkany(self, idx)
	if type(idx) ~= "number" then
		return error(string_format("State.checkany: idx must be a number, got %s", type(idx)), 2)
	end
	return _get(self, idx)
end

--- Check if stack element is a userdata and return it.<br>
--- Returns the userdata at the specified index, or raises an error if not a userdata.
---@param self StackVM.State The State instance.
---@param idx integer Stack index to check (negative indices are relative to top).
---@return any userdata The userdata value.
---@usage <br>
--- ```
--- L:pushlightuserdata(0x1234)
--- local ud = L:checkuserdata(-1)
--- ```
function State.checkuserdata(self, idx)
	if type(idx) ~= "number" then
		return error(string_format("State.checkuserdata: idx must be a number, got %s", type(idx)), 2)
	end
	local v = _get(self, idx)
	if type(v) ~= "userdata" then
		return error(string_format("State.checkuserdata: expected userdata at index %d, got %s", idx, type(v)), 2)
	end
	return v
end

--- Convert stack element to userdata.<br>
--- Returns the value at the specified index if it is a userdata (or lightuserdata).
---@param self StackVM.State The State instance.
---@param idx integer Stack index to convert (negative indices are relative to top).
---@return any userdata The userdata value, or nil if not a userdata.
function State.touserdata(self, idx)
	if type(idx) ~= "number" then
		return error(string_format("State.touserdata: idx must be a number, got %s", type(idx)), 2)
	end
	local v = _get(self, idx)
	if v == nil then
		return error(string_format("State.touserdata: invalid index %d", idx), 2)
	end
	if type(v) == "userdata" then return v end
end

--- Convert stack element to C function.<br>
--- Returns the function at the specified index if it is a function.
---@param self StackVM.State The State instance.
---@param idx integer Stack index to convert (negative indices are relative to top).
---@return function? function The function value, or nil if not a function.
function State.tocfunction(self, idx)
	if type(idx) ~= "number" then
		return error(string_format("State.tocfunction: idx must be a number, got %s", type(idx)), 2)
	end
	local v = _get(self, idx)
	if v == nil then
		return error(string_format("State.tocfunction: invalid index %d", idx), 2)
	end
	if type(v) == "function" and debug.getinfo(v, "S").what == "C" then return v end
end

--- Get the raw Lua value from a stack element.<br>
--- Returns the raw Lua value at the specified index without type checking.
---@param self StackVM.State The State instance.
---@param idx integer Stack index to get (negative indices are relative to top).
---@return any value The raw value at the index.
function State.torawvalue(self, idx)
	if type(idx) ~= "number" then
		return error(string_format("State.torawvalue: idx must be a number, got %s", type(idx)), 2)
	end
	return _get(self, idx)
end

--- Convert stack element to table.<br>
--- Returns the table at the specified index, or nil if not a table.
---@param self StackVM.State The State instance.
---@param idx integer Stack index to convert (negative indices are relative to top).
---@return table? table The table value, or nil if not a table.
---@usage <br>
--- ```
--- L:newtable()
--- local t = L:totable(-1)
--- ```
function State.totable(self, idx)
	if type(idx) ~= "number" then
		return error(string_format("State.totable: idx must be a number, got %s", type(idx)), 2)
	end
	local v = _get(self, idx)
	if type(v) == "table" then return v end
end

--- Convert stack element to function.<br>
--- Returns the function at the specified index, or nil if not a function.
---@param self StackVM.State The State instance.
---@param idx integer Stack index to convert (negative indices are relative to top).
---@return function? function The function value, or nil if not a function.
---@usage <br>
--- ```
--- L:pushcfunction(print)
--- local fn = L:tofunction(-1)
--- ```
function State.tofunction(self, idx)
	if type(idx) ~= "number" then
		return error(string_format("State.tofunction: idx must be a number, got %s", type(idx)), 2)
	end
	local v = _get(self, idx)
	if type(v) == "function" then return v end
end

--- Check that stack element has the specified type.<br>
--- Raises an error if the element at the specified index is not of the expected type.
---@param self StackVM.State The State instance.
---@param idx integer Stack index to check (negative indices are relative to top).
---@param t integer Expected type constant.
---@return StackVM.State self The State instance for chaining.
---@usage <br>
--- ```
--- L:pushnumber(42)
--- L:checktype(-1, StackVM.TNUMBER)
--- ```
function State.checktype(self, idx, t)
	if type(idx) ~= "number" then
		return error(string_format("State.checktype: idx must be a number, got %s", type(idx)), 2)
	end
	if type(t) ~= "number" then
		return error(string_format("State.checktype: t must be a number, got %s", type(t)), 2)
	end
	local got = self:type(idx)
	if got ~= t then
		return error(string_format(
			"State.checktype: type error at %d: expected %s, got %s", idx, self:typename(t), self:typename(got)), 2)
	end
	return self
end

--- Check that stack element is a number and return it.<br>
--- Raises an error if the element at the specified index is not a number.
---@param self StackVM.State The State instance.
---@param idx integer Stack index to check (negative indices are relative to top).
---@return number number The number value.
---@usage <br>
--- ```
--- L:pushnumber(42)
--- local n = L:checknumber(-1)
--- ```
function State.checknumber(self, idx)
	if type(idx) ~= "number" then
		return error(string_format("State.checknumber: idx must be a number, got %s", type(idx)), 2)
	end
	local n = self:tonumber(idx)
	if n == nil then
		local got = self:type(idx)
		return error(string_format("State.checknumber: number expected at %d (got %s)", idx, self:typename(got)), 2)
	end
	return n
end

--- Check that stack element is a string and return it.<br>
--- Raises an error if the element at the specified index is not a string.
---@param self StackVM.State The State instance.
---@param idx integer Stack index to check (negative indices are relative to top).
---@return string string The string value.
---@usage <br>
--- ```
--- L:pushstring("hello")
--- local s = L:checkstring(-1)
--- ```
function State.checkstring(self, idx)
	if type(idx) ~= "number" then
		return error(string_format("State.checkstring: idx must be a number, got %s", type(idx)), 2)
	end
	local v = _get(self, idx)
	if v == nil then
		return error(string_format("State.checkstring: invalid index %d", idx), 2)
	end
	if type(v) ~= "string" then
		local got = self:type(idx)
		return error(string_format("State.checkstring: string expected at %d (got %s)", idx, self:typename(got)), 2)
	end
	return v
end

--- Push the value of a global variable onto the stack.<br>
--- Retrieves the value of a global variable and pushes it onto the stack.
---@param self StackVM.State The State instance.
---@param name string Name of the global variable.
---@return StackVM.State self The State instance for chaining.
---@usage <br>
--- ```
--- L:register("x", 42)
--- L:getglobal("x")
--- print(L:tonumber(-1)) -- 42
--- ```
function State.getglobal(self, name)
	if type(name) ~= "string" then
		return error(string_format("State.getglobal: name must be a string, got %s", type(name)), 2)
	end
	_check_overflow(self, 1)
	self.top = self.top + 1
	self.stack[self.top] = rawget(self.globals, name)
	return self
end

--- Pop the top value and set it as a global variable.<br>
--- Pops the top value from the stack and stores it in the global variable table.
---@param self StackVM.State The State instance.
---@param name string Name of the global variable.
---@return StackVM.State self The State instance for chaining.
---@usage <br>
--- ```
--- L:pushnumber(42)
--- L:setglobal("x")
--- ```
function State.setglobal(self, name)
	if type(name) ~= "string" then
		return error(string_format("State.setglobal: name must be a string, got %s", type(name)), 2)
	end
	_check_underflow(self, 1)
	local v = self.stack[self.top]
	self.stack[self.top] = nil
	self.top = self.top - 1
	rawset(self.globals, name, v)
	return self
end

--- Register a Lua function as a global variable.<br>
--- Stores a Lua function in the global variable table for use by VM bytecode.
---@param self StackVM.State The State instance.
---@param name string Name to register the function under.
---@param fn function Lua function to register.
---@return StackVM.State self The State instance for chaining.
---@usage <br>
--- ```
--- L:register("print", print)
--- ```
function State.register(self, name, fn)
	if type(name) ~= "string" then
		return error(string_format("State.register: name must be a string, got %s", type(name)), 2)
	end
	if type(fn) ~= "function" then
		return error(string_format("State.register: fn must be a function, got %s", type(fn)), 2)
	end
	rawset(self.globals, name, fn)
	return self
end

--- Create a new table and push it onto the stack.<br>
--- Creates a table with pre-allocated array and hash sizes.
---@param self StackVM.State The State instance.
---@param narr integer Number of array elements to pre-allocate.
---@param nrec integer Number of hash elements to pre-allocate.
---@return StackVM.State self The State instance for chaining.
---@usage <br>
--- ```
--- L:createtable(10, 5)
--- ```
function State.createtable(self, narr, nrec)
	if type(narr) ~= "number" then
		return error(string_format("State.createtable: narr must be a number, got %s", type(narr)), 2)
	end
	if type(nrec) ~= "number" then
		return error(string_format("State.createtable: nrec must be a number, got %s", type(nrec)), 2)
	end
	_check_overflow(self, 1)
	self.top = self.top + 1
	self.stack[self.top] = {}
	return self
end

--- Create a new empty table and push it onto the stack.<br>
--- Convenience function for creating a table with no pre-allocation.
---@param self StackVM.State The State instance.
---@return StackVM.State self The State instance for chaining.
---@usage <br>
--- ```
--- L:newtable()
--- ```
function State.newtable(self)
	return self:createtable(0, 0)
end

--- Get a table value.<br>
--- Pushes t[k] where t is at idx and k is on top of the stack.
---@param self StackVM.State The State instance.
---@param idx integer Stack index of the table (negative indices are relative to top).
---@return StackVM.State self The State instance for chaining.
---@usage <br>
--- ```
--- L:newtable()
--- L:pushstring("key"):pushstring("value"):settable(-3)
--- L:pushstring("key"):gettable(-2)
--- ```
function State.gettable(self, idx)
	if type(idx) ~= "number" then
		return error(string_format("State.gettable: idx must be a number, got %s", type(idx)), 2)
	end
	_check_underflow(self, 1)
	local t = _get(self, idx)
	local k = self.stack[self.top]
	if type(t) ~= "table" then
		return error(string_format("State.gettable: expected table at index %d, got %s", idx, type(t)), 2)
	end
	self.stack[self.top] = rawget(t, k)
	return self
end

--- Set a table value.<br>
--- Pops key and value from stack and sets t[k] = v where t is at idx.
---@param self StackVM.State The State instance.
---@param idx integer Stack index of the table (negative indices are relative to top).
---@return StackVM.State self The State instance for chaining.
---@usage <br>
--- ```
--- L:newtable()
--- L:pushstring("key"):pushstring("value"):settable(-3)
--- ```
function State.settable(self, idx)
	if type(idx) ~= "number" then
		return error(string_format("State.settable: idx must be a number, got %s", type(idx)), 2)
	end
	_check_underflow(self, 2)
	local t = _get(self, idx)
	if type(t) ~= "table" then
		return error(string_format("State.settable: expected table at index %d, got %s", idx, type(t)), 2)
	end
	local v = self.stack[self.top]
	local k = self.stack[self.top - 1]
	rawset(t, k, v)
	self.stack[self.top] = nil
	self.stack[self.top - 1] = nil
	self.top = self.top - 2
	return self
end

--- Get a table field by name.<br>
--- Pushes t[name] where t is at idx onto the stack.
---@param self StackVM.State The State instance.
---@param idx integer Stack index of the table (negative indices are relative to top).
---@param name string Field name to get.
---@return StackVM.State self The State instance for chaining.
---@usage <br>
--- ```
--- L:newtable()
--- L:pushstring("value"):setfield(-2, "key")
--- L:getfield(-1, "key")
--- ```
function State.getfield(self, idx, name)
	if type(idx) ~= "number" then
		return error(string_format("State.getfield: idx must be a number, got %s", type(idx)), 2)
	end
	if type(name) ~= "string" then
		return error(string_format("State.getfield: name must be a string, got %s", type(name)), 2)
	end
	_check_overflow(self, 1)
	local t = _get(self, idx)
	if type(t) ~= "table" then
		return error(string_format("State.getfield: expected table at index %d, got %s", idx, type(t)), 2)
	end
	self.top = self.top + 1
	self.stack[self.top] = rawget(t, name)
	return self
end

--- Set a table field by name.<br>
--- Pops the value from stack and sets t[name] = v where t is at idx.
---@param self StackVM.State The State instance.
---@param idx integer Stack index of the table (negative indices are relative to top).
---@param name string Field name to set.
---@return StackVM.State self The State instance for chaining.
---@usage <br>
--- ```
--- L:newtable()
--- L:pushstring("value"):setfield(-2, "key")
--- ```
function State.setfield(self, idx, name)
	if type(idx) ~= "number" then
		return error(string_format("State.setfield: idx must be a number, got %s", type(idx)), 2)
	end
	if type(name) ~= "string" then
		return error(string_format("State.setfield: name must be a string, got %s", type(name)), 2)
	end
	_check_underflow(self, 1)
	local t = _get(self, idx)
	if type(t) ~= "table" then
		return error(string_format("State.setfield: expected table at index %d, got %s", idx, type(t)), 2)
	end
	local v = self.stack[self.top]
	rawset(t, name, v)
	self.stack[self.top] = nil
	self.top = self.top - 1
	return self
end

--- Get a table value by integer index.<br>
--- Pushes t[n] where t is at idx onto the stack.
---@param self StackVM.State The State instance.
---@param idx integer Stack index of the table (negative indices are relative to top).
---@param n integer Integer index to get.
---@return StackVM.State self The State instance for chaining.
---@usage <br>
--- ```
--- L:newtable()
--- L:pushstring("a"):pushstring("b"):rawseti(-3, 1)
--- L:rawgeti(-1, 1)
--- ```
function State.rawgeti(self, idx, n)
	if type(idx) ~= "number" then
		return error(string_format("State.rawgeti: idx must be a number, got %s", type(idx)), 2)
	end
	if type(n) ~= "number" then
		return error(string_format("State.rawgeti: n must be a number, got %s", type(n)), 2)
	end
	_check_overflow(self, 1)
	local t = _get(self, idx)
	if type(t) ~= "table" then
		return error(string_format("State.rawgeti: expected table at index %d, got %s", idx, type(t)), 2)
	end
	self.top = self.top + 1
	self.stack[self.top] = rawget(t, n)
	return self
end

--- Set a table value by integer index.<br>
--- Pops the value from stack and sets t[n] = v where t is at idx.
---@param self StackVM.State The State instance.
---@param idx integer Stack index of the table (negative indices are relative to top).
---@param n integer Integer index to set.
---@return StackVM.State self The State instance for chaining.
---@usage <br>
--- ```
--- L:newtable()
--- L:pushstring("a"):rawseti(-2, 1)
--- ```
function State.rawseti(self, idx, n)
	if type(idx) ~= "number" then
		return error(string_format("State.rawseti: idx must be a number, got %s", type(idx)), 2)
	end
	if type(n) ~= "number" then
		return error(string_format("State.rawseti: n must be a number, got %s", type(n)), 2)
	end
	_check_underflow(self, 1)
	local t = _get(self, idx)
	if type(t) ~= "table" then
		return error(string_format("State.rawseti: expected table at index %d, got %s", idx, type(t)), 2)
	end
	local v = self.stack[self.top]
	rawset(t, n, v)
	self.stack[self.top] = nil
	self.top = self.top - 1
	return self
end

--- Get the length of an object.<br>
--- Pushes the length of the value at idx (for strings and tables).
---@param self StackVM.State The State instance.
---@param idx integer Stack index to get length of (negative indices are relative to top).
---@return StackVM.State self The State instance for chaining.
---@usage <br>
--- ```
--- L:pushstring("hello")
--- L:len(-1)
--- print(L:tonumber(-1)) -- 5
--- ```
function State.len(self, idx)
	if type(idx) ~= "number" then
		return error(string_format("State.len: idx must be a number, got %s", type(idx)), 2)
	end
	_check_overflow(self, 1)
	local v = _get(self, idx)
	if v == nil then
		return error(string_format("State.len: invalid index %d", idx), 2)
	end
	if type(v) == "string" then
		self.top = self.top + 1
		self.stack[self.top] = #v
	elseif type(v) == "table" then
		self.top = self.top + 1
		self.stack[self.top] = #v
	else
		return error(string_format("State.len: expected string or table at index %d, got %s", idx, type(v)), 2)
	end
	return self
end

--- Set the metatable of an object.<br>
--- Pops a table from the stack and sets it as the metatable of the object at idx.
---@param self StackVM.State The State instance.
---@param idx integer Stack index of the object (negative indices are relative to top).
---@return StackVM.State self The State instance for chaining.
---@usage <br>
--- ```
--- L:newtable()
--- L:newtable()
--- L:setmetatable(-2)
--- ```
function State.setmetatable(self, idx)
	if type(idx) ~= "number" then
		return error(string_format("State.setmetatable: idx must be a number, got %s", type(idx)), 2)
	end
	_check_underflow(self, 1)
	local obj = _get(self, idx)
	local mt = self.stack[self.top]
	if type(obj) ~= "table" then
		return error(string_format("State.setmetatable: expected table at index %d, got %s", idx, type(obj)), 2)
	end
	if mt ~= nil and type(mt) ~= "table" then
		return error(string_format("State.setmetatable: expected table or nil on stack top, got %s", type(mt)), 2)
	end
	setmetatable(obj, mt)
	self.stack[self.top] = nil
	self.top = self.top - 1
	return self
end

--- Get the metatable of an object.<br>
--- Pushes the metatable of the object at idx onto the stack.
---@param self StackVM.State The State instance.
---@param idx integer Stack index of the object (negative indices are relative to top).
---@return boolean has_meta True if the object has a metatable.
---@usage <br>
--- ```
--- L:newtable()
--- L:newtable()
--- L:setmetatable(-2)
--- local has = L:getmetatable(-1)
--- ```
function State.getmetatable(self, idx)
	if type(idx) ~= "number" then
		return error(string_format("State.getmetatable: idx must be a number, got %s", type(idx)), 2)
	end
	_check_overflow(self, 1)
	local obj = _get(self, idx)
	if type(obj) ~= "table" then
		return error(string_format("State.getmetatable: expected table at index %d, got %s", idx, type(obj)), 2)
	end
	local mt = getmetatable(obj)
	if mt ~= nil then
		self.top = self.top + 1
		self.stack[self.top] = mt
		return true
	end
	return false
end

--- Push a Lua function onto the stack as a VM-callable builtin.<br>
--- Pushes a Lua function closure that can be called by VM bytecode.
---@param self StackVM.State The State instance.
---@param fn function Lua function to push.
---@return StackVM.State self The State instance for chaining.
---@usage <br>
--- ```
--- L:pushcfunction(function(n) return n * 2 end)
--- ```
function State.pushcfunction(self, fn)
	if type(fn) ~= "function" then
		return error(string_format("State.pushcfunction: fn must be a function, got %s", type(fn)), 2)
	end
	_check_overflow(self, 1)
	self.top = self.top + 1
	self.stack[self.top] = fn
	return self
end

State.pushfunction = State.pushcfunction -- alias

--- Push a C closure with upvalues onto the stack.<br>
--- Pops n values from the stack and associates them with the function as upvalues.
---@param self StackVM.State The State instance.
---@param fn function Lua function to push as a closure.
---@param n integer Number of upvalues to pop from the stack.
---@return StackVM.State self The State instance for chaining.
---@usage <br>
--- ```
--- L:pushstring("hello")
--- L:pushcclosure(function(L) print(L:tostring(1)) end, 1)
--- ```
function State.pushcclosure(self, fn, n)
	if type(fn) ~= "function" then
		return error(string_format("State.pushcclosure: fn must be a function, got %s", type(fn)), 2)
	end
	if type(n) ~= "number" then
		return error(string_format("State.pushcclosure: n must be a number, got %s", type(n)), 2)
	end
	if n < 0 then
		return error(string_format("State.pushcclosure: n must be >= 0, got %d", n), 2)
	end
	_check_underflow(self, n)
	_check_overflow(self, 1)
	-- Pop n upvalues from stack
	local upvals = {}
	for i = 1, n do
		upvals[i] = self.stack[self.top - n + i]
	end
	-- Clear the upvalues from stack
	for i = self.top - n + 1, self.top do
		self.stack[i] = nil
	end
	self.top = self.top - n
	-- Push the closure with upvalues attached
	self.top = self.top + 1
	self.stack[self.top] = { fn = fn, upvals = upvals }
	return self
end

--- Set a debug hook function.<br>
--- Sets a hook function that will be called during VM execution.<br>
--- The mask specifies when to call the hook: "c" for call, "r" for return, "l" for line (instruction).<br>
--- The count specifies how many instructions to execute before calling the hook (when mask includes "l").
---@param self StackVM.State The State instance.
---@param hook? function Hook function (receives event: "call", "return", "line").
---@param mask string Hook mask (e.g. "crl" for call, return, line).
---@param count integer Instruction count for line hooks (default: 1).
---@return StackVM.State self The State instance for chaining.
---@usage <br>
--- ```
--- L:sethook(function(event) print("Hook:", event) end, "crl", 1)
--- ```
function State.sethook(self, hook, mask, count)
	if hook ~= nil and type(hook) ~= "function" then
		return error(string_format("State.sethook: hook must be a function or nil, got %s", type(hook)), 2)
	end
	if type(mask) ~= "string" then
		return error(string_format("State.sethook: mask must be a string, got %s", type(mask)), 2)
	end
	if type(count) ~= "number" then
		return error(string_format("State.sethook: count must be a number, got %s", type(count)), 2)
	end
	self.hooks.hook = hook
	self.hooks.mask = mask
	self.hooks.count = count or 1
	self.hooks.instruction_counter = 0
	return self
end

--- Get the current debug hook function.<br>
--- Returns the current hook function, mask, and count.
---@param self StackVM.State The State instance.
---@return function? hook Current hook function.
---@return string mask Current hook mask.
---@return integer count Current instruction count.
---@usage <br>
--- ```
--- local hook, mask, count = L:gethook()
--- ```
function State.gethook(self)
	return self.hooks.hook, self.hooks.mask, self.hooks.count
end

--- Push a light userdata onto the stack.<br>
--- Pushes a light userdata (pointer) value onto the stack.<br>
--- NOTE: Light userdatas are not supported in StackVM, it will simply push any value.
---@param self StackVM.State The State instance.
---@param p any Light userdata value to push.
---@return StackVM.State self The State instance for chaining.
---@usage <br>
--- ```
--- L:pushlightuserdata(0x1234)
--- ```
function State.pushlightuserdata(self, p)
	_check_overflow(self, 1)
	self.top = self.top + 1
	self.stack[self.top] = p
	return self
end

--- Check if two values are equal.<br>
--- Compares values at two indices using Lua's equality operator (respects metamethods).
---@param self StackVM.State The State instance.
---@param idx1 integer First stack index (negative indices are relative to top).
---@param idx2 integer Second stack index (negative indices are relative to top).
---@return boolean equal True if values are equal.
---@usage <br>
--- ```
--- L:pushnumber(42)
--- L:pushnumber(42)
--- print(L:equal(-2, -1)) -- true
--- ```
function State.equal(self, idx1, idx2)
	if type(idx1) ~= "number" then
		return error(string_format("State.equal: idx1 must be a number, got %s", type(idx1)), 2)
	end
	if type(idx2) ~= "number" then
		return error(string_format("State.equal: idx2 must be a number, got %s", type(idx2)), 2)
	end
	return _get(self, idx1) == _get(self, idx2)
end

--- Check if two values are equal (raw).<br>
--- Compares values at two indices without invoking metamethods.
---@param self StackVM.State The State instance.
---@param idx1 integer First stack index (negative indices are relative to top).
---@param idx2 integer Second stack index (negative indices are relative to top).
---@return boolean equal True if values are equal.
---@usage <br>
--- ```
--- L:pushnumber(42)
--- L:pushnumber(42)
--- print(L:rawequal(-2, -1)) -- true
--- ```
function State.rawequal(self, idx1, idx2)
	if type(idx1) ~= "number" then
		return error(string_format("State.rawequal: idx1 must be a number, got %s", type(idx1)), 2)
	end
	if type(idx2) ~= "number" then
		return error(string_format("State.rawequal: idx2 must be a number, got %s", type(idx2)), 2)
	end
	return rawequal(_get(self, idx1), _get(self, idx2))
end

--- Compare two values using a comparison operator.<br>
--- Compares values at two indices using the specified operator (0=EQ, 1=LT, 2=LE).
---@param self StackVM.State The State instance.
---@param idx1 integer First stack index (negative indices are relative to top).
---@param idx2 integer Second stack index (negative indices are relative to top).
---@param op integer Comparison operator (0=EQ, 1=LT, 2=LE).
---@return boolean result True if comparison succeeds.
---@usage <br>
--- ```
--- L:pushnumber(10):pushnumber(20)
--- print(L:compare(-2, -1, 1)) -- true (10 < 20)
--- ```
function State.compare(self, idx1, idx2, op)
	if type(idx1) ~= "number" then
		return error(string_format("State.compare: idx1 must be a number, got %s", type(idx1)), 2)
	end
	if type(idx2) ~= "number" then
		return error(string_format("State.compare: idx2 must be a number, got %s", type(idx2)), 2)
	end
	if type(op) ~= "number" then
		return error(string_format("State.compare: op must be a number, got %s", type(op)), 2)
	end
	local a = _get(self, idx1)
	local b = _get(self, idx2)
	if op == 0 then -- LUA_OPEQ
		return a == b
	end
	if op == 1 then -- LUA_OPLT
		return a < b
	end
	if op == 2 then -- LUA_OPLE
		return a <= b
	end
	return error(string_format("State.compare: invalid operator %d (expected 0=EQ, 1=LT, 2=LE)", op), 2)
end

--- Iterate over a table.<br>
--- Pops a key from the stack and pushes the next key-value pair.<br>
--- Returns 0 when iteration is complete.
---@param self StackVM.State The State instance.
---@param idx integer Stack index of the table (negative indices are relative to top).
---@return integer has_next 1 if there are more elements, 0 if iteration is complete.
---@usage <br>
--- ```
--- L:newtable()
--- L:pushstring("key1"):pushstring("value1"):settable(-3)
--- L:pushnil() -- start iteration
--- while L:next(-2) ~= 0 do
---   local key = L:tostring(-2)
---   local value = L:tostring(-1)
---   print(key, value)
---   L:pop(1) -- remove value, keep key for next iteration
--- end
--- ```
function State.next(self, idx)
	if type(idx) ~= "number" then
		return error(string_format("State.next: idx must be a number, got %s", type(idx)), 2)
	end
	_check_underflow(self, 1)
	_check_overflow(self, 1)
	local t = _get(self, idx)
	if type(t) ~= "table" then
		return error(string_format("State.next: expected table at index %d, got %s", idx, type(t)), 2)
	end
	local key = self.stack[self.top]
	local next_key, next_value = next(t, key)
	if next_key == nil then
		self.stack[self.top] = nil
		self.top = self.top - 1
		return 0
	end
	self.stack[self.top] = next_key
	self.top = self.top + 1
	self.stack[self.top] = next_value
	return 1
end

--- Concatenate values on the stack.<br>
--- Concatenates n values starting from the bottom index and pushes the result.
---@param self StackVM.State The State instance.
---@param n integer Number of values to concatenate.
---@return StackVM.State self The State instance for chaining.
---@usage <br>
--- ```
--- L:pushstring("hello"):pushstring(" "):pushstring("world")
--- L:concat(3)
--- print(L:tostring(-1)) -- "hello world"
--- ```
function State.concat(self, n)
	if type(n) ~= "number" then
		return error(string_format("State.concat: n must be a number, got %s", type(n)), 2)
	end
	if n < 1 then
		return error(string_format("State.concat: n must be >= 1, got %d", n), 2)
	end
	_check_underflow(self, n)
	_check_overflow(self, 1)
	local parts = {}
	for i = 1, n do
		local v = self.stack[self.top - n + i]
		if type(v) == "string" then
			parts[i] = v
		elseif type(v) == "number" then
			parts[i] = tostring(v)
		else
			return error(string_format("State.concat: expected string or number at position %d, got %s", i, type(v)), 2)
		end
	end
	-- Pop the concatenated values
	for i = self.top - n + 1, self.top do
		self.stack[i] = nil
	end
	self.top = self.top - n
	-- Push the concatenated result
	self.top = self.top + 1
	self.stack[self.top] = table_concat(parts)
	return self
end

--- Call a Lua function on the stack.<br>
--- Calls the function at the specified position with nargs arguments from the stack.<br>
--- Pops the function and arguments, pushes the return values.
---@param self StackVM.State The State instance.
---@param nargs integer Number of arguments to pass.
---@param nrets? integer Number of return values to accept (-1 for all).
---@return StackVM.State self The State instance for chaining.
---@usage <br>
--- ```
--- L:pushcfunction(function(a, b) return a + b end)
--- L:pushnumber(10):pushnumber(20)
--- L:call(2, 1)
--- print(L:tonumber(-1)) -- 30
--- ```
function State.call(self, nargs, nrets)
	if type(nargs) ~= "number" then
		return error(string_format("State.call: nargs must be a number, got %s", type(nargs)), 2)
	end
	if nargs < 0 then
		return error(string_format("State.call: nargs must be >= 0, got %d", nargs), 2)
	end
	if nrets ~= nil and type(nrets) ~= "number" then
		return error(string_format("State.call: nrets must be a number or nil, got %s", type(nrets)), 2)
	end
	-- call a Lua function residing below args: [..., func, arg1..argN]
	-- similar to lua_call (no error catching)
	local top = self.top
	local funcpos = top - nargs
	if funcpos < 1 then
		return error(string_format("State.call: not enough stack elements (need %d, have %d)", nargs + 1, top), 2)
	end
	local f = self.stack[funcpos]
	if type(f) ~= "function" then
		return error(string_format("State.call: attempt to call a %s value", type(f)), 2)
	end

	local args = {}
	for i = 1, nargs do
		args[i] = self.stack[funcpos + i]
	end

	-- pop func + args
	for i = funcpos, top do
		self.stack[i] = nil
	end
	self.top = funcpos - 1

	local r = table_pack(f(table_unpack(args, 1, nargs)))
	local rn = r.n
	if nrets == nil or nrets < 0 then
		nrets = rn
	end
	for i = 1, nrets do
		self.top = self.top + 1
		self.stack[self.top] = r[i]
	end
	return self
end

--- Protected call with error handling.<br>
--- Calls a Lua function on the stack and catches any errors.<br>
--- On error, pushes the error message onto the stack.
---@param self StackVM.State The State instance.
---@param nargs integer Number of arguments to pass.
---@param nrets? integer Number of return values to accept (-1 for all).
---@return boolean ok True if call succeeded, false if error occurred.
---@usage <br>
--- ```
--- L:pushcfunction(function() return error("test error") end)
--- local ok = L:pcall(0, 0)
--- if not ok then
---   print(L:tostring(-1)) -- "test error"
--- end
--- ```
function State.pcall(self, nargs, nrets)
	if type(nargs) ~= "number" then
		return error(string_format("State.pcall: nargs must be a number, got %s", type(nargs)), 2)
	end
	if nrets ~= nil and type(nrets) ~= "number" then
		return error(string_format("State.pcall: nrets must be a number or nil, got %s", type(nrets)), 2)
	end
	-- protected call, returns (ok)
	local ok, err = pcall(self.call, self, nargs, nrets)
	if not ok then
		if self.top >= self.maxstack then
			return error(string_format(
				"State.pcall: stack overflow when pushing error (top=%d maxstack=%d)", self.top, self.maxstack), 2)
		end
		self:pushstring(err)
	end
	return ok
end

----------------------------------------------------------------------
-- Assembler / compile helpers
----------------------------------------------------------------------

-- Instruction encoding: we keep it simple and fast.
-- After compile, proto.code is an array of numeric opcodes and operands in a flat stream.
-- This reduces per-step table allocations (vs {op=...,a=...}).

local OP = {
	NOP     = 0,
	PUSHK   = 1, -- A: kidx
	PUSHN   = 2, -- A: immediate number
	PUSHS   = 3, -- A: immediate string
	PUSHB   = 4, -- A: 0/1
	PUSHNIL = 5,

	POP     = 10, -- A: n
	DUP     = 11, -- A: idx (1=top)
	SWAP    = 12,

	ADD     = 20,
	SUB     = 21,
	MUL     = 22,
	DIV     = 23,
	MOD     = 24,
	NEG     = 25,
	POW     = 26,

	BAND    = 27,
	BOR     = 28,
	BXOR    = 29,
	BNOT    = 30,
	BSHL    = 31, -- A: shift amount
	BSHR    = 32, -- A: shift amount

	EQ      = 40,
	LT      = 41,
	LE      = 42,
	NOT     = 43,

	JMP     = 50, -- A: rel
	JMPT    = 51, -- A: rel (pops cond)
	JMPF    = 52, -- A: rel (pops cond)

	GETG    = 60, -- A: name (string constant index)
	SETG    = 61, -- A: name (string constant index)

	CALL    = 70, -- A: nargs, B: nrets (-1 for all)
	RET     = 71, -- A: nrets

	DEBUG   = 254, -- Debugger breakpoint
	HALT    = 255,
}
StackVM.OP = OP

-- Reverse mapping for disassembler (opcode number to name)
local OP_NAMES = {}
for name, id in pairs(OP) do
	OP_NAMES[id] = name
end

--- Get opcode ID from opcode name.<br>
--- Converts an opcode name (e.g. "PUSHN") to its numeric ID.<br>
--- Raises an error if the opcode name is unknown.
---@param name string The opcode name.
---@return integer id The numeric opcode ID.
local function _opid(name)
	local v = OP[name]
	if v == nil then return error(string_format("unknown opcode %q", tostring(name)), 3) end
	return v
end

--- Create a new assembler instance.<br>
--- Returns an assembler object for building bytecode with label support.
---@return table assembler Assembler instance with const, label, emit, proto methods.
---@usage <br>
--- ```
--- local a = StackVM.asm()
--- a:label("loop")
--- a:emit("PUSHN", 1)
--- a:emit("JMP", "loop")
--- local proto = a:proto()
--- ```
function StackVM.asm()
	local a = {
		code = {},
		labels = {},
		fixups = {},
		k = {},
		label_counter = 0,
	}

	--- Add a constant value to the constant pool.<br>
	--- Stores a value in the constant pool and returns its index.
	---@param v any Value to store in constant pool.
	---@return integer index Index of the constant in the pool.
	---@usage <br>
	--- ```
	--- local idx = a:const("hello")
	--- ```
	function a.const(self, v)
		if v == nil then
			return error("a.const: cannot add nil to constant pool", 2)
		end
		local k = self.k
		k[#k + 1] = v
		return #k
	end

	--- Define a label at the current code position.<br>
	--- Marks the current code position with a label for use in jump instructions.<br>
	--- If no name is provided, auto-generates a unique label name.
	---@param name? string Label name (optional, auto-generated if nil).
	---@return string|table name_or_self The label name if auto-generated, otherwise the assembler instance for chaining.
	---@usage <br>
	--- ```
	--- local label = a:label()  -- Auto-generates name like "label1"
	--- a:emit("JMP", label)
	--- a:emit("PUSHN", 42)
	--- a:label(label)  -- Define the label position
	--- ```
	--- ```
	--- a:label("start")  -- Use explicit name
	--- a:emit("JMP", "start")
	--- ```
	function a.label(self, name)
		if name == nil then
			-- Auto-generate unique label name
			self.label_counter = self.label_counter + 1
			name = string_format("label%d", self.label_counter)
		elseif type(name) ~= "string" then
			return error(string_format("a.label: name must be a string or nil, got %s", type(name)), 2)
		elseif name == "" then
			return error("a.label: name cannot be empty", 2)
		end
		if self.labels[name] ~= nil then
			return error(string_format("a.label: label %q already defined", name), 2)
		end
		self.labels[name] = #self.code + 1
		if string_match(name, "^label%d+$") and self.label_counter > 0 then
			-- Return the auto-generated label name for use in jump instructions
			return name
		end
		return self
	end

	--- Emit an instruction to the bytecode stream.<br>
	--- Appends an instruction with optional operands to the code stream.<br>
	--- Supports opcode names (strings) or numeric opcodes.<br>
	--- Jump instructions can use label names for the operand.
	---@param op string|integer Opcode name (e.g. "PUSHN") or numeric opcode.
	---@param a1 any First operand (optional, depends on opcode).
	---@param a2 any Second operand (optional, for CALL opcode).
	---@return table assembler The assembler instance for chaining.
	---@usage <br>
	--- ```
	--- a:emit("PUSHN", 42)
	--- a:emit("ADD")
	--- a:emit("CALL", 1, 0)
	--- ```
	function a.emit(self, op, a1, a2)
		local c = self.code
		if type(op) == "string" then
			op = _opid(op)
		elseif type(op) ~= "number" then
			return error(string_format("a.emit: op must be a string or number, got %s", type(op)), 2)
		end

		if type(op) ~= "number" or op < 0 or op > 255 then
			return error(string_format("a.emit: invalid opcode %d", op), 2)
		end

		c[#c + 1] = op

		-- variable arity encoding
		if op == OP.PUSHK or op == OP.PUSHN or op == OP.PUSHS or op == OP.PUSHB
			or op == OP.POP or op == OP.DUP
			or op == OP.JMP or op == OP.JMPT or op == OP.JMPF
			or op == OP.GETG or op == OP.SETG
			or op == OP.RET then
			if type(a1) == "string" and (op == OP.JMP or op == OP.JMPT or op == OP.JMPF) then
				-- label fixup: store placeholder 0; patch later with relative offset
				self.fixups[#self.fixups + 1] = { at = #c + 1, label = a1 }
				c[#c + 1] = 0
			else
				c[#c + 1] = a1 or 0
			end
		elseif op == OP.CALL then
			c[#c + 1] = a1 or 0
			c[#c + 1] = a2 or 0
		end

		return self
	end

	--- Generate a protocol (bytecode) from the assembler state.<br>
	--- Resolves label fixups and returns a complete protocol object for execution.<br>
	--- The protocol contains the code stream and constant pool.
	---@param extra? table Optional extra fields to include (e.g. custom constant pool).
	---@return table proto Protocol object with code and k fields.
	---@usage <br>
	--- ```
	--- local proto = a:proto({ k = {"custom", "constants"} })
	--- ```
	function a.proto(self, extra)
		if extra ~= nil and type(extra) ~= "table" then
			return error(string_format("a.proto: extra must be a table or nil, got %s", type(extra)), 2)
		end
		if #self.code == 0 then
			return error("a.proto: cannot create proto from empty code", 2)
		end
		extra = extra or {}
		local proto = {
			code = self.code,
			k = extra.k or self.k,
			-- debug info could go here
		}
		-- resolve fixups
		if #self.fixups > 0 then
			local labels = self.labels
			local code = proto.code
			for i = 1, #self.fixups do
				local f = self.fixups[i]
				if type(f) ~= "table" or f.label == nil then
					return error("a.proto: invalid fixup entry", 2)
				end
				local target = labels[f.label]
				if not target then
					return error(string_format("a.proto: unknown label %q", f.label), 2)
				end
				-- f.at is index in code array where operand lives; the PC will be at operand index - 1
				local operandIndex = f.at
				if type(operandIndex) ~= "number" or operandIndex < 1 or operandIndex > #code then
					return error(string_format("a.proto: invalid fixup position %d", operandIndex), 2)
				end
				local pcAtOp = operandIndex - 1
				-- Our JMP uses relative offset in units of code array indices.
				code[operandIndex] = target - pcAtOp
			end
		end
		return proto
	end

	return a
end

--- Compile a chunk into bytecode protocol.<br>
--- Accepts a chunk with symbolic instructions and returns a protocol with numeric opcodes.<br>
--- The chunk format is: { k = {...}, code = { {op="PUSHK", 1}, ...} }.
---@param chunk table Chunk object with code and optional constant pool.
---@return table proto Protocol object with numeric code stream and constant pool.
---@usage <br>
--- ```
--- local proto = StackVM.compile({
---   code = { {op="PUSHN", 42}, {op="HALT"} }
--- })
--- ```
function StackVM.compile(chunk)
	if type(chunk) ~= "table" then
		return error(string_format("StackVM.compile: chunk must be a table, got %s", type(chunk)), 2)
	end
	local a = StackVM.asm()
	if chunk.k then
		if type(chunk.k) ~= "table" then
			return error(string_format("StackVM.compile: chunk.k must be a table, got %s", type(chunk.k)), 2)
		end
		a.k = chunk.k
	end
	local code = chunk.code or {}
	if type(code) ~= "table" then
		return error(string_format("StackVM.compile: chunk.code must be a table, got %s", type(code)), 2)
	end
	for i = 1, #code do
		local ins = code[i]
		if type(ins) == "table" then
			local op = ins.op or ins[1]
			a.emit(a, op, ins[2], ins[3])
		else
			return error(
				string_format("StackVM.compile: invalid instruction at %d (expected table, got %s)", i, type(ins)), 2)
		end
	end
	return a.proto(a, { k = a.k })
end

-- Disassembler operand handlers
local DISASM_HANDLERS = {
	[OP.PUSHK] = function(code, pc, k, line)
		local kidx = code[pc]
		local kvalue = k[kidx]
		if type(kvalue) == "string" then
			return pc + 1, line .. "  " .. to_string_literal(kvalue)
		end
		return pc + 1, line .. "  " .. tostring(kvalue)
	end,
	[OP.PUSHN] = function(code, pc, k, line)
		local n = code[pc]
		return pc + 1, line .. "  " .. tostring(n)
	end,
	[OP.PUSHS] = function(code, pc, k, line)
		local s = code[pc]
		return pc + 1, line .. "  " .. to_string_literal(s)
	end,
	[OP.PUSHB] = function(code, pc, k, line)
		local b = code[pc]
		return pc + 1, line .. "  " .. tostring(b)
	end,
	[OP.POP] = function(code, pc, k, line)
		local n = code[pc]
		return pc + 1, line .. "  " .. tostring(n)
	end,
	[OP.DUP] = function(code, pc, k, line)
		local idx = code[pc]
		return pc + 1, line .. "  " .. tostring(idx)
	end,
	[OP.JMP] = function(code, pc, k, line)
		local rel = code[pc]
		local target = pc + rel
		return pc + 1, line .. "  -> " .. tostring(target)
	end,
	[OP.JMPT] = function(code, pc, k, line)
		local rel = code[pc]
		local target = pc + rel
		return pc + 1, line .. "  -> " .. tostring(target)
	end,
	[OP.JMPF] = function(code, pc, k, line)
		local rel = code[pc]
		local target = pc + rel
		return pc + 1, line .. "  -> " .. tostring(target)
	end,
	[OP.GETG] = function(code, pc, k, line)
		local ki = code[pc]
		local name = k[ki]
		return pc + 1, line .. "  " .. to_string_literal(name)
	end,
	[OP.SETG] = function(code, pc, k, line)
		local ki = code[pc]
		local name = k[ki]
		return pc + 1, line .. "  " .. to_string_literal(name)
	end,
	[OP.RET] = function(code, pc, k, line)
		local nrets = code[pc]
		return pc + 1, line .. "  " .. tostring(nrets)
	end,
	[OP.CALL] = function(code, pc, k, line)
		local nargs = code[pc]
		local nrets = code[pc + 1]
		return pc + 2, line .. "  " .. tostring(nargs) .. ", " .. tostring(nrets)
	end,
	[OP.BSHL] = function(code, pc, k, line)
		local shift = code[pc]
		return pc + 1, line .. "  " .. tostring(shift)
	end,
	[OP.BSHR] = function(code, pc, k, line)
		local shift = code[pc]
		return pc + 1, line .. "  " .. tostring(shift)
	end,
}

--- Disassemble a bytecode protocol into human-readable format.<br>
--- Converts compiled bytecode back to a readable list of instructions.<br>
--- Useful for debugging and inspecting compiled code.
---@param proto table Protocol object with code and k fields.
---@return string disassembly Formatted disassembly string.
---@usage <br>
--- ```
--- local proto = StackVM.compile({ code = { {op="PUSHN", 42}, {op="HALT"} } })
--- print(StackVM.disassemble(proto))
--- ```
function StackVM.disassemble(proto)
	if type(proto) ~= "table" then
		return error(string_format("StackVM.disassemble: proto must be a table, got %s", type(proto)), 2)
	end
	local code = proto.code
	local k = proto.k or {}
	if type(code) ~= "table" then
		return error(string_format("StackVM.disassemble: proto.code must be a table, got %s", type(code)), 2)
	end

	local lines = {}
	local pc = 1
	while pc <= #code do
		local op = code[pc]
		local opname = OP_NAMES[op] or ("UNKNOWN_" .. tostring(op))
		local line = string_format("%4d  %s", pc, opname)
		pc = pc + 1

		local handler = DISASM_HANDLERS[op]
		if handler then
			pc, line = handler(code, pc, k, line)
		end

		lines[#lines + 1] = line
	end

	return table_concat(lines, "\n")
end

----------------------------------------------------------------------
-- Bytecode optimizer
----------------------------------------------------------------------

-- Constant folding handlers
local CONST_FOLD_HANDLERS = {
	[OP.PUSHN] = function(code, pc, k, new_code, const_stack)
		const_stack[#const_stack + 1] = { type = "number", value = code[pc] }
		table_insert(new_code, OP.PUSHN)
		table_insert(new_code, code[pc])
		return pc + 1
	end,
	[OP.PUSHK] = function(code, pc, k, new_code, const_stack)
		local kidx = code[pc]
		local kvalue = k[kidx]
		local ktype = type(kvalue)
		if ktype == "number" then
			const_stack[#const_stack + 1] = { type = "number", value = kvalue }
		elseif ktype == "boolean" then
			const_stack[#const_stack + 1] = { type = "boolean", value = kvalue }
		else
			const_stack[#const_stack + 1] = { type = "other" }
		end
		table_insert(new_code, OP.PUSHK)
		table_insert(new_code, kidx)
		return pc + 1
	end,
	[OP.PUSHB] = function(code, pc, k, new_code, const_stack)
		const_stack[#const_stack + 1] = { type = "boolean", value = code[pc] ~= 0 }
		table_insert(new_code, OP.PUSHB)
		table_insert(new_code, code[pc])
		return pc + 1
	end,
	[OP.PUSHNIL] = function(code, pc, k, new_code, const_stack)
		const_stack[#const_stack + 1] = { type = "nil" }
		table_insert(new_code, OP.PUSHNIL)
		return pc
	end,
	[OP.NEG] = function(code, pc, k, new_code, const_stack)
		if #const_stack > 0 and const_stack[#const_stack].type == "number" then
			const_stack[#const_stack].value = -const_stack[#const_stack].value
			-- Remove the NEG instruction and the previous PUSH
			table_remove(new_code, #new_code)
			table_remove(new_code, #new_code)
			table_remove(const_stack, #const_stack)
			-- Re-emit the negated constant
			table_insert(new_code, OP.PUSHN)
			table_insert(new_code, const_stack[#const_stack].value)
			return pc
		else
			const_stack[#const_stack] = nil
			table_insert(new_code, OP.NEG)
			return pc
		end
	end,
	[OP.NOT] = function(code, pc, k, new_code, const_stack)
		if #const_stack > 0 and const_stack[#const_stack].type == "boolean" then
			const_stack[#const_stack].value = not const_stack[#const_stack].value
			-- Remove the NOT instruction and the previous PUSH
			table_remove(new_code, #new_code)
			table_remove(new_code, #new_code)
			table_remove(const_stack, #const_stack)
			-- Re-emit the negated constant
			table_insert(new_code, OP.PUSHB)
			table_insert(new_code, const_stack[#const_stack].value and 1 or 0)
			return pc
		else
			const_stack[#const_stack] = nil
			table_insert(new_code, OP.NOT)
			return pc
		end
	end,
	[OP.ADD] = function(code, pc, k, new_code, const_stack)
		if #const_stack >= 2 and const_stack[#const_stack].type == "number" and const_stack[#const_stack - 1].type == "number" then
			local b = table_remove(const_stack)
			local a = table_remove(const_stack)
			local result = a.value + b.value
			-- Remove the two previous PUSH instructions
			table_remove(new_code, #new_code)
			table_remove(new_code, #new_code)
			table_remove(new_code, #new_code)
			table_remove(new_code, #new_code)
			-- Emit the folded constant
			const_stack[#const_stack + 1] = { type = "number", value = result }
			table_insert(new_code, OP.PUSHN)
			table_insert(new_code, result)
			return pc
		else
			const_stack[#const_stack] = nil
			const_stack[#const_stack] = nil
			table_insert(new_code, OP.ADD)
			return pc
		end
	end,
	[OP.SUB] = function(code, pc, k, new_code, const_stack)
		if #const_stack >= 2 and const_stack[#const_stack].type == "number" and const_stack[#const_stack - 1].type == "number" then
			local b = table_remove(const_stack)
			local a = table_remove(const_stack)
			local result = a.value - b.value
			table_remove(new_code, #new_code)
			table_remove(new_code, #new_code)
			table_remove(new_code, #new_code)
			table_remove(new_code, #new_code)
			const_stack[#const_stack + 1] = { type = "number", value = result }
			table_insert(new_code, OP.PUSHN)
			table_insert(new_code, result)
			return pc
		else
			const_stack[#const_stack] = nil
			const_stack[#const_stack] = nil
			table_insert(new_code, OP.SUB)
			return pc
		end
	end,
	[OP.MUL] = function(code, pc, k, new_code, const_stack)
		if #const_stack >= 2 and const_stack[#const_stack].type == "number" and const_stack[#const_stack - 1].type == "number" then
			local b = table_remove(const_stack)
			local a = table_remove(const_stack)
			local result = a.value * b.value
			table_remove(new_code, #new_code)
			table_remove(new_code, #new_code)
			table_remove(new_code, #new_code)
			table_remove(new_code, #new_code)
			const_stack[#const_stack + 1] = { type = "number", value = result }
			table_insert(new_code, OP.PUSHN)
			table_insert(new_code, result)
			return pc
		else
			const_stack[#const_stack] = nil
			const_stack[#const_stack] = nil
			table_insert(new_code, OP.MUL)
			return pc
		end
	end,
	[OP.DIV] = function(code, pc, k, new_code, const_stack)
		if #const_stack >= 2 and const_stack[#const_stack].type == "number" and const_stack[#const_stack - 1].type == "number" then
			local b = table_remove(const_stack)
			local a = table_remove(const_stack)
			if b.value ~= 0 then
				local result = a.value / b.value
				table_remove(new_code, #new_code)
				table_remove(new_code, #new_code)
				table_remove(new_code, #new_code)
				table_remove(new_code, #new_code)
				const_stack[#const_stack + 1] = { type = "number", value = result }
				table_insert(new_code, OP.PUSHN)
				table_insert(new_code, result)
				return pc
			else
				const_stack[#const_stack] = nil
				const_stack[#const_stack] = nil
				table_insert(new_code, OP.DIV)
				return pc
			end
		else
			const_stack[#const_stack] = nil
			const_stack[#const_stack] = nil
			table_insert(new_code, OP.DIV)
			return pc
		end
	end,
	[OP.MOD] = function(code, pc, k, new_code, const_stack)
		if #const_stack >= 2 and const_stack[#const_stack].type == "number" and const_stack[#const_stack - 1].type == "number" then
			local b = table_remove(const_stack)
			local a = table_remove(const_stack)
			if b.value ~= 0 then
				local result = a.value % b.value
				table_remove(new_code, #new_code)
				table_remove(new_code, #new_code)
				table_remove(new_code, #new_code)
				table_remove(new_code, #new_code)
				const_stack[#const_stack + 1] = { type = "number", value = result }
				table_insert(new_code, OP.PUSHN)
				table_insert(new_code, result)
				return pc
			else
				const_stack[#const_stack] = nil
				const_stack[#const_stack] = nil
				table_insert(new_code, OP.MOD)
				return pc
			end
		else
			const_stack[#const_stack] = nil
			const_stack[#const_stack] = nil
			table_insert(new_code, OP.MOD)
			return pc
		end
	end,
	[OP.POW] = function(code, pc, k, new_code, const_stack)
		if #const_stack >= 2 and const_stack[#const_stack].type == "number" and const_stack[#const_stack - 1].type == "number" then
			local b = table_remove(const_stack)
			local a = table_remove(const_stack)
			local result = a.value ^ b.value
			table_remove(new_code, #new_code)
			table_remove(new_code, #new_code)
			table_remove(new_code, #new_code)
			table_remove(new_code, #new_code)
			const_stack[#const_stack + 1] = { type = "number", value = result }
			table_insert(new_code, OP.PUSHN)
			table_insert(new_code, result)
			return pc
		else
			const_stack[#const_stack] = nil
			const_stack[#const_stack] = nil
			table_insert(new_code, OP.POW)
			return pc
		end
	end,
}

--- Optimize bytecode using constant folding.<br>
--- Folds constant expressions at compile time to reduce runtime overhead.<br>
--- Handles arithmetic operations, negation, and logical NOT on constants.
---@param code table The bytecode code array.
---@param k table The constant pool.
---@return table new_code Optimized bytecode code array.
local function optimize_constant_folding(code, k)
	local new_code = {}
	local pc = 1
	local const_stack = {}

	while pc <= #code do
		local op = code[pc]
		pc = pc + 1

		local handler = CONST_FOLD_HANDLERS[op]
		if handler then
			pc = handler(code, pc, k, new_code, const_stack)
		else
			-- For all other instructions, clear the const stack
			const_stack = {}
			table_insert(new_code, op)

			-- Handle opcodes with operands
			if op == OP.PUSHK or op == OP.PUSHS or op == OP.PUSHB or op == OP.POP or op == OP.DUP
				or op == OP.JMP or op == OP.JMPT or op == OP.JMPF or op == OP.GETG or op == OP.SETG
				or op == OP.RET or op == OP.BSHL or op == OP.BSHR then
				table_insert(new_code, code[pc])
				pc = pc + 1
			elseif op == OP.CALL then
				table_insert(new_code, code[pc])
				table_insert(new_code, code[pc + 1])
				pc = pc + 2
			end
		end
	end

	return new_code
end

--- Optimize bytecode using dead code elimination.<br>
--- Removes unreachable code by tracing control flow and keeping only reachable instructions.<br>
--- Handles jump targets and removes code that cannot be executed.
---@param code table The bytecode code array.
---@return table new_code Optimized bytecode code array.
local function optimize_dead_code_elimination(code)
	local new_code = {}
	local pc = 1
	local reachable = {}
	local worklist = { 1 }

	-- Mark all reachable code
	while #worklist > 0 do
		local current = table_remove(worklist)
		if not reachable[current] then
			reachable[current] = true

			if current <= #code then
				local op = code[current]
				pc = current + 1

				-- Add next instruction
				if pc <= #code then
					table_insert(worklist, pc)
				end

				-- Add jump targets
				if op == OP.JMP then
					local rel = code[pc]
					local target = current + rel
					if target >= 1 and target <= #code then
						table_insert(worklist, target)
					end
				elseif op == OP.JMPT or op == OP.JMPF then
					local rel = code[pc]
					local target = current + rel
					if target >= 1 and target <= #code then
						table_insert(worklist, target)
					end
				end
			end
		end
	end

	-- Copy only reachable code
	pc = 1
	while pc <= #code do
		if reachable[pc] then
			table_insert(new_code, code[pc])
		end
		pc = pc + 1
	end

	return new_code
end

--- Optimize bytecode using peephole optimizations.<br>
--- Performs local optimizations like removing NOP instructions and redundant PUSH/POP pairs.<br>
--- Scans through the code and applies pattern-based optimizations.
---@param code table The bytecode code array.
---@return table new_code Optimized bytecode code array.
local function optimize_peephole(code)
	local new_code = {}
	local pc = 1

	while pc <= #code do
		local op = code[pc]

		-- Remove NOP instructions
		if op == OP.NOP then
			pc = pc + 1
			-- PUSHNIL followed by POP 1 can be removed
		elseif op == OP.PUSHNIL and pc + 1 <= #code and code[pc + 1] == OP.POP and code[pc + 2] == 1 then
			pc = pc + 3
			-- PUSHN 0 followed by POP 1 can be removed
		elseif op == OP.PUSHN and code[pc + 1] == 0 and pc + 2 <= #code and code[pc + 2] == OP.POP and code[pc + 3] == 1 then
			pc = pc + 4
		else
			table_insert(new_code, op)
			pc = pc + 1

			-- Copy operands
			if op == OP.PUSHK or op == OP.PUSHS or op == OP.PUSHB or op == OP.POP or op == OP.DUP
				or op == OP.JMP or op == OP.JMPT or op == OP.JMPF or op == OP.GETG or op == OP.SETG
				or op == OP.RET or op == OP.BSHL or op == OP.BSHR then
				table_insert(new_code, code[pc])
				pc = pc + 1
			elseif op == OP.CALL then
				table_insert(new_code, code[pc])
				table_insert(new_code, code[pc + 1])
				pc = pc + 2
			end
		end
	end

	return new_code
end

--- Optimize a bytecode protocol.<br>
--- Applies multiple optimization passes to improve bytecode efficiency.<br>
--- Includes constant folding, dead code elimination, and peephole optimizations.
---@param proto table Protocol object with code and k fields.
---@param opts? table Optimization options (constant_folding, dead_code_elimination, peephole).
---@return table proto Optimized protocol object.
---@usage <br>
--- ```
--- local proto = StackVM.compile({ code = { {op="PUSHN", 2}, {op="PUSHN", 3}, {op="ADD"}, {op="HALT"} } })
--- local optimized = StackVM.optimize(proto)
--- ```
function StackVM.optimize(proto, opts)
	if type(proto) ~= "table" then
		return error(string_format("StackVM.optimize: proto must be a table, got %s", type(proto)), 2)
	end

	opts = opts or {}
	local code = proto.code
	local k = proto.k or {}

	if type(code) ~= "table" then
		return error(string_format("StackVM.optimize: proto.code must be a table, got %s", type(code)), 2)
	end

	if opts.constant_folding ~= false then
		code = optimize_constant_folding(code, k)
	end

	if opts.dead_code_elimination ~= false then
		code = optimize_dead_code_elimination(code)
	end

	if opts.peephole ~= false then
		code = optimize_peephole(code)
	end

	return {
		code = code,
		k = k,
	}
end

----------------------------------------------------------------------
-- VM execution
----------------------------------------------------------------------

--- Clear a range of elements in a table.<br>
--- Sets elements from index a to b to nil.<br>
--- Used for clearing stack ranges after function calls.
---@param t table The table to clear.
---@param a number Starting index.
---@param b number Ending index.
local function _clear_range(t, a, b)
	if type(t) ~= "table" then
		return error(string_format("_clear_range: t must be a table, got %s", type(t)), 2)
	end
	if type(a) ~= "number" then
		return error(string_format("_clear_range: a must be a number, got %s", type(a)), 2)
	end
	if type(b) ~= "number" then
		return error(string_format("_clear_range: b must be a number, got %s", type(b)), 2)
	end
	if a > b then return end
	for i = a, b do
		t[i] = nil
	end
end

--- Call a function from stack and push results.<br>
--- Calls a function at funcpos with nargs arguments and pushes nrets results.<br>
--- Used internally by the VM to call Lua functions.
---@param L table The State instance.
---@param nargs integer Number of arguments to pass.
---@param nrets? integer Number of return values to accept (-1 for all).
local function _call_into_stack(L, nargs, nrets)
	if type(L) ~= "table" then
		return error("_call_into_stack: L must be a table", 2)
	end
	if type(nargs) ~= "number" then
		return error(string_format("_call_into_stack: nargs must be a number, got %s", type(nargs)), 2)
	end
	if nargs < 0 then
		return error(string_format("_call_into_stack: nargs must be >= 0, got %d", nargs), 2)
	end
	if nrets ~= nil and type(nrets) ~= "number" then
		return error(string_format("_call_into_stack: nrets must be a number or nil, got %s", type(nrets)), 2)
	end
	-- Stack layout: [..., func, arg1..argN]
	local stack = L.stack
	local top = L.top
	local funcpos = top - nargs
	if funcpos < 1 then
		return error(string_format("_call_into_stack: not enough stack elements (need %d, have %d)", nargs + 1, top), 2)
	end
	local f = stack[funcpos]
	if type(f) ~= "function" then
		return error(string_format("_call_into_stack: attempt to call a %s value", type(f)), 2)
	end

	if nrets == 0 then
		f(table_unpack(stack, funcpos + 1, top))
		_clear_range(stack, funcpos, top)
		L.top = funcpos - 1
		return
	end
	if nrets == 1 then
		local r1 = f(table_unpack(stack, funcpos + 1, top))
		_clear_range(stack, funcpos, top)
		stack[funcpos] = r1
		L.top = funcpos
		return
	end
	if nrets == 2 then
		local r1, r2 = f(table_unpack(stack, funcpos + 1, top))
		_clear_range(stack, funcpos, top)
		stack[funcpos] = r1
		stack[funcpos + 1] = r2
		L.top = funcpos + 1
		return
	end
	if nrets and nrets > 0 then
		local results = { f(table_unpack(stack, funcpos + 1, top)) }
		_clear_range(stack, funcpos, top)
		local rp = funcpos - 1
		for i = 1, nrets do
			rp = rp + 1
			stack[rp] = results[i]
		end
		L.top = rp
		return
	end
	-- nrets < 0 => all
	local results = table_pack(f(table_unpack(stack, funcpos + 1, top)))
	_clear_range(stack, funcpos, top)
	local rp = funcpos - 1
	for i = 1, results.n do
		rp = rp + 1
		stack[rp] = results[i]
	end
	L.top = rp
end

-- Hook event handlers
local HOOK_EVENT_HANDLERS = {
	["call"] = function(hooks)
		return string_find(hooks.mask, "c")
	end,
	["return"] = function(hooks)
		return string_find(hooks.mask, "r")
	end,
	["line"] = function(hooks)
		if not string_find(hooks.mask, "l") then
			return false
		end
		hooks.instruction_counter = hooks.instruction_counter + 1
		if hooks.instruction_counter >= hooks.count then
			hooks.instruction_counter = 0
			return true
		end
		return false
	end,
	["debug"] = function(hooks)
		return true
	end,
}

--- Call debug hook if configured.<br>
--- Checks if a hook is registered for the event and calls it if the mask matches.<br>
--- Used internally by the VM to trigger debugger hooks.
---@param L table The State instance.
---@param event string Hook event name ("call", "return", "line", "debug").
local function _call_hook(L, event)
	local hooks = L.hooks
	if not hooks or not hooks.hook then
		return
	end
	local handler = HOOK_EVENT_HANDLERS[event]
	if handler and handler(hooks) then
		hooks.hook(event)
	end
end

-- Opcode dispatch table for VM execution
local OP_HANDLERS = {}

-- NOP: no operation
OP_HANDLERS[OP.NOP] = function(code, pc, stack, top, k, globals, L)
	return pc, top
end

-- PUSHK: push constant from constant pool
OP_HANDLERS[OP.PUSHK] = function(code, pc, stack, top, k, globals, L)
	local ki = code[pc]
	pc = pc + 1
	top = top + 1
	stack[top] = k[ki]
	return pc, top
end

-- PUSHN: push number
OP_HANDLERS[OP.PUSHN] = function(code, pc, stack, top, k, globals, L)
	local n = code[pc]
	pc = pc + 1
	top = top + 1
	stack[top] = n
	return pc, top
end

-- PUSHS: push string
OP_HANDLERS[OP.PUSHS] = function(code, pc, stack, top, k, globals, L)
	local s = code[pc]
	pc = pc + 1
	top = top + 1
	stack[top] = s
	return pc, top
end

-- PUSHB: push boolean
OP_HANDLERS[OP.PUSHB] = function(code, pc, stack, top, k, globals, L)
	local b = code[pc]
	pc = pc + 1
	top = top + 1
	stack[top] = (b ~= 0)
	return pc, top
end

-- PUSHNIL: push nil
OP_HANDLERS[OP.PUSHNIL] = function(code, pc, stack, top, k, globals, L)
	top = top + 1
	stack[top] = nil
	return pc, top
end

-- POP: pop n elements
OP_HANDLERS[OP.POP] = function(code, pc, stack, top, k, globals, L)
	local n = code[pc]
	pc = pc + 1
	if top < n then return error(string_format("stack underflow (POP needs %d values, have %d)", n, top), 0) end
	local newtop = top - n
	if newtop < 0 then newtop = 0 end
	_clear_range(stack, newtop + 1, top)
	top = newtop
	return pc, top
end

-- DUP: duplicate element
OP_HANDLERS[OP.DUP] = function(code, pc, stack, top, k, globals, L)
	local idx = code[pc]
	pc = pc + 1
	local src = top - idx
	if src < 1 then return error(string_format("stack underflow (DUP idx=%d needs at least %d values)", idx, idx + 1), 0) end
	local val = stack[src]
	if val == nil then return error(string_format("stack[src] is nil (DUP idx=%d src=%d)", idx, src), 0) end
	top = top + 1
	stack[top] = val
	return pc, top
end

-- SWAP: swap top two elements
OP_HANDLERS[OP.SWAP] = function(code, pc, stack, top, k, globals, L)
	if top < 2 then return error("stack underflow (SWAP needs 2 values)", 0) end
	local a = stack[top]
	local b = stack[top - 1]
	if a == nil then return error("stack[top] is nil (SWAP)", 0) end
	if b == nil then return error("stack[top-1] is nil (SWAP)", 0) end
	stack[top] = b
	stack[top - 1] = a
	return pc, top
end

-- NEG: negate top element
OP_HANDLERS[OP.NEG] = function(code, pc, stack, top, k, globals, L)
	if top < 1 then return error("stack underflow (NEG needs 1 value)", 0) end
	local a = stack[top]
	if a == nil then return error("stack[top] is nil (NEG)", 0) end
	stack[top] = -a
	return pc, top
end

-- ADD: add top two elements
OP_HANDLERS[OP.ADD] = function(code, pc, stack, top, k, globals, L)
	if top < 2 then return error("stack underflow (ADD needs 2 values)", 0) end
	local b = stack[top]
	local a = stack[top - 1]
	if b == nil then return error("stack[top] is nil (ADD)", 0) end
	if a == nil then return error("stack[top-1] is nil (ADD)", 0) end
	top = top - 1
	stack[top] = a + b
	return pc, top
end

-- SUB: subtract top from second
OP_HANDLERS[OP.SUB] = function(code, pc, stack, top, k, globals, L)
	if top < 2 then return error("stack underflow (SUB needs 2 values)", 0) end
	local b = stack[top]
	local a = stack[top - 1]
	if b == nil then return error("stack[top] is nil (SUB)", 0) end
	if a == nil then return error("stack[top-1] is nil (SUB)", 0) end
	top = top - 1
	stack[top] = a - b
	return pc, top
end

-- MUL: multiply top two elements
OP_HANDLERS[OP.MUL] = function(code, pc, stack, top, k, globals, L)
	if top < 2 then return error("stack underflow (MUL needs 2 values)", 0) end
	local b = stack[top]
	local a = stack[top - 1]
	if b == nil then return error("stack[top] is nil (MUL)", 0) end
	if a == nil then return error("stack[top-1] is nil (MUL)", 0) end
	top = top - 1
	stack[top] = a * b
	return pc, top
end

-- DIV: divide second by top
OP_HANDLERS[OP.DIV] = function(code, pc, stack, top, k, globals, L)
	if top < 2 then return error("stack underflow (DIV needs 2 values)", 0) end
	local b = stack[top]
	local a = stack[top - 1]
	if b == nil then return error("stack[top] is nil (DIV)", 0) end
	if a == nil then return error("stack[top-1] is nil (DIV)", 0) end
	top = top - 1
	stack[top] = a / b
	return pc, top
end

-- MOD: modulo second by top
OP_HANDLERS[OP.MOD] = function(code, pc, stack, top, k, globals, L)
	if top < 2 then return error("stack underflow (MOD needs 2 values)", 0) end
	local b = stack[top]
	local a = stack[top - 1]
	if b == nil then return error("stack[top] is nil (MOD)", 0) end
	if a == nil then return error("stack[top-1] is nil (MOD)", 0) end
	top = top - 1
	stack[top] = a % b
	return pc, top
end

-- POW: raise second to power of top
OP_HANDLERS[OP.POW] = function(code, pc, stack, top, k, globals, L)
	if top < 2 then return error("stack underflow (POW needs 2 values)", 0) end
	local b = stack[top]
	local a = stack[top - 1]
	if b == nil then return error("stack[top] is nil (POW)", 0) end
	if a == nil then return error("stack[top-1] is nil (POW)", 0) end
	top = top - 1
	stack[top] = a ^ b
	return pc, top
end

-- BAND: bitwise AND top two elements
OP_HANDLERS[OP.BAND] = function(code, pc, stack, top, k, globals, L)
	if top < 2 then return error("stack underflow (BAND needs 2 values)", 0) end
	local b = stack[top]
	local a = stack[top - 1]
	if b == nil then return error("stack[top] is nil (BAND)", 0) end
	if a == nil then return error("stack[top-1] is nil (BAND)", 0) end
	top = top - 1
	stack[top] = bitwise.band(a, b)
	return pc, top
end

-- BOR: bitwise OR top two elements
OP_HANDLERS[OP.BOR] = function(code, pc, stack, top, k, globals, L)
	if top < 2 then return error("stack underflow (BOR needs 2 values)", 0) end
	local b = stack[top]
	local a = stack[top - 1]
	if b == nil then return error("stack[top] is nil (BOR)", 0) end
	if a == nil then return error("stack[top-1] is nil (BOR)", 0) end
	top = top - 1
	stack[top] = bitwise.bor(a, b)
	return pc, top
end

-- BXOR: bitwise XOR top two elements
OP_HANDLERS[OP.BXOR] = function(code, pc, stack, top, k, globals, L)
	if top < 2 then return error("stack underflow (BXOR needs 2 values)", 0) end
	local b = stack[top]
	local a = stack[top - 1]
	if b == nil then return error("stack[top] is nil (BXOR)", 0) end
	if a == nil then return error("stack[top-1] is nil (BXOR)", 0) end
	top = top - 1
	stack[top] = bitwise.bxor(a, b)
	return pc, top
end

-- BNOT: bitwise NOT top element
OP_HANDLERS[OP.BNOT] = function(code, pc, stack, top, k, globals, L)
	if top < 1 then return error("stack underflow (BNOT needs 1 value)", 0) end
	local a = stack[top]
	if a == nil then return error("stack[top] is nil (BNOT)", 0) end
	stack[top] = bitwise.bnot(a)
	return pc, top
end

-- BSHL: bitwise shift left
OP_HANDLERS[OP.BSHL] = function(code, pc, stack, top, k, globals, L)
	if top < 2 then return error("stack underflow (BSHL needs 2 values)", 0) end
	local shift = stack[top]
	local a = stack[top - 1]
	if shift == nil then return error("stack[top] is nil (BSHL)", 0) end
	if a == nil then return error("stack[top-1] is nil (BSHL)", 0) end
	top = top - 1
	stack[top] = bitwise.lshift(a, shift)
	return pc, top
end

-- BSHR: bitwise shift right
OP_HANDLERS[OP.BSHR] = function(code, pc, stack, top, k, globals, L)
	if top < 2 then return error("stack underflow (BSHR needs 2 values)", 0) end
	local shift = stack[top]
	local a = stack[top - 1]
	if shift == nil then return error("stack[top] is nil (BSHR)", 0) end
	if a == nil then return error("stack[top-1] is nil (BSHR)", 0) end
	top = top - 1
	stack[top] = bitwise.rshift(a, shift)
	return pc, top
end

-- EQ: compare top two for equality
OP_HANDLERS[OP.EQ] = function(code, pc, stack, top, k, globals, L)
	if top < 2 then return error("stack underflow (EQ needs 2 values)", 0) end
	local b = stack[top]
	local a = stack[top - 1]
	if b == nil then return error("stack[top] is nil (EQ)", 0) end
	if a == nil then return error("stack[top-1] is nil (EQ)", 0) end
	top = top - 1
	stack[top] = (a == b)
	return pc, top
end

-- LT: compare top two for less than
OP_HANDLERS[OP.LT] = function(code, pc, stack, top, k, globals, L)
	if top < 2 then return error("stack underflow (LT needs 2 values)", 0) end
	local b = stack[top]
	local a = stack[top - 1]
	if b == nil then return error("stack[top] is nil (LT)", 0) end
	if a == nil then return error("stack[top-1] is nil (LT)", 0) end
	top = top - 1
	stack[top] = (a < b)
	return pc, top
end

-- LE: compare top two for less than or equal
OP_HANDLERS[OP.LE] = function(code, pc, stack, top, k, globals, L)
	if top < 2 then return error("stack underflow (LE needs 2 values)", 0) end
	local b = stack[top]
	local a = stack[top - 1]
	if b == nil then return error("stack[top] is nil (LE)", 0) end
	if a == nil then return error("stack[top-1] is nil (LE)", 0) end
	top = top - 1
	stack[top] = (a <= b)
	return pc, top
end

-- NOT: logical NOT top element
OP_HANDLERS[OP.NOT] = function(code, pc, stack, top, k, globals, L)
	if top < 1 then return error("stack underflow (NOT needs 1 value)", 0) end
	local a = stack[top]
	if a == nil then return error("stack[top] is nil (NOT)", 0) end
	stack[top] = not a
	return pc, top
end

-- JMP: unconditional jump
OP_HANDLERS[OP.JMP] = function(code, pc, stack, top, k, globals, L)
	local rel = code[pc]
	pc = pc + 1
	pc = (pc - 2) + rel
	return pc, top
end

-- JMPT: jump if true
OP_HANDLERS[OP.JMPT] = function(code, pc, stack, top, k, globals, L)
	if top < 1 then return error("stack underflow (JMPT needs 1 value)", 0) end
	local rel = code[pc]
	pc = pc + 1
	local cond = stack[top]
	if cond == nil then return error("stack[top] is nil (JMPT)", 0) end
	stack[top] = nil
	top = top - 1
	if cond then
		pc = (pc - 2) + rel
	end
	return pc, top
end

-- JMPF: jump if false
OP_HANDLERS[OP.JMPF] = function(code, pc, stack, top, k, globals, L)
	if top < 1 then return error("stack underflow (JMPF needs 1 value)", 0) end
	local rel = code[pc]
	pc = pc + 1
	local cond = stack[top]
	if cond == nil then return error("stack[top] is nil (JMPF)", 0) end
	stack[top] = nil
	top = top - 1
	if not cond then
		pc = (pc - 2) + rel
	end
	return pc, top
end

-- GETG: get global variable
OP_HANDLERS[OP.GETG] = function(code, pc, stack, top, k, globals, L)
	local ki = code[pc]
	pc = pc + 1
	local name = k[ki]
	top = top + 1
	stack[top] = rawget(globals, name)
	return pc, top
end

-- SETG: set global variable
OP_HANDLERS[OP.SETG] = function(code, pc, stack, top, k, globals, L)
	local ki = code[pc]
	pc = pc + 1
	local name = k[ki]
	rawset(globals, name, stack[top])
	stack[top] = nil
	top = top - 1
	return pc, top
end

-- CALL: call function
OP_HANDLERS[OP.CALL] = function(code, pc, stack, top, k, globals, L)
	_call_hook(L, "call")
	local nargs = code[pc]
	local nrets = code[pc + 1]
	pc = pc + 2
	L.top = top
	_call_into_stack(L, nargs, nrets)
	top = L.top
	return pc, top
end

-- RET: return from function
OP_HANDLERS[OP.RET] = function(code, pc, stack, top, k, globals, L)
	_call_hook(L, "return")
	local nrets = code[pc]
	pc = pc + 1
	if nrets and nrets >= 0 then
		local keep_from = top - nrets + 1
		if keep_from < 1 then keep_from = 1 end
		for i = 1, nrets do
			stack[i] = stack[keep_from + i - 1]
		end
		_clear_range(stack, nrets + 1, top)
		top = nrets
	end
	L.top = top
	return pc, top, true
end

-- DEBUG: debugger breakpoint
OP_HANDLERS[OP.DEBUG] = function(code, pc, stack, top, k, globals, L)
	-- Call the hook if set (acts as a breakpoint)
	if L.hooks and L.hooks.hook then
		L.hooks.hook("debug")
	end
	L.top = top
	return pc, top, false
end

-- HALT: stop execution
OP_HANDLERS[OP.HALT] = function(code, pc, stack, top, k, globals, L)
	L.top = top
	return pc, top, true
end

--- Run bytecode on a VM state without error protection.<br>
--- Executes a protocol (bytecode) on the specified VM state.<br>
--- Errors will propagate to the caller without being caught.<br>
--- Used internally by StackVM.run when protected mode is disabled.
---@param L table The State instance.
---@param proto table Protocol object with code and constant pool.
---@param opts table Options table (protected: boolean, step_limit: integer).
local function _run_unprotected(L, proto, opts)
	if type(L) ~= "table" then
		return error("_run_unprotected: L must be a table", 2)
	end
	if type(proto) ~= "table" then
		return error(string_format("_run_unprotected: proto must be a table, got %s", type(proto)), 2)
	end
	opts = opts or {}
	if type(opts) ~= "table" then
		return error(string_format("_run_unprotected: opts must be a table, got %s", type(opts)), 2)
	end
	local code = proto.code
	if type(code) ~= "table" then
		return error(string_format("_run_unprotected: proto.code must be a table, got %s", type(code)), 2)
	end
	if #code == 0 then
		return error("_run_unprotected: proto.code is empty", 2)
	end
	local k = proto.k or {}
	if type(k) ~= "table" then
		return error(string_format("_run_unprotected: proto.k must be a table, got %s", type(k)), 2)
	end
	local stack = L.stack
	if type(stack) ~= "table" then
		return error("_run_unprotected: L.stack must be a table", 2)
	end
	local globals = L.globals
	if type(globals) ~= "table" then
		return error("_run_unprotected: L.globals must be a table", 2)
	end

	local pc = 1
	local steps = 0
	local step_limit = opts.step_limit or false

	-- Locals for speed
	local top = L.top

	while true do
		steps = steps + 1
		if step_limit and steps > step_limit then
			return error(string_format("step limit exceeded (%d)", step_limit), 2)
		end

		-- Call line hook if configured
		_call_hook(L, "line")

		local op = code[pc]
		pc = pc + 1

		local handler = OP_HANDLERS[op]
		if handler then
			local new_pc, new_top, should_return = handler(code, pc, stack, top, k, globals, L)
			if should_return then
				return true
			end
			pc = new_pc
			top = new_top
		else
			return error(string_format("bad opcode %s at pc=%d", tostring(op), pc - 1), 2)
		end

		if top > L.maxstack then
			return error(string_format("stack overflow (top=%d maxstack=%d)", top, L.maxstack), 2)
		end
	end
end

--- Run bytecode on a VM state.<br>
--- Executes a protocol (bytecode) on the specified VM state.<br>
--- By default runs in protected mode and catches errors.
---@param L StackVM.State The VM state to execute on.
---@param proto table Protocol object with code and constant pool.
---@param opts? table Options table (protected: boolean, step_limit: integer).
---@return boolean ok True if execution succeeded, false if error occurred.
---@return string? error Error message if execution failed.
---@usage <br>
--- ```
--- local L = StackVM.new(256)
--- local proto = StackVM.compile({ code = { {op="HALT"} })
--- local ok, err = StackVM.run(L, proto, { protected = true })
--- ```
function StackVM.run(L, proto, opts)
	if type(L) ~= "table" then
		return error(string_format("StackVM.run: L must be a State instance, got %s", type(L)), 2)
	end
	if getmetatable(L) ~= State then
		return error("StackVM.run: L is not a valid State instance", 2)
	end
	if type(proto) ~= "table" then
		return error(string_format("StackVM.run: proto must be a table, got %s", type(proto)), 2)
	end
	if type(proto.code) ~= "table" then
		return error(string_format("StackVM.run: proto.code must be a table, got %s", type(proto.code)), 2)
	end
	if #proto.code == 0 then
		return error("StackVM.run: proto.code is empty", 2)
	end
	if opts ~= nil and type(opts) ~= "table" then
		return error(string_format("StackVM.run: opts must be a table or nil, got %s", type(opts)), 2)
	end
	if opts and opts.step_limit ~= nil then
		if type(opts.step_limit) ~= "number" then
			return error(string_format("StackVM.run: opts.step_limit must be a number, got %s", type(opts.step_limit)), 2)
		end
		if opts.step_limit < 0 then
			return error(string_format("StackVM.run: opts.step_limit must be >= 0, got %d", opts.step_limit), 2)
		end
	end
	if opts and not opts.protected then
		return _run_unprotected(L, proto, opts)
	end
	local ok, err = pcall(_run_unprotected, L, proto, opts)
	if not ok then
		return false, err
	end
	return true
end

-- Export
return StackVM
