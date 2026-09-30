-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for BiMap.lua.
-- Run from this directory:
--   lua BiMap.lua
--   luajit BiMap.lua

-- Bootstrap: shared test bootstrap (see ../../.tools/bootstrap.lua).
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
	local boot
	for _, c in ipairs({
		dir .. "../../.tools/bootstrap.lua",
		dir .. "../.tools/bootstrap.lua",
		dir .. "../../../.tools/bootstrap.lua",
		"./.tools/bootstrap.lua",
		"../.tools/bootstrap.lua",
		"../../.tools/bootstrap.lua",
	}) do
		if isfile(c) then
			boot = c
			break
		end
	end
	assert(boot, "cheatoid test bootstrap not found (.tools/bootstrap.lua)")
	assert(dofile(boot))(dir)
end
local lib = require "BiMap"
-- Bridging: file-locals used by tests mapped to module exports.
local BiMap = lib

-- Lua 5.1/LuaJIT do not support __len/__pairs/__ipairs metamethods on tables.
local is_lua51 = _VERSION == "Lua 5.1" or type(jit) == "table"

if true then
	-- Test the BiMap class
	do
		-- Create a new bimap
		local bimap = BiMap.new()
		-- Test that the bimap is initially empty
		assert(bimap:isEmpty(), "BiMap should be empty after creation")
		-- Test that the count of items in the bimap is initially 0
		assert(bimap:count() == 0, "BiMap count should be 0 after creation")
		-- Add a value to the bimap
		local id1 = bimap:add("Apple")
		-- Test that the bimap is not empty after adding a value
		assert(not bimap:isEmpty(), "BiMap should not be empty after adding a value")
		-- Test that the count of items in the bimap is 1 after adding a value
		assert(bimap:count() == 1, "BiMap count should be 1 after adding a value")
		-- Test that the index returned is 1
		assert(id1 == 1, "First index should be 1")
		-- Test getting the index of a value
		assert(bimap:get_index("Apple") == 1, "get_index should return 1 for Apple")
		-- Test checking if a value exists
		assert(bimap:contains("Apple"), "BiMap should contain Apple")
		assert(not bimap:contains("Banana"), "BiMap should not contain Banana")
		-- Test adding another value
		local id2 = bimap:add("Banana")
		assert(id2 == 2, "Second index should be 2")
		assert(bimap:count() == 2, "BiMap count should be 2 after adding second value")
		-- Test adding a duplicate value
		local id3 = bimap:add("Apple")
		assert(id3 == id1, "Adding duplicate should return existing index")
		assert(bimap:count() == 2, "BiMap count should still be 2 after adding duplicate")
		-- Test remove by index
		bimap:remove(id1)
		assert(not bimap:contains("Apple"), "BiMap should not contain Apple after removal")
		assert(bimap:count() == 1, "BiMap count should be 1 after removal")
		-- Test remove by value
		bimap:add("Cherry")
		bimap:removeByValue("Banana")
		assert(not bimap:contains("Banana"), "BiMap should not contain Banana after removal")
		assert(bimap:count() == 1, "BiMap count should be 1 after removal")
		-- Test clear operation
		bimap:clear()
		assert(bimap:isEmpty(), "BiMap should be empty after clear")
		assert(bimap:count() == 0, "BiMap count should be 0 after clear")
		-- Test with different types of values
		local t = { 1, 2, 3 }
		local f = function() return 4 end
		local id4 = bimap:add("test")
		local id5 = bimap:add(t)
		local id6 = bimap:add(f)
		assert(bimap:count() == 3, "BiMap should have 3 items after adding different types")
		assert(bimap:get_index(t) == id5, "get_index should work for table")
		assert(bimap:get_index(f) == id6, "get_index should work for function")
		-- Test containsIndex
		assert(bimap:containsIndex(id5), "containsIndex should return true for existing index")
		assert(not bimap:containsIndex(999), "containsIndex should return false for non-existing index")
		-- Test iterator
		local values = {}
		for value in bimap:iterator() do
			table.insert(values, value)
		end
		assert(#values == 3, "Iterator should yield 3 values")
		-- Test # operator (requires Lua 5.2+; __len on tables unsupported in 5.1/LuaJIT)
		if not is_lua51 then
			assert(#bimap == 3, "# operator should return count")
		else
			assert(bimap:count() == 3, "# operator should return count")
		end
	end
	do
		-- Test iteration with holes
		local bimap = BiMap.new()
		local id1 = bimap:add("Apple")
		local id2 = bimap:add("Banana")
		bimap:remove(id2)
		local id3 = bimap:add("Cherry")
		-- Test that indices are monotonically increasing
		assert(id1 == 1, "First index should be 1")
		assert(id2 == 2, "Second index should be 2")
		assert(id3 == 3, "Third index should be 3")
		-- Test pairs iteration (unordered)
		-- On 5.1/LuaJIT __pairs is unsupported, call __pairs directly.
		local count = 0
		if is_lua51 then
			for index, value in bimap:__pairs() do
				count = count + 1
			end
		else
			for index, value in pairs(bimap) do
				count = count + 1
			end
		end
		assert(count == 2, "pairs should iterate over 2 active elements")
		-- Test ipairs iteration (ordered)
		local ipairs_count = 0
		for index, value in bimap:__ipairs() do
			ipairs_count = ipairs_count + 1
		end
		assert(ipairs_count == 2, "ipairs should iterate over 2 active elements")
	end

	print("All tests passed")
end
