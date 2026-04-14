-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Localized global functions for better performance
local setmetatable = setmetatable
local string_format = string.format

--- Define the CircularBuffer class
---@class CircularBuffer
---@field size integer Maximum capacity of the buffer
---@field positions table Array storing the buffer items
---@field currentIndex integer Current insertion index
---@field count integer Current number of items in buffer
local CircularBuffer = {}
CircularBuffer.__index = CircularBuffer

--- Create a new CircularBuffer instance with a fixed size.<br>
--- The buffer will overwrite the oldest item when full.
---@param size integer Maximum number of items the buffer can hold.
---@return CircularBuffer buffer New CircularBuffer instance.
---@usage <br>
--- ```
--- local buffer = CircularBuffer.new(3)
--- buffer:insert(1)
--- buffer:insert(2)
--- buffer:insert(3)
--- buffer:insert(4) -- Overwrites 1
--- ```
function CircularBuffer.new(size)
	return setmetatable({
		size = size,
		positions = {},
		currentIndex = 1,
		count = 0,
	}, CircularBuffer)
end

CircularBuffer.__call = CircularBuffer.new

--- Get the number of items using # operator.<br>
--- Allows using #buffer instead of buffer:count().
---@param self CircularBuffer The buffer instance.
---@return integer count Number of items in the buffer.
---@usage <br>
--- ```
--- local buffer = CircularBuffer.new(5)
--- buffer:insert(1)
--- buffer:insert(2)
--- print(#buffer) -- 2
--- ```
function CircularBuffer.__len(self)
	return self.count
end

--- Iterate over buffer items using pairs().<br>
--- Yields index and value for each item (most recent first).
---@param self CircularBuffer The buffer instance.
---@return function iterator Iterator that yields index and value pairs.
---@usage <br>
--- ```
--- local buffer = CircularBuffer.new(3)
--- buffer:insert(1)
--- buffer:insert(2)
--- for index, value in pairs(buffer) do
---   print(index, value)
--- end
--- ```
function CircularBuffer.__pairs(self)
	return self:iterator()
end

--- Iterate over buffer items using ipairs().<br>
--- Same as pairs() for CircularBuffer.
---@param self CircularBuffer The buffer instance.
---@return function iterator Iterator that yields index and value pairs.
function CircularBuffer.__ipairs(self)
	return self:iterator()
end

--- Get string representation of the buffer.<br>
--- Returns a string showing size and count.
---@param self CircularBuffer The buffer instance.
---@return string string String representation of the buffer.
---@usage <br>
--- ```
--- local buffer = CircularBuffer.new(5)
--- buffer:insert(1)
--- buffer:insert(2)
--- print(tostring(buffer)) -- "CircularBuffer(size=5, count=2)"
--- ```
function CircularBuffer.__tostring(self)
	return string_format("CircularBuffer(size=%d, count=%d)", self.size, self.count)
end

--- Insert a position into the circular buffer.<br>
--- If the buffer is full, the oldest item will be overwritten.
---@param self CircularBuffer The buffer instance.
---@param position any The position value to insert.
---@usage <br>
--- ```
--- local buffer = CircularBuffer.new(2)
--- buffer:insert(1)
--- buffer:insert(2)
--- buffer:insert(3) -- Overwrites 1
--- ```
function CircularBuffer:insert(position)
	self.positions[self.currentIndex] = position
	self.currentIndex = (self.currentIndex % self.size) + 1
	if self.count < self.size then
		self.count = self.count + 1
	end
end

--- Get all items from the buffer in order (most recent first).<br>
--- Returns a table containing all items and the total count.
---@param self CircularBuffer The buffer instance.
---@return table array Array of items (most recent first).
---@return integer count Total number of items in the buffer.
---@usage <br>
--- ```
--- local buffer = CircularBuffer.new(3)
--- buffer:insert(1)
--- buffer:insert(2)
--- buffer:insert(3)
--- local items, count = buffer:get()
--- -- items = {3, 2, 1}, count = 3
--- ```
function CircularBuffer:get()
	local result = {}
	local count = self.count
	for i = 1, count do
		local index = (self.currentIndex - i - 1 + self.size) % self.size + 1
		result[i] = self.positions[index]
	end
	return result, count
end

--- Get the number of items currently in the buffer.
---@param self CircularBuffer The buffer instance.
---@return integer count Number of items in the buffer.
---@usage <br>
--- ```
--- local buffer = CircularBuffer.new(5)
--- buffer:insert(1)
--- buffer:insert(2)
--- print(buffer:count()) -- 2
--- ```
function CircularBuffer:count()
	return self.count
