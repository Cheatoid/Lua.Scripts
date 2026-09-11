-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Localized global functions for better performance
local next = next
local rawget = rawget
local rawset = rawset
local setmetatable = setmetatable
local string_format = string.format

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
---@return integer? index The index of the value, or `nil` if not found.
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
---@return integer? initial Initial control variable.
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

function BiMap._iter_values(state, _)
	local key, value = next(state[1], state[2])
	if key ~= nil then
		state[2] = key
		return value
	end
end

--- Return an iterator over the BiMap values.<br>
--- Yields each value in the BiMap in no particular order.
---@param self BiMap The BiMap instance.
---@return function iterator Iterator that yields each value.
---@return table state The iterator state table.
---@return nil initial Initial control variable.
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
	return BiMap._iter_values, { self[1] }, nil
end

-- Deprecated aliases (naming standard: snake_case). Kept for compatibility.
BiMap.is_empty = BiMap.isEmpty
BiMap.contains_index = BiMap.containsIndex
BiMap.remove_by_value = BiMap.removeByValue

-- Export
return BiMap
