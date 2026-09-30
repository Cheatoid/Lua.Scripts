-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for SparseArray.lua.
-- Run from this directory:
--   lua SparseArray.lua
--   luajit SparseArray.lua

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
local lib = require "SparseArray"
-- Bridging: file-locals used by tests mapped to module exports.
local SparseArray = lib

-- Lua 5.1/LuaJIT do not support __len/__pairs/__ipairs metamethods on tables.
local is_lua51 = _VERSION == "Lua 5.1" or type(jit) == "table"
local function len(m) return (not is_lua51) and #m or m:count() end

if true then
	-- Create a new SparseArray
	local sparsearray = SparseArray.new()
	-- Test that the sparsearray is initially empty
	assert(len(sparsearray) == 0, "SparseArray should be empty initially")
	-- Test add operation
	local id1 = sparsearray:add("Apple")
	assert(len(sparsearray) == 1, "SparseArray should have 1 item after add")
	assert(sparsearray:contains(id1), "SparseArray should contain the added value")
	-- Test add multiple values
	local id2 = sparsearray:add("Banana")
	local id3 = sparsearray:add("Cherry")
	assert(len(sparsearray) == 3, "SparseArray should have 3 items after adding multiple values")
	-- Test remove operation to create a hole
	sparsearray:remove(id2)
	assert(len(sparsearray) == 2, "SparseArray should have 2 items after remove")
	assert(not sparsearray:contains(id2), "SparseArray should not contain removed value")
	-- Test __pairs metamethod (unordered iteration)
	-- On 5.1/LuaJIT __pairs is unsupported, call __pairs directly.
	local pairs_count = 0
	if is_lua51 then
		for index, value in sparsearray:__pairs() do
			pairs_count = pairs_count + 1
		end
	else
		for index, value in pairs(sparsearray) do
			pairs_count = pairs_count + 1
		end
	end
	assert(pairs_count == 2, "pairs() should iterate over 2 items")
	-- Test __ipairs metamethod (ordered iteration, skips holes)
	local ipairs_count = 0
	local previous_index = 0
	for index, value in sparsearray:__ipairs() do
		ipairs_count = ipairs_count + 1
		assert(index > previous_index, "__ipairs() should return indices in ascending order")
		previous_index = index
	end
	assert(ipairs_count == 2, "__ipairs() should iterate over 2 items")
	-- Test iterator
	local iterator_count = 0
	for value in sparsearray:iterator() do
		iterator_count = iterator_count + 1
	end
	assert(iterator_count == 2, "iterator() should iterate over 2 items")
	-- Test clear operation
	sparsearray:clear()
	assert(len(sparsearray) == 0, "SparseArray should be empty after clear")
	print("All tests passed")
end
