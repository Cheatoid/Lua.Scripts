-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Localized global functions for better performance
local next = next
local rawget = rawget
local rawset = rawset
local setmetatable = setmetatable
local string_format = string.format

--- Define the SparseArray class.<br>
--- A simple sparse array with unique indices that never repeat. Provides O(1) add, remove, and get operations.<br>
--- Simpler than BiMap as it only supports index->value lookup. Perfect for indexed data storage.
---@class SparseArray
---@field [1] table<integer, any> The sparse array holding the actual elements
---@field [2] integer Tracks the number of active (non-nil) elements
---@field [3] integer The monotonically increasing index generator
---@field [4] table Iterator state table (data reference and limit)
local SparseArray = {}
SparseArray.__index = SparseArray

--- Create a new SparseArray instance.<br>
--- A sparse array data structure with O(1) add, remove, and get operations.<br>
--- Each element is assigned a unique monotonically increasing index that is never reused.<br>
--- Simpler than BiMap as it only supports index->value lookup (no reverse lookup).
---@return SparseArray sparsearray New SparseArray instance.
---@usage <br>
--- ```
--- local sparsearray = SparseArray.new()
--- local id1 = sparsearray:add("Apple")
--- local id2 = sparsearray:add("Banana")
--- sparsearray:remove(id1)
--- ```
function SparseArray.new()
	local data = {}
	return setmetatable({ data, 0, 1, { data, 0 } }, SparseArray)
end

SparseArray.__call = SparseArray.new

--- Add a new element to the SparseArray.<br>
--- Assigns a unique monotonically increasing index that is never reused.
---@param self SparseArray The SparseArray instance.
---@param value any The value to store.
---@return integer index The unique index assigned to this value.
---@usage <br>
--- ```
--- local sparsearray = SparseArray.new()
--- local id1 = sparsearray:add("Apple")
--- local id2 = sparsearray:add("Banana")
--- print(id1, id2) -- 1, 2
--- ```
function SparseArray.add(self, value)
	local data = self[1]
	local index = self[3]

	rawset(data, index, value)
	self[3] = index + 1
	self[2] = self[2] + 1

	return index
end

--- Remove an element by its explicit index.<br>
--- O(1) removal without shifting or `table.remove()`.
---@param self SparseArray The SparseArray instance.
---@param index integer The index returned from `SparseArray:add()`.
---@usage <br>
--- ```
--- local sparsearray = SparseArray.new()
--- local id = sparsearray:add("Apple")
--- sparsearray:remove(id)
--- ```
function SparseArray.remove(self, index)
	local data = self[1]
	if rawget(data, index) ~= nil then
		rawset(data, index, nil)
		self[2] = self[2] - 1
	end
end

--- Get the number of active elements using `#` operator.<br>
--- Allows using `#sparsearray` instead of `sparsearray:count()`.
---@param self SparseArray The SparseArray instance.
---@return integer count Number of active elements.
---@usage <br>
--- ```
--- local sparsearray = SparseArray.new()
--- sparsearray:add(1)
--- sparsearray:add(2)
--- print(#sparsearray) -- 2
--- ```
function SparseArray.__len(self)
	return self[2]
end

--- Iterate over active elements using `pairs()`.<br>
--- Unordered iteration using `next`, which natively skips over nil entries.<br>
--- No extra memory allocation for iteration.
---@param self SparseArray The SparseArray instance.
---@return function iterator Iterator function.
---@return table state The internal data table (used as state).
---@return nil initial Initial control variable.
---@usage <br>
--- ```
--- local sparsearray = SparseArray.new()
--- sparsearray:add("Apple")
--- sparsearray:add("Banana")
--- for index, value in pairs(sparsearray) do
---   print(index, value)
--- end
--- ```
function SparseArray.__pairs(self)
	return next, self[1]
end

local function ipairs_next(state, current_index)
	local data, limit = state[1], state[2]
	for i = (current_index or 0) + 1, limit do
		if rawget(data, i) ~= nil then
			return i, data[i]
		end
	end
end

--- Iterate over active elements using `ipairs()`.<br>
--- Ordered numeric iteration that safely skips over "holes" (removed elements).<br>
--- Guarantees ascending numeric order, unlike `pairs()`.
---@param self SparseArray The SparseArray instance.
---@return function iterator Iterator function.
---@return table state Snapshot state table (data reference and max bound).
---@return nil initial Initial control variable.
---@usage <br>
--- ```
--- local sparsearray = SparseArray.new()
--- local id1 = sparsearray:add("Apple")
--- local id2 = sparsearray:add("Banana")
--- sparsearray:remove(id2)
--- local id3 = sparsearray:add("Cherry")
--- for index, value in ipairs(sparsearray) do
---   print(index, value) -- 1 "Apple", 3 "Cherry"
--- end
--- ```
function SparseArray.__ipairs(self)
	local state = self[4]
	state[1] = self[1]
	state[2] = self[3] - 1
	return ipairs_next, state, 0
