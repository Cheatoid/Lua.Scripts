-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Localized global functions for better performance
local assert = assert
local setmetatable = setmetatable
local string_format = string.format

--- Define the LinkedList class
---@class LinkedList
---@field size integer Number of items in the list
---@field head table|nil First node in the list
---@field tail table|nil Last node in the list
local LinkedList = {}
LinkedList.__index = LinkedList

--- Create a new LinkedList instance.<br>
--- A singly linked list with O(1) operations at both ends.
---@return LinkedList list New LinkedList instance.
---@usage <br>
--- ```
--- local list = LinkedList.new()
--- list:addLast(1)
--- list:addLast(2)
--- ```
function LinkedList.new()
	return setmetatable({ size = 0 }, LinkedList)
end

LinkedList.__call = LinkedList.new

--- Get the number of items using `#` operator.<br>
--- Allows using `#list` instead of `list:count()`.
---@param self LinkedList The linked list instance.
---@return integer count Number of items in the list.
---@usage <br>
--- ```
--- local list = LinkedList.new()
--- list:addLast(1)
--- list:addLast(2)
--- print(#list) -- 2
--- ```
function LinkedList.__len(self)
	return self.size
end

--- Iterate over list items using `pairs()`.<br>
--- Yields index and value for each item (front to back, 1-based).
---@param self LinkedList The linked list instance.
---@return function iterator Iterator that yields index and value pairs.
---@usage <br>
--- ```
--- local list = LinkedList.new()
--- list:addLast(1)
--- list:addLast(2)
--- for index, value in pairs(list) do
---   print(index, value)
--- end
--- ```
function LinkedList.__pairs(self)
	local node = self.head
	local index = 0
	return function()
		if node == nil then
			return
		end
		index = index + 1
		local value = node.value
		node = node.next
		return index, value
	end
end

--- Iterate over list items using `ipairs()`.<br>
--- Yields index and value for each item (front to back, 1-based).
---@param self LinkedList The linked list instance.
---@return function iterator Iterator that yields index and value pairs.
function LinkedList.__ipairs(self)
	local node = self.head
	local index = 0
	return function()
		if node == nil then
			return
		end
		index = index + 1
		local value = node.value
		node = node.next
		return index, value
	end
end

--- Get string representation of the linked list.<br>
--- Returns a string showing the size.
---@param self LinkedList The linked list instance.
---@return string string String representation of the linked list.
---@usage <br>
--- ```
--- local list = LinkedList.new()
--- list:addLast(1)
--- list:addLast(2)
--- print(tostring(list)) -- "LinkedList(size=2)"
--- ```
function LinkedList.__tostring(self)
	return string_format("LinkedList(size=%d)", self.size)
end

--- Get the number of items in the linked list.
---@param self LinkedList The linked list instance.
---@return integer count Number of items in the list.
---@usage <br>
--- ```
--- local list = LinkedList.new()
--- list:addLast(1)
--- list:addLast(2)
--- print(list:count()) -- 2
--- ```
function LinkedList.count(self)
	return self.size
end

--- Check if the linked list is empty.
---@param self LinkedList The linked list instance.
---@return boolean empty `true` if the list is empty, `false` otherwise.
---@usage <br>
--- ```
--- local list = LinkedList.new()
--- print(list:isEmpty()) -- true
--- list:addLast(1)
--- print(list:isEmpty()) -- false
--- ```
function LinkedList.isEmpty(self)
	return self.size == 0
end

--- Clear all items from the linked list.
---@param self LinkedList The linked list instance.
---@usage <br>
--- ```
--- local list = LinkedList.new()
--- list:addLast(1)
--- list:addLast(2)
--- list:clear()
--- print(list:isEmpty()) -- true
--- ```
function LinkedList.clear(self)
	self.head = nil
	self.tail = nil
	self.size = 0
end

