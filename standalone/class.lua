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

-- Quick tests
--if true then
--	print("Running class system tests...")
--
--	-- Test 1: Basic class creation and inheritance
--	local Animal = class(function(self, name)
--		self.name = name
--	end)
--
--	local Dog = class(Animal, function(self, name, breed)
--		Animal.ctor(self, name)
--		self.breed = breed
--	end)
--
--	function Dog:bark()
--		return self.name .. " says woof!"
--	end
--
--	local dog = Dog("Buddy", "Golden Retriever")
--	assert(dog.name == "Buddy", "Test 1a failed: name not set")
--	assert(dog.breed == "Golden Retriever", "Test 1b failed: breed not set")
--	assert(dog:bark() == "Buddy says woof!", "Test 1c failed: bark method")
--	assert(dog:is(Animal), "Test 1d failed: is inheritance")
--	assert(instanceof(dog, Dog), "Test 1e failed: instanceof")
--	assert(instanceof(dog, Animal), "Test 1f failed: instanceof inheritance")
--
--	-- Test 2: Default Object inheritance
--	local Simple = class(function(self, value)
--		self.value = value
--	end)
--
--	local simple = Simple(42)
--	assert(simple.value == 42, "Test 2a failed: simple class")
--	assert(simple:is(Object), "Test 2b failed: default Object inheritance")
--	assert(instanceof(simple, Object), "Test 2c failed: instanceof Object")
--
--	-- Test 3: Constructor-only class
--	local OnlyCtor = class(function(self, x)
--		self.x = x
--	end)
--
--	local only = OnlyCtor(10)
--	assert(only.x == 10, "Test 3a failed: constructor-only")
--	assert(only:is(Object), "Test 3b failed: ctor-only inherits Object")
--
--	-- Test 4: Reparenting
--	local Cat = class(Animal, function(self, name)
--		Animal.ctor(self, name)
--	end)
--
--	function Cat:meow()
--		return self.name .. " says meow!"
--	end
--
--	local cat = Cat("Whiskers")
--	assert(cat:meow() == "Whiskers says meow!", "Test 4a failed: cat meow")
--
--	-- Reparent cat to be a dog
--	cat:rebase(Dog)
--	assert(cat:is(Dog), "Test 4b failed: rebase Dog")
--	assert(cat:bark() == "Whiskers says woof!", "Test 4c failed: reparented method")
--
--	-- Test 5: Class inheritance checking
--	assert(Dog:inherits(Animal), "Test 5a failed: Dog inherits Animal")
--	assert(Dog:inherits(Object), "Test 5b failed: Dog inherits Object")
--	assert(not Animal:inherits(Dog), "Test 5c failed: Animal doesn't inherit Dog")
--	assert(Object:inherits(Object) == false, "Test 5d failed: Object doesn't inherit itself")
--
--	print("All tests passed!")
--end

-- Export
return setmetatable({
		instanceof = instanceof,
	},
	{
		__call = function(_, ...)
			return class(...)
		end,
	})
