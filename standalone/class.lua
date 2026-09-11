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
				if b.ctor then   -- skip if undefined
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

-- Module-scope helper function to check if a value is an instance of a class
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

-- Properly initialize Object with the class system
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
