-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Reference wrapper
-- - Scalar operator overloading
-- - Readonly refs
-- - Weak refs
-- - Table-proxy mode
-- - Safe semantics

---@alias RefOptions table
---@field proxy boolean? Create proxy table for table values
---@field readonly boolean? Make reference readonly
---@field weak boolean? Use weak references
---@field deep boolean? Enable deep mode for table operations
---@field nil_sentinel boolean? Use sentinel for nil values

---@class Ref
---@field _value any The stored value
---@field _readonly boolean Whether the reference is readonly
---@field _weak boolean Whether the reference uses weak references
---@field _proxy boolean Whether the reference is a proxy
---@field _deep boolean Whether deep mode is enabled
---@field _nil_sentinel boolean Whether nil is represented by sentinel
---@field new fun(value: any, opts?: table): Ref Create a new reference
---@field get fun(self: Ref): any Get the value
---@field set fun(self: Ref, value: any): Ref Set the value (returns self for chaining)
---@field update fun(self: Ref, fn: fun(value: any): any): Ref Update with function
---@field map fun(self: Ref, fn: fun(value: any): any): Ref Map to new reference
---@field is_readonly fun(self: Ref): boolean Check if readonly
---@field is_weak fun(self: Ref): boolean Check if weak
---@field is_nil_sentinel fun(self: Ref): boolean Check if nil sentinel
---@field from_table fun(tbl: table, opts?: table): table Wrap table fields in refs
---@field is fun(x: any): boolean Check if value is a ref
---@field unwrap fun(v: any): any Unwrap ref if present
---@operator call: fun(value: any, opts?: table): Ref Create new ref (shorthand for Ref.new)
---@operator unm: fun(): fun(value: any): Ref Create readonly ref factory
---@operator mul: fun(rhs: table): table Wrap table fields in refs (shorthand for Ref.from_table)
---@operator add: fun(rhs: table): table Merge refs into table
---@operator mod: fun(rhs: table): table Create deep proxy refs
---@operator pow: fun(rhs: table): table Create deep refs
---@operator div: fun(rhs: table): table Create readonly struct refs
local Ref = {}
Ref.__index = Ref

-- Shared metatable for all Refs (except proxy refs)
local ref_metatable = {}
ref_metatable.__index = Ref

-- My precious forward declarations for performance ---------------------------
local Ref_new, Ref_from_table, Ref_is, Ref_unwrap
local Ref_get, Ref_set, Ref_update, Ref_map, Ref_is_readonly, Ref_is_weak

-- Constructors ---------------------------------------------------------------

--- Create a new reference wrapper.
---@param value any Initial value.
---@param opts RefOptions|nil Options for reference behavior
---@return Ref ref New reference instance
Ref_new = function(value, opts)
	opts = opts or {}

	-- Special case: nil values are always readonly sentinel refs
	if value == nil then
		local self = {
			_value = nil,
			_proxy = false,
			_readonly = true, -- Always readonly for nil
			_weak = false,
			_deep = false,
			_nil_sentinel = true -- Special flag for nil sentinel
		}
		-- Use shared metatable for nil sentinel refs
		return setmetatable(self, ref_metatable)
	end

	local self = {
		_value = value,
		_proxy = opts.proxy and type(value) == "table" or false,
		_readonly = opts.readonly or false,
		_weak = opts.weak or false,
		_deep = opts.deep or false -- Flag to indicate deep mode
	}

	-- Weak reference mode
	if self._weak then
		local weak = setmetatable({}, { __mode = "v" })
		weak.ref = value
		self._value = weak
	end

	-- Metatable dispatch
	local mt = {}

	-- Proxy mode for tables --------------------------------------------------
	if self._proxy then
		mt.__index = function(_, k)
			local val = value[k]
			-- For readonly refs in deep mode, wrap returned values in readonly refs
			-- For regular readonly refs (not deep mode), return raw values
			if self._readonly and self._deep and type(val) ~= "table" then
				return Ref_new(val, { readonly = true })
			elseif self._deep and type(val) ~= "table" then
				-- For deep mode proxy refs, wrap scalar values in refs
				return Ref_new(val)
			end
			return val
		end
		mt.__newindex = function(_, k, v)
			if self._readonly then
				return error("attempt to modify readonly ref", 2)
			end
			value[k] = v
		end
		mt.__call = function(_)
			return value
		end
		mt.__tostring = function(_)
			return tostring(value)
		end
		return setmetatable(self, mt)
	end

	-- Scalar / non-proxy mode ------------------------------------------------
	-- Use shared metatable for scalar refs
	return setmetatable(self, ref_metatable)
end

Ref.new = Ref_new

