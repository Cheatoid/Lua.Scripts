-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Localized global functions for better performance
local assert = assert
local setmetatable = setmetatable
local math_floor = math.floor
local string_format = string.format
local table_insert = table.insert

--- Define the Heap class.<br>
--- A binary heap data structure with customizable comparison function. Supports both min-heap (smallest first) and max-heap (largest first) operations.<br>
--- Perfect for priority queues, finding min/max quickly, or sorting algorithms.
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
---@param comp? function Comparison function (default: min-heap).
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

function Heap._iter_pairs(self, index)
	index = index + 1
	if index <= #self[1] then
		return index, self[1][index]
	end
end

--- Iterate over heap items using `pairs()`.<br>
--- Yields index and value for each item (heap array order, 1-based).
---@param self Heap The heap instance.
---@return function iterator Iterator that yields index and value pairs.
---@return table state The heap instance used as iterator state.
---@return integer initial Initial control variable.
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
	return Heap._iter_pairs, self, 0
end

--- Iterate over heap items using `ipairs()`.<br>
--- Yields index and value for each item (heap array order, 1-based).
---@param self Heap The heap instance.
---@return function iterator Iterator that yields index and value pairs.
---@return table state The heap instance used as iterator state.
---@return integer initial Initial control variable.
function Heap.__ipairs(self)
	return Heap._iter_pairs, self, 0
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

function Heap._iter_values(self, index)
	index = index + 1
	if index <= #self[1] then
		return self[1][index]
	end
end

--- Return an iterator over the heap items.<br>
--- Yields each value in heap array order (not priority order).
---@param self Heap The heap instance.
---@return function iterator Iterator that yields each value.
---@return table state The heap instance used as iterator state.
---@return integer initial Initial control variable.
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
	return Heap._iter_values, self, 0
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

-- Deprecated aliases (naming standard: snake_case). Kept for compatibility.
Heap.is_empty = Heap.isEmpty

-- Export
return Heap
