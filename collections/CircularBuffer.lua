-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Localized global functions for better performance
local setmetatable = setmetatable
local string_format = string.format

--- Define the CircularBuffer class.<br>
--- A fixed-size buffer that automatically overwrites the oldest items when full.<br>
--- Perfect for streaming data, logs, or recent history tracking where you only need to keep the most recent N items.
---@class CircularBuffer
---@field [1] table Array storing the buffer items
---@field [2] integer Current number of items in buffer
---@field [3] integer Current insertion index
---@field [4] integer Maximum capacity of the buffer
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
		{},
		0,
		1,
		size,
	}, CircularBuffer)
end

CircularBuffer.__call = CircularBuffer.new

--- Get the number of items using `#` operator.<br>
--- Allows using `#buffer` instead of `buffer:count()`.
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
	return self[2]
end

--- Iterate over buffer items using `pairs()`.<br>
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
	return CircularBuffer.iterator(self)
end

--- Iterate over buffer items using `ipairs()`.<br>
--- Same as `pairs()` for CircularBuffer.
---@param self CircularBuffer The buffer instance.
---@return function iterator Iterator that yields index and value pairs.
function CircularBuffer.__ipairs(self)
	return CircularBuffer.iterator(self)
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
	return string_format("CircularBuffer(size=%d, count=%d)", self[4], self[2])
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
function CircularBuffer.insert(self, position)
	self[1][self[3]] = position
	self[3] = (self[3] % self[4]) + 1
	if self[2] < self[4] then
		self[2] = self[2] + 1
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
function CircularBuffer.get(self)
	local result = {}
	local count = self[2]
	for i = 1, count do
		local index = (self[3] - i - 1 + self[4]) % self[4] + 1
		result[i] = self[1][index]
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
function CircularBuffer.count(self)
	return self[2]
end

--- Remove and return the oldest item from the buffer.<br>
--- Returns `nil` if the buffer is empty.
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
function CircularBuffer.remove(self)
	if self[2] == 0 then
		return
	end
	-- Compute the index of the oldest item (the tail).
	-- self[3] is the next write position; the oldest element is self[2] positions
	-- behind that. Adding self[4] - 1 avoids negative values before modulo.
	local size = self[4]
	local removeIndex = (self[3] - self[2] + size - 1) % size + 1
	local removedValue = self[1][removeIndex]
	self[1][removeIndex] = nil
	self[2] = self[2] - 1
	return removedValue
end

function CircularBuffer._iter(state, index)
	index = index + 1
	if index <= state[1] then
		local realIndex = (state[2] - index - 1 + state[3]) % state[3] + 1
		return index, state[4][realIndex]
	end
end

--- Return an iterator over the buffer items (most recent first).<br>
--- Yields index and value for each item in the buffer.
---@param self CircularBuffer The buffer instance.
---@return function iterator Iterator that yields index and value pairs.
---@return table state The iterator state table.
---@return integer initial Initial control variable.
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
function CircularBuffer.iterator(self)
	return CircularBuffer._iter, {
		CircularBuffer.count(self),
		self[3],
		self[4],
		self[1],
	}, 0
end

-- Export
return CircularBuffer