--- Wrap each field of a table in a Ref.
---@param tbl table The source table.
---@param opts RefOptions|nil Options for reference behavior
---@return table result A new table where each field is a Ref.
Ref_from_table = function(tbl, opts, _seen)
	assert(type(tbl) == "table", "Ref.from_table expects a table")
	opts = opts or {}
	_seen = _seen or {}

	-- Cycle detection
	if _seen[tbl] then
		---@diagnostic disable-next-line: missing-return-value
		return -- TODO: Maybe return a special marker/sentinel, but (implicit) nil is safer...
	end
	_seen[tbl] = true

	local out = {}

	for k, v in next, tbl do
		if type(v) == "table" and opts.deep then
			-- Recursively wrap nested tables with cycle detection
			-- For deep mode, create a single Ref with proxy for the nested table
			local nested_opts = {
				readonly = opts.readonly,
				weak = opts.weak,
				proxy = true, -- Always use proxy for nested tables in deep mode
				deep = true -- Mark as deep mode proxy
			}
			out[k] = Ref_new(v, nested_opts)
		else
			out[k] = Ref_new(v, {
				readonly = opts.readonly,
				weak = opts.weak,
				proxy = opts.proxy and type(v) == "table"
			})
		end
	end

	_seen[tbl] = nil -- Clean up for other branches
	return out
end

Ref.from_table = Ref_from_table

-- API ------------------------------------------------------------------------

--- Get the value from a Ref.
---@param self Ref Reference instance
---@return any value The stored value
Ref_get = function(self)
	return self._weak and self._value.ref or self._value
end

Ref.get = Ref_get

--- Set the value of a Ref (if not readonly).
---@param self Ref Reference instance
---@param v any New value
---@return Ref self Self for chaining
Ref_set = function(self, v)
	if self._readonly or self._nil_sentinel then
		local error_msg = self._nil_sentinel and
			"attempt to modify nil sentinel ref" or
			"attempt to modify readonly ref"
		return error(error_msg, 2)
	end
	if self._weak then
		self._value.ref = v
	else
		self._value = v
	end
	return self
end

Ref.set = Ref_set

--- Update the value of a Ref using a function (if not readonly).
---@param self Ref Reference instance
---@param f fun(value: any): any Update function
---@return Ref self Self for chaining
Ref_update = function(self, f)
	if not Ref_is(self) then
		return error("Ref.update expects a Ref as first argument", 2)
	end
	return Ref_set(self, f(Ref_get(self)))
end

Ref.update = Ref_update

--- Map a Ref to a new Ref by applying a function to its value.
---@param self Ref Reference instance
---@param f fun(value: any): any Mapping function
---@return Ref mapped New reference with mapped value
Ref_map = function(self, f)
	return Ref_new(f(Ref_get(self)))
end

Ref.map = Ref_map

--- Check if a Ref is readonly.
---@param self Ref Reference instance
---@return boolean is_readonly True if readonly
Ref_is_readonly = function(self)
	return self._readonly
end

Ref.is_readonly = Ref_is_readonly

--- Check if a Ref uses weak references.
---@param self Ref Reference instance
---@return boolean is_weak True if weak
Ref_is_weak = function(self)
	return self._weak
end

Ref.is_weak = Ref_is_weak

--- Check if a Ref uses nil sentinel.
---@param self Ref Reference instance
---@return boolean is_nil_sentinel True if nil sentinel
Ref_is_nil_sentinel = function(self)
	return self and self._nil_sentinel or false
end

Ref.is_nil_sentinel = Ref_is_nil_sentinel

-- Utility --------------------------------------------------------------------

--- Check if a value is a Ref.
---@param x any Value to check
---@return boolean is_ref True if value is a Ref
Ref_is = function(x)
	local mt = getmetatable(x)
	return mt and (mt.__index == Ref or x._proxy)
end

Ref.is = Ref_is

--- Unwrap a Ref if present, otherwise return the value as-is.
---@param v any Value to unwrap
---@return any unwrapped Unwrapped value
Ref_unwrap = function(v)
	if Ref_is(v) then return Ref_get(v) end
	return v
end

Ref.unwrap = Ref_unwrap

-- Initialize the shared metatable's metamethods (after all functions are defined)
ref_metatable.__call = function(_, v)
	if v ~= nil then
		local self = _
		if self._readonly or self._nil_sentinel then
			local error_msg = self._nil_sentinel and
				"attempt to modify nil sentinel ref" or
				"attempt to modify readonly ref"
			return error(error_msg, 2)
		end
		if self._weak then
			self._value.ref = v
		else
			self._value = v
		end
	end
	return Ref_get(_)
end

ref_metatable.__tostring = function(_)
	return tostring(Ref_get(_))
end

-- Operator overloading for scalar refs ----------------------------------
ref_metatable.__add = function(a, b)
	local a_val = Ref_is(a) and Ref_get(a) or a
	local b_val = Ref_is(b) and Ref_get(b) or b
	return Ref_new(a_val + b_val)
end
ref_metatable.__sub = function(a, b)
	local a_val = Ref_is(a) and Ref_get(a) or a
	local b_val = Ref_is(b) and Ref_get(b) or b
	return Ref_new(a_val - b_val)
