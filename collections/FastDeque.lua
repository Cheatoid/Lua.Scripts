-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Localized global functions for better performance
local setmetatable = setmetatable
local string_format = string.format

--- Define the Deque class.<br>
--- A performance-optimized double-ended queue using floating indices and optional maximum capacity.<br>
--- Faster than standard Deque for frequent operations, with O(1) push/pop from both ends and automatic overflow handling.
---@class Deque
---@field [1] table Array storing the deque items
---@field [2] integer Current number of items in deque
---@field [3] integer Head index (next to pop left)
---@field [4] integer Tail index (next push right)
---@field [5] integer Maximum capacity of the deque (0 for unbounded)
local Deque = {}
Deque.__index = Deque

--- Create a new Deque instance.<br>
--- The deque grows dynamically using floating indices.<br>
--- If `maxSize` is provided and greater than 0, the deque will discard items<br>
--- from the opposite end when full.
---@param maxSize? integer Maximum number of items the deque can hold. 0 or nil for unbounded.
---@return Deque deque New Deque instance.
---@usage <br>
--- ```
--- local deque = Deque.new(3)
--- deque:pushRight(1)
--- deque:pushRight(2)
--- deque:pushLeft(3)
--- ```
function Deque.new(maxSize)
	return setmetatable({
		{},
		0,
		1,
		1,
		maxSize or 0,
	}, Deque)
end

Deque.__call = Deque.new

--- Get the number of items using `#` operator.<br>
--- Allows using `#deque` instead of `deque:count()`.
---@param self Deque The deque instance.
---@return integer count Number of items in the deque.
---@usage <br>
--- ```
--- local deque = Deque.new()
--- deque:pushRight(1)
--- deque:pushRight(2)
--- print(#deque) -- 2
--- ```
function Deque.__len(self)
	return self[2]
end

--- Iterate over deque items using `pairs()`.<br>
--- Yields index and value for each item (left to right).
---@param self Deque The deque instance.
---@return function iterator Iterator that yields index and value pairs.
---@usage <br>
--- ```
--- local deque = Deque.new()
--- deque:pushRight(1)
--- deque:pushRight(2)
--- for index, value in pairs(deque) do
---   print(index, value)
--- end
--- ```
function Deque.__pairs(self)
	return Deque.iterator(self)
end

--- Iterate over deque items using `ipairs()`.<br>
--- Same as `pairs()` for Deque.
---@param self Deque The deque instance.
---@return function iterator Iterator that yields index and value pairs.
function Deque.__ipairs(self)
	return Deque.iterator(self)
end

--- Get string representation of the deque.<br>
--- Returns a string showing count and maxSize if bounded.
---@param self Deque The deque instance.
---@return string string String representation of the deque.
---@usage <br>
--- ```
--- local deque = Deque.new(5)
--- deque:pushRight(1)
--- deque:pushRight(2)
--- print(tostring(deque)) -- "Deque(count=2, maxSize=5)"
--- ```
function Deque.__tostring(self)
	if self[5] > 0 then
		return string_format("Deque(count=%d, maxSize=%d)", self[2], self[5])
	end
	return string_format("Deque(count=%d)", self[2])
end

--- Push an item to the left end of the deque.<br>
--- If the deque is bounded and full, the rightmost item will be discarded.
---@param self Deque The deque instance.
---@param value any The value to push.
---@usage <br>
--- ```
--- local deque = Deque.new(2)
--- deque:pushLeft(1)
--- deque:pushLeft(2)
--- deque:pushLeft(3) -- Discards 1 on the right
--- ```
function Deque.pushLeft(self, value)
	self[3] = self[3] - 1
	self[1][self[3]] = value
	self[2] = self[2] + 1
	if self[5] > 0 and self[2] > self[5] then
		self[4] = self[4] - 1
		self[1][self[4]] = nil
		self[2] = self[2] - 1
	end
end

