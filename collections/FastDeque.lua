-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Localized global functions for better performance
local setmetatable = setmetatable
local string_format = string.format

--- Define the FastDeque class.<br>
--- A performance-optimized double-ended queue using floating indices and optional maximum capacity.<br>
--- Faster than standard FastDeque for frequent operations, with O(1) push/pop from both ends and automatic overflow handling.
---@class FastDeque
---@field [1] table Array storing the deque items
---@field [2] integer Current number of items in deque
---@field [3] integer Head index (next to pop left)
---@field [4] integer Tail index (next push right)
---@field [5] integer Maximum capacity of the deque (0 for unbounded)
local FastDeque = {}
FastDeque.__index = FastDeque

--- Create a new FastDeque instance.<br>
--- The deque grows dynamically using floating indices.<br>
--- If `maxSize` is provided and greater than 0, the deque will discard items<br>
--- from the opposite end when full.
---@param maxSize? integer Maximum number of items the deque can hold. 0 or nil for unbounded.
---@return FastDeque deque New FastDeque instance.
---@usage <br>
--- ```
--- local deque = FastDeque.new(3)
--- deque:pushRight(1)
--- deque:pushRight(2)
--- deque:pushLeft(3)
--- ```
function FastDeque.new(maxSize)
	return setmetatable({
		{},
		0,
		1,
		1,
		maxSize or 0,
	}, FastDeque)
end

FastDeque.__call = FastDeque.new

--- Get the number of items using `#` operator.<br>
--- Allows using `#deque` instead of `deque:count()`.
---@param self FastDeque The deque instance.
---@return integer count Number of items in the FastDeque.
---@usage <br>
--- ```
--- local deque = FastDeque.new()
--- deque:pushRight(1)
--- deque:pushRight(2)
--- print(#deque) -- 2
--- ```
function FastDeque.__len(self)
	return self[2]
end

--- Iterate over deque items using `pairs()`.<br>
--- Yields index and value for each item (left to right).
---@param self FastDeque The deque instance.
---@return function iterator Iterator that yields index and value pairs.
---@usage <br>
--- ```
--- local deque = FastDeque.new()
--- deque:pushRight(1)
--- deque:pushRight(2)
--- for index, value in pairs(deque) do
---   print(index, value)
--- end
--- ```
function FastDeque.__pairs(self)
	return FastDeque.iterator(self)
end

--- Iterate over deque items using `ipairs()`.<br>
--- Same as `pairs()` for FastDeque.
---@param self FastDeque The deque instance.
---@return function iterator Iterator that yields index and value pairs.
function FastDeque.__ipairs(self)
	return FastDeque.iterator(self)
end

--- Get string representation of the FastDeque.<br>
--- Returns a string showing count and maxSize if bounded.
---@param self FastDeque The deque instance.
---@return string string String representation of the FastDeque.
---@usage <br>
--- ```
--- local deque = FastDeque.new(5)
--- deque:pushRight(1)
--- deque:pushRight(2)
--- print(tostring(deque)) -- "FastDeque(count=2, maxSize=5)"
--- ```
function FastDeque.__tostring(self)
	if self[5] > 0 then
		return string_format("FastDeque(count=%d, maxSize=%d)", self[2], self[5])
	end
	return string_format("FastDeque(count=%d)", self[2])
end

--- Push an item to the left end of the FastDeque.<br>
--- If the deque is bounded and full, the rightmost item will be discarded.
---@param self FastDeque The deque instance.
---@param value any The value to push.
---@usage <br>
--- ```
--- local deque = FastDeque.new(2)
--- deque:pushLeft(1)
--- deque:pushLeft(2)
--- deque:pushLeft(3) -- Discards 1 on the right
--- ```
function FastDeque.pushLeft(self, value)
	self[3] = self[3] - 1
	self[1][self[3]] = value
	self[2] = self[2] + 1
	if self[5] > 0 and self[2] > self[5] then
		self[4] = self[4] - 1
		self[1][self[4]] = nil
		self[2] = self[2] - 1
	end
end

--- Push an item to the right end of the FastDeque.<br>
--- If the deque is bounded and full, the leftmost item will be discarded.
---@param self FastDeque The deque instance.
---@param value any The value to push.
---@usage <br>
--- ```
--- local deque = FastDeque.new(2)
--- deque:pushRight(1)
--- deque:pushRight(2)
--- deque:pushRight(3) -- Discards 1 on the left
--- ```
function FastDeque.pushRight(self, value)
	self[1][self[4]] = value
	self[4] = self[4] + 1
	self[2] = self[2] + 1
	if self[5] > 0 and self[2] > self[5] then
		self[1][self[3]] = nil
		self[3] = self[3] + 1
		self[2] = self[2] - 1
	end