end
ref_metatable.__mul = function(a, b)
	local a_val = Ref_is(a) and Ref_get(a) or a
	local b_val = Ref_is(b) and Ref_get(b) or b
	return Ref_new(a_val * b_val)
end
ref_metatable.__div = function(a, b)
	local a_val = Ref_is(a) and Ref_get(a) or a
	local b_val = Ref_is(b) and Ref_get(b) or b
	return Ref_new(a_val / b_val)
end
ref_metatable.__mod = function(a, b)
	local a_val = Ref_is(a) and Ref_get(a) or a
	local b_val = Ref_is(b) and Ref_get(b) or b
	return Ref_new(a_val % b_val)
end
ref_metatable.__pow = function(a, b)
	local a_val = Ref_is(a) and Ref_get(a) or a
	local b_val = Ref_is(b) and Ref_get(b) or b
	return Ref_new(a_val ^ b_val)
end
-- Unary negation respects underlying value's metatable
ref_metatable.__unm = function(self)
	local val = Ref_get(self)

	-- Check for custom metatable __unm metamethod
	local mt = getmetatable(val)
	if mt and type(mt.__unm) == "function" then
		return mt.__unm(val)
	end

	-- Default behavior for numeric values
	if type(val) == "number" then
		return Ref_new(-val)
	end

	return error("cannot apply unary negation to " .. type(val) .. " value", 2)
end
ref_metatable.__eq = function(a, b)
	local a_val = Ref_is(a) and Ref_get(a) or a
	local b_val = Ref_is(b) and Ref_get(b) or b
	return a_val == b_val
end
ref_metatable.__lt = function(a, b)
	local a_val = Ref_is(a) and Ref_get(a) or a
	local b_val = Ref_is(b) and Ref_get(b) or b
	return a_val < b_val
end
ref_metatable.__le = function(a, b)
	local a_val = Ref_is(a) and Ref_get(a) or a
	local b_val = Ref_is(b) and Ref_get(b) or b
	return a_val <= b_val
end

-- String concatenation for refs
ref_metatable.__concat = function(a, b)
	local a_val = Ref_is(a) and Ref_get(a) or a
	local b_val = Ref_is(b) and Ref_get(b) or b
	return Ref_new(tostring(a_val) .. tostring(b_val))
end

---@type Ref
local RefExport = setmetatable(Ref, {
	--- Allow Ref(value) as shorthand for Ref.new(value)
	---@param ... any Arguments to pass to Ref_new
	---@return Ref ref New reference
	__call = function(_, ...)
		return Ref_new(...)
	end,

	--- -Ref  ==>  readonly ref factory function
	---@return fun(value: any): Ref factory Function that creates readonly refs
	__unm = function(_)
		return function(value)
			return Ref_new(value, { readonly = true })
		end
	end,

	--- Ref* { x=1, y=2 }  ==>  Ref.from_table({ x=1, y=2 })
	---@param rhs table Table to wrap
	---@return table wrapped Table with Ref-wrapped fields
	__mul = function(_, rhs)
		if type(rhs) ~= "table" then
			return error("Ref* expects a table on the right-hand side")
		end
		return Ref_from_table(rhs)
	end,

	--- Ref+ { ... }  ==>  merge refs
	---@param rhs table Table to merge
	---@return table merged Table with Ref-wrapped fields
	__add = function(_, rhs)
		if type(rhs) ~= "table" then
			return error("Ref+ expects a table on the right-hand side")
		end
		local out = {}
		for k, v in next, rhs do
			out[k] = Ref_new(v)
		end
		return out
	end,

	--- Ref% t  ==>  deep-proxy refs
	---@param rhs table Table to wrap
	---@return table deep_proxy Table with deep proxy Ref-wrapped fields
	__mod = function(_, rhs)
		if type(rhs) ~= "table" then
			return error("Ref% expects a table on the right-hand side")
		end
		return Ref_from_table(rhs, { deep = true, proxy = true })
	end,

	--- Ref^ t  ==>  deep refs
	---@param rhs table Table to wrap
	---@return table deep Table with deep Ref-wrapped fields
	__pow = function(_, rhs)
		if type(rhs) ~= "table" then
			return error("Ref^ expects a table on the right-hand side")
		end
		return Ref_from_table(rhs, { deep = true })
	end,

	--- Ref/ t  ==>  readonly struct refs
	---@param rhs table Table to wrap
	---@return table readonly_struct Table with readonly deep Ref-wrapped fields
	__div = function(_, rhs)
		if type(rhs) ~= "table" then
			return error("Ref/ expects a table on the right-hand side")
		end
		return Ref_from_table(rhs, { deep = true, readonly = true })
	end,

	__tostring = function() return "Ref" end,
	__metatable = false
})

-- Export
---@type Ref
return RefExport
