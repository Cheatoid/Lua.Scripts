-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for Set.lua.
-- Run from this directory:
--   lua Set.lua
--   luajit Set.lua

-- Bootstrap: make requires work from tests/ subdir with plain lua/luajit.
do
  local src = debug.getinfo(1, "S").source
  local dir = src:match("^@(.+/)[^/]+$") or "./"
  local function isfile(p)
    local f = io.open(p, "r")
    if f then f:close() return true end
    return false
  end
  local root
  for _, c in ipairs({ dir, dir .. "../", dir .. "../..//", dir .. "../../..//", "./", "../", "../../" }) do
    if isfile(c .. "standalone/bits.lua") then root = c break end
  end
  root = root or dir .. "../"
  if package then
    package.path = dir .. "../?.lua;" .. dir .. "../?/init.lua;" .. dir .. "?.lua;" .. dir .. "?/init.lua;" .. root .. "?.lua;" .. root .. "?/init.lua;" .. root .. "standalone/?.lua;" .. root .. "math/?.lua;" .. root .. "collections/?.lua;" .. root .. "benchmark/?.lua;" .. root .. "timer/?.lua;" .. root .. "autocompleter/?.lua;" .. root .. "permission/?.lua;" .. root .. "chat_commander/?.lua;" .. root .. "vm/?.lua;" .. root .. "require_finder/?.lua;" .. root .. "inventory/?.lua;" .. package.path
  end
  local searchers = package.searchers or package.loaders
  if searchers then
    table.insert(searchers, 2, function(mod)
      if mod:sub(1, 3) == "../" or mod:sub(1, 2) == "./" then
        local clean = mod:gsub("^%./", ""):gsub("^%.%.%/", ""):gsub("^%.%.%/", "")
        local tries = { dir .. "../" .. clean .. ".lua", dir .. "../" .. clean .. "/init.lua", root .. clean .. ".lua", root .. clean .. "/init.lua" }
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
local lib = require "Set"
local Set = lib

if true then
	-- Create a new Set
	local set = Set.new()
	-- Test that the set is initially empty
	assert(set:isEmpty(), "Set should be empty initially")
	-- Test add operation
	set:add(1)
	assert(set:count() == 1, "Set should have 1 item after add")
	assert(set:contains(1), "Set should contain the added value")
	-- Test adding duplicate
	set:add(1)
	assert(set:count() == 1, "Set should still have 1 item after adding duplicate")
	-- Test add multiple values
	set:add(2)
	set:add(3)
	assert(set:count() == 3, "Set should have 3 items after adding multiple values")
	-- Test contains
	assert(set:contains(2), "Set should contain 2")
	assert(set:contains(3), "Set should contain 3")
	assert(not set:contains(4), "Set should not contain 4")
	-- Test remove operation
	set:remove(2)
	assert(set:count() == 2, "Set should have 2 items after remove")
	assert(not set:contains(2), "Set should not contain removed value")
	-- Test __pairs metamethod (unordered iteration) after remove (hole)
	local pairs_count = 0
	for key, value in pairs(set) do
		pairs_count = pairs_count + 1
	end
	assert(pairs_count == 2, "pairs() should iterate over 2 items after remove")
	-- Test remove non-existent value
	set:remove(99)
	assert(set:count() == 2, "Set should still have 2 items after removing non-existent value")
	-- Test iterator
	local iterated = {}
	for value in set:iterator() do
		iterated[value] = true
	end
	assert(iterated[1] or iterated[3], "Iterator should return values from the set")
	assert(not set:isEmpty(), "Set should not be empty after non-destructive iterator")
	-- Test union
	local set1 = Set.new()
	set1:add(1)
	set1:add(2)
	local set2 = Set.new()
	set2:add(2)
	set2:add(3)
	local union = set1:union(set2)
	assert(union:count() == 3, "Union should have 3 items")
	assert(union:contains(1), "Union should contain 1")
	assert(union:contains(2), "Union should contain 2")
	assert(union:contains(3), "Union should contain 3")
	-- Test intersection
	local intersection = set1:intersection(set2)
	assert(intersection:count() == 1, "Intersection should have 1 item")
	assert(intersection:contains(2), "Intersection should contain 2")
	-- Test difference
	local difference = set1:difference(set2)
	assert(difference:count() == 1, "Difference should have 1 item")
	assert(difference:contains(1), "Difference should contain 1")
	assert(not difference:contains(2), "Difference should not contain 2")
	-- Test subset
	local subset = Set.new()
	subset:add(1)
	assert(subset:isSubset(set1), "Subset should be subset of set1")
	assert(not set1:isSubset(subset), "set1 should not be subset of subset")
	-- Test superset
	assert(set1:isSuperset(subset), "set1 should be superset of subset")
	assert(not subset:isSuperset(set1), "subset should not be superset of set1")
	-- Test equals
	local set3 = Set.new()
	set3:add(1)
	set3:add(2)
	assert(set1:equals(set3), "Identical sets should be equal")
	assert(not set1:equals(set2), "Different sets should not be equal")
	-- Test add with nil
	local status, err = pcall(function() set:add(nil) end)
	assert(not status and string.find(err, "cannot add a nil value to the set"),
		"Adding nil should throw an error")
	-- Test clear
	set:clear()
	assert(set:isEmpty(), "Set should be empty after clear")
	assert(set:count() == 0, "Set should have count 0 after clear")
	-- Test with different types of values
	set:add("string")
	set:add(123)
	local test_table = { key = "value" }
	local test_function = function() return "function" end
	set:add(test_table)
	set:add(test_function)
	assert(set:count() == 4, "Set should handle different types of values")
	assert(set:contains("string"), "Set should contain string")
	assert(set:contains(123), "Set should contain number")
	assert(set:contains(test_table), "Set should contain table")
	assert(set:contains(test_function), "Set should contain function")
	-- Test empty set operations
	local empty = Set.new()
	assert(empty:isEmpty(), "Empty set should be empty")
	assert(empty:union(set):equals(set), "Union with empty should equal original")
	assert(empty:intersection(set):isEmpty(), "Intersection with empty should be empty")
	assert(empty:difference(set):isEmpty(), "Difference of empty should be empty")
	assert(set:difference(empty):equals(set), "Difference with empty should equal original")
	assert(empty:isSubset(set), "Empty set is subset of any set")
	assert(empty:isSuperset(empty), "Empty set is superset of empty set")
	assert(not empty:isSuperset(set), "Empty set is not superset of non-empty set")
	assert(not set:equals(empty), "Non-empty set should not equal empty set")
	print("All tests passed")
end
