-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Localized global functions for better performance
local assert = assert
local setmetatable = setmetatable
local string_format = string.format
local table_insert = table.insert
local table_remove = table.remove

--- A double-ended queue that allows adding and removing items from both the front and back.<br>
--- Perfect for implementing sliding windows, undo/redo systems, or any scenario where you need flexible access to both ends.
---@class Deque
---@field [1] table Container table storing the deque items
local Deque = {}
Deque.__index = Deque

--- Create a new Deque instance.<br>
--- A double-ended queue that allows adding and removing from both ends.
---@return Deque deque New Deque instance.
---@usage <br>
--- ```
--- local deque = Deque.new()
--- deque:pushBack(1)
--- deque:pushFront(2)
--- ```
function Deque.new()
	return setmetatable({ {} }, Deque)
end

Deque.__call = Deque.new

--- Get the number of items using `#` operator.<br>
--- Allows using `#deque` instead of `deque:count()`.
---@param self Deque The deque instance.
---@return integer count Number of items in the deque.
---@usage <br>
--- ```
--- local deque = Deque.new()
--- deque:pushBack(1)
--- deque:pushBack(2)
--- print(#deque) -- 2
--- ```
function Deque.__len(self)
	return #self[1]
end

function Deque._iter_pairs(self, index)
	index = index + 1
	if index <= #self[1] then
		return index, self[1][index]
	end
end

--- Iterate over deque items using `pairs()`.<br>
--- Yields index and value for each item (front to back, 1-based).
---@param self Deque The deque instance.
---@return function iterator Iterator that yields index and value pairs.
---@return table state The deque instance used as iterator state.
---@return integer initial Initial control variable.
---@usage <br>
--- ```
--- local deque = Deque.new()
--- deque:pushBack(1)
--- deque:pushBack(2)
--- for index, value in pairs(deque) do
---   print(index, value)
--- end
--- ```
function Deque.__pairs(self)
	return Deque._iter_pairs, self, 0
end

--- Iterate over deque items using `ipairs()`.<br>
--- Yields index and value for each item (front to back, 1-based).
---@param self Deque The deque instance.
---@return function iterator Iterator that yields index and value pairs.
---@return table state The deque instance used as iterator state.
---@return integer initial Initial control variable.
function Deque.__ipairs(self)
	return Deque._iter_pairs, self, 0
end