--- Push an item to the right end of the deque.<br>
--- If the deque is bounded and full, the leftmost item will be discarded.
---@param self Deque The deque instance.
---@param value any The value to push.
---@usage <br>
--- ```
--- local deque = Deque.new(2)
--- deque:pushRight(1)
--- deque:pushRight(2)
--- deque:pushRight(3) -- Discards 1 on the left
--- ```
function Deque.pushRight(self, value)
	self[1][self[4]] = value
	self[4] = self[4] + 1
	self[2] = self[2] + 1
	if self[5] > 0 and self[2] > self[5] then
		self[1][self[3]] = nil
		self[3] = self[3] + 1
		self[2] = self[2] - 1
	end
end

--- Pop and return the leftmost item from the deque.<br>
--- Returns `nil` if the deque is empty.
---@param self Deque The deque instance.
---@return any value The removed value, or nil if empty.
---@usage <br>
--- ```
--- local deque = Deque.new()
--- deque:pushRight(1)
--- deque:pushRight(2)
--- local popped = deque:popLeft()
--- -- popped = 1
--- ```
function Deque.popLeft(self)
	if self[2] == 0 then
		return
	end
	local value = self[1][self[3]]
	self[1][self[3]] = nil
	self[3] = self[3] + 1
	self[2] = self[2] - 1
	return value
end

--- Pop and return the rightmost item from the deque.<br>
--- Returns `nil` if the deque is empty.
---@param self Deque The deque instance.
---@return any value The removed value, or nil if empty.
---@usage <br>
--- ```
--- local deque = Deque.new()
--- deque:pushRight(1)
--- deque:pushRight(2)
--- local popped = deque:popRight()
--- -- popped = 2
--- ```
function Deque.popRight(self)
	if self[2] == 0 then
		return
	end
	self[4] = self[4] - 1
	local value = self[1][self[4]]
	self[1][self[4]] = nil
	self[2] = self[2] - 1
	return value
end

--- Get the leftmost item without removing it.<br>
--- Returns `nil` if the deque is empty.
---@param self Deque The deque instance.
---@return any value The leftmost value, or nil if empty.
---@usage <br>
--- ```
--- local deque = Deque.new()
--- deque:pushRight(1)
--- deque:pushRight(2)
--- local val = deque:peekLeft()
--- -- val = 1
--- ```
function Deque.peekLeft(self)
	if self[2] == 0 then
		return
	end
	return self[1][self[3]]
end

--- Get the rightmost item without removing it.<br>
--- Returns `nil` if the deque is empty.
---@param self Deque The deque instance.
---@return any value The rightmost value, or nil if empty.
---@usage <br>
--- ```
--- local deque = Deque.new()
--- deque:pushRight(1)
--- deque:pushRight(2)
--- local val = deque:peekRight()
--- -- val = 2
--- ```
function Deque.peekRight(self)
	if self[2] == 0 then
		return
	end
	return self[1][self[4] - 1]
end

--- Get all items from the deque in order (left to right).<br>
--- Returns a table containing all items and the total count.
---@param self Deque The deque instance.
---@return table array Array of items (left to right).
---@return integer count Total number of items in the deque.
---@usage <br>
--- ```
--- local deque = Deque.new()
--- deque:pushRight(1)
--- deque:pushLeft(2)
--- deque:pushRight(3)
--- local items, count = deque:get()
--- -- items = {2, 1, 3}, count = 3
--- ```
function Deque.get(self)
	local result = {}
	local count = self[2]
	for i = 1, count do
		result[i] = self[1][self[3] + i - 1]
	end
	return result, count
end

--- Get the number of items currently in the deque.
---@param self Deque The deque instance.
---@return integer count Number of items in the deque.
---@usage <br>
--- ```
--- local deque = Deque.new()
--- deque:pushRight(1)
--- deque:pushRight(2)
--- print(deque:count()) -- 2
--- ```
function Deque.count(self)
	return self[2]
end

function Deque._iter(state, index)
	index = index + 1
	if index <= state[1] then
		local realIndex = state[2] + index - 1
		return index, state[3][realIndex]
	end
end

