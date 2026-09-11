-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for Queue.lua.
-- Run from this directory:
--   lua Queue.lua
--   luajit Queue.lua

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
local lib = require "Queue"
local Queue = lib

if true then
	-- Create a new Queue
	local queue = Queue.new()
	-- Test that the queue is initially empty
	assert(queue:isEmpty(), "Queue should be empty initially")
	-- Test enqueue operation
	queue:enqueue(1)
	assert(queue:count() == 1, "Queue should have 1 item after enqueue")
	-- Test peek operation
	assert(queue:peek() == 1, "Peek should return the first item in the queue")
	-- Test dequeue operation
	local item = queue:dequeue()
	assert(item == 1, "Dequeue should return the first item in the queue")
	assert(queue:isEmpty(), "Queue should be empty after dequeue")
	-- Test iterator operation
	queue:enqueue(1)
	queue:enqueue(2)
	queue:enqueue(3)
	local sum = 0
	for value in queue:iterator() do
		sum = sum + value
	end
	assert(sum == 6, "Sum of all items in the queue should be 6")
	-- Dequeue all items from the queue
	queue:dequeue()
	queue:dequeue()
	queue:dequeue()
	-- Test enqueue operation with nil
	local status, err = pcall(function() queue:enqueue(nil) end)
	assert(not status and string.find(err, "cannot add a nil value to the queue"),
		"Enqueue operation should fail when trying to add nil")
	-- Test dequeue operation on empty queue
	local item = queue:dequeue()
	assert(item == nil, "Dequeue operation should return nil when the queue is empty")
	-- Test peek operation on empty queue
	local item = queue:peek()
	assert(item == nil, "Peek operation should return nil when the queue is empty")
	-- Test iterator operation on empty queue
	local count = 0
	for _ in queue:iterator() do
		count = count + 1
	end
	assert(count == 0, "Iterator operation should not return any items when the queue is empty")
	-- Test the clear method
	for i = 1, 10 do
		queue:enqueue(i)
	end
	queue:clear()
	assert(queue:isEmpty(), "Queue should be empty after clear")
	assert(queue:count() == 0, "Queue should have count 0 after clear")
	assert(queue:dequeue() == nil, "Dequeue operation should return nil after clear")
	assert(queue:peek() == nil, "Peek operation should return nil after clear")
	do
		local _f, _s, _i = queue:iterator()
		assert(_f(_s, _i) == nil, "Iterator of cleared queue should return nil")
	end
	-- Test enqueueing and dequeuing multiple items
	for i = 1, 10 do
		queue:enqueue(i)
	end
	for i = 1, 10 do
		assert(queue:dequeue() == i, "Queue should maintain FIFO order of items")
	end
	-- Test clearing the queue and then enqueueing more items
	for i = 1, 10 do
		queue:enqueue(i)
	end
	queue:clear()
	for i = 11, 20 do
		queue:enqueue(i)
	end
	for i = 11, 20 do
		assert(queue:dequeue() == i, "Queue should maintain FIFO order after clear")
	end
	-- Test enqueueing a large number of items
	for i = 1, 10000 do
		queue:enqueue(i)
	end
	assert(queue:count() == 10000, "Queue should handle a large number of items")
	-- Test enqueueing different types of values
	queue:clear()
	local t = { 1, 2, 3 }
	queue:enqueue("test")
	queue:enqueue(t)
	queue:enqueue(true)
	assert(queue:dequeue() == "test", "Queue should handle string values")
	assert(queue:dequeue() == t, "Queue should handle table values")
	assert(queue:dequeue() == true, "Queue should handle boolean values")
	-- Test __ipairs iteration
	queue:clear()
	for i = 1, 5 do
		queue:enqueue(i)
	end
	local ipairs_count = 0
	for index, value in queue:__ipairs() do
		ipairs_count = ipairs_count + 1
		assert(index == value, "__ipairs() should return index and value in queue order")
	end
	assert(ipairs_count == 5, "__ipairs() should iterate over all 5 items")
	print("All tests passed")
end