end

--- Remove and return the oldest item from the buffer.<br>
--- Returns nil if the buffer is empty.
---@param self CircularBuffer The buffer instance.
---@return any value The removed value, or nil if empty.
---@usage <br>
--- ```
--- local buffer = CircularBuffer.new(3)
--- buffer:insert(1)
--- buffer:insert(2)
--- local removed = buffer:remove()
--- -- removed = 1 (oldest)
--- ```
function CircularBuffer:remove()
	if self.count == 0 then
		return
	end
	local removeIndex = (self.currentIndex - 2 + self.size) % self.size + 1
	local removedValue = self.positions[removeIndex]
	self.positions[removeIndex] = nil
	self.count = self.count - 1
	return removedValue
end

--- Return an iterator over the buffer items (most recent first).<br>
--- Yields index and value for each item in the buffer.
---@param self CircularBuffer The buffer instance.
---@return function iterator Iterator that yields index and value pairs.
---@usage <br>
--- ```
--- local buffer = CircularBuffer.new(3)
--- buffer:insert(1)
--- buffer:insert(2)
--- buffer:insert(3)
--- for index, value in buffer:iterator() do
---   print(index, value)
--- end
--- -- Outputs: 1, 3  (most recent)
--- --          2, 2
--- --          3, 1  (oldest)
--- ```
function CircularBuffer:iterator()
	local count = self:count()
	local currentIndex = self.currentIndex
	local size = self.size
	local positions = self.positions
	return function(state, index)
		index = index + 1
		if index <= count then
			local realIndex = (currentIndex - index - 1 + size) % size + 1
			return index, positions[realIndex]
		end
	end, nil, 0
end

-- Test the CircularBuffer class
--if true then
--	-- Create a new CircularBuffer with size 3
--	local buffer = CircularBuffer.new(3)
--	-- Test that the buffer is initially empty
--	assert(buffer:count() == 0, "Buffer should be empty initially")
--	-- Test insert operations
--	buffer:insert(1)
--	assert(buffer:count() == 1, "Buffer should have 1 item after first insert")
--	buffer:insert(2)
--	assert(buffer:count() == 2, "Buffer should have 2 items after second insert")
--	buffer:insert(3)
--	assert(buffer:count() == 3, "Buffer should have 3 items after third insert")
--	-- Test get operation
--	local items, count = buffer:get()
--	assert(count == 3, "Get should return count of 3")
--	assert(items[1] == 3, "First item should be 3 (most recent)")
--	assert(items[2] == 2, "Second item should be 2")
--	assert(items[3] == 1, "Third item should be 1 (oldest)")
--	-- Test overwrite behavior (buffer is full)
--	buffer:insert(4)
--	assert(buffer:count() == 3, "Buffer should still have 3 items after overwrite")
--	local items, count = buffer:get()
--	assert(count == 3, "Get should return count of 3")
--	assert(items[1] == 4, "First item should be 4 (newest)")
--	assert(items[2] == 3, "Second item should be 3")
--	assert(items[3] == 2, "Third item should be 2 (oldest, 1 was overwritten)")
--	-- Test remove operation
--	local removed = buffer:remove()
--	assert(removed == 2, "Removed item should be 2 (oldest)")
--	assert(buffer:count() == 2, "Buffer should have 2 items after remove")
--	-- Test remove on empty buffer
--	buffer:remove()
--	buffer:remove()
--	assert(buffer:count() == 0, "Buffer should be empty after removing all items")
--	local removed = buffer:remove()
--	assert(removed == nil, "Remove on empty buffer should return nil")
--	-- Test iterator
--	buffer:insert("a")
--	buffer:insert("b")
--	buffer:insert("c")
--	local iterated_items = {}
--	for index, value in buffer:iterator() do
--		iterated_items[index] = value
--	end
--	assert(iterated_items[1] == "c", "Iterator should return 'c' first")
--	assert(iterated_items[2] == "b", "Iterator should return 'b' second")
--	assert(iterated_items[3] == "a", "Iterator should return 'a' third")
--	-- Test with different data types
--	buffer:insert({test = "table"})
--	buffer:insert(function() return "function" end)
--	buffer:insert("string")
--	assert(buffer:count() == 3, "Buffer should handle different data types")
--	print("All tests passed ✔")
--end

-- Export
return CircularBuffer
