-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Localized global functions for better performance
local setmetatable = setmetatable
local string_format = string.format

--- Define the Stack class.<br>
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

--- Return an iterator over the stack items (most recent first).<br>
--- Yields index and value for each item in the stack.
---@param self Stack The stack instance.
---@return function iterator Iterator that yields index and value pairs.
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
	local count = Stack.count(self)
	local nextIndex = self[3]
	local items = self[1]
	return function(state, index)
		index = index + 1
		if index <= count then
			local realIndex = nextIndex - index
			return index, items[realIndex]
		end
	end, nil, 0
end

--[[ Test the Stack class
if true then
	-- Create a new Stack
	local stack = Stack.new()
	-- Test that the stack is initially empty
	assert(stack:count() == 0, "Stack should be empty initially")
	-- Test push operations
	stack:push(1)
	assert(stack:count() == 1, "Stack should have 1 item after first push")
	stack:push(2)
	assert(stack:count() == 2, "Stack should have 2 items after second push")
	stack:push(3)
	assert(stack:count() == 3, "Stack should have 3 items after third push")
	-- Test get operation
	local items, count = stack:get()
	assert(count == 3, "Get should return count of 3")
	assert(items[1] == 3, "First item should be 3 (most recent)")
	assert(items[2] == 2, "Second item should be 2")
	assert(items[3] == 1, "Third item should be 1 (oldest)")
	-- Test pop operation
	local popped = stack:pop()
	assert(popped == 3, "Popped item should be 3 (most recent)")
	assert(stack:count() == 2, "Stack should have 2 items after pop")
	-- Test peek operation
	local peeked = stack:peek()
	assert(peeked == 2, "Peeked item should be 2 (new top)")
	-- Test pop on empty stack
	stack:pop()
	stack:pop()
	assert(stack:count() == 0, "Stack should be empty after removing all items")
	popped = stack:pop()
	assert(popped == nil, "Pop on empty stack should return nil")
	assert(stack:peek() == nil, "Peek on empty stack should return nil")
	-- Test iterator
	stack:push("a")
	stack:push("b")
	stack:push("c")
	local iterated_items = {}
	for index, value in stack:iterator() do
		iterated_items[index] = value
	end
	assert(iterated_items[1] == "c", "Iterator should return 'c' first")
	assert(iterated_items[2] == "b", "Iterator should return 'b' second")
	assert(iterated_items[3] == "a", "Iterator should return 'a' third")
	-- Test with different data types
	stack:pop()
	stack:pop()
	stack:pop()
	stack:push({ test = "table" })
	stack:push(function() return "function" end)
	stack:push("string")
	assert(stack:count() == 3, "Stack should handle different data types")
	print("All tests passed ✔")
end
--]]

-- Export
return Stack
