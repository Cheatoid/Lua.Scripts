-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Localized global functions for better performance
local next = next
local rawget = rawget
local rawset = rawset
local setmetatable = setmetatable
local string_format = string.format

--- Define the BiMap class.<br>
--- A bidirectional map that allows O(1) lookups in both directions. Each element gets a unique index that never repeats, enabling both index->value and value->index lookups.<br>
--- Perfect for entity management where you need to quickly find items by either ID or value.
---@class BiMap
---@field [1] table<integer, any> The sparse array holding the actual elements
---@field [2] integer Tracks the number of active (non-nil) elements
---@field [3] integer The monotonically increasing index generator
---@field [4] table<any, integer> Reverse lookup table: value -> index
---@field [5] {[1]: table<integer, any>, [2]: integer} Iterator state table (data reference and limit)
local BiMap = {}
BiMap.__index = BiMap

--- Create a new BiMap instance.<br>
--- A bidirectional map data structure with O(1) add, remove, and lookup operations in both directions.<br>
--- Each element is assigned a unique monotonically increasing index that is never reused.<br>
--- Supports both index->value and value->index lookups.
---@return BiMap bimap New BiMap instance.
---@usage <br>
--- ```
--- local bimap = BiMap.new()
--- local id1 = bimap:add("Apple")
--- local id2 = bimap:add("Banana")
--- print(bimap:get_index("Apple")) -- 1
--- print(bimap:contains("Apple")) -- true
--- bimap:removeByValue("Apple")
--- ```
function BiMap.new()
	local data = {}
	return setmetatable({ data, 0, 1, {}, { data, 0 } }, BiMap)
end

BiMap.__call = BiMap.new

--- Get the index of a value.<br>
--- Returns the index associated with the given value, or `nil` if the value is not in the BiMap.
---@param self BiMap The BiMap instance.
---@param value any The value to look up.
---@return integer|nil index The index of the value, or `nil` if not found.
---@usage <br>
--- ```
--- local bimap = BiMap.new()
--- local id = bimap:add("Apple")
--- print(bimap:get_index("Apple")) -- 1
--- print(bimap:get_index("Banana")) -- nil
--- ```
function BiMap.get_index(self, value)
	return rawget(self[4], value)
end

--- Check if a value exists in the BiMap.<br>
--- Returns `true` if the value is present in the BiMap.
---@param self BiMap The BiMap instance.
---@param value any The value to check for.
---@return boolean result `true` if the value exists, `false` otherwise.
---@usage <br>
--- ```
--- local bimap = BiMap.new()
--- bimap:add("Apple")
--- print(bimap:contains("Apple")) -- true
--- print(bimap:contains("Banana")) -- false
--- ```
function BiMap.contains(self, value)
	return rawget(self[4], value) ~= nil
end

--- Add a new element to the BiMap.<br>
--- Assigns a unique monotonically increasing index that is never reused.<br>
--- If the value already exists, returns its existing index instead of adding a duplicate.
---@param self BiMap The BiMap instance.
---@param value any The value to store.
---@return integer index The unique index assigned to this value (or existing index if duplicate).
---@usage <br>
--- ```
--- local bimap = BiMap.new()
--- local id1 = bimap:add("Apple")
--- local id2 = bimap:add("Banana")
--- local id3 = bimap:add("Apple") -- Returns id1 (existing)
--- print(id1, id2, id3) -- 1, 2, 1
--- ```
function BiMap.add(self, value)
	local rev = self[4]
	local existing_index = rawget(rev, value)
	if existing_index then
		return existing_index
	end

	local data = self[1]
	local index = self[3]

	rawset(data, index, value)
	rawset(rev, value, index)

	self[3] = index + 1
	self[2] = self[2] + 1

	return index
end

--- Remove an element by its explicit index.<br>
--- O(1) removal without shifting or `table.remove()`. Also removes the reverse lookup entry.
---@param self BiMap The BiMap instance.
---@param index integer The index returned from `BiMap:add()`.
---@usage <br>
--- ```
--- local bimap = BiMap.new()
--- local id = bimap:add("Apple")
--- bimap:remove(id)
--- print(bimap:contains("Apple")) -- false
--- ```
function BiMap.remove(self, index)
	local data = self[1]
	local value = rawget(data, index)

	if value ~= nil then
		rawset(data, index, nil)
		rawset(self[4], value, nil)
		self[2] = self[2] - 1
	end
end

--- Remove an element by its value.<br>
--- Removes the element associated with the given value using reverse lookup.
---@param self BiMap The BiMap instance.
---@param value any The value to remove.
---@usage <br>
--- ```
--- local bimap = BiMap.new()
--- bimap:add("Apple")
--- bimap:removeByValue("Apple")
--- print(bimap:contains("Apple")) -- false
--- ```
function BiMap.removeByValue(self, value)
	local index = rawget(self[4], value)
	if index then
		self:remove(index)
	end
