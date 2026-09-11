-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for SparseMap.lua.
-- Run from this directory:
--   lua SparseMap.lua
--   luajit SparseMap.lua

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
local lib = require "SparseMap"
-- Bridging: file-locals used by tests mapped to module exports.
local SparseMap = lib
-- TODO(manual): the following were file-locals with no direct export;
-- verify and export or inline as needed: count

if true then
	-- Create a new SparseMap
	local map = SparseMap.new()
	-- Test that the map is initially empty
	assert(map:is_empty(), "SparseMap should be empty initially")
	assert(map:size() == 0, "SparseMap size should be 0 initially")
	-- Test set operation
	map:set("a", 1)
	assert(map:size() == 1, "SparseMap should have 1 item after set")
	assert(map:get("a") == 1, "get should return the correct value")
	assert(map:contains("a"), "contains should return true for existing key")
	assert(not map:contains("b"), "contains should return false for missing key")
	-- Test set returns previous value
	assert(map:set("a", 10) == 1, "set should return previous value")
	assert(map:get("a") == 10, "get should return updated value")
	-- Test add operation
	assert(map:add("b", 2), "add should return true for new key")
	assert(not map:add("a", 99), "add should return false for existing key")
	assert(map:get("a") == 10, "get should still return original value after failed add")
	-- Test get_or
	assert(map:get_or("missing", "default") == "default", "get_or should return default for missing key")
	assert(map:get_or("a", "default") == 10, "get_or should return actual value for existing key")
	-- Test get_index and get_key_at / get_value_at
	local index = map:get_index("a")
	assert(index ~= nil, "get_index should return index for existing key")
	assert(map:get_key_at(index) == "a", "get_key_at should return correct key")
	assert(map:get_value_at(index) == 10, "get_value_at should return correct value")
	-- Test remove
	assert(map:remove("a") == 10, "remove should return the removed value")
	assert(not map:contains("a"), "contains should return false after remove")
	assert(map:size() == 1, "SparseMap size should be 1 after remove")
	assert(map:remove("missing") == nil, "remove should return nil for missing key")
	-- Test remove_at
	map:set("c", 3)
	map:set("d", 4)
	local key, value = map:remove_at(1)
	assert(key == "b", "remove_at should return correct key")
	assert(value == 2, "remove_at should return correct value")
	assert(map:size() == 2, "SparseMap size should be 2 after remove_at")
	-- Test iteration
	local iterated = {}
	for idx, key, value in map:iter() do
		iterated[idx] = { key = key, value = value }
	end
	assert(iterated[1] ~= nil, "iter should yield at least one entry")
	-- Test keys and values iterators
	local keys = {}
	for key in map:keys() do
		table.insert(keys, key)
	end
	assert(#keys == 2, "keys iterator should yield 2 keys")
	local values = {}
	for value in map:values() do
		table.insert(values, value)
	end
	assert(#values == 2, "values iterator should yield 2 values")
	-- Test for_each
	local for_each_count = 0
	map:for_each(function(key, value, dense_index)
		for_each_count = for_each_count + 1
	end)
	assert(for_each_count == 2, "for_each should call function for each entry")
	-- Test min/max
	local min_key, min_value = map:min()
	local max_key, max_value = map:max()
	assert(min_key ~= nil, "min should return a key")
	assert(max_key ~= nil, "max should return a key")
	-- Test clone
	local clone = map:clone()
	assert(clone:size() == map:size(), "clone should have same size")
	assert(clone:get("c") == map:get("c"), "clone should have same values")
	assert(clone ~= map, "clone should be a different object")
	-- Test clear
	map:clear()
	assert(map:is_empty(), "SparseMap should be empty after clear")
	assert(map:size() == 0, "SparseMap size should be 0 after clear")
	-- Test reserve
	map:set("x", 1)
	map:set("y", 2)
	map:reserve(10)
	assert(map:get_capacity() >= 10, "reserve should increase capacity")
	-- Test sort
	map:set("c", 3)
	map:set("a", 1)
	map:set("b", 2)
	map:sort_by_key_ascending()
	local sorted_keys = {}
	for key in map:keys() do
		table.insert(sorted_keys, key)
	end
	assert(sorted_keys[1] == "a", "First key should be 'a' after ascending sort")
	assert(sorted_keys[2] == "b", "Second key should be 'b' after ascending sort")
	assert(sorted_keys[3] == "c", "Third key should be 'c' after ascending sort")
	-- Test remove_if
	map:set("remove_me", 999)
	map:set("keep_me", 1)
	local removed = map:remove_if(function(_, value)
		return value == 999
	end)
	assert(removed == 1, "remove_if should return count of removed entries")
	assert(not map:contains("remove_me"), "remove_if should remove matching entry")
	assert(map:contains("keep_me"), "remove_if should keep non-matching entry")
	-- Test with different types of keys and values
	local typed_map = SparseMap.new()
	local table_key = {}
	typed_map:set(1, "number_key")
	typed_map:set("string_key", true)
	typed_map:set(table_key, "table_value")
	assert(typed_map:size() == 3, "SparseMap should handle different types")
	assert(typed_map:get(1) == "number_key", "SparseMap should handle number keys")
	assert(typed_map:get("string_key") == true, "SparseMap should handle string keys")
	assert(typed_map:get(table_key) == "table_value", "SparseMap should handle table keys")
	-- Test tostring
	local str = tostring(map)
	assert(str:find("SparseMap") ~= nil, "tostring should contain SparseMap")
	print("All tests passed")
end
