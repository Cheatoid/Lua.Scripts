-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Localized global functions for better performance
local assert = assert
local setmetatable = setmetatable
local table_insert = table.insert
local table_remove = table.remove

--- Define the Queue class
---@class Queue
local Queue = {}
Queue.__index = Queue
-- Constructor for Queue
function Queue.new()
	return setmetatable({ {} }, Queue)
end

Queue.__call = Queue.new

-- Method to get the amount of items in the queue
function Queue:count()
	-- Return the length of the container
	return #self[1]
end

-- Method to check if the queue is empty
function Queue:isEmpty()
	-- Check if the container is empty
	return #self[1] == 0
end

-- Method to clear the queue entirely
function Queue:clear()
	-- local t = self[1]
	-- for k in next, t do t[k] = nil end
	self[1] = {}
end

-- Method to add a value to the queue
function Queue:enqueue(value)
	-- Assert that the value is not nil
	assert(value ~= nil, "cannot add a nil value to the queue")
	-- Insert the value into the queue container
	table_insert(self[1], value)
end

-- Method to remove and return the first value from the queue
function Queue:dequeue()
	-- Check if the queue is empty
	if #self[1] == 0 then
		-- If the queue is empty, return
		return
	end
	-- Otherwise, remove and return the first value from the queue
	return table_remove(self[1], 1)
end

-- Method to return the first value from the queue without removing it
function Queue:peek()
	-- If the queue is empty, return
	if #self[1] == 0 then
		return
	end
	-- Otherwise, return the first value from the queue
	return self[1][1]
end

-- Method to return an iterator over the queue
function Queue:iterator()
	local i = 1
	return function()
		if i > #self[1] then
			return
		end
		local value = self[1][i]
		i = i + 1
		return value
	end
end

-- Test the Queue class
if false then
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
	assert(queue:iterator()() == nil, "Iterator of cleared queue should return nil")
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
	print("All tests passed ✔")
end

return Queue