end

--- Get the number of active elements using `#` operator.<br>
--- Allows using `#bimap` instead of `bimap:count()`.
---@param self BiMap The BiMap instance.
---@return integer count Number of active elements.
---@usage <br>
--- ```
--- local bimap = BiMap.new()
--- bimap:add(1)
--- bimap:add(2)
--- print(#bimap) -- 2
--- ```
function BiMap.__len(self)
	return self[2]
end

--- Iterate over active elements using `pairs()`.<br>
--- Unordered iteration using `next`, which natively skips over nil entries.<br>
--- No extra memory allocation for iteration.
---@param self BiMap The BiMap instance.
---@return function iterator Iterator function.
---@return table state The internal data table (used as state).
---@return nil initial Initial control variable.
---@usage <br>
--- ```
--- local bimap = BiMap.new()
--- bimap:add("Apple")
--- bimap:add("Banana")
--- for index, value in pairs(bimap) do
---   print(index, value)
--- end
--- ```
function BiMap.__pairs(self)
	return next, self[1]
end

local function ipairs_next(state, current_index)
	local data = state[1]
	local limit = state[2]
	for i = (current_index or 0) + 1, limit do
		if rawget(data, i) ~= nil then
			return i, data[i]
		end
	end
end

--- Iterate over active elements using `ipairs()`.<br>
--- Ordered numeric iteration that safely skips over "holes" (removed elements).<br>
--- Guarantees ascending numeric order, unlike `pairs()`.
---@param self BiMap The BiMap instance.
---@return function iterator Iterator function.
---@return table state Snapshot state table (data reference and max bound).
---@return integer|nil initial Initial control variable.
---@usage <br>
--- ```
--- local bimap = BiMap.new()
--- local id1 = bimap:add("Apple")
--- local id2 = bimap:add("Banana")
--- bimap:remove(id2)
--- local id3 = bimap:add("Cherry")
--- for index, value in ipairs(bimap) do
---   print(index, value) -- 1 "Apple", 3 "Cherry"
--- end
--- ```
function BiMap.__ipairs(self)
	--local state = { self[1], self[3] } -- allocation
	local state = self[5]
	state[1], state[2] = self[1], self[3]
	return ipairs_next, state, 0
end

--- Get string representation of the BiMap.<br>
--- Returns a string showing the count.
---@param self BiMap The BiMap instance.
---@return string string String representation of the BiMap.
---@usage <br>
--- ```
--- local bimap = BiMap.new()
--- bimap:add(1)
--- bimap:add(2)
--- print(tostring(bimap)) -- "BiMap(count=2)"
--- ```
function BiMap.__tostring(self)
	return string_format("BiMap(count=%d)", self[2])
end

--- Get the number of active elements.
---@param self BiMap The BiMap instance.
---@return integer count Number of active elements.
---@usage <br>
--- ```
--- local bimap = BiMap.new()
--- bimap:add(1)
--- bimap:add(2)
--- print(bimap:count()) -- 2
--- ```
function BiMap.count(self)
	return self[2]
end

--- Check if the BiMap is empty.
---@param self BiMap The BiMap instance.
---@return boolean empty `true` if the BiMap is empty, `false` otherwise.
---@usage <br>
--- ```
--- local bimap = BiMap.new()
--- print(bimap:isEmpty()) -- true
--- bimap:add(1)
--- print(bimap:isEmpty()) -- false
--- ```
function BiMap.isEmpty(self)
	return self[2] == 0
end

--- Clear all elements from the BiMap.<br>
--- Resets the data table, reverse lookup, and count, but preserves the next_index for uniqueness.
---@param self BiMap The BiMap instance.
---@usage <br>
--- ```
--- local bimap = BiMap.new()
--- bimap:add(1)
--- bimap:add(2)
--- bimap:clear()
--- print(bimap:isEmpty()) -- true
--- ```
function BiMap.clear(self)
	self[1] = {}
	self[2] = 0
	self[4] = {}
	self[5][1], self[5][2] = self[1], 0
end

--- Check if an index exists in the BiMap.<br>
--- Returns `true` if the index has an active value.
---@param self BiMap The BiMap instance.
---@param index integer The index to check for.
---@return boolean result `true` if the index exists, `false` otherwise.
---@usage <br>
--- ```
--- local bimap = BiMap.new()
--- local id = bimap:add("Apple")
--- print(bimap:containsIndex(id)) -- true
--- bimap:remove(id)
--- print(bimap:containsIndex(id)) -- false
--- ```
function BiMap.containsIndex(self, index)
	return rawget(self[1], index) ~= nil
