-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for class.lua.
-- Run from this directory:
--   lua class.lua
--   luajit class.lua

-- Bootstrap: make requires work from tests/ subdir with plain lua/luajit.
do
	local src = debug.getinfo(1, "S").source
	local dir = src:match("^@(.+/)[^/]+$") or "./"
	local function isfile(p)
		local f = io.open(p, "r")
		if f then
			f:close()
			return true
		end
		return false
	end
	local root
	for _, c in ipairs({ dir, dir .. "../", dir .. "../..//", dir .. "../../..//", "./", "../", "../../" }) do
		if isfile(c .. "standalone/bits.lua") then
			root = c
			break
		end
	end
	root = root or dir .. "../"
	if package then
		package.path = dir ..
			"../?.lua;" ..
			dir ..
			"../?/init.lua;" ..
			dir ..
			"?.lua;" ..
			dir ..
			"?/init.lua;" ..
			root ..
			"?.lua;" ..
			root ..
			"?/init.lua;" ..
			root ..
			"standalone/?.lua;" ..
			root ..
			"math/?.lua;" ..
			root ..
			"collections/?.lua;" ..
			root ..
			"benchmark/?.lua;" ..
			root ..
			"timer/?.lua;" ..
			root ..
			"autocompleter/?.lua;" ..
			root ..
			"permission/?.lua;" ..
			root ..
			"chat_commander/?.lua;" ..
			root .. "vm/?.lua;" .. root .. "require_finder/?.lua;" .. root .. "inventory/?.lua;" .. package.path
	end
	local searchers = package.searchers or package.loaders
	if searchers then
		table.insert(searchers, 2, function(mod)
			if mod:sub(1, 3) == "../" or mod:sub(1, 2) == "./" then
				local clean = mod:gsub("^%./", ""):gsub("^%.%.%/", ""):gsub("^%.%.%/", "")
				local tries = { dir .. "../" .. clean .. ".lua", dir .. "../" .. clean .. "/init.lua", root ..
				clean .. ".lua", root .. clean .. "/init.lua" }
				for _, f in ipairs(tries) do
					if isfile(f) then
						local chunk, err = loadfile(f)
						if chunk then return chunk, f end
					end
				end
			end
			return nil
		end)
	end
end
local lib = require "class"
-- Bridging: use exported Object/class so identity matches lib internals.
local class = lib.class or function(...) return lib(...) end
local Object = lib.Object
local instanceof = lib.instanceof

if true then
	print("Running class system tests...")

	-- Test 1: Basic class creation and inheritance
	local Animal = class(function(self, name)
		self.name = name
	end)

	local Dog = class(Animal, function(self, name, breed)
		Animal.ctor(self, name)
		self.breed = breed
	end)

	function Dog:bark()
		return self.name .. " says woof!"
	end

	local dog = Dog("Buddy", "Golden Retriever")
	assert(dog.name == "Buddy", "Test 1a failed: name not set")
	assert(dog.breed == "Golden Retriever", "Test 1b failed: breed not set")
	assert(dog:bark() == "Buddy says woof!", "Test 1c failed: bark method")
	assert(dog:is(Animal), "Test 1d failed: is inheritance")
	assert(instanceof(dog, Dog), "Test 1e failed: instanceof")
	assert(instanceof(dog, Animal), "Test 1f failed: instanceof inheritance")

	-- Test 2: Default Object inheritance
	local Simple = class(function(self, value)
		self.value = value
	end)

	local simple = Simple(42)
	assert(simple.value == 42, "Test 2a failed: simple class")
	assert(simple:is(Object), "Test 2b failed: default Object inheritance")
	assert(instanceof(simple, Object), "Test 2c failed: instanceof Object")

	-- Test 3: Constructor-only class
	local OnlyCtor = class(function(self, x)
		self.x = x
	end)

	local only = OnlyCtor(10)
	assert(only.x == 10, "Test 3a failed: constructor-only")
	assert(only:is(Object), "Test 3b failed: ctor-only inherits Object")

	-- Test 4: Reparenting
	local Cat = class(Animal, function(self, name)
		Animal.ctor(self, name)
	end)

	function Cat:meow()
		return self.name .. " says meow!"
	end

	local cat = Cat("Whiskers")
	assert(cat:meow() == "Whiskers says meow!", "Test 4a failed: cat meow")

	-- Reparent cat to be a dog
	cat:rebase(Dog)
	assert(cat:is(Dog), "Test 4b failed: rebase Dog")
	assert(cat:bark() == "Whiskers says woof!", "Test 4c failed: reparented method")

	-- Test 5: Class inheritance checking
	assert(Dog:inherits(Animal), "Test 5a failed: Dog inherits Animal")
	assert(Dog:inherits(Object), "Test 5b failed: Dog inherits Object")
	assert(not Animal:inherits(Dog), "Test 5c failed: Animal doesn't inherit Dog")
	assert(Object:inherits(Object) == false, "Test 5d failed: Object doesn't inherit itself")

	print("All tests passed!")
end
