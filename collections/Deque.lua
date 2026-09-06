-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Localized global functions for better performance
local assert = assert
local setmetatable = setmetatable
local string_format = string.format
local table_insert = table.insert
local table_remove = table.remove

--- Define the Deque class.<br>
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

--[[ Test the Deque class
if true then
	-- Create a new Deque
	local deque = Deque.new()
	-- Test that the deque is initially empty
	assert(deque:isEmpty(), "Deque should be empty initially")
	-- Test pushFront operation
	deque:pushFront(1)
	assert(deque:count() == 1, "Deque should have 1 item after pushFront")
	assert(deque:peekFront() == 1, "peekFront should return the first item in the deque")
	assert(deque:peekBack() == 1, "peekBack should return the last item in the deque")
	-- Test pushBack operation
	deque:pushBack(2)
	assert(deque:count() == 2, "Deque should have 2 items after pushBack")
	assert(deque:peekFront() == 1, "peekFront should return the first item in the deque")
	assert(deque:peekBack() == 2, "peekBack should return the last item in the deque")
	-- Test popFront operation
	local item = deque:popFront()
	assert(item == 1, "popFront should return the first item in the deque")
	assert(deque:count() == 1, "Deque should have 1 item after popFront")
	assert(deque:peekFront() == 2, "peekFront should return the first item in the deque")
	assert(deque:peekBack() == 2, "peekBack should return the last item in the deque")
	-- Test popBack operation
	item = deque:popBack()
	assert(item == 2, "popBack should return the last item in the deque")
	assert(deque:isEmpty(), "Deque should be empty after popBack")
	-- Test iterator operation on empty deque
	local count = 0
	for _ in deque:iterator() do
		count = count + 1
	end
	assert(count == 0, "Iterator operation should not return any items when the deque is empty")
	-- Test pushFront and pushBack operations with nil
	local status, err = pcall(function() deque:pushFront(nil) end)
	assert(not status and string.find(err, "cannot add a nil value to the deque"),
		"pushFront operation should fail when trying to add nil")
	status, err = pcall(function() deque:pushBack(nil) end)
	assert(not status and string.find(err, "cannot add a nil value to the deque"),
		"pushBack operation should fail when trying to add nil")
	-- Test popFront and popBack operations on empty deque
	item = deque:popFront()
	assert(item == nil, "popFront operation should return nil when the deque is empty")
	item = deque:popBack()
	assert(item == nil, "popBack operation should return nil when the deque is empty")
	-- Test peekFront and peekBack operations on empty deque
	item = deque:peekFront()
	assert(item == nil, "peekFront operation should return nil when the deque is empty")
	item = deque:peekBack()
	assert(item == nil, "peekBack operation should return nil when the deque is empty")
	-- Test clear operation
	deque:pushFront(1)
	deque:pushBack(2)
	deque:clear()
	assert(deque:isEmpty() and deque:count() == 0, "Deque should be empty after clear")
	-- Test with different types of values
	local t = { 1, 2, 3 }
	local f = function() return 4 end
	deque:pushFront("test")
	deque:pushBack(t)
	deque:pushFront(f)
	assert(deque:count() == 3, "Deque should have 3 items after adding different types of values")
	assert(deque:popFront() == f, "popFront should return the function")
	assert(deque:popBack() == t, "popBack should return the table")
	assert(deque:popFront() == "test", "popFront should return the string")
	-- Test with multiple values
	for i = 1, 10 do
		deque:pushFront(i)
	end
	assert(deque:count() == 10, "Deque should have 10 items after adding multiple values")
	for i = 10, 1, -1 do
		assert(deque:popFront() == i, "popFront should return the correct value")
	end
	assert(deque:isEmpty(), "Deque should be empty after removing all items")
	-- Test __ipairs iteration
	deque:clear()
	deque:pushBack(1)
	deque:pushBack(2)
	deque:pushBack(3)
	local ipairs_count = 0
	for index, value in deque:__ipairs() do
		ipairs_count = ipairs_count + 1
		assert(index == value, "__ipairs() should return index and value in deque order")
	end
	assert(ipairs_count == 3, "__ipairs() should iterate over all 3 items")
	print("All tests passed")
end
--]]

-- Export
return Deque
