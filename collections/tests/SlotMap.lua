-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for SlotMap.lua.
-- Run from this directory:
--   lua SlotMap.lua
--   luajit SlotMap.lua

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
local lib = require "SlotMap"
local SlotMap = lib

-- Lua 5.1/LuaJIT do not support __len/__pairs/__ipairs metamethods on tables.
local is_lua51 = _VERSION == "Lua 5.1" or type(jit) == "table"
local function len(m) return (not is_lua51) and #m or m:count() end

if true then
	-- Create a new SlotMap
	local slotmap = SlotMap.new()
	-- Test that the slotmap is initially empty
	assert(len(slotmap) == 0, "SlotMap should be empty initially")
	-- Test add operation
	local id1 = slotmap:add("Apple")
	assert(len(slotmap) == 1, "SlotMap should have 1 item after add")
	assert(slotmap:contains(id1), "SlotMap should contain the added value")
	assert(slotmap:get(id1) == "Apple", "SlotMap should return the correct value")
	-- Test add multiple values
	local id2 = slotmap:add("Banana")
	local id3 = slotmap:add("Cherry")
	assert(len(slotmap) == 3, "SlotMap should have 3 items after adding multiple values")
	-- Test remove operation to create a hole
	slotmap:remove(id2)
	assert(len(slotmap) == 2, "SlotMap should have 2 items after remove")
	assert(not slotmap:contains(id2), "SlotMap should not contain removed value")
	-- Test add after removal (should get new index, not reuse hole)
	local id4 = slotmap:add("Date")
	assert(id4 > id3, "New index should be greater than previous max index")
	assert(len(slotmap) == 3, "SlotMap should have 3 items after add")
	-- Test __pairs metamethod (unordered iteration)
	-- On 5.1/LuaJIT __pairs is unsupported, call __pairs directly.
	local pairs_count = 0
	if is_lua51 then
		for index, value in slotmap:__pairs() do
			pairs_count = pairs_count + 1
		end
	else
		for index, value in pairs(slotmap) do
			pairs_count = pairs_count + 1
		end
	end
	assert(pairs_count == 3, "pairs() should iterate over 3 items")
	-- Test __ipairs metamethod (ordered iteration, skips holes)
	local ipairs_count = 0
	local previous_index
	for index, value in slotmap:__ipairs() do
		ipairs_count = ipairs_count + 1
		assert(previous_index == nil or index > previous_index, "__ipairs() should return indices in ascending order")
		previous_index = index
	end
	assert(ipairs_count == 3, "__ipairs() should iterate over 3 items")
	-- Test iterator
	local iterator_count = 0
	for value in slotmap:iterator() do
		iterator_count = iterator_count + 1
	end
	assert(iterator_count == 3, "iterator() should iterate over 3 items")
	-- Test get non-existent index
	assert(slotmap:get(999) == nil, "get() should return nil for non-existent index")
	-- Test remove non-existent index
	slotmap:remove(999)
	assert(len(slotmap) == 3, "Removing non-existent index should not affect count")
	-- Test clear operation
	slotmap:clear()
	assert(len(slotmap) == 0, "SlotMap should be empty after clear")
	print("All tests passed")
end
