-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Localized global functions for better performance
local assert = assert
local setmetatable = setmetatable
local table_insert = table.insert
local table_remove = table.remove

--- Define the Deque class
---@class Deque
local Deque = {}
Deque.__index = Deque
-- Constructor for Deque
function Deque.new()
	return setmetatable({ {} }, Deque)
end

Deque.__call = Deque.new

-- Method to get the amount of items in the deque
function Deque:count()
	-- Return the length of the container
	return #self[1]
end

-- Method to check if the deque is empty
function Deque:isEmpty()
	-- Check if the container is empty
	return #self[1] == 0
end

-- Method to clear the deque entirely
function Deque:clear()
	-- local t = self[1]
	-- for k in next, t do t[k] = nil end
	self[1] = {}
end

-- Method to add a value to the front of the deque
function Deque:pushFront(value)
	-- Assert that the value is not nil
	assert(value ~= nil, "cannot add a nil value to the deque")
	-- Insert the value into the front of the deque container
	table_insert(self[1], 1, value)
end

-- Method to add a value to the back of the deque
function Deque:pushBack(value)
	-- Assert that the value is not nil
	assert(value ~= nil, "cannot add a nil value to the deque")
	-- Insert the value into the back of the deque container
	table_insert(self[1], value)
end

-- Method to remove and return the first value from the deque
function Deque:popFront()
	-- Check if the deque is empty
	if #self[1] == 0 then
		-- If the deque is empty, return
		return
	end
	-- Otherwise, remove and return the first value from the deque
	return table_remove(self[1], 1)
end

-- Method to remove and return the last value from the deque
function Deque:popBack()
	-- Check if the deque is empty
	if #self[1] == 0 then
		-- If the deque is empty, return
		return
	end
	-- Otherwise, remove and return the last value from the deque
	return table_remove(self[1])
end

-- Method to return the first value from the deque without removing it
function Deque:peekFront()
	-- If the deque is empty, return
	if #self[1] == 0 then
		return
	end
	-- Otherwise, return the first value from the deque
	return self[1][1]
end

-- Method to return the last value from the deque without removing it
function Deque:peekBack()
	-- Cache the length of the deque
	local length = #self[1]
	-- If the deque is empty, return
	if length == 0 then
		return
	end
	-- Otherwise, return the last value from the deque
	return self[1][length]
end

-- Method to return an iterator over the deque from front to back
function Deque:iterator()
	local i = 1
	return function()
		if i > #self[1] then
			return
		end
		local value = self[1][i]
		i = i + 1
		return value
	end
end

-- Test the Deque class
--if true then
--	-- Create a new Deque
--	local deque = Deque.new()
--	-- Test that the deque is initially empty
--	assert(deque:isEmpty(), "Deque should be empty initially")
--	-- Test pushFront operation
--	deque:pushFront(1)
--	assert(deque:count() == 1, "Deque should have 1 item after pushFront")
--	assert(deque:peekFront() == 1, "peekFront should return the first item in the deque")
--	assert(deque:peekBack() == 1, "peekBack should return the last item in the deque")
--	-- Test pushBack operation
--	deque:pushBack(2)
--	assert(deque:count() == 2, "Deque should have 2 items after pushBack")
--	assert(deque:peekFront() == 1, "peekFront should return the first item in the deque")
--	assert(deque:peekBack() == 2, "peekBack should return the last item in the deque")
--	-- Test popFront operation
--	local item = deque:popFront()
--	assert(item == 1, "popFront should return the first item in the deque")
--	assert(deque:count() == 1, "Deque should have 1 item after popFront")
--	assert(deque:peekFront() == 2, "peekFront should return the first item in the deque")
--	assert(deque:peekBack() == 2, "peekBack should return the last item in the deque")
--	-- Test popBack operation
--	item = deque:popBack()
--	assert(item == 2, "popBack should return the last item in the deque")
--	assert(deque:isEmpty(), "Deque should be empty after popBack")
--	-- Test iterator operation on empty deque
--	local count = 0
--	for _ in deque:iterator() do
--		count = count + 1
--	end
--	assert(count == 0, "Iterator operation should not return any items when the deque is empty")
--	-- Test pushFront and pushBack operations with nil
--	local status, err = pcall(function() deque:pushFront(nil) end)
--	assert(not status and string.find(err, "cannot add a nil value to the deque"),
--		"pushFront operation should fail when trying to add nil")
--	status, err = pcall(function() deque:pushBack(nil) end)
--	assert(not status and string.find(err, "cannot add a nil value to the deque"),
--		"pushBack operation should fail when trying to add nil")
--	-- Test popFront and popBack operations on empty deque
--	item = deque:popFront()
--	assert(item == nil, "popFront operation should return nil when the deque is empty")
--	item = deque:popBack()
--	assert(item == nil, "popBack operation should return nil when the deque is empty")
--	-- Test peekFront and peekBack operations on empty deque
--	item = deque:peekFront()
--	assert(item == nil, "peekFront operation should return nil when the deque is empty")
--	item = deque:peekBack()
--	assert(item == nil, "peekBack operation should return nil when the deque is empty")
--	-- Test clear operation
--	deque:pushFront(1)
--	deque:pushBack(2)
--	deque:clear()
--	assert(deque:isEmpty() and deque:count() == 0, "Deque should be empty after clear")
--	-- Test with different types of values
--	local t = { 1, 2, 3 }
--	local f = function() return 4 end
--	deque:pushFront("test")
--	deque:pushBack(t)
--	deque:pushFront(f)
--	assert(deque:count() == 3, "Deque should have 3 items after adding different types of values")
--	assert(deque:popFront() == f, "popFront should return the function")
--	assert(deque:popBack() == t, "popBack should return the table")
--	assert(deque:popFront() == "test", "popFront should return the string")
--	-- Test with multiple values
--	for i = 1, 10 do
--		deque:pushFront(i)
--	end
--	assert(deque:count() == 10, "Deque should have 10 items after adding multiple values")
--	for i = 10, 1, -1 do
--		assert(deque:popFront() == i, "popFront should return the correct value")
--	end
--	assert(deque:isEmpty(), "Deque should be empty after removing all items")
--	print("All tests passed ✔")
--end

-- Export
return Deque
