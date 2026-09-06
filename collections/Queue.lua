-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Localized global functions for better performance
local assert = assert
local setmetatable = setmetatable
local string_format = string.format
local table_insert = table.insert
local table_remove = table.remove

--- Define the Queue class.<br>
--- A FIFO (First-In-First-Out) queue where items are processed in the order they were added.<br>
--- Perfect for task processing, message passing, or any scenario where order of operations matters.
---@class Queue
---@field [1] table Container table storing the queue items
local Queue = {}
Queue.__index = Queue

--- Create a new Queue instance.<br>
--- A FIFO (First-In-First-Out) queue data structure.
---@return Queue queue New Queue instance.
---@usage <br>
--- ```
--- local queue = Queue.new()
--- queue:enqueue(1)
--- queue:enqueue(2)
--- ```
function Queue.new()
	return setmetatable({ {} }, Queue)
end

Queue.__call = Queue.new

--- Get the number of items using `#` operator.<br>
--- Allows using `#queue` instead of `queue:count()`.
---@param self Queue The queue instance.
---@return integer count Number of items in the queue.
---@usage <br>
--- ```
--- local queue = Queue.new()
--- queue:enqueue(1)
--- queue:enqueue(2)
--- print(#queue) -- 2
--- ```
function Queue.__len(self)
	return #self[1]
end

function Queue._iter_pairs(self, index)
	index = index + 1
	if index <= #self[1] then
		return index, self[1][index]
	end
end

--- Iterate over queue items using `pairs()`.<br>
--- Yields index and value for each item (front to back, 1-based).
---@param self Queue The queue instance.
---@return function iterator Iterator that yields index and value pairs.
---@return table state The queue instance used as iterator state.
---@return integer initial Initial control variable.
---@usage <br>
--- ```
--- local queue = Queue.new()
--- queue:enqueue(1)
--- queue:enqueue(2)
--- for index, value in pairs(queue) do
---   print(index, value)
--- end
--- ```
function Queue.__pairs(self)
	return Queue._iter_pairs, self, 0
end

--- Iterate over queue items using `ipairs()`.<br>
--- Yields index and value for each item (front to back, 1-based).
---@param self Queue The queue instance.
---@return function iterator Iterator that yields index and value pairs.
---@return table state The queue instance used as iterator state.
---@return integer initial Initial control variable.
function Queue.__ipairs(self)
	return Queue._iter_pairs, self, 0
end

--- Get string representation of the queue.<br>
--- Returns a string showing the count.
---@param self Queue The queue instance.
---@return string string String representation of the queue.
---@usage <br>
--- ```
--- local queue = Queue.new()
--- queue:enqueue(1)
--- queue:enqueue(2)
--- print(tostring(queue)) -- "Queue(count=2)"
--- ```
function Queue.__tostring(self)
	return string_format("Queue(count=%d)", #self[1])
end

--- Get the number of items in the queue.
---@param self Queue The queue instance.
---@return integer count Number of items in the queue.
---@usage <br>
--- ```
--- local queue = Queue.new()
--- queue:enqueue(1)
--- queue:enqueue(2)
--- print(queue:count()) -- 2
--- ```
function Queue.count(self)
	return #self[1]
end

--- Check if the queue is empty.
---@param self Queue The queue instance.
---@return boolean empty `true` if the queue is empty, `false` otherwise.
---@usage <br>
--- ```
--- local queue = Queue.new()
--- print(queue:isEmpty()) -- true
--- queue:enqueue(1)
--- print(queue:isEmpty()) -- false
--- ```
function Queue.isEmpty(self)
	return #self[1] == 0
end

--- Clear all items from the queue.
---@param self Queue The queue instance.
---@usage <br>
--- ```
--- local queue = Queue.new()
--- queue:enqueue(1)
--- queue:enqueue(2)
--- queue:clear()
--- print(queue:isEmpty()) -- true
--- ```
function Queue.clear(self)
	self[1] = {}
end

--- Add a value to the back of the queue (enqueue).<br>
--- Items are dequeued in the order they were enqueued (FIFO).
---@param self Queue The queue instance.
---@param value any The value to add (cannot be `nil`).
---@usage <br>
--- ```
--- local queue = Queue.new()
--- queue:enqueue(1)
--- queue:enqueue(2)
--- print(queue:dequeue()) -- 1
--- ```
function Queue.enqueue(self, value)
	assert(value ~= nil, "cannot add a nil value to the queue")
	table_insert(self[1], value)
end

--- Remove and return the first value from the queue (dequeue).<br>
--- Returns `nil` if the queue is empty.
---@param self Queue The queue instance.
---@return any value The dequeued value, or `nil` if empty.
---@usage <br>
--- ```
--- local queue = Queue.new()
--- queue:enqueue(1)
--- queue:enqueue(2)
--- local value = queue:dequeue()
--- print(value) -- 1
--- ```
function Queue.dequeue(self)
	if #self[1] == 0 then
		return
	end
	return table_remove(self[1], 1)
end

--- Return the first value from the queue without removing it (peek).<br>
--- Returns `nil` if the queue is empty.
---@param self Queue The queue instance.
---@return any value The first value, or `nil` if empty.
---@usage <br>
--- ```
--- local queue = Queue.new()
--- queue:enqueue(1)
--- queue:enqueue(2)
--- print(queue:peek()) -- 1
--- print(queue:count()) -- 2 (still has both items)
--- ```
function Queue.peek(self)
	if #self[1] == 0 then
		return
	end
	return self[1][1]
end

function Queue._iter_values(self, index)
	index = index + 1
	if index <= #self[1] then
		return self[1][index]
	end
end

--- Return an iterator over the queue from front to back.<br>
--- Yields each value in the queue in FIFO order.
---@param self Queue The queue instance.
---@return function iterator Iterator that yields each value.
---@return table state The queue instance used as iterator state.
---@return integer initial Initial control variable.
---@usage <br>
--- ```
--- local queue = Queue.new()
--- queue:enqueue(1)
--- queue:enqueue(2)
--- queue:enqueue(3)
--- for value in queue:iterator() do
---   print(value)
--- end
--- -- Outputs: 1, 2, 3
--- ```
function Queue.iterator(self)
	return Queue._iter_values, self, 0
end

--[[ Test the Queue class
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
--]]

-- Export
return Queue