--- Add a value to the front of the linked list.
---@param self LinkedList The linked list instance.
---@param value any The value to add (cannot be `nil`).
---@usage <br>
--- ```
--- local list = LinkedList.new()
--- list:addFirst(2)
--- list:addFirst(1)
--- print(list:removeFirst()) -- 1
--- ```
function LinkedList.addFirst(self, value)
	assert(value ~= nil, "cannot add a nil value to the linked list")
	local node = { value = value, next = self.head }
	if LinkedList.isEmpty(self) then
		self.tail = node
	end
	self.head = node
	self.size = self.size + 1
end

--- Add a value to the back of the linked list.
---@param self LinkedList The linked list instance.
---@param value any The value to add (cannot be `nil`).
---@usage <br>
--- ```
--- local list = LinkedList.new()
--- list:addLast(1)
--- list:addLast(2)
--- print(list:removeFirst()) -- 1
--- ```
function LinkedList.addLast(self, value)
	assert(value ~= nil, "cannot add a nil value to the linked list")
	local node = { value = value, next = nil }
	if LinkedList.isEmpty(self) then
		self.head = node
	else
		self.tail.next = node
	end
	self.tail = node
	self.size = self.size + 1
end

--- Add a value before an existing value in the linked list.<br>
--- Does nothing if the existing value is not found or list is empty.
---@param self LinkedList The linked list instance.
---@param existingValue any The value to insert before (cannot be `nil`).
---@param newValue any The new value to insert (cannot be `nil`).
---@usage <br>
--- ```
--- local list = LinkedList.new()
--- list:addLast(1)
--- list:addLast(3)
--- list:addBefore(3, 2)
--- -- List now contains: 1, 2, 3
--- ```
function LinkedList.addBefore(self, existingValue, newValue)
	assert(existingValue ~= nil, "existing value cannot be nil")
	assert(newValue ~= nil, "new value cannot be nil")
	if LinkedList.isEmpty(self) then
		return
	end
	if self.head.value == existingValue then
		LinkedList.addFirst(self, newValue)
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

--- Add a value after an existing value in the linked list.<br>
--- Does nothing if the existing value is not found or list is empty.
---@param self LinkedList The linked list instance.
---@param existingValue any The value to insert after (cannot be `nil`).
---@param newValue any The new value to insert (cannot be `nil`).
---@usage <br>
--- ```
--- local list = LinkedList.new()
--- list:addLast(1)
--- list:addLast(2)
--- list:addAfter(2, 3)
--- -- List now contains: 1, 2, 3
--- ```
function LinkedList.addAfter(self, existingValue, newValue)
	assert(existingValue ~= nil, "existing value cannot be nil")
	assert(newValue ~= nil, "new value cannot be nil")
	if LinkedList.isEmpty(self) then
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

--- Remove and return the first value from the linked list.<br>
--- Returns `nil` if the list is empty.
---@param self LinkedList The linked list instance.
---@return any value The removed value, or `nil` if empty.
---@usage <br>
--- ```
--- local list = LinkedList.new()
--- list:addLast(1)
--- list:addLast(2)
--- local value = list:removeFirst()
--- print(value) -- 1
--- ```
function LinkedList.removeFirst(self)
	if LinkedList.isEmpty(self) then
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

--- Remove and return the last value from the linked list.<br>
--- Returns `nil` if the list is empty.
---@param self LinkedList The linked list instance.
---@return any value The removed value, or `nil` if empty.
---@usage <br>
--- ```
--- local list = LinkedList.new()
--- list:addLast(1)
--- list:addLast(2)
--- local value = list:removeLast()
--- print(value) -- 2
--- ```
function LinkedList.removeLast(self)
	if LinkedList.isEmpty(self) then
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

--- Return an iterator over the linked list from front to back.<br>
--- Yields each value in the list in order.
---@param self LinkedList The linked list instance.
---@return function iterator Iterator that yields each value.
---@usage <br>
--- ```
--- local list = LinkedList.new()
--- list:addLast(1)
--- list:addLast(2)
--- list:addLast(3)
--- for value in list:iterator() do
---   print(value)
--- end
--- -- Outputs: 1, 2, 3
--- ```
function LinkedList.iterator(self)
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

-- Export
return LinkedList
