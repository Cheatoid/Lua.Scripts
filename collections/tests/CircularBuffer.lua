-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for CircularBuffer.lua.
-- Run from this directory:
--   lua CircularBuffer.lua
--   luajit CircularBuffer.lua

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
local lib = require "CircularBuffer"
local CircularBuffer = lib

if true then
	-- Create a new CircularBuffer with size 3
	local buffer = CircularBuffer.new(3)
	-- Test that the buffer is initially empty
	assert(buffer:count() == 0, "Buffer should be empty initially")
	-- Test insert operations
	buffer:insert(1)
	assert(buffer:count() == 1, "Buffer should have 1 item after first insert")
	buffer:insert(2)
	assert(buffer:count() == 2, "Buffer should have 2 items after second insert")
	buffer:insert(3)
	assert(buffer:count() == 3, "Buffer should have 3 items after third insert")
	-- Test get operation
	local items, count = buffer:get()
	assert(count == 3, "Get should return count of 3")
	assert(items[1] == 3, "First item should be 3 (most recent)")
	assert(items[2] == 2, "Second item should be 2")
	assert(items[3] == 1, "Third item should be 1 (oldest)")
	-- Test overwrite behavior (buffer is full)
	buffer:insert(4)
	assert(buffer:count() == 3, "Buffer should still have 3 items after overwrite")
	local items, count = buffer:get()
	assert(count == 3, "Get should return count of 3")
	assert(items[1] == 4, "First item should be 4 (newest)")
	assert(items[2] == 3, "Second item should be 3")
	assert(items[3] == 2, "Third item should be 2 (oldest, 1 was overwritten)")
	-- Test remove operation (should remove the oldest item -> 2)
	local removed = buffer:remove()
	assert(removed == 2, "Removed item should be 2 (oldest)")
	assert(buffer:count() == 2, "Buffer should have 2 items after remove")
	-- Test remove on empty buffer
	buffer:remove()
	buffer:remove()
	assert(buffer:count() == 0, "Buffer should be empty after removing all items")
	local removed = buffer:remove()
	assert(removed == nil, "Remove on empty buffer should return nil")
	-- Test iterator
	buffer:insert("a")
	buffer:insert("b")
	buffer:insert("c")
	local iterated_items = {}
	for index, value in buffer:iterator() do
		iterated_items[index] = value
	end
	assert(iterated_items[1] == "c", "Iterator should return 'c' first")
	assert(iterated_items[2] == "b", "Iterator should return 'b' second")
	assert(iterated_items[3] == "a", "Iterator should return 'a' third")
	-- Test with different data types
	buffer:insert({ test = "table" })
	buffer:insert(function() return "function" end)
	buffer:insert("string")
	assert(buffer:count() == 3, "Buffer should handle different data types")
	print("All tests passed")
end
