-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Localized global functions for better performance
local assert = assert
local setmetatable = setmetatable
local string_format = string.format

-- Import Heap
local Heap = require "Heap"

--- Define the PriorityQueue class
---@class PriorityQueue
---@field [1] Heap Internal heap for priority ordering
local PriorityQueue = {}
PriorityQueue.__index = PriorityQueue

--- Max-heap comparison function for priority queue.<br>
--- Higher priority values will be at the top.
---@param a table First priority-item pair `{priority, item}`.
---@param b table Second priority-item pair `{priority, item}`.
---@return boolean result `true` if a should be above b in the heap.
function PriorityQueue.MaxHeapComparer(a, b) return a[1] > b[1] end

--- Min-heap comparison function for priority queue.<br>
--- Lower priority values will be at the top.
---@param a table First priority-item pair `{priority, item}`.
---@param b table Second priority-item pair `{priority, item}`.
---@return boolean result `true` if a should be above b in the heap.
function PriorityQueue.MinHeapComparer(a, b) return a[1] < b[1] end

--- Create a new PriorityQueue instance.<br>
--- A priority queue backed by a heap, items are retrieved by priority.
---@param comp function|nil Comparison function (default: min-heap by priority).
---@return PriorityQueue queue New PriorityQueue instance.
---@usage <br>
--- ```
--- local queue = PriorityQueue.new()
--- queue:push(3, "low")
--- queue:push(1, "high")
--- queue:push(2, "medium")
--- print(queue:pop()) -- "high" (priority 1)
--- ```
function PriorityQueue.new(comp)
	return setmetatable({
		Heap.new(comp or PriorityQueue.MinHeapComparer),
	}, PriorityQueue)
end

PriorityQueue.__call = PriorityQueue.new

--- Get the number of items using `#` operator.<br>
--- Allows using `#queue` instead of `queue:count()`.
---@param self PriorityQueue The priority queue instance.
---@return integer count Number of items in the queue.
---@usage <br>
--- ```
--- local queue = PriorityQueue.new()
--- queue:push(1, "item1")
--- queue:push(2, "item2")
--- print(#queue) -- 2
--- ```
function PriorityQueue.__len(self)
	return #self[1][1]
end

--- Iterate over priority queue items using `pairs()`.<br>
--- Yields index and value (item) for each item (heap array order, 1-based).
---@param self PriorityQueue The priority queue instance.
---@return function iterator Iterator that yields index and value pairs.
---@usage <br>
--- ```
--- local queue = PriorityQueue.new()
--- queue:push(1, "item1")
--- queue:push(2, "item2")
--- for index, value in pairs(queue) do
---   print(index, value)
--- end
--- ```
function PriorityQueue.__pairs(self)
	local index = 0
	local array = self[1][1]
	local length = #array
	return function()
		index = index + 1
		if index <= length then
			return index, array[index][2]
		end
	end
end

--- Iterate over priority queue items using `ipairs()`.<br>
--- Yields index and value (item) for each item (heap array order, 1-based).
---@param self PriorityQueue The priority queue instance.
---@return function iterator Iterator that yields index and value pairs.
function PriorityQueue.__ipairs(self)
	local index = 0
	local array = self[1][1]
	local length = #array
	return function()
		index = index + 1
		if index <= length then
			return index, array[index][2]
		end
	end
end

