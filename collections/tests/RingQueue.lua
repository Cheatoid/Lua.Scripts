-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for RingQueue.lua.
-- Run from this directory:
--   lua RingQueue.lua
--   luajit RingQueue.lua

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
local lib = require "RingQueue"
local RingQueue = lib

if true then
	-- Create a new RingQueue with size 3
	local queue = RingQueue.new(3)
	-- Test that the queue is initially empty
	assert(queue:count() == 0, "Queue should be empty initially")
	-- Test enqueue operations
	queue:enqueue(1)
	assert(queue:count() == 1, "Queue should have 1 item after first enqueue")
	queue:enqueue(2)
	assert(queue:count() == 2, "Queue should have 2 items after second enqueue")
	queue:enqueue(3)
	assert(queue:count() == 3, "Queue should have 3 items after third enqueue")
	-- Test enqueue when full
	local success = queue:enqueue(4)
	assert(success == false, "Enqueue on full queue should return false")
	assert(queue:count() == 3, "Queue should still have 3 items after failed enqueue")
	-- Test get operation (oldest first)
	local items, count = queue:get()
	assert(count == 3, "Get should return count of 3")
	assert(items[1] == 1, "First item should be 1 (oldest)")
	assert(items[2] == 2, "Second item should be 2")
	assert(items[3] == 3, "Third item should be 3 (newest)")
	-- Test dequeue operation
	local removed = queue:dequeue()
	assert(removed == 1, "Dequeued item should be 1 (oldest)")
	assert(queue:count() == 2, "Queue should have 2 items after dequeue")
	-- Test peek operation
	local peeked = queue:peek()
	assert(peeked == 2, "Peeked item should be 2 (new oldest)")
	-- Test dequeue on empty queue
	queue:dequeue()
	queue:dequeue()
	assert(queue:count() == 0, "Queue should be empty after removing all items")
	removed = queue:dequeue()
	assert(removed == nil, "Dequeue on empty queue should return nil")
	assert(queue:peek() == nil, "Peek on empty queue should return nil")
	-- Test circular behavior
	queue:enqueue("a")
	queue:enqueue("b")
	queue:enqueue("c")
	queue:dequeue() -- removes "a"
	queue:enqueue("d") -- wraps around
	assert(queue:count() == 3, "Queue should have 3 items after wrap-around")
	items, count = queue:get()
	assert(items[1] == "b", "First item should be 'b'")
	assert(items[2] == "c", "Second item should be 'c'")
	assert(items[3] == "d", "Third item should be 'd'")
	-- Test iterator
	queue:dequeue()
	queue:dequeue()
	queue:dequeue()
	queue:enqueue("x")
	queue:enqueue("y")
	local iterated_items = {}
	for index, value in queue:iterator() do
		iterated_items[index] = value
	end
	assert(iterated_items[1] == "x", "Iterator should return 'x' first")
	assert(iterated_items[2] == "y", "Iterator should return 'y' second")
	-- Test with different data types
	queue:dequeue()
	queue:dequeue()
	queue:enqueue({ test = "table" })
	queue:enqueue(function() return "function" end)
	queue:enqueue("string")
	assert(queue:count() == 3, "Queue should handle different data types")
	print("All tests passed")
end
