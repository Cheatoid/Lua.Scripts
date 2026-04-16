-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Localized global functions for better performance
local assert = assert
local setmetatable = setmetatable
local string_format = string.format
local table_insert = table.insert
local table_remove = table.remove

--- Define the Stack class
---@class Stack
---@field [1] table Container table storing the stack items
local Stack = {}
Stack.__index = Stack

--- Create a new Stack instance.<br>
--- A LIFO (Last-In-First-Out) stack data structure.
---@return Stack stack New Stack instance.
---@usage <br>
--- ```
--- local stack = Stack.new()
--- stack:push(1)
--- stack:push(2)
--- ```
function Stack.new()
	return setmetatable({ {} }, Stack)
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
	return #self[1]
end

--- Iterate over stack items using `pairs()`.<br>
--- Yields index and value for each item (bottom to top, 1-based).
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
	local i = 0
	return function()
		i = i + 1
		if i > #self[1] then
			return
		end
		return i, self[1][i]
	end
end

--- Iterate over stack items using `ipairs()`.<br>
--- Yields index and value for each item (bottom to top, 1-based).
---@param self Stack The stack instance.
---@return function iterator Iterator that yields index and value pairs.
function Stack.__ipairs(self)
	local i = 0
	return function()
		i = i + 1
		if i > #self[1] then
			return
		end
		return i, self[1][i]
	end
end