--- Get string representation of the priority queue.<br>
--- Returns a string showing the count.
---@param self PriorityQueue The priority queue instance.
---@return string string String representation of the priority queue.
---@usage <br>
--- ```
--- local queue = PriorityQueue.new()
--- queue:push(1, "item1")
--- queue:push(2, "item2")
--- print(tostring(queue)) -- "PriorityQueue(count=2)"
--- ```
function PriorityQueue.__tostring(self)
	return string_format("PriorityQueue(count=%d)", #self[1][1])
end

--- Get the number of items in the priority queue.
---@param self PriorityQueue The priority queue instance.
---@return integer count Number of items in the queue.
---@usage <br>
--- ```
--- local queue = PriorityQueue.new()
--- queue:push(1, "item1")
--- queue:push(2, "item2")
--- print(queue:count()) -- 2
--- ```
function PriorityQueue.count(self)
	return #self[1][1]
end

--- Check if the priority queue is empty.
---@param self PriorityQueue The priority queue instance.
---@return boolean empty `true` if the queue is empty, `false` otherwise.
---@usage <br>
--- ```
--- local queue = PriorityQueue.new()
--- print(queue:isEmpty()) -- true
--- queue:push(1, "item1")
--- print(queue:isEmpty()) -- false
--- ```
function PriorityQueue.isEmpty(self)
	return #self[1][1] == 0
end

--- Clear all items from the priority queue.
---@param self PriorityQueue The priority queue instance.
---@usage <br>
--- ```
--- local queue = PriorityQueue.new()
--- queue:push(1, "item1")
--- queue:push(2, "item2")
--- queue:clear()
--- print(queue:isEmpty()) -- true
--- ```
function PriorityQueue.clear(self)
	Heap.clear(self[1])
end

--- Add an item with a given priority to the queue.<br>
--- Lower priority values are retrieved first (by default).
---@param self PriorityQueue The priority queue instance.
---@param priority number Priority value (lower = higher priority by default).
---@param item any The item to add (cannot be `nil`).
---@usage <br>
--- ```
--- local queue = PriorityQueue.new()
--- queue:push(3, "low priority")
--- queue:push(1, "high priority")
--- print(queue:pop()) -- "high priority"
--- ```
function PriorityQueue.push(self, priority, item)
	assert(item ~= nil, "cannot add a nil value to the priority queue")
	Heap.push(self[1], { priority, item })
end

--- Remove and return the item with the highest priority.<br>
--- Returns `nil` if the queue is empty.
---@param self PriorityQueue The priority queue instance.
---@return any item The item with highest priority, or `nil` if empty.
---@usage <br>
--- ```
--- local queue = PriorityQueue.new()
--- queue:push(3, "low")
--- queue:push(1, "high")
--- local item = queue:pop()
--- print(item) -- "high"
--- ```
function PriorityQueue.pop(self)
	if PriorityQueue.isEmpty(self) then
		return
	end
	return Heap.pop(self[1])[2]
end

--- Return the item with the highest priority without removing it.<br>
--- Returns `nil` if the queue is empty.
---@param self PriorityQueue The priority queue instance.
---@return any item The item with highest priority, or `nil` if empty.
---@usage <br>
--- ```
--- local queue = PriorityQueue.new()
--- queue:push(3, "low")
--- queue:push(1, "high")
--- print(queue:peek()) -- "high"
--- print(queue:count()) -- 2 (still has both items)
--- ```
function PriorityQueue.peek(self)
	if PriorityQueue.isEmpty(self) then
		return
	end
	return self[1][1][1][2]
end

--- Return an iterator over the priority queue items.<br>
--- Yields each item (not the priority-item pair) in heap array order.
---@param self PriorityQueue The priority queue instance.
---@return function iterator Iterator that yields each item.
---@usage <br>
--- ```
--- local queue = PriorityQueue.new()
--- queue:push(1, "a")
--- queue:push(2, "b")
--- queue:push(3, "c")
--- for item in queue:iterator() do
---   print(item)
--- end
--- ```
function PriorityQueue.iterator(self)
	local index, length = 0, PriorityQueue.count(self)
	return function()
		index = index + 1
		if index <= length then
			return self[1][1][index][2]
		end
	end
end

--[[ Quick tests
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
	-- Test the PriorityQueue class
	do
		-- Create a new priority queue
		local queue = PriorityQueue.new()
		-- Test that the queue is initially empty
		assert(queue:isEmpty(), "Queue should be empty after creation")
		-- Test that the count of items in the queue is initially 0
		assert(queue:count() == 0, "Queue count should be 0 after creation")
		-- Add an item to the queue
		queue:push(1, "item1")
		-- Test that the queue is not empty after adding an item
		assert(not queue:isEmpty(), "Queue should not be empty after adding an item")
		-- Test that the count of items in the queue is 1 after adding an item
		assert(queue:count() == 1, "Queue count should be 1 after adding an item")
		-- Test that the item with the highest priority in the queue is the item that was added
		assert(queue:peek() == "item1", "Queue peek should return the item that was added")
		-- Remove the item from the queue
		local item = queue:pop()
		-- Test that the item removed from the queue is the item that was added
		assert(item == "item1", "Queue pop should return the item that was added")
		-- Test that the queue is empty after removing the item
		assert(queue:isEmpty(), "Queue should be empty after removing the item")
		-- Test that the count of items in the queue is 0 after removing the item
		assert(queue:count() == 0, "Queue count should be 0 after removing the item")
		-- Test that adding a nil item to the queue throws an error
		local status, err = pcall(function() queue:push(1, nil) end)
		assert(not status and string.find(err, "cannot add a nil value to the priority queue"),
			"Adding a nil item to the queue should throw an error")
		-- Test that adding items with different priorities returns the item with the smallest priority
		queue:push(1, "item1")
		queue:push(2, "item2")
		assert(queue:peek() == "item1", "Queue peek should return the item with the smallest priority")
		-- Test clear operation
		queue:push(1, "item1")
		queue:push(2, "item2")
		queue:clear()
		assert(queue:isEmpty() and queue:count() == 0, "Queue should be empty after clear")
		-- Test with different types of values
		local t = { 1, 2, 3 }
		local f = function() return 4 end
		queue:push(1, "test")
		queue:push(2, t)
		queue:push(3, f)
		assert(queue:count() == 3, "Queue should have 3 items after adding different types of values")
		assert(queue:pop() == "test", "Queue pop should return the string")
		assert(queue:pop() == t, "Queue pop should return the table")
		assert(queue:pop() == f, "Queue pop should return the function")
		-- Test with multiple values
		for i = 1, 10 do
			queue:push(i, "item" .. i)
		end
		assert(queue:count() == 10, "Queue should have 10 items after adding multiple values")
		for i = 1, 10 do
			assert(queue:pop() == "item" .. i, "Queue pop should return the correct value")
		end
		assert(queue:isEmpty(), "Queue should be empty after removing all items")
	end
	do
		-- Create a new priority queue with a custom comparison function
		local queue = PriorityQueue.new(function(a, b) return a[1] > b[1] end)
		-- Add multiple items with different priorities to the queue
		queue:push(1, "item1")
		queue:push(3, "item3")
		queue:push(2, "item2")
		-- Test that the queue is not empty after adding items
		assert(not queue:isEmpty(), "Queue should not be empty after adding items")
		-- Test that the count of items in the queue is 3 after adding items
		assert(queue:count() == 3, "Queue count should be 3 after adding items")
		-- Test that the item with the highest priority in the queue is the last item that was added
		assert(queue:peek() == "item3", "Queue peek should return the item with the highest priority")
		-- Remove the item with the highest priority from the queue
		local item = queue:pop()
		-- Test that the item removed from the queue is the last item that was added
		assert(item == "item3", "Queue pop should return the item with the highest priority")
		-- Test that the queue is not empty after removing an item
		assert(not queue:isEmpty(), "Queue should not be empty after removing an item")
		-- Test that the count of items in the queue is 2 after removing an item
		assert(queue:count() == 2, "Queue count should be 2 after removing an item")
		-- Test that the item with the highest priority in the queue is now the second item that was added
		assert(queue:peek() == "item2",
			"Queue peek should return the next highest priority item after popping the highest priority item")
		-- Remove all items from the queue
		queue:pop()
		queue:pop()
		-- Test that the queue is empty after removing all items
		assert(queue:isEmpty(), "Queue should be empty after removing all items")
		-- Test that the count of items in the queue is 0 after removing all items
		assert(queue:count() == 0, "Queue count should be 0 after removing all items")
		-- Test that peeking at an empty queue returns nil
		assert(queue:peek() == nil, "Queue peek should return nil when the queue is empty")
		-- Test that popping an empty queue returns nil
		assert(queue:pop() == nil, "Queue pop should return nil when the queue is empty")
		-- Test clear operation
		queue:push(1, "item1")
		queue:push(2, "item2")
		queue:clear()
		assert(queue:isEmpty() and queue:count() == 0, "Queue should be empty after clear")
		-- Test with different types of values
		local t = { 1, 2, 3 }
		local f = function() return 4 end
		queue:push(1, "test")
		queue:push(2, t)
		queue:push(3, f)
		assert(queue:count() == 3, "Queue should have 3 items after adding different types of values")
		assert(queue:pop() == f, "Queue pop should return the function")
		assert(queue:pop() == t, "Queue pop should return the table")
		assert(queue:pop() == "test", "Queue pop should return the string")
		-- Test with multiple values
		for i = 1, 10 do
			queue:push(i, "item" .. i)
		end
		assert(queue:count() == 10, "Queue should have 10 items after adding multiple values")
		for i = 10, 1, -1 do
			assert(queue:pop() == "item" .. i, "Queue pop should return the correct value")
		end
		assert(queue:isEmpty(), "Queue should be empty after removing all items")
	end
	-- Test __ipairs iteration
	do
		local queue = PriorityQueue.new()
		queue:push(1, "a")
		queue:push(2, "b")
		queue:push(3, "c")
		local ipairs_count = 0
		for index, value in queue:__ipairs() do
			ipairs_count = ipairs_count + 1
			assert(type(index) == "number", "__ipairs() should return numeric index")
		end
		assert(ipairs_count == 3, "__ipairs() should iterate over all 3 items")
	end
	print("All tests passed ✔")
end
--]]

-- Export
return PriorityQueue
