-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Localized global functions for better performance
local assert = assert
local setmetatable = setmetatable
local math_floor = math.floor
local string_format = string.format
local table_insert = table.insert

--- Define the Heap class
---@class Heap
---@field [1] table Array storing the heap items
---@field [2] function Comparison function for heap ordering
local Heap = {}
Heap.__index = Heap

--- Max-heap comparison function.<br>
--- Higher values have higher priority (will be at the top).
---@param a any First value to compare.
---@param b any Second value to compare.
---@return boolean result `true` if a should be above b in the heap.
function Heap.MaxHeapComparer(a, b) return a > b end

--- Min-heap comparison function.<br>
--- Lower values have higher priority (will be at the top).
---@param a any First value to compare.
---@param b any Second value to compare.
---@return boolean result `true` if a should be above b in the heap.
function Heap.MinHeapComparer(a, b) return a < b end

--- Create a new Heap instance.<br>
--- A binary heap data structure with customizable comparison function.
---@param comp function|nil Comparison function (default: min-heap).
---@return Heap heap New Heap instance.
---@usage <br>
--- ```
--- local heap = Heap.new() -- Min-heap by default
--- heap:push(3)
--- heap:push(1)
--- heap:push(2)
--- print(heap:pop()) -- 1 (smallest)
--- ```
function Heap.new(comp)
	return setmetatable({
		{},
		comp or Heap.MinHeapComparer,
	}, Heap)
end

Heap.__call = Heap.new

--- Get the number of items using `#` operator.<br>
--- Allows using `#heap` instead of `heap:count()`.
---@param self Heap The heap instance.
---@return integer count Number of items in the heap.
---@usage <br>
--- ```
--- local heap = Heap.new()
--- heap:push(1)
--- heap:push(2)
--- print(#heap) -- 2
--- ```
function Heap.__len(self)
	return #self[1]
end

--- Iterate over heap items using `pairs()`.<br>
--- Yields index and value for each item (heap array order, 1-based).
---@param self Heap The heap instance.
---@return function iterator Iterator that yields index and value pairs.
---@usage <br>
--- ```
--- local heap = Heap.new()
--- heap:push(1)
--- heap:push(2)
--- for index, value in pairs(heap) do
---   print(index, value)
--- end
--- ```
function Heap.__pairs(self)
	local index = 0
	local length = #self[1]
	return function()
		index = index + 1
		if index <= length then
			return index, self[1][index]
		end
	end
end

--- Iterate over heap items using `ipairs()`.<br>
--- Yields index and value for each item (heap array order, 1-based).
---@param self Heap The heap instance.
---@return function iterator Iterator that yields index and value pairs.
function Heap.__ipairs(self)
	local index = 0
	local length = #self[1]
	return function()
		index = index + 1
		if index <= length then
			return index, self[1][index]
		end
	end
end

