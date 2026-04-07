-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Localized global functions for better performance
local assert = assert
local setmetatable = setmetatable
local table_insert = table.insert
local table_remove = table.remove

--- Define the Stack class
---@class Stack
local Stack = {}
Stack.__index = Stack
-- Constructor for Stack
function Stack.new()
	return setmetatable({ {} }, Stack)
end

Stack.__call = Stack.new

-- Method to get the amount of items in the stack
function Stack:count()
	-- Return the length of the container
	return #self[1]
end

-- Method to check if the stack is empty
function Stack:isEmpty()
	-- Check if the container is empty
	return #self[1] == 0
end

-- Method to clear the stack entirely
function Stack:clear()
	-- local t = self[1]
	-- for k in next, t do t[k] = nil end
	self[1] = {}
end

-- Method to add a value to the stack
function Stack:push(value)
	-- Assert that the value is not nil
	assert(value ~= nil, "cannot add a nil value to the stack")
	-- Insert the value into the stack container
	table_insert(self[1], value)
end

-- Method to remove and return the top-most value from the stack
function Stack:pop()
	-- Check if the stack is empty
	if #self[1] == 0 then
		-- If the stack is empty, return
		return
	end
	-- Otherwise, remove and return the top-most value from the stack
	return table_remove(self[1])
end

-- Method to return the top-most value from the stack without removing it
function Stack:peek()
	-- Cache the length of the stack
	local length = #self[1]
	-- If the stack is empty, return
	if length == 0 then
		return
	end
	-- Otherwise, return the top-most value from the stack
	return self[1][length]
end

-- Method to return an iterator over the stack
function Stack:iterator()
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
if false then
	-- Create a new Stack
	local stack = Stack.new()
	-- Test that a new stack is empty
	assert(stack:isEmpty(), "New stack should be empty")
	-- Test that the count of a new stack is 0
	assert(stack:count() == 0, "New stack should have count 0")
	-- Push a value onto the stack
	stack:push(1)
	-- Test that the stack is not empty
	assert(not stack:isEmpty(), "Stack should not be empty after push")
	-- Test that the count of the stack is 1
	assert(stack:count() == 1, "Stack should have count 1 after push")
	-- Test that the top value of the stack is the pushed value
	assert(stack:peek() == 1, "Top value of stack should be the pushed value")
	-- Pop a value from the stack
	local poppedValue = stack:pop()
	-- Test that the popped value is the pushed value
	assert(poppedValue == 1, "Popped value should be the pushed value")
	-- Test that the stack is empty after pop
	assert(stack:isEmpty(), "Stack should be empty after pop")
	-- Test that the count of the stack is 0 after pop
	assert(stack:count() == 0, "Stack should have count 0 after pop")
	-- Test that the top value of the stack is nil after pop
	assert(stack:peek() == nil, "Top value of stack should be nil after pop")
	-- Test that the iterator of an empty stack returns nil
	assert(stack:iterator()() == nil, "Iterator of empty stack should return nil")
	-- Test pushing nil onto the stack
	local status, err = pcall(function() stack:push(nil) end)
	assert(not status and string.find(err, "cannot add a nil value to the stack"), "Pushing nil should throw an error")
	-- Test popping from an empty stack
	local poppedValue = stack:pop()
	assert(poppedValue == nil, "Popping from an empty stack should return nil")
	-- Test peeking at an empty stack
	local peekedValue = stack:peek()
	assert(peekedValue == nil, "Peeking at an empty stack should return nil")
	-- Test pushing multiple values onto the stack
	for i = 1, 10 do
		stack:push(i)
	end
	-- Test that the count of the stack is 10
	assert(stack:count() == 10, "Stack should have count 10 after pushing 10 values")
	-- Test that the top value of the stack is 10
	assert(stack:peek() == 10, "Top value of stack should be 10 after pushing 10 values")
	-- Test the iterator with multiple values
	local i = 10
	for value in stack:iterator() do
		assert(value == i, "Iterator should return values in LIFO order")
		i = i - 1
	end
	-- Test the clear method
	for i = 1, 10 do
		stack:push(i)
	end
	stack:clear()
	assert(stack:isEmpty(), "Stack should be empty after clear")
	assert(stack:count() == 0, "Stack should have count 0 after clear")
	assert(stack:pop() == nil, "Pop operation should return nil after clear")
	assert(stack:peek() == nil, "Peek operation should return nil after clear")
	assert(stack:iterator()() == nil, "Iterator of cleared stack should return nil")
	-- Test pushing and popping multiple items
	for i = 1, 10 do
		stack:push(i)
	end
	for i = 10, 1, -1 do
		assert(stack:pop() == i, "Stack should maintain LIFO order of items")
	end
	-- Test clearing the stack and then pushing more items
	for i = 1, 10 do
		stack:push(i)
	end
	stack:clear()
	for i = 11, 20 do
		stack:push(i)
	end
	for i = 20, 11, -1 do
		assert(stack:pop() == i, "Stack should maintain LIFO order after clear")
	end
	-- Test pushing a large number of items
	for i = 1, 10000 do
		stack:push(i)
	end
	assert(stack:count() == 10000, "Stack should handle a large number of items")
	-- Test pushing different types of values
	stack:clear()
	local t = { 1, 2, 3 }
	stack:push("test")
	stack:push(t)
	stack:push(true)
	assert(stack:pop() == true, "Stack should handle boolean values")
	assert(stack:pop() == t, "Stack should handle table values")
	assert(stack:pop() == "test", "Stack should handle string values")
	print("All tests passed ✔")
end

return Stack