end

--- Pop and return the leftmost item from the FastDeque.<br>
--- Returns `nil` if the deque is empty.
---@param self FastDeque The deque instance.
---@return any value The removed value, or nil if empty.
---@usage <br>
--- ```
--- local deque = FastDeque.new()
--- deque:pushRight(1)
--- deque:pushRight(2)
--- local popped = deque:popLeft()
--- -- popped = 1
--- ```
function FastDeque.popLeft(self)
	if self[2] == 0 then
		return
	end
	local value = self[1][self[3]]
	self[1][self[3]] = nil
	self[3] = self[3] + 1
	self[2] = self[2] - 1
	return value
end

--- Pop and return the rightmost item from the FastDeque.<br>
--- Returns `nil` if the deque is empty.
---@param self FastDeque The deque instance.
---@return any value The removed value, or nil if empty.
---@usage <br>
--- ```
--- local deque = FastDeque.new()
--- deque:pushRight(1)
--- deque:pushRight(2)
--- local popped = deque:popRight()
--- -- popped = 2
--- ```
function FastDeque.popRight(self)
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
---@param self FastDeque The deque instance.
---@return any value The leftmost value, or nil if empty.
---@usage <br>
--- ```
--- local deque = FastDeque.new()
--- deque:pushRight(1)
--- deque:pushRight(2)
--- local val = deque:peekLeft()
--- -- val = 1
--- ```
function FastDeque.peekLeft(self)
	if self[2] == 0 then
		return
	end
	return self[1][self[3]]
end

--- Get the rightmost item without removing it.<br>
--- Returns `nil` if the deque is empty.
---@param self FastDeque The deque instance.
---@return any value The rightmost value, or nil if empty.
---@usage <br>
--- ```
--- local deque = FastDeque.new()
--- deque:pushRight(1)
--- deque:pushRight(2)
--- local val = deque:peekRight()
--- -- val = 2
--- ```
function FastDeque.peekRight(self)
	if self[2] == 0 then
		return
	end
	return self[1][self[4] - 1]
end

--- Get all items from the deque in order (left to right).<br>
--- Returns a table containing all items and the total count.
---@param self FastDeque The deque instance.
---@return table array Array of items (left to right).
---@return integer count Total number of items in the FastDeque.
---@usage <br>
--- ```
--- local deque = FastDeque.new()
--- deque:pushRight(1)
--- deque:pushLeft(2)
--- deque:pushRight(3)
--- local items, count = deque:get()
--- -- items = {2, 1, 3}, count = 3
--- ```
function FastDeque.get(self)
	local result = {}
	local count = self[2]
	for i = 1, count do
		result[i] = self[1][self[3] + i - 1]
	end
	return result, count
end

--- Get the number of items currently in the FastDeque.
---@param self FastDeque The deque instance.
---@return integer count Number of items in the FastDeque.
---@usage <br>
--- ```
--- local deque = FastDeque.new()
--- deque:pushRight(1)
--- deque:pushRight(2)
--- print(deque:count()) -- 2
--- ```
function FastDeque.count(self)
	return self[2]
end

function FastDeque._iter(state, index)
	index = index + 1
	if index <= state[1] then
		local realIndex = state[2] + index - 1
		return index, state[3][realIndex]
	end
end

--- Return an iterator over the deque items (left to right).<br>
--- Yields index and value for each item in the FastDeque.
---@param self FastDeque The deque instance.
---@return function iterator Iterator that yields index and value pairs.
---@return table state The iterator state table.
---@return integer initial Initial control variable.
---@usage <br>
--- ```
--- local deque = FastDeque.new()
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
function FastDeque.iterator(self)
	return FastDeque._iter, {
		FastDeque.count(self),
		self[3],
		self[1],
	}, 0
end

-- Deprecated aliases (naming standard: snake_case). Kept for compatibility.
FastDeque.push_left = FastDeque.pushLeft
FastDeque.push_right = FastDeque.pushRight
FastDeque.pop_left = FastDeque.popLeft
FastDeque.pop_right = FastDeque.popRight
FastDeque.peek_left = FastDeque.peekLeft
FastDeque.peek_right = FastDeque.peekRight

-- Export
return FastDeque
