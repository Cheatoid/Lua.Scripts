-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Localized global functions for better performance
local assert = assert
local setmetatable = setmetatable

--- Define the LinkedList class
---@class LinkedList
local LinkedList = {}
LinkedList.__index = LinkedList
-- Constructor for LinkedList
function LinkedList.new()
	return setmetatable({ size = 0 }, LinkedList)
end

LinkedList.__call = LinkedList.new

-- Method to get the amount of items in the linked list
function LinkedList:count()
	return self.size
end

-- Method to check if the linked list is empty
function LinkedList:isEmpty()
	return self.size == 0
end

-- Method to clear the linked list entirely
function LinkedList:clear()
	self.head = nil
	self.tail = nil
	self.size = 0
end

-- Method to add a value to the front of the linked list
function LinkedList:addFirst(value)
	assert(value ~= nil, "cannot add a nil value to the linked list")
	local node = { value = value, next = self.head }
	if self:isEmpty() then
		self.tail = node
	end
	self.head = node
	self.size = self.size + 1
end

-- Method to add a value to the back of the linked list
function LinkedList:addLast(value)
	assert(value ~= nil, "cannot add a nil value to the linked list")
	local node = { value = value, next = nil }
	if self:isEmpty() then
		self.head = node
	else
		self.tail.next = node
	end
	self.tail = node
	self.size = self.size + 1
end

-- Method to add a value before an existing value in the linked list
function LinkedList:addBefore(existingValue, newValue)
	assert(existingValue ~= nil, "existing value cannot be nil")
	assert(newValue ~= nil, "new value cannot be nil")
	if self:isEmpty() then
		return
	end
	if self.head.value == existingValue then
		self:addFirst(newValue)
		return
	end
	local node = self.head
	while node.next ~= nil and node.next.value ~= existingValue do
		node = node.next
	end
	if node.next ~= nil then
		local newNode = { value = newValue, next = node.next }
		node.next = newNode
		self.size = self.size + 1
	end
end

-- Method to add a value after an existing value in the linked list
function LinkedList:addAfter(existingValue, newValue)
	assert(existingValue ~= nil, "existing value cannot be nil")
	assert(newValue ~= nil, "new value cannot be nil")
	if self:isEmpty() then
		return
	end
	local node = self.head
	while node ~= nil and node.value ~= existingValue do
		node = node.next
	end
	if node ~= nil then
		local newNode = { value = newValue, next = node.next }
		node.next = newNode
		if node == self.tail then
			self.tail = newNode
		end
		self.size = self.size + 1
	end
end

-- Method to remove and return the first value from the linked list
function LinkedList:removeFirst()
	if self:isEmpty() then
		return
	end
	local value = self.head.value
	self.head = self.head.next
	if self.head == nil then
		self.tail = nil
	end
	self.size = self.size - 1
	return value
end

-- Method to remove and return the last value from the linked list
function LinkedList:removeLast()
	if self:isEmpty() then
		return
	end
	local value = self.tail.value
	if self.size == 1 then
		self.head = nil
		self.tail = nil
	else
		local node = self.head
		while node.next ~= self.tail do
			node = node.next
		end
		node.next = nil
		self.tail = node
	end
	self.size = self.size - 1
	return value
end

-- Method to return an iterator over the linked list from front to back
function LinkedList:iterator()
	local node = self.head
	return function()
		if node == nil then
			return
		end
		local value = node.value
		node = node.next
		return value
	end
end

-- Test the LinkedList class
--if true then
--	local list = LinkedList.new()
--	assert(list:isEmpty(), "LinkedList should be empty initially")
--	list:addFirst(1)
--	assert(list:count() == 1, "LinkedList should have 1 item after addFirst")
--	list:addLast(2)
--	assert(list:count() == 2, "LinkedList should have 2 items after addLast")
--	assert(list:removeFirst() == 1, "removeFirst should return the first item in the LinkedList")
--	assert(list:count() == 1, "LinkedList should have 1 item after removeFirst")
--	assert(list:removeLast() == 2, "removeLast should return the last item in the LinkedList")
--	assert(list:isEmpty(), "LinkedList should be empty after removeLast")
--	local status, err = pcall(function() list:addFirst(nil) end)
--	assert(not status and string.find(err, "cannot add a nil value to the linked list"),
--		"addFirst operation should fail when trying to add nil")
--	status, err = pcall(function() list:addLast(nil) end)
--	assert(not status and string.find(err, "cannot add a nil value to the linked list"),
--		"addLast operation should fail when trying to add nil")
--	assert(list:removeFirst() == nil, "removeFirst operation should return nil when the LinkedList is empty")
--	assert(list:removeLast() == nil, "removeLast operation should return nil when the LinkedList is empty")
--	for i = 1, 10 do
--		list:addFirst(i)
--	end
--	assert(list:count() == 10, "LinkedList should have 10 items after adding multiple values")
--	for i = 10, 1, -1 do
--		assert(list:removeFirst() == i, "removeFirst should return the correct value")
--	end
--	assert(list:isEmpty(), "LinkedList should be empty after removing all items")
--	-- Test clear operation
--	list:addFirst(1)
--	list:addLast(2)
--	list:clear()
--	assert(list:isEmpty() and list:count() == 0, "LinkedList should be empty after clear")
--	-- Test with different types of values
--	local t = { 1, 2, 3 }
--	local f = function() return 4 end
--	list:addFirst("test")
--	list:addLast(t)
--	list:addFirst(f)
--	assert(list:count() == 3, "LinkedList should have 3 items after adding different types of values")
--	assert(list:removeFirst() == f, "removeFirst should return the function")
--	assert(list:removeLast() == t, "removeLast should return the table")
--	assert(list:removeFirst() == "test", "removeFirst should return the string")
--	-- Test with multiple values
--	for i = 1, 10 do
--		list:addFirst(i)
--	end
--	assert(list:count() == 10, "LinkedList should have 10 items after adding multiple values")
--	for i = 10, 1, -1 do
--		assert(list:removeFirst() == i, "removeFirst should return the correct value")
--	end
--	assert(list:isEmpty(), "LinkedList should be empty after removing all items")
--	-- Test iterator operation on empty list
--	local count = 0
--	for _ in list:iterator() do
--		count = count + 1
--	end
--	assert(count == 0, "Iterator operation should not return any items when the LinkedList is empty")
--	-- Test iterator operation on non-empty list
--	for i = 1, 5 do
--		list:addLast(i)
--	end
--	local expected = 1
--	for value in list:iterator() do
--		assert(value == expected, "Iterator operation should return the correct value")
--		expected = expected + 1
--	end
--	print("All tests passed ✔")
--end

return LinkedList
