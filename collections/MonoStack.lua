-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Localized global functions for better performance
local setmetatable = setmetatable
local string_format = string.format

--- A stack that grows using monotonically increasing indices.<br>
--- Each element gets a unique index that never repeats, making it ideal for undo systems or when you need stable references to stack positions.
---@class Stack
---@field [1] table Array storing the stack items
---@field [2] integer Current number of items in stack
---@field [3] integer Next insertion index (top + 1)
local Stack = {}
Stack.__index = Stack

--- Create a new Stack instance.<br>
--- The stack grows dynamically using monotonically increasing indices.
---@return Stack stack New Stack instance.
---@usage <br>
--- ```
--- local stack = Stack.new()
--- stack:push(1)
--- stack:push(2)
--- stack:push(3)
--- ```
function Stack.new()
	return setmetatable({
		{},
		0,
		1,
	}, Stack)
end

Stack.__call = Stack.new

--- Get the number of items using `#` operator.<br>
--- Allows using `#stack` instead of `stack:count()`.
---@param self Stack The stack instance.
---@return integer count Number of items in the stack.
---@usage <br>
--- ```
--- local stack = Stack.new()
--- stack:push(1)
--- stack:push(2)
--- print(#stack) -- 2
--- ```
function Stack.__len(self)
	return self[2]
end

--- Iterate over stack items using `pairs()`.<br>
--- Yields index and value for each item (most recent first).
---@param self Stack The stack instance.
---@return function iterator Iterator that yields index and value pairs.
---@usage <br>
--- ```
--- local stack = Stack.new()
--- stack:push(1)
--- stack:push(2)
--- for index, value in pairs(stack) do
---   print(index, value)
--- end
--- ```
function Stack.__pairs(self)
	return Stack.iterator(self)
end

--- Iterate over stack items using `ipairs()`.<br>
--- Same as `pairs()` for Stack.
---@param self Stack The stack instance.
---@return function iterator Iterator that yields index and value pairs.
function Stack.__ipairs(self)
	return Stack.iterator(self)
end

--- Get string representation of the stack.<br>
--- Returns a string showing count.
---@param self Stack The stack instance.
---@return string string String representation of the stack.
---@usage <br>
--- ```
--- local stack = Stack.new()
--- stack:push(1)
--- stack:push(2)
--- print(tostring(stack)) -- "Stack(count=2)"
--- ```
function Stack.__tostring(self)
	return string_format("Stack(count=%d)", self[2])
end

--- Push an item onto the stack.<br>
--- Uses a monotonically increasing index for O(1) insertion.
---@param self Stack The stack instance.
---@param value any The value to push.
---@usage <br>
--- ```
--- local stack = Stack.new()
--- stack:push(1)
--- stack:push(2)
--- ```
function Stack.push(self, value)
	self[1][self[3]] = value
	self[3] = self[3] + 1
	self[2] = self[2] + 1
end

--- Pop and return the top item from the stack.<br>
--- Returns `nil` if the stack is empty.
---@param self Stack The stack instance.
---@return any value The removed value, or nil if empty.
---@usage <br>
--- ```
--- local stack = Stack.new()
--- stack:push(1)
--- stack:push(2)
--- local popped = stack:pop()
--- -- popped = 2 (most recent)
--- ```
function Stack.pop(self)
	if self[2] == 0 then
		return
	end
	self[3] = self[3] - 1
	local value = self[1][self[3]]
	self[1][self[3]] = nil
	self[2] = self[2] - 1
	return value
end

--- Get the top item from the stack without removing it.<br>
--- Returns `nil` if the stack is empty.
---@param self Stack The stack instance.
---@return any value The top value, or nil if empty.
---@usage <br>
--- ```
--- local stack = Stack.new()
--- stack:push(1)
--- stack:push(2)
--- local peeked = stack:peek()
--- -- peeked = 2 (most recent)
--- ```
function Stack.peek(self)
	if self[2] == 0 then
		return
	end
	return self[1][self[3] - 1]
end

--- Get all items from the stack in order (most recent first).<br>
--- Returns a table containing all items and the total count.
---@param self Stack The stack instance.
---@return table array Array of items (most recent first).
---@return integer count Total number of items in the stack.
---@usage <br>
--- ```
--- local stack = Stack.new()
--- stack:push(1)
--- stack:push(2)
--- stack:push(3)
--- local items, count = stack:get()
--- -- items = {3, 2, 1}, count = 3
--- ```
function Stack.get(self)
	local result = {}
	local count = self[2]
	for i = 1, count do
		result[i] = self[1][count - i + 1]
	end
	return result, count
end

--- Get the number of items currently in the stack.
---@param self Stack The stack instance.
---@return integer count Number of items in the stack.
---@usage <br>
--- ```
--- local stack = Stack.new()
--- stack:push(1)
--- stack:push(2)
--- print(stack:count()) -- 2
--- ```
function Stack.count(self)
	return self[2]
end

function Stack._iter(state, index)
	index = index + 1
	if index <= state[1] then
		local realIndex = state[2] - index
		return index, state[3][realIndex]
	end
end

--- Return an iterator over the stack items (most recent first).<br>
--- Yields index and value for each item in the stack.
---@param self Stack The stack instance.
---@return function iterator Iterator that yields index and value pairs.
---@return table state The iterator state table.
---@return integer initial Initial control variable.
---@usage <br>
--- ```
--- local stack = Stack.new()
--- stack:push(1)
--- stack:push(2)
--- stack:push(3)
--- for index, value in stack:iterator() do
---   print(index, value)
--- end
--- -- Outputs: 1, 3  (most recent)
--- --          2, 2
--- --          3, 1  (oldest)
--- ```
function Stack.iterator(self)
	return Stack._iter, {
		Stack.count(self),
		self[3],
		self[1],
	}, 0
end

-- Export
return Stack