--- Get string representation of the heap.<br>
--- Returns a string showing the count.
---@param self Heap The heap instance.
---@return string string String representation of the heap.
---@usage <br>
--- ```
--- local heap = Heap.new()
--- heap:push(1)
--- heap:push(2)
--- print(tostring(heap)) -- "Heap(count=2)"
--- ```
function Heap.__tostring(self)
	return string_format("Heap(count=%d)", #self[1])
end

--- Get the number of items in the heap.
---@param self Heap The heap instance.
---@return integer count Number of items in the heap.
---@usage <br>
--- ```
--- local heap = Heap.new()
--- heap:push(1)
--- heap:push(2)
--- print(heap:count()) -- 2
--- ```
function Heap.count(self)
	return #self[1]
end

--- Check if the heap is empty.
---@param self Heap The heap instance.
---@return boolean empty `true` if the heap is empty, `false` otherwise.
---@usage <br>
--- ```
--- local heap = Heap.new()
--- print(heap:isEmpty()) -- true
--- heap:push(1)
--- print(heap:isEmpty()) -- false
--- ```
function Heap.isEmpty(self)
	return #self[1] == 0
end

--- Clear all items from the heap.
---@param self Heap The heap instance.
---@usage <br>
--- ```
--- local heap = Heap.new()
--- heap:push(1)
--- heap:push(2)
--- heap:clear()
--- print(heap:isEmpty()) -- true
--- ```
function Heap.clear(self)
	self[1] = {}
end

--- Add a value to the heap.<br>
--- The value will be sifted up to maintain heap property.
---@param self Heap The heap instance.
---@param value any The value to add (cannot be `nil`).
---@usage <br>
--- ```
--- local heap = Heap.new()
--- heap:push(3)
--- heap:push(1)
--- heap:push(2)
--- print(heap:peek()) -- 1 (smallest at top)
--- ```
function Heap.push(self, value)
	assert(value ~= nil, "cannot add a nil value to the heap")
	table_insert(self[1], value)
	Heap.up(self, #self[1])
end

--- Remove and return the top value from the heap.<br>
--- Returns `nil` if the heap is empty.
---@param self Heap The heap instance.
---@return any value The removed value, or `nil` if empty.
---@usage <br>
--- ```
--- local heap = Heap.new()
--- heap:push(3)
--- heap:push(1)
--- heap:push(2)
--- local value = heap:pop()
--- print(value) -- 1 (smallest)
--- ```
function Heap.pop(self)
	local length = #self[1]
	if length == 0 then
		return
	end
	local value = self[1][1]
	self[1][1] = self[1][length]
	self[1][length] = nil
	Heap.down(self, 1)
	return value
end

--- Return the top value from the heap without removing it.<br>
--- Returns `nil` if the heap is empty.
---@param self Heap The heap instance.
---@return any value The top value, or `nil` if empty.
---@usage <br>
--- ```
--- local heap = Heap.new()
--- heap:push(3)
--- heap:push(1)
--- print(heap:peek()) -- 1
--- print(heap:count()) -- 2 (still has both items)
--- ```
function Heap.peek(self)
	if Heap.isEmpty(self) then
		return
	end
	return self[1][1]
end

--- Return an iterator over the heap items.<br>
--- Yields each value in heap array order (not priority order).
---@param self Heap The heap instance.
---@return function iterator Iterator that yields each value.
---@usage <br>
--- ```
--- local heap = Heap.new()
--- heap:push(1)
--- heap:push(2)
--- heap:push(3)
--- for value in heap:iterator() do
---   print(value)
--- end
--- ```
function Heap.iterator(self)
	local index, length = 0, #self[1]
	return function()
		index = index + 1
		if index <= length then
			return self[1][index]
		end
	end
end

--- Sift up a value at a given index to maintain heap property.<br>
--- Internal method used to restore heap invariant after insertion.
---@param self Heap The heap instance.
---@param index integer The index to sift up.
function Heap.up(self, index)
	-- Calculate the index of the parent
	local parent = math_floor(index * 0.5)
	-- If the value is smaller than its parent, swap them and continue sifting up
	if parent >= 1 and self[2](self[1][index], self[1][parent]) then
		self[1][index], self[1][parent] = self[1][parent], self[1][index]
		Heap.up(self, parent)
	end
end

--- Sift down a value at a given index to maintain heap property.<br>
--- Internal method used to restore heap invariant after removal.
---@param self Heap The heap instance.
---@param index integer The index to sift down.
function Heap.down(self, index)
	-- Assume the value is the smallest
	local smallest = index
	-- Calculate the indices of the left and right children
	local left = 2 * index
	local right = left + 1
	-- Cache the length of the array
	local length = #self[1]
	-- If the left child is smaller, note it
	if left <= length and self[2](self[1][left], self[1][smallest]) then
		smallest = left
	end
	-- If the right child is even smaller, note it
	if right <= length and self[2](self[1][right], self[1][smallest]) then
		smallest = right
	end
	-- If the value is not the smallest, swap it with the smallest child and continue sifting down
	if smallest ~= index then
		self[1][index], self[1][smallest] = self[1][smallest], self[1][index]
		Heap.down(self, smallest)
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
	print("All tests passed ✔")
end
--]]

-- Export
return Heap
