-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Localized global function(s) for better performance
local setmetatable = setmetatable

--- Define the CircularBuffer class
---@class CircularBuffer
local CircularBuffer = {}
CircularBuffer.__index = CircularBuffer

function CircularBuffer.new(size)
	return setmetatable({
		size = size,
		positions = {},
		currentIndex = 1,
		count = 0,
	}, CircularBuffer)
end

CircularBuffer.__call = CircularBuffer.new

function CircularBuffer:insert(position)
	self.positions[self.currentIndex] = position
	self.currentIndex = (self.currentIndex % self.size) + 1
	if self.count < self.size then
		self.count = self.count + 1
	end
end

function CircularBuffer:get()
	local result = {}
	local count = self.count
	for i = 1, count do
		local index = (self.currentIndex - i - 1 + self.size) % self.size + 1
		result[i] = self.positions[index]
	end
	return result, count
end

function CircularBuffer:length()
	return self.count
end

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

function CircularBuffer:iterate()
	local count = self:length()
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
--	assert(buffer:length() == 0, "Buffer should be empty initially")
--	-- Test insert operations
--	buffer:insert(1)
--	assert(buffer:length() == 1, "Buffer should have 1 item after first insert")
--	buffer:insert(2)
--	assert(buffer:length() == 2, "Buffer should have 2 items after second insert")
--	buffer:insert(3)
--	assert(buffer:length() == 3, "Buffer should have 3 items after third insert")
--	-- Test get operation
--	local items, count = buffer:get()
--	assert(count == 3, "Get should return count of 3")
--	assert(items[1] == 3, "First item should be 3 (most recent)")
--	assert(items[2] == 2, "Second item should be 2")
--	assert(items[3] == 1, "Third item should be 1 (oldest)")
--	-- Test overwrite behavior (buffer is full)
--	buffer:insert(4)
--	assert(buffer:length() == 3, "Buffer should still have 3 items after overwrite")
--	local items, count = buffer:get()
--	assert(count == 3, "Get should return count of 3")
--	assert(items[1] == 4, "First item should be 4 (newest)")
--	assert(items[2] == 3, "Second item should be 3")
--	assert(items[3] == 2, "Third item should be 2 (oldest, 1 was overwritten)")
--	-- Test remove operation
--	local removed = buffer:remove()
--	assert(removed == 2, "Removed item should be 2 (oldest)")
--	assert(buffer:length() == 2, "Buffer should have 2 items after remove")
--	-- Test remove on empty buffer
--	buffer:remove()
--	buffer:remove()
--	assert(buffer:length() == 0, "Buffer should be empty after removing all items")
--	local removed = buffer:remove()
--	assert(removed == nil, "Remove on empty buffer should return nil")
--	-- Test iterator
--	buffer:insert("a")
--	buffer:insert("b")
--	buffer:insert("c")
--	local iterated_items = {}
--	for index, value in buffer:iterate() do
--		iterated_items[index] = value
--	end
--	assert(iterated_items[1] == "c", "Iterator should return 'c' first")
--	assert(iterated_items[2] == "b", "Iterator should return 'b' second")
--	assert(iterated_items[3] == "a", "Iterator should return 'a' third")
--	-- Test with different data types
--	buffer:insert({test = "table"})
--	buffer:insert(function() return "function" end)
--	buffer:insert("string")
--	assert(buffer:length() == 3, "Buffer should handle different data types")
--	print("All tests passed ✔")
--end

-- Export
return CircularBuffer