--- Get string representation of the stack.<br>
--- Returns a string showing the count.
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
	return string_format("Stack(count=%d)", #self[1])
end

--- Get the number of items in the stack.
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
	return #self[1]
end

--- Check if the stack is empty.
---@param self Stack The stack instance.
---@return boolean empty `true` if the stack is empty, `false` otherwise.
---@usage <br>
--- ```
--- local stack = Stack.new()
--- print(stack:isEmpty()) -- true
--- stack:push(1)
--- print(stack:isEmpty()) -- false
--- ```
function Stack.isEmpty(self)
	return #self[1] == 0
end

--- Clear all items from the stack.
---@param self Stack The stack instance.
---@usage <br>
--- ```
--- local stack = Stack.new()
--- stack:push(1)
--- stack:push(2)
--- stack:clear()
--- print(stack:isEmpty()) -- true
--- ```
function Stack.clear(self)
	self[1] = {}
end

--- Add a value to the top of the stack (push).<br>
--- Items are popped in reverse order of being pushed (LIFO).
---@param self Stack The stack instance.
---@param value any The value to add (cannot be `nil`).
---@usage <br>
--- ```
--- local stack = Stack.new()
--- stack:push(1)
--- stack:push(2)
--- print(stack:pop()) -- 2
--- ```
function Stack.push(self, value)
	assert(value ~= nil, "cannot add a nil value to the stack")
	table_insert(self[1], value)
end

--- Remove and return the top value from the stack (pop).<br>
--- Returns `nil` if the stack is empty.
---@param self Stack The stack instance.
---@return any value The popped value, or `nil` if empty.
---@usage <br>
--- ```
--- local stack = Stack.new()
--- stack:push(1)
--- stack:push(2)
--- local value = stack:pop()
--- print(value) -- 2
--- ```
function Stack.pop(self)
	if #self[1] == 0 then
		return
	end
	return table_remove(self[1])
end

--- Return the top value from the stack without removing it (peek).<br>
--- Returns `nil` if the stack is empty.
---@param self Stack The stack instance.
---@return any value The top value, or `nil` if empty.
---@usage <br>
--- ```
--- local stack = Stack.new()
--- stack:push(1)
--- stack:push(2)
--- print(stack:peek()) -- 2
--- print(stack:count()) -- 2 (still has both items)
--- ```
function Stack.peek(self)
	local length = #self[1]
	if length == 0 then
		return
	end
	return self[1][length]
end

--- Return an iterator over the stack from top to bottom.<br>
--- Yields each value in the stack in LIFO order.
---@param self Stack The stack instance.
---@return function iterator Iterator that yields each value.
---@usage <br>
--- ```
--- local stack = Stack.new()
--- stack:push(1)
--- stack:push(2)
--- stack:push(3)
--- for value in stack:iterator() do
---   print(value)
--- end
--- -- Outputs: 3, 2, 1
--- ```
function Stack.iterator(self)
	local i = #self[1]
	return function()
		if i < 1 then
			return
		end
		local value = self[1][i]
		i = i - 1
		return value
	end
end

-- Test the Stack class
--if true then
--	-- Create a new Stack
--	local stack = Stack.new()
--	-- Test that a new stack is empty
--	assert(stack:isEmpty(), "New stack should be empty")
--	-- Test that the count of a new stack is 0
--	assert(stack:count() == 0, "New stack should have count 0")
--	-- Push a value onto the stack
--	stack:push(1)
--	-- Test that the stack is not empty
--	assert(not stack:isEmpty(), "Stack should not be empty after push")
--	-- Test that the count of the stack is 1
--	assert(stack:count() == 1, "Stack should have count 1 after push")
--	-- Test that the top value of the stack is the pushed value
--	assert(stack:peek() == 1, "Top value of stack should be the pushed value")
--	-- Pop a value from the stack
--	local poppedValue = stack:pop()
--	-- Test that the popped value is the pushed value
--	assert(poppedValue == 1, "Popped value should be the pushed value")
--	-- Test that the stack is empty after pop
--	assert(stack:isEmpty(), "Stack should be empty after pop")
--	-- Test that the count of the stack is 0 after pop
--	assert(stack:count() == 0, "Stack should have count 0 after pop")
--	-- Test that the top value of the stack is nil after pop
--	assert(stack:peek() == nil, "Top value of stack should be nil after pop")
--	-- Test that the iterator of an empty stack returns nil
--	assert(stack:iterator()() == nil, "Iterator of empty stack should return nil")
--	-- Test pushing nil onto the stack
--	local status, err = pcall(function() stack:push(nil) end)
--	assert(not status and string.find(err, "cannot add a nil value to the stack"), "Pushing nil should throw an error")
--	-- Test popping from an empty stack
--	local poppedValue = stack:pop()
--	assert(poppedValue == nil, "Popping from an empty stack should return nil")
--	-- Test peeking at an empty stack
--	local peekedValue = stack:peek()
--	assert(peekedValue == nil, "Peeking at an empty stack should return nil")
--	-- Test pushing multiple values onto the stack
--	for i = 1, 10 do
--		stack:push(i)
--	end
--	-- Test that the count of the stack is 10
--	assert(stack:count() == 10, "Stack should have count 10 after pushing 10 values")
--	-- Test that the top value of the stack is 10
--	assert(stack:peek() == 10, "Top value of stack should be 10 after pushing 10 values")
--	-- Test the iterator with multiple values
--	local i = 10
--	for value in stack:iterator() do
--		assert(value == i, "Iterator should return values in LIFO order")
--		i = i - 1
--	end
--	-- Test the clear method
--	for i = 1, 10 do
--		stack:push(i)
--	end
--	stack:clear()
--	assert(stack:isEmpty(), "Stack should be empty after clear")
--	assert(stack:count() == 0, "Stack should have count 0 after clear")
--	assert(stack:pop() == nil, "Pop operation should return nil after clear")
--	assert(stack:peek() == nil, "Peek operation should return nil after clear")
--	assert(stack:iterator()() == nil, "Iterator of cleared stack should return nil")
--	-- Test pushing and popping multiple items
--	for i = 1, 10 do
--		stack:push(i)
--	end
--	for i = 10, 1, -1 do
--		assert(stack:pop() == i, "Stack should maintain LIFO order of items")
--	end
--	-- Test clearing the stack and then pushing more items
--	for i = 1, 10 do
--		stack:push(i)
--	end
--	stack:clear()
--	for i = 11, 20 do
--		stack:push(i)
--	end
--	for i = 20, 11, -1 do
--		assert(stack:pop() == i, "Stack should maintain LIFO order after clear")
--	end
--	-- Test pushing a large number of items
--	for i = 1, 10000 do
--		stack:push(i)
--	end
--	assert(stack:count() == 10000, "Stack should handle a large number of items")
--	-- Test pushing different types of values
--	stack:clear()
--	local t = { 1, 2, 3 }
--	stack:push("test")
--	stack:push(t)
--	stack:push(true)
--	assert(stack:pop() == true, "Stack should handle boolean values")
--	assert(stack:pop() == t, "Stack should handle table values")
--	assert(stack:pop() == "test", "Stack should handle string values")
--	print("All tests passed ✔")
--end

-- Export
return Stack
