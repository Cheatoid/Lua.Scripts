-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Simple class implementation

-- Localized global functions for better performance
local type = type
local error = error
local getmetatable = getmetatable
local setmetatable = setmetatable
--local rawget = rawget

-- Forward declare Object (root of all classes)
local Object

-- Create Object first to avoid circular reference issues
Object = {} -- temporary placeholder

--- Create a class table; call it to construct an instance of the class.<br>
--- `base` may be a class table (defaults to `Object`); when only a function is passed it is
--- treated as the constructor `ctor`.<br>
--- Base constructors run first (root parent to derived), then this class's constructor.<br>
--- Instances get the `inherits`, `is` and `rebase` helpers through `__index`.
---@param base? table|function Base class table, or the constructor when `ctor` is omitted.
---@param ctor? function Constructor called with the new instance and the constructor arguments.
---@return table class The new class table, callable to construct instances.
local function class(base, ctor)
	local c = {} -- a new class instance
	if not ctor and type(base) == "function" then
		ctor = base
		base = Object -- set Object as default base when only constructor is provided
	elseif not base then
		base = Object -- set Object as default base when no arguments provided
	end
	-- now set __base if base is a table
	if type(base) == "table" then
		-- do not make copies; allow swapping/extending base classes easily
		c.__base = base
	elseif base then
		-- handle the case where base is Object (which is a table)
		c.__base = base
	else
		base = Object -- fallback to Object for invalid base types
	end
	-- the class will be the metatable for all its objects, and they will look up their methods in it
	c.__index = function(_, key)
		local val = c[key] -- TODO/CONS: perhaps use rawget(c, key)?
		if val ~= nil then return val end
		-- not found in this class, check in the base class
		if base then
			return base[key]
		end
	end
	c.ctor = ctor
	c.inherits = function(self, Class)
		local m = self.__base -- start with the base class, not self
		while m do
			if m == Class then return true end
			m = m.__base
		end
		return false
	end
	c.is = function(self, Class)
		local m = getmetatable(self)
		while m do
			if m == Class then return true end
			m = m.__base
		end
		return false
	end
	c.rebase = function(self, Class)
		if type(Class) ~= "table" then -- TODO: Object?
			return error("rebase: Class must be a table", 2)
		end
		-- change the metatable of the instance to the new class
		return setmetatable(self, Class)
	end
	-- expose a constructor which can be called by <classname>(<args>)
	return setmetatable(c, {
		__call = function(_, ...)
			local this = setmetatable({}, c)
			-- traverse up the base class hierarchy and call each ctor function if present
			local b = base
			local base_inits = {} -- [sub base, sub sub base, ..., root base]
			while b do
				if b.ctor then -- skip if undefined
					base_inits[#base_inits + 1] = b.ctor
				end
				b = b.__base
			end
			-- call base class constructors from top(root) to bottom(final)
			for i = #base_inits, 1, -1 do
				base_inits[i](this, ...)
			end
			-- finally call this class's constructor (if present)
			if c.ctor then
				c.ctor(this, ...)
			end
			return this
		end
	})
end

--- Module-scope helper function to check if a value is an instance of a class.<br>
--- Walks the `__base` chain, so instances of subclasses count as well.
---@param obj any Value to test.
---@param Class table The class to test against.
---@return boolean is_instance True when `obj` derives from `Class`.
local function instanceof(obj, Class)
	if type(obj) ~= "table" or type(Class) ~= "table" then
		return false
	end
	local m = getmetatable(obj)
	while m do
		if m == Class then return true end
		m = m.__base
	end
	return false
end

--- Root of the class system: `class()` called without a base class inherits from this one.
Object = class()

-- Export
return setmetatable({
		instanceof = instanceof,
		-- Exposed for standalone Quick-tests (file-locals used directly in tests).
		Object = Object,
		class = class,
	},
	{
		__call = function(_, ...)
			return class(...)
		end,
	})