end

--- Return an iterator over the BiMap values.<br>
--- Yields each value in the BiMap in no particular order.
---@param self BiMap The BiMap instance.
---@return function iterator Iterator that yields each value.
---@usage <br>
--- ```
--- local bimap = BiMap.new()
--- bimap:add("Apple")
--- bimap:add("Banana")
--- bimap:add("Cherry")
--- for value in bimap:iterator() do
---   print(value)
--- end
--- ```
function BiMap.iterator(self)
	local items = self[1]
	local key
	return function()
		key = next(items, key)
		if key ~= nil then
			return items[key]
		end
	end
end

--[[ Quick tests
if true then
	-- Test the BiMap class
	do
		-- Create a new bimap
		local bimap = BiMap.new()
		-- Test that the bimap is initially empty
		assert(bimap:isEmpty(), "BiMap should be empty after creation")
		-- Test that the count of items in the bimap is initially 0
		assert(bimap:count() == 0, "BiMap count should be 0 after creation")
		-- Add a value to the bimap
		local id1 = bimap:add("Apple")
		-- Test that the bimap is not empty after adding a value
		assert(not bimap:isEmpty(), "BiMap should not be empty after adding a value")
		-- Test that the count of items in the bimap is 1 after adding a value
		assert(bimap:count() == 1, "BiMap count should be 1 after adding a value")
		-- Test that the index returned is 1
		assert(id1 == 1, "First index should be 1")
		-- Test getting the index of a value
		assert(bimap:get_index("Apple") == 1, "get_index should return 1 for Apple")
		-- Test checking if a value exists
		assert(bimap:contains("Apple"), "BiMap should contain Apple")
		assert(not bimap:contains("Banana"), "BiMap should not contain Banana")
		-- Test adding another value
		local id2 = bimap:add("Banana")
		assert(id2 == 2, "Second index should be 2")
		assert(bimap:count() == 2, "BiMap count should be 2 after adding second value")
		-- Test adding a duplicate value
		local id3 = bimap:add("Apple")
		assert(id3 == id1, "Adding duplicate should return existing index")
		assert(bimap:count() == 2, "BiMap count should still be 2 after adding duplicate")
		-- Test remove by index
		bimap:remove(id1)
		assert(not bimap:contains("Apple"), "BiMap should not contain Apple after removal")
		assert(bimap:count() == 1, "BiMap count should be 1 after removal")
		-- Test remove by value
		bimap:add("Cherry")
		bimap:removeByValue("Banana")
		assert(not bimap:contains("Banana"), "BiMap should not contain Banana after removal")
		assert(bimap:count() == 1, "BiMap count should be 1 after removal")
		-- Test clear operation
		bimap:clear()
		assert(bimap:isEmpty(), "BiMap should be empty after clear")
		assert(bimap:count() == 0, "BiMap count should be 0 after clear")
		-- Test with different types of values
		local t = { 1, 2, 3 }
		local f = function() return 4 end
		local id4 = bimap:add("test")
		local id5 = bimap:add(t)
		local id6 = bimap:add(f)
		assert(bimap:count() == 3, "BiMap should have 3 items after adding different types")
		assert(bimap:get_index(t) == id5, "get_index should work for table")
		assert(bimap:get_index(f) == id6, "get_index should work for function")
		-- Test containsIndex
		assert(bimap:containsIndex(id5), "containsIndex should return true for existing index")
		assert(not bimap:containsIndex(999), "containsIndex should return false for non-existing index")
		-- Test iterator
		local values = {}
		for value in bimap:iterator() do
			table.insert(values, value)
		end
		assert(#values == 3, "Iterator should yield 3 values")
		-- Test # operator
		assert(#bimap == 3, "# operator should return count")
	end
	do
		-- Test iteration with holes
		local bimap = BiMap.new()
		local id1 = bimap:add("Apple")
		local id2 = bimap:add("Banana")
		bimap:remove(id2)
		local id3 = bimap:add("Cherry")
		-- Test that indices are monotonically increasing
		assert(id1 == 1, "First index should be 1")
		assert(id2 == 2, "Second index should be 2")
		assert(id3 == 3, "Third index should be 3")
		-- Test pairs iteration (unordered)
		local count = 0
		for index, value in pairs(bimap) do
			count = count + 1
		end
		assert(count == 2, "pairs should iterate over 2 active elements")
		-- Test ipairs iteration (ordered)
		local ipairs_count = 0
		for index, value in bimap:__ipairs() do
			ipairs_count = ipairs_count + 1
		end
		assert(ipairs_count == 2, "ipairs should iterate over 2 active elements")
	end

	print("All tests passed ✔")
end
--]]

-- Export
return BiMap
