-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Localized global functions for better performance
local assert = assert
local setmetatable = setmetatable
local string_format = string.format
local table_insert = table.insert
local table_remove = table.remove

--- Define the Stack class.<br>
--- A LIFO (Last-In-First-Out) stack where the most recently added item is removed first.<br>
--- Perfect for undo systems, expression evaluation, or any scenario where you need to reverse the order of operations.
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

function Stack._iter_pairs(self, index)
	index = index + 1
	if index <= #self[1] then
		return index, self[1][index]
	end
end

--- Iterate over stack items using `pairs()`.<br>
--- Yields index and value for each item (bottom to top, 1-based).
---@param self Stack The stack instance.
---@return function iterator Iterator that yields index and value pairs.
---@return table state The stack instance used as iterator state.
---@return integer initial Initial control variable.
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
	return Stack._iter_pairs, self, 0
end

--- Iterate over stack items using `ipairs()`.<br>
--- Yields index and value for each item (bottom to top, 1-based).
---@param self Stack The stack instance.
---@return function iterator Iterator that yields index and value pairs.
---@return table state The stack instance used as iterator state.
---@return integer initial Initial control variable.
function Stack.__ipairs(self)
	return Stack._iter_pairs, self, 0
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

function Stack._iter_values(state, _)
	if state[2] < 1 then
		return
	end
	local value = state[1][state[2]]
	state[2] = state[2] - 1
	return value
end

--- Return an iterator over the stack from top to bottom.<br>
--- Yields each value in the stack in LIFO order.
---@param self Stack The stack instance.
---@return function iterator Iterator that yields each value.
---@return table state The iterator state table.
---@return nil initial Initial control variable.
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
	return Stack._iter_values, { self[1], #self[1] }, nil
end

-- Deprecated aliases (naming standard: snake_case). Kept for compatibility.
Stack.is_empty = Stack.isEmpty

-- Export
return Stack