--- Get string representation of the deque.<br>
--- Returns a string showing the count.
---@param self Deque The deque instance.
---@return string string String representation of the deque.
---@usage <br>
--- ```
--- local deque = Deque.new()
--- deque:pushBack(1)
--- deque:pushBack(2)
--- print(tostring(deque)) -- "Deque(count=2)"
--- ```
function Deque.__tostring(self)
	return string_format("Deque(count=%d)", #self[1])
end

--- Get the number of items in the deque.
---@param self Deque The deque instance.
---@return integer count Number of items in the deque.
---@usage <br>
--- ```
--- local deque = Deque.new()
--- deque:pushBack(1)
--- deque:pushBack(2)
--- print(deque:count()) -- 2
--- ```
function Deque.count(self)
	return #self[1]
end

--- Check if the deque is empty.
---@param self Deque The deque instance.
---@return boolean empty `true` if the deque is empty, `false` otherwise.
---@usage <br>
--- ```
--- local deque = Deque.new()
--- print(deque:isEmpty()) -- true
--- deque:pushBack(1)
--- print(deque:isEmpty()) -- false
--- ```
function Deque.isEmpty(self)
	return #self[1] == 0
end

--- Clear all items from the deque.
---@param self Deque The deque instance.
---@usage <br>
--- ```
--- local deque = Deque.new()
--- deque:pushBack(1)
--- deque:pushBack(2)
--- deque:clear()
--- print(deque:isEmpty()) -- true
--- ```
function Deque.clear(self)
	self[1] = {}
end

--- Add a value to the front of the deque.
---@param self Deque The deque instance.
---@param value any The value to add (cannot be `nil`).
---@usage <br>
--- ```
--- local deque = Deque.new()
--- deque:pushFront(2)
--- deque:pushFront(1)
--- print(deque:peekFront()) -- 1
--- ```
function Deque.pushFront(self, value)
	assert(value ~= nil, "cannot add a nil value to the deque")
	table_insert(self[1], 1, value)
end

--- Add a value to the back of the deque.
---@param self Deque The deque instance.
---@param value any The value to add (cannot be `nil`).
---@usage <br>
--- ```
--- local deque = Deque.new()
--- deque:pushBack(1)
--- deque:pushBack(2)
--- print(deque:peekBack()) -- 2
--- ```
function Deque.pushBack(self, value)
	assert(value ~= nil, "cannot add a nil value to the deque")
	table_insert(self[1], value)
end

--- Remove and return the first value from the deque.<br>
--- Returns `nil` if the deque is empty.
---@param self Deque The deque instance.
---@return any value The removed value, or `nil` if empty.
---@usage <br>
--- ```
--- local deque = Deque.new()
--- deque:pushBack(1)
--- deque:pushBack(2)
--- local value = deque:popFront()
--- print(value) -- 1
--- ```
function Deque.popFront(self)
	if #self[1] == 0 then
		return
	end
	return table_remove(self[1], 1)
end

--- Remove and return the last value from the deque.<br>
--- Returns `nil` if the deque is empty.
---@param self Deque The deque instance.
---@return any value The removed value, or `nil` if empty.
---@usage <br>
--- ```
--- local deque = Deque.new()
--- deque:pushBack(1)
--- deque:pushBack(2)
--- local value = deque:popBack()
--- print(value) -- 2
--- ```
function Deque.popBack(self)
	if #self[1] == 0 then
		return
	end
	return table_remove(self[1])
end

--- Return the first value from the deque without removing it.<br>
--- Returns `nil` if the deque is empty.
---@param self Deque The deque instance.
---@return any value The first value, or `nil` if empty.
---@usage <br>
--- ```
--- local deque = Deque.new()
--- deque:pushBack(1)
--- deque:pushBack(2)
--- print(deque:peekFront()) -- 1
--- print(deque:count()) -- 2 (still has both items)
--- ```
function Deque.peekFront(self)
	if #self[1] == 0 then
		return
	end
	return self[1][1]
end

--- Return the last value from the deque without removing it.<br>
--- Returns `nil` if the deque is empty.
---@param self Deque The deque instance.
---@return any value The last value, or `nil` if empty.
---@usage <br>
--- ```
--- local deque = Deque.new()
--- deque:pushBack(1)
--- deque:pushBack(2)
--- print(deque:peekBack()) -- 2
--- print(deque:count()) -- 2 (still has both items)
--- ```
function Deque.peekBack(self)
	local length = #self[1]
	if length == 0 then
		return
	end
	return self[1][length]
end

function Deque._iter_values(self, index)
	index = index + 1
	if index <= #self[1] then
		return self[1][index]
	end
end

--- Return an iterator over the deque from front to back.<br>
--- Yields each value in the deque in order.
---@param self Deque The deque instance.
---@return function iterator Iterator that yields each value.
---@return table state The deque instance used as iterator state.
---@return integer initial Initial control variable.
---@usage <br>
--- ```
--- local deque = Deque.new()
--- deque:pushBack(1)
--- deque:pushBack(2)
--- deque:pushBack(3)
--- for value in deque:iterator() do
---   print(value)
--- end
--- -- Outputs: 1, 2, 3
--- ```
function Deque.iterator(self)
	return Deque._iter_values, self, 0
end

-- Deprecated aliases (naming standard: snake_case). Kept for compatibility.
Deque.is_empty = Deque.isEmpty
Deque.push_front = Deque.pushFront
Deque.push_back = Deque.pushBack
Deque.pop_front = Deque.popFront
Deque.pop_back = Deque.popBack
Deque.peek_front = Deque.peekFront
Deque.peek_back = Deque.peekBack

-- Export
return Deque
