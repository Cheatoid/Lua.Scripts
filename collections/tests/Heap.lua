-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for Heap.lua.
-- Run from this directory:
--   lua Heap.lua
--   luajit Heap.lua

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
local lib = require "Heap"
-- Bridging: file-locals used by tests mapped to module exports.
local Heap = lib
-- TODO(manual): the following were file-locals with no direct export;
-- verify and export or inline as needed: smallest

if true then
	-- Test the Heap class
	do
		-- Create a new heap
		local heap = Heap.new()
		-- Test that the heap is initially empty
		assert(heap:isEmpty(), "Heap should be empty after creation")
		-- Test that the count of items in the heap is initially 0
		assert(heap:count() == 0, "Heap count should be 0 after creation")
		-- Add a value to the heap
		heap:push(5)
		-- Test that the heap is not empty after adding a value
		assert(not heap:isEmpty(), "Heap should not be empty after adding a value")
		-- Test that the count of items in the heap is 1 after adding a value
		assert(heap:count() == 1, "Heap count should be 1 after adding a value")
		-- Test that the smallest value in the heap is the value that was added
		assert(heap:peek() == 5, "Heap peek should return the value that was added")
		-- Remove the value from the heap
		local value = heap:pop()
		-- Test that the value removed from the heap is the value that was added
		assert(value == 5, "Heap pop should return the value that was added")
		-- Test that the heap is empty after removing the value
		assert(heap:isEmpty(), "Heap should be empty after removing the value")
		-- Test that the count of items in the heap is 0 after removing the value
		assert(heap:count() == 0, "Heap count should be 0 after removing the value")
		-- Test that adding a nil value to the heap throws an error
		local status, err = pcall(function() heap:push(nil) end)
		assert(not status and string.find(err, "cannot add a nil value to the heap"),
			"Adding a nil value to the heap should throw an error")
		-- Test clear operation
		heap:push(1)
		heap:push(2)
		heap:clear()
		assert(heap:isEmpty(), "Heap should be empty after clear")
		-- Test with different types of values
		heap:push("3")
		heap:push("1")
		heap:push("2")
		assert(heap:count() == 3, "Heap should have 3 items after adding different types of values")
		assert(heap:pop() == "1", "Heap pop should return the string 1")
		assert(heap:pop() == "2", "Heap pop should return the string 2")
		assert(heap:pop() == "3", "Heap pop should return the string 3")
		-- Test with multiple values
		for i = 1, 10 do
			heap:push(i)
		end
		assert(heap:count() == 10, "Heap should have 10 items after adding multiple values")
		for i = 1, 10 do
			assert(heap:pop() == i, "Heap pop should return the correct value")
		end
		assert(heap:isEmpty(), "Heap should be empty after removing all items")
	end
	do
		-- Create a new heap with a custom comparison function
		local heap = Heap.new(function(a, b) return a > b end)
		-- Add multiple values to the heap
		heap:push(5)
		heap:push(3)
		heap:push(4)
		-- Test that the heap is not empty after adding values
		assert(not heap:isEmpty(), "Heap should not be empty after adding values")
		-- Test that the count of items in the heap is 3 after adding values
		assert(heap:count() == 3, "Heap count should be 3 after adding values")
		-- Test that the largest value in the heap is the first value that was added
		assert(heap:peek() == 5, "Heap peek should return the largest value when using a custom comparison function")
		-- Remove the largest value from the heap
		local value = heap:pop()
		-- Test that the value removed from the heap is the first value that was added
		assert(value == 5, "Heap pop should return the largest value when using a custom comparison function")
		-- Test that the heap is not empty after removing a value
		assert(not heap:isEmpty(), "Heap should not be empty after removing a value")
		-- Test that the count of items in the heap is 2 after removing a value
		assert(heap:count() == 2, "Heap count should be 2 after removing a value")
		-- Test that the largest value in the heap is now the second value that was added
		assert(heap:peek() == 4, "Heap peek should return the next largest value after popping the largest value")
		-- Remove all values from the heap
		heap:pop()
		heap:pop()
		-- Test that the heap is empty after removing all values
		assert(heap:isEmpty(), "Heap should be empty after removing all values")
		-- Test that the count of items in the heap is 0 after removing all values
		assert(heap:count() == 0, "Heap count should be 0 after removing all values")
		-- Test that peeking at an empty heap returns nil
		assert(heap:peek() == nil, "Heap peek should return nil when the heap is empty")
		-- Test that popping an empty heap returns nil
		assert(heap:pop() == nil, "Heap pop should return nil when the heap is empty")
	end
	-- Test __ipairs iteration
	do
		local heap = Heap.new()
		heap:push(5)
		heap:push(3)
		heap:push(4)
		local ipairs_count = 0
		for index, value in heap:__ipairs() do
			ipairs_count = ipairs_count + 1
			assert(type(index) == "number", "__ipairs() should return numeric index")
			assert(type(value) == "number", "__ipairs() should return numeric value")
		end
		assert(ipairs_count == 3, "__ipairs() should iterate over all 3 items")
	end
	print("All tests passed")
end
