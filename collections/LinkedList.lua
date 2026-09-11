-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Localized global functions for better performance
local assert = assert
local setmetatable = setmetatable
local string_format = string.format

--- Define the LinkedList class.<br>
--- A singly linked list with O(1) operations at both ends.<br>
--- Perfect for scenarios where you need frequent insertions/deletions at the ends but don't require random access to middle elements.
---@class LinkedList
---@field [1] integer Number of items in the list
---@field [2] table|nil First node in the list
---@field [3] table|nil Last node in the list
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
	return setmetatable({ 0 }, LinkedList)
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
	return self[1]
end

function LinkedList._iter_pairs(state, _)
	local node = state[1]
	if node == nil then
		return
	end
	local value = node[1]
	state[1] = node[2]
	state[2] = state[2] + 1
	return state[2], value
end

--- Iterate over list items using `pairs()`.<br>
--- Yields index and value for each item (front to back, 1-based).
---@param self LinkedList The linked list instance.
---@return function iterator Iterator that yields index and value pairs.
---@return table state The iterator state table.
---@return integer initial Initial control variable.
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
	return LinkedList._iter_pairs, { self[2], 0 }, nil
end

--- Iterate over list items using `ipairs()`.<br>
--- Yields index and value for each item (front to back, 1-based).
---@param self LinkedList The linked list instance.
---@return function iterator Iterator that yields index and value pairs.
---@return table state The iterator state table.
---@return integer initial Initial control variable.
function LinkedList.__ipairs(self)
	return LinkedList._iter_pairs, { self[2], 0 }, nil
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
	return string_format("LinkedList(size=%d)", self[1])
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
	return self[1]
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
	return self[1] == 0
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
	self[1], self[2], self[3] = 0
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
	local node = { value, self[2] }
	if LinkedList.isEmpty(self) then
		self[3] = node
	end
	self[2] = node
	self[1] = self[1] + 1
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
	local node = { value }
	if LinkedList.isEmpty(self) then
		self[2] = node
	else
		self[3][2] = node
	end
	self[3] = node
	self[1] = self[1] + 1
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
	if self[2][1] == existingValue then
		LinkedList.addFirst(self, newValue)
		return
	end
	local node = self[2]
	while node[2] ~= nil and node[2][1] ~= existingValue do
		node = node[2]
	end
	if node[2] ~= nil then
		local newNode = { newValue, node[2] }
		node[2] = newNode
		self[1] = self[1] + 1
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
	local node = self[2]
	while node ~= nil and node[1] ~= existingValue do
		node = node[2]
	end
	if node ~= nil then
		local newNode = { newValue, node[2] }
		node[2] = newNode
		if node == self[3] then
			self[3] = newNode
		end
		self[1] = self[1] + 1
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
	local value = self[2][1]
	self[2] = self[2][2]
	if self[2] == nil then
		self[3] = nil
	end
	self[1] = self[1] - 1
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
	local value = self[3][1]
	if self[1] == 1 then
		self[2] = nil
		self[3] = nil
	else
		local node = self[2]
		while node[2] ~= self[3] do
			node = node[2]
		end
		node[2] = nil
		self[3] = node
	end
	self[1] = self[1] - 1
	return value
end

function LinkedList._iter_values(state, _)
	local node = state[1]
	if node == nil then
		return
	end
	local value = node[1]
	state[1] = node[2]
	return value
end

--- Return an iterator over the linked list from front to back.<br>
--- Yields each value in the list in order.
---@param self LinkedList The linked list instance.
---@return function iterator Iterator that yields each value.
---@return table state The iterator state table.
---@return nil initial Initial control variable.
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
	return LinkedList._iter_values, { self[2] }, nil
end

-- Deprecated aliases (naming standard: snake_case). Kept for compatibility.
LinkedList.is_empty = LinkedList.isEmpty
LinkedList.add_first = LinkedList.addFirst
LinkedList.add_last = LinkedList.addLast
LinkedList.add_before = LinkedList.addBefore
LinkedList.add_after = LinkedList.addAfter
LinkedList.remove_first = LinkedList.removeFirst
LinkedList.remove_last = LinkedList.removeLast

-- Export
return LinkedList