--- Return an iterator over the deque items (left to right).<br>
--- Yields index and value for each item in the deque.
---@param self Deque The deque instance.
---@return function iterator Iterator that yields index and value pairs.
---@return table state The iterator state table.
---@return integer initial Initial control variable.
---@usage <br>
--- ```
--- local deque = Deque.new()
--- deque:pushRight(1)
--- deque:pushLeft(2)
--- deque:pushRight(3)
--- for index, value in deque:iterator() do
---   print(index, value)
--- end
--- -- Outputs: 1, 2  (leftmost)
--- --          2, 1
--- --          3, 3  (rightmost)
--- ```
function Deque.iterator(self)
	return Deque._iter, {
		Deque.count(self),
		self[3],
		self[1],
	}, 0
end

--[[ Test the Deque class
if true then
	-- Create a new unbounded Deque
	local deque = Deque.new()
	-- Test that the deque is initially empty
	assert(deque:count() == 0, "Deque should be empty initially")

	-- Test pushRight operations
	deque:pushRight(1)
	assert(deque:count() == 1, "Deque should have 1 item after first pushRight")
	deque:pushRight(2)
	assert(deque:count() == 2, "Deque should have 2 items after second pushRight")

	-- Test pushLeft operations
	deque:pushLeft(3)
	assert(deque:count() == 3, "Deque should have 3 items after pushLeft")

	-- Test get operation (left to right)
	local items, count = deque:get()
	assert(count == 3, "Get should return count of 3")
	assert(items[1] == 3, "First item should be 3 (leftmost)")
	assert(items[2] == 1, "Second item should be 1")
	assert(items[3] == 2, "Third item should be 2 (rightmost)")

	-- Test peek operations
	assert(deque:peekLeft() == 3, "PeekLeft should return 3")
	assert(deque:peekRight() == 2, "PeekRight should return 2")

	-- Test popLeft operation
	local popped = deque:popLeft()
	assert(popped == 3, "PopLeft should return 3")
	assert(deque:count() == 2, "Deque should have 2 items after popLeft")

	-- Test popRight operation
	popped = deque:popRight()
	assert(popped == 2, "PopRight should return 2")
	assert(deque:count() == 1, "Deque should have 1 item after popRight")

	-- Test pop on empty deque
	deque:popLeft()
	assert(deque:count() == 0, "Deque should be empty after removing all items")
	popped = deque:popLeft()
	assert(popped == nil, "PopLeft on empty deque should return nil")
	popped = deque:popRight()
	assert(popped == nil, "PopRight on empty deque should return nil")
	assert(deque:peekLeft() == nil, "PeekLeft on empty deque should return nil")
	assert(deque:peekRight() == nil, "PeekRight on empty deque should return nil")

	-- Test bounded Deque
	local bDeque = Deque.new(3)
	bDeque:pushRight(1)
	bDeque:pushRight(2)
	bDeque:pushRight(3)
	assert(bDeque:count() == 3, "Bounded deque should have 3 items")

	-- Test bounded overflow on pushRight
	bDeque:pushRight(4)
	assert(bDeque:count() == 3, "Bounded deque count should remain 3 after overflow pushRight")
	items = bDeque:get()
	assert(items[1] == 2 and items[2] == 3 and items[3] == 4, "PushRight overflow should discard leftmost item")

	-- Test bounded overflow on pushLeft
	bDeque:pushLeft(5)
	assert(bDeque:count() == 3, "Bounded deque count should remain 3 after overflow pushLeft")
	items = bDeque:get()
	assert(items[1] == 5 and items[2] == 2 and items[3] == 3, "PushLeft overflow should discard rightmost item")

	-- Test iterator
	local iterated_items = {}
	for index, value in bDeque:iterator() do
		iterated_items[index] = value
	end
	assert(iterated_items[1] == 5, "Iterator should return 5 first")
	assert(iterated_items[2] == 2, "Iterator should return 2 second")
	assert(iterated_items[3] == 3, "Iterator should return 3 third")

	-- Test with different data types
	bDeque:popLeft()
	bDeque:popLeft()
	bDeque:popLeft()
	bDeque:pushLeft({ test = "table" })
	bDeque:pushLeft(function() return "function" end)
	bDeque:pushLeft("string")
	assert(bDeque:count() == 3, "Deque should handle different data types")

	print("All tests passed")
end
--]]

-- Export
return Deque
