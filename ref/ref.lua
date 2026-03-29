-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Reference wrapper
-- - Scalar operator overloading
-- - Readonly refs
-- - Weak refs
-- - Table-proxy mode
-- - Safe semantics

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
--- @param value any Initial value.
--- @param opts table|nil { proxy = bool, readonly = bool, weak = bool }
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
--- @param tbl table The source table.
--- @param opts table|nil { deep = bool, readonly = bool, weak = bool, proxy = bool }
--- @return table table A new table where each field is a Ref.
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

Ref_get = function(self)
	return self._weak and self._value.ref or self._value
end
Ref.get = Ref_get

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

Ref_update = function(self, f)
	if not Ref_is(self) then
		return error("Ref.update expects a Ref as first argument", 2)
	end
	return Ref_set(self, f(Ref_get(self)))
end
Ref.update = Ref_update

Ref_map = function(self, f)
	return Ref_new(f(Ref_get(self)))
end
Ref.map = Ref_map

Ref_is_readonly = function(self)
	return self._readonly
end
Ref.is_readonly = Ref_is_readonly

Ref_is_weak = function(self)
	return self._weak
end
Ref.is_weak = Ref_is_weak

Ref_is_nil_sentinel = function(self)
	return self and self._nil_sentinel or false
end
Ref.is_nil_sentinel = Ref_is_nil_sentinel

-- Utility --------------------------------------------------------------------

Ref_is = function(x)
	local mt = getmetatable(x)
	return mt and (mt.__index == Ref or x._proxy)
end
Ref.is = Ref_is

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

return setmetatable(Ref, {
	-- Allow Ref(value) as shorthand for Ref.new(value)
	__call = function(_, ...)
		return Ref_new(...)
	end,

	-- -Ref  ==>  readonly ref factory function
	__unm = function(_)
		return function(value)
			return Ref_new(value, { readonly = true })
		end
	end,

	-- Ref* { x=1, y=2 }  ==>  Ref.from_table({ x=1, y=2 })
	__mul = function(_, rhs)
		if type(rhs) ~= "table" then
			return error("Ref* expects a table on the right-hand side")
		end
		return Ref_from_table(rhs)
	end,

	-- Ref+ { ... }  ==>  merge refs
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

	-- Ref% t  ==>  deep-proxy refs
	__mod = function(_, rhs)
		if type(rhs) ~= "table" then
			return error("Ref% expects a table on the right-hand side")
		end
		return Ref_from_table(rhs, { deep = true, proxy = true })
	end,

	-- Ref^ t  ==>  deep refs
	__pow = function(_, rhs)
		if type(rhs) ~= "table" then
			return error("Ref^ expects a table on the right-hand side")
		end
		return Ref_from_table(rhs, { deep = true })
	end,

	-- Ref/ t  ==>  readonly struct refs
	__div = function(_, rhs)
		if type(rhs) ~= "table" then
			return error("Ref/ expects a table on the right-hand side")
		end
		return Ref_from_table(rhs, { deep = true, readonly = true })
	end,

	__tostring = function() return "Ref" end,
	__metatable = false
})
