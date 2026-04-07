-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Localized global functions for better performance
local assert = assert
local setmetatable = setmetatable
local table_insert = table.insert
local math_floor = math.floor

--- Define the Heap class
---@class Heap
local Heap = {}
Heap.__index = Heap
-- The heap is a max-heap and the highest value will be at the top of the heap
function Heap.MaxHeapComparer(a, b) return a > b end

-- The heap is a min-heap and the smallest value will be at the top of the heap
function Heap.MinHeapComparer(a, b) return a < b end

-- Constructor for Heap
function Heap.new(comp)
	-- Initialize a new heap with an empty array and a comparison function
	-- The comparison function defaults to the less-than operator
	return setmetatable({
		array = {},
		comp = comp or Heap.MinHeapComparer
	}, Heap)
end

Heap.__call = Heap.new

-- Method to get the amount of items in the heap
function Heap:count()
	-- Return the length of the array
	return #self.array
end

-- Method to check if the heap is empty
function Heap:isEmpty()
	-- Check if the array is empty
	return #self.array == 0
end

-- Method to clear the heap entirely
function Heap:clear()
	-- local t = self.array
	-- for k in next, t do t[k] = nil end
	self.array = {}
end

-- Method to add a value to the heap
function Heap:push(value)
	-- Assert that the value is not nil
	assert(value ~= nil, "cannot add a nil value to the heap")
	-- Add the value to the end of the array
	table_insert(self.array, value)
	-- Sift up the new value to its proper position
	self:up(#self.array)
	-- TODO/CONS: Should return self for call-chaining?
end

-- Method to remove and return the smallest value from the heap
function Heap:pop()
	-- Cache the length of the array
	local length = #self.array
	-- Check if the heap is empty
	if length == 0 then
		-- If the heap is empty, return
		return
	end
	-- Save the smallest value
	local value = self.array[1]
	-- Move the last value in the array to the top of the heap
	self.array[1] = self.array[length]
	-- Remove the last value from the array
	self.array[length] = nil
	-- Sift down the new root value to its proper position
	self:down(1)
	-- Return the smallest value
	return value
end

-- Method to return the smallest value from the heap without removing it
function Heap:peek()
	-- Check if the heap is empty
	if self:isEmpty() then
		-- If the heap is empty, return
		return
	end
	-- Otherwise, return the smallest value from the heap
	return self.array[1]
end

-- Method to return an iterator over the heap
function Heap:iterator()
	local index, length = 0, #self.array
	return function()
		index = index + 1
		if index <= length then
			return self.array[index]
		end
	end
end

-- Method to sift up a value at a given index
function Heap:up(index)
	-- Calculate the index of the parent
	local parent = math_floor(index * 0.5)
	-- If the value is smaller than its parent, swap them and continue sifting up
	if parent >= 1 and self.comp(self.array[index], self.array[parent]) then
		self.array[index], self.array[parent] = self.array[parent], self.array[index]
		self:up(parent)
	end
end

-- Method to sift down a value at a given index
function Heap:down(index)
	-- Assume the value is the smallest
	local smallest = index
	-- Calculate the indices of the left and right children
	local left = 2 * index
	local right = left + 1
	-- Cache the length of the array
	local length = #self.array
	-- If the left child is smaller, note it
	if left <= length and self.comp(self.array[left], self.array[smallest]) then
		smallest = left
	end
	-- If the right child is even smaller, note it
	if right <= length and self.comp(self.array[right], self.array[smallest]) then
		smallest = right
	end
	-- If the value is not the smallest, swap it with the smallest child and continue sifting down
	if smallest ~= index then
		self.array[index], self.array[smallest] = self.array[smallest], self.array[index]
		self:down(smallest)
	end
end

--- Define the PriorityQueue class
---@class PriorityQueue
local PriorityQueue = {}
PriorityQueue.__index = PriorityQueue
-- The heap is a max-heap and the highest priority value will be at the top of the heap
function PriorityQueue.MaxHeapComparer(a, b) return a[1] > b[1] end

-- The heap is a min-heap and the smallest priority value will be at the top of the heap
function PriorityQueue.MinHeapComparer(a, b) return a[1] < b[1] end

-- Constructor for PriorityQueue
function PriorityQueue.new(comp)
	-- Initialize a new priority queue with an empty heap
	-- Provide a custom comparison function that compares the 'priority' field of the entries
	return setmetatable({
		heap = Heap.new(comp or PriorityQueue.MinHeapComparer)
	}, PriorityQueue)
end

PriorityQueue.__call = PriorityQueue.new

-- Method to get the amount of items in the priority queue
function PriorityQueue:count()
	-- Return the length of the heap
	-- return self.heap:count()
	-- Inline to avoid a function call overhead
	return #self.heap.array
end

-- Method to check if the priority queue is empty
function PriorityQueue:isEmpty()
	-- Check if the heap is empty
	-- return self.heap:isEmpty()
	-- Inline to avoid a function call overhead
	return #self.heap.array == 0
end

-- Method to clear the priority queue entirely
function PriorityQueue:clear()
	self.heap:clear()
end

-- Method to add an item with a given priority to the queue
function PriorityQueue:push(priority, item)
	-- Assert that the item is not nil
	assert(item ~= nil, "cannot add a nil value to the priority queue")
	-- Add the item to the heap with its priority
	-- Use a table with numeric indices instead of named keys for performance reasons
	self.heap:push({ priority, item })
	-- TODO/CONS: Should return self for call-chaining?
end

-- Method to remove and return the item with the highest priority from the queue
function PriorityQueue:pop()
	-- Check if the heap is empty
	if self:isEmpty() then
		-- If the heap is empty, return
		return
	end
	-- Otherwise, remove and return the item with the highest priority from the heap
	-- Access the item using its numeric index
	-- TODO/CONS: Should also return priority too?
	return self.heap:pop()[2]
end

-- Method to return the item with the highest priority without removing it
function PriorityQueue:peek()
	-- Check if the heap is empty
	if self:isEmpty() then
		-- If the heap is empty, return
		return
	end
	-- Otherwise, return the item with the highest priority from the heap
	-- Access the item using its numeric index
	-- TODO/CONS: Should also return priority too?
	return self.heap.array[1][2]
end

-- Method to return an iterator over the priority queue
function PriorityQueue:iterator()
	local index, length = 0, self:count()
	return function()
		index = index + 1
		if index <= length then
			return self.heap.array[index][2] -- Return the item, not the priority-item pair
		end
	end
end

--if true then
--	-- Test the Heap class
--	do
--		-- Create a new heap
--		local heap = Heap.new()
--		-- Test that the heap is initially empty
--		assert(heap:isEmpty(), "Heap should be empty after creation")
--		-- Test that the count of items in the heap is initially 0
--		assert(heap:count() == 0, "Heap count should be 0 after creation")
--		-- Add a value to the heap
--		heap:push(5)
--		-- Test that the heap is not empty after adding a value
--		assert(not heap:isEmpty(), "Heap should not be empty after adding a value")
--		-- Test that the count of items in the heap is 1 after adding a value
--		assert(heap:count() == 1, "Heap count should be 1 after adding a value")
--		-- Test that the smallest value in the heap is the value that was added
--		assert(heap:peek() == 5, "Heap peek should return the value that was added")
--		-- Remove the value from the heap
--		local value = heap:pop()
--		-- Test that the value removed from the heap is the value that was added
--		assert(value == 5, "Heap pop should return the value that was added")
--		-- Test that the heap is empty after removing the value
--		assert(heap:isEmpty(), "Heap should be empty after removing the value")
--		-- Test that the count of items in the heap is 0 after removing the value
--		assert(heap:count() == 0, "Heap count should be 0 after removing the value")
--		-- Test that adding a nil value to the heap throws an error
--		local status, err = pcall(function() heap:push(nil) end)
--		assert(not status and string.find(err, "cannot add a nil value to the heap"),
--			"Adding a nil value to the heap should throw an error")
--		-- Test clear operation
--		heap:push(1)
--		heap:push(2)
--		heap:clear()
--		assert(heap:isEmpty(), "Heap should be empty after clear")
--		-- Test with different types of values
--		heap:push("3")
--		heap:push("1")
--		heap:push("2")
--		assert(heap:count() == 3, "Heap should have 3 items after adding different types of values")
--		assert(heap:pop() == "1", "Heap pop should return the string 1")
--		assert(heap:pop() == "2", "Heap pop should return the string 2")
--		assert(heap:pop() == "3", "Heap pop should return the string 3")
--		-- Test with multiple values
--		for i = 1, 10 do
--			heap:push(i)
--		end
--		assert(heap:count() == 10, "Heap should have 10 items after adding multiple values")
--		for i = 1, 10 do
--			assert(heap:pop() == i, "Heap pop should return the correct value")
--		end
--		assert(heap:isEmpty(), "Heap should be empty after removing all items")
--	end
--	do
--		-- Create a new heap with a custom comparison function
--		local heap = Heap.new(function(a, b) return a > b end)
--		-- Add multiple values to the heap
--		heap:push(5)
--		heap:push(3)
--		heap:push(4)
--		-- Test that the heap is not empty after adding values
--		assert(not heap:isEmpty(), "Heap should not be empty after adding values")
--		-- Test that the count of items in the heap is 3 after adding values
--		assert(heap:count() == 3, "Heap count should be 3 after adding values")
--		-- Test that the largest value in the heap is the first value that was added
--		assert(heap:peek() == 5, "Heap peek should return the largest value when using a custom comparison function")
--		-- Remove the largest value from the heap
--		local value = heap:pop()
--		-- Test that the value removed from the heap is the first value that was added
--		assert(value == 5, "Heap pop should return the largest value when using a custom comparison function")
--		-- Test that the heap is not empty after removing a value
--		assert(not heap:isEmpty(), "Heap should not be empty after removing a value")
--		-- Test that the count of items in the heap is 2 after removing a value
--		assert(heap:count() == 2, "Heap count should be 2 after removing a value")
--		-- Test that the largest value in the heap is now the second value that was added
--		assert(heap:peek() == 4, "Heap peek should return the next largest value after popping the largest value")
--		-- Remove all values from the heap
--		heap:pop()
--		heap:pop()
--		-- Test that the heap is empty after removing all values
--		assert(heap:isEmpty(), "Heap should be empty after removing all values")
--		-- Test that the count of items in the heap is 0 after removing all values
--		assert(heap:count() == 0, "Heap count should be 0 after removing all values")
--		-- Test that peeking at an empty heap returns nil
--		assert(heap:peek() == nil, "Heap peek should return nil when the heap is empty")
--		-- Test that popping an empty heap returns nil
--		assert(heap:pop() == nil, "Heap pop should return nil when the heap is empty")
--	end
--	-- Test the PriorityQueue class
--	do
--		-- Create a new priority queue
--		local queue = PriorityQueue.new()
--		-- Test that the queue is initially empty
--		assert(queue:isEmpty(), "Queue should be empty after creation")
--		-- Test that the count of items in the queue is initially 0
--		assert(queue:count() == 0, "Queue count should be 0 after creation")
--		-- Add an item to the queue
--		queue:push(1, "item1")
--		-- Test that the queue is not empty after adding an item
--		assert(not queue:isEmpty(), "Queue should not be empty after adding an item")
--		-- Test that the count of items in the queue is 1 after adding an item
--		assert(queue:count() == 1, "Queue count should be 1 after adding an item")
--		-- Test that the item with the highest priority in the queue is the item that was added
--		assert(queue:peek() == "item1", "Queue peek should return the item that was added")
--		-- Remove the item from the queue
--		local item = queue:pop()
--		-- Test that the item removed from the queue is the item that was added
--		assert(item == "item1", "Queue pop should return the item that was added")
--		-- Test that the queue is empty after removing the item
--		assert(queue:isEmpty(), "Queue should be empty after removing the item")
--		-- Test that the count of items in the queue is 0 after removing the item
--		assert(queue:count() == 0, "Queue count should be 0 after removing the item")
--		-- Test that adding a nil item to the queue throws an error
--		local status, err = pcall(function() queue:push(1, nil) end)
--		assert(not status and string.find(err, "cannot add a nil value to the priority queue"),
--			"Adding a nil item to the queue should throw an error")
--		-- Test that adding items with different priorities returns the item with the smallest priority
--		queue:push(1, "item1")
--		queue:push(2, "item2")
--		assert(queue:peek() == "item1", "Queue peek should return the item with the smallest priority")
--		-- Test clear operation
--		queue:push(1, "item1")
--		queue:push(2, "item2")
--		queue:clear()
--		assert(queue:isEmpty() and queue:count() == 0, "Queue should be empty after clear")
--		-- Test with different types of values
--		local t = { 1, 2, 3 }
--		local f = function() return 4 end
--		queue:push(1, "test")
--		queue:push(2, t)
--		queue:push(3, f)
--		assert(queue:count() == 3, "Queue should have 3 items after adding different types of values")
--		assert(queue:pop() == "test", "Queue pop should return the string")
--		assert(queue:pop() == t, "Queue pop should return the table")
--		assert(queue:pop() == f, "Queue pop should return the function")
--		-- Test with multiple values
--		for i = 1, 10 do
--			queue:push(i, "item" .. i)
--		end
--		assert(queue:count() == 10, "Queue should have 10 items after adding multiple values")
--		for i = 1, 10 do
--			assert(queue:pop() == "item" .. i, "Queue pop should return the correct value")
--		end
--		assert(queue:isEmpty(), "Queue should be empty after removing all items")
--	end
--	do
--		-- Create a new priority queue with a custom comparison function
--		local queue = PriorityQueue.new(function(a, b) return a[1] > b[1] end)
--		-- Add multiple items with different priorities to the queue
--		queue:push(1, "item1")
--		queue:push(3, "item3")
--		queue:push(2, "item2")
--		-- Test that the queue is not empty after adding items
--		assert(not queue:isEmpty(), "Queue should not be empty after adding items")
--		-- Test that the count of items in the queue is 3 after adding items
--		assert(queue:count() == 3, "Queue count should be 3 after adding items")
--		-- Test that the item with the highest priority in the queue is the last item that was added
--		assert(queue:peek() == "item3", "Queue peek should return the item with the highest priority")
--		-- Remove the item with the highest priority from the queue
--		local item = queue:pop()
--		-- Test that the item removed from the queue is the last item that was added
--		assert(item == "item3", "Queue pop should return the item with the highest priority")
--		-- Test that the queue is not empty after removing an item
--		assert(not queue:isEmpty(), "Queue should not be empty after removing an item")
--		-- Test that the count of items in the queue is 2 after removing an item
--		assert(queue:count() == 2, "Queue count should be 2 after removing an item")
--		-- Test that the item with the highest priority in the queue is now the second item that was added
--		assert(queue:peek() == "item2",
--			"Queue peek should return the next highest priority item after popping the highest priority item")
--		-- Remove all items from the queue
--		queue:pop()
--		queue:pop()
--		-- Test that the queue is empty after removing all items
--		assert(queue:isEmpty(), "Queue should be empty after removing all items")
--		-- Test that the count of items in the queue is 0 after removing all items
--		assert(queue:count() == 0, "Queue count should be 0 after removing all items")
--		-- Test that peeking at an empty queue returns nil
--		assert(queue:peek() == nil, "Queue peek should return nil when the queue is empty")
--		-- Test that popping an empty queue returns nil
--		assert(queue:pop() == nil, "Queue pop should return nil when the queue is empty")
--		-- Test clear operation
--		queue:push(1, "item1")
--		queue:push(2, "item2")
--		queue:clear()
--		assert(queue:isEmpty() and queue:count() == 0, "Queue should be empty after clear")
--		-- Test with different types of values
--		local t = { 1, 2, 3 }
--		local f = function() return 4 end
--		queue:push(1, "test")
--		queue:push(2, t)
--		queue:push(3, f)
--		assert(queue:count() == 3, "Queue should have 3 items after adding different types of values")
--		assert(queue:pop() == f, "Queue pop should return the function")
--		assert(queue:pop() == t, "Queue pop should return the table")
--		assert(queue:pop() == "test", "Queue pop should return the string")
--		-- Test with multiple values
--		for i = 1, 10 do
--			queue:push(i, "item" .. i)
--		end
--		assert(queue:count() == 10, "Queue should have 10 items after adding multiple values")
--		for i = 10, 1, -1 do
--			assert(queue:pop() == "item" .. i, "Queue pop should return the correct value")
--		end
--		assert(queue:isEmpty(), "Queue should be empty after removing all items")
--	end
--
--	print("All tests passed ✔")
--end

return PriorityQueue