end

--- Get string representation of the SparseArray.<br>
--- Returns a string showing the count.
---@param self SparseArray The SparseArray instance.
---@return string string String representation of the SparseArray.
---@usage <br>
--- ```
--- local sparsearray = SparseArray.new()
--- sparsearray:add(1)
--- sparsearray:add(2)
--- print(tostring(sparsearray)) -- "SparseArray(count=2)"
--- ```
function SparseArray.__tostring(self)
	return string_format("SparseArray(count=%d)", self[2])
end

--- Get the number of active elements.
---@param self SparseArray The SparseArray instance.
---@return integer count Number of active elements.
---@usage <br>
--- ```
--- local sparsearray = SparseArray.new()
--- sparsearray:add(1)
--- sparsearray:add(2)
--- print(sparsearray:count()) -- 2
--- ```
function SparseArray.count(self)
	return self[2]
end

--- Check if the SparseArray is empty.
---@param self SparseArray The SparseArray instance.
---@return boolean empty `true` if the SparseArray is empty, `false` otherwise.
---@usage <br>
--- ```
--- local sparsearray = SparseArray.new()
--- print(sparsearray:isEmpty()) -- true
--- sparsearray:add(1)
--- print(sparsearray:isEmpty()) -- false
--- ```
function SparseArray.isEmpty(self)
	return self[2] == 0
end

--- Clear all elements from the SparseArray.<br>
--- Resets the data table and count, but preserves the next_index for uniqueness.
---@param self SparseArray The SparseArray instance.
---@usage <br>
--- ```
--- local sparsearray = SparseArray.new()
--- sparsearray:add(1)
--- sparsearray:add(2)
--- sparsearray:clear()
--- print(sparsearray:isEmpty()) -- true
--- ```
function SparseArray.clear(self)
	self[1], self[2] = {}, 0
end

--- Check if an index exists in the SparseArray.<br>
--- Returns `true` if the index has an active value.
---@param self SparseArray The SparseArray instance.
---@param index integer The index to check for.
---@return boolean result `true` if the index exists, `false` otherwise.
---@usage <br>
--- ```
--- local sparsearray = SparseArray.new()
--- local id = sparsearray:add("Apple")
--- print(sparsearray:contains(id)) -- true
--- sparsearray:remove(id)
--- print(sparsearray:contains(id)) -- false
--- ```
function SparseArray.contains(self, index)
	return rawget(self[1], index) ~= nil
end

--- Return an iterator over the SparseArray values.<br>
--- Yields each value in the SparseArray in no particular order.
---@param self SparseArray The SparseArray instance.
---@return function iterator Iterator that yields each value.
---@usage <br>
--- ```
--- local sparsearray = SparseArray.new()
--- sparsearray:add("Apple")
--- sparsearray:add("Banana")
--- sparsearray:add("Cherry")
--- for value in sparsearray:iterator() do
---   print(value)
--- end
--- ```
function SparseArray.iterator(self)
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
	-- Create a new SparseArray
	local sparsearray = SparseArray.new()
	-- Test that the sparsearray is initially empty
	assert(#sparsearray == 0, "SparseArray should be empty initially")
	-- Test add operation
	local id1 = sparsearray:add("Apple")
	assert(#sparsearray == 1, "SparseArray should have 1 item after add")
	assert(sparsearray:contains(id1), "SparseArray should contain the added value")
	-- Test add multiple values
	local id2 = sparsearray:add("Banana")
	local id3 = sparsearray:add("Cherry")
	assert(#sparsearray == 3, "SparseArray should have 3 items after adding multiple values")
	-- Test remove operation to create a hole
	sparsearray:remove(id2)
	assert(#sparsearray == 2, "SparseArray should have 2 items after remove")
	assert(not sparsearray:contains(id2), "SparseArray should not contain removed value")
	-- Test __pairs metamethod (unordered iteration)
	local pairs_count = 0
	for index, value in pairs(sparsearray) do
		pairs_count = pairs_count + 1
	end
	assert(pairs_count == 2, "pairs() should iterate over 2 items")
	-- Test __ipairs metamethod (ordered iteration, skips holes)
	local ipairs_count = 0
	local previous_index = 0
	for index, value in sparsearray:__ipairs() do
		ipairs_count = ipairs_count + 1
		assert(index > previous_index, "__ipairs() should return indices in ascending order")
		previous_index = index
	end
	assert(ipairs_count == 2, "__ipairs() should iterate over 2 items")
	-- Test iterator
	local iterator_count = 0
	for value in sparsearray:iterator() do
		iterator_count = iterator_count + 1
	end
	assert(iterator_count == 2, "iterator() should iterate over 2 items")
	-- Test clear operation
	sparsearray:clear()
	assert(#sparsearray == 0, "SparseArray should be empty after clear")
	print("All tests passed ✔")
end
--]]

-- Export
return SparseArray
