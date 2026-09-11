-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Localized global functions for better performance
local assert = assert
local next = next
local rawget = rawget
local setmetatable = setmetatable
local type = type
local string_format = string.format

--- Define the SlotMap class.<br>
--- A sparse array where each element gets a unique index that never repeats. Provides O(1) add, remove, and get operations.<br>
--- Perfect for entity management, component systems, or when you need stable references.
---@class SlotMap
---@field [1] table<integer, any> The sparse array holding the actual elements
---@field [2] integer Tracks the number of active (non-nil) elements
---@field [3] integer The monotonically increasing index generator
local SlotMap = {}
SlotMap.__index = SlotMap

--- Create a new SlotMap instance.<br>
--- A sparse array data structure with O(1) add, remove, and get operations.<br>
--- Each element is assigned a unique monotonically increasing index that is never reused.
---@return SlotMap slotmap New SlotMap instance.
---@usage <br>
--- ```
--- local slotmap = SlotMap.new()
--- local id1 = slotmap:add("Apple")
--- local id2 = slotmap:add("Banana")
--- slotmap:remove(id1)
--- ```
function SlotMap.new()
	return setmetatable({
		{},
		0,
		math.mininteger or -99999999999999,
	}, SlotMap)
end

SlotMap.__call = SlotMap.new

--- Add a new element to the SlotMap.<br>
--- Assigns a unique monotonically increasing index that is never reused.
---@param self SlotMap The SlotMap instance.
---@param value any The value to store.
---@return integer index The unique index assigned to this value.
---@usage <br>
--- ```
--- local slotmap = SlotMap.new()
--- local id1 = slotmap:add("Apple")
--- local id2 = slotmap:add("Banana")
--- print(id1, id2) -- 1, 2
--- ```
function SlotMap.add(self, value)
	local index = self[3]
	self[1][index] = value

	-- Increment towards infinity, ensuring this index is never reused
	self[3] = index + 1
	self[2] = self[2] + 1

	return index
end

--- Remove an element by its explicit index.<br>
--- O(1) removal without shifting or `table.remove()`.
---@param self SlotMap The SlotMap instance.
---@param index integer The index returned from `SlotMap:add()`.
---@usage <br>
--- ```
--- local slotmap = SlotMap.new()
--- local id = slotmap:add("Apple")
--- slotmap:remove(id)
--- ```
function SlotMap.remove(self, index)
	assert(type(index) == "number", "index must be a number")

	-- Only decrement count if the slot was actually occupied
	if rawget(self[1], index) ~= nil then
		self[1][index] = nil -- O(1) removal, no table.remove, no shifting
		self[2] = self[2] - 1
	end
end

--- Retrieve a value by its explicit index.<br>
--- Returns `nil` if the index doesn't exist or was removed.
---@param self SlotMap The SlotMap instance.
---@param index integer The index to look up.
---@return any value The value, or `nil` if it doesn't exist/was removed.
---@usage <br>
--- ```
--- local slotmap = SlotMap.new()
--- local id = slotmap:add("Apple")
--- print(slotmap:get(id)) -- "Apple"
--- slotmap:remove(id)
--- print(slotmap:get(id)) -- nil
--- ```
function SlotMap.get(self, index)
	return rawget(self[1], index)
end

--- Get the number of active elements using `#` operator.<br>
--- Allows using `#slotmap` instead of `slotmap:count()`.
---@param self SlotMap The SlotMap instance.
---@return integer count Number of active elements.
---@usage <br>
--- ```
--- local slotmap = SlotMap.new()
--- slotmap:add(1)
--- slotmap:add(2)
--- print(#slotmap) -- 2
--- ```
function SlotMap.__len(self)
	return self[2]
end

--- Iterate over active elements using `pairs()`.<br>
--- Unordered iteration using `next`, which natively skips over nil entries.<br>
--- No extra memory allocation for iteration.
---@param self SlotMap The SlotMap instance.
---@return function iterator Iterator function.
---@return table state The internal data table (used as state).
---@return nil initial Initial control variable.
---@usage <br>
--- ```
--- local slotmap = SlotMap.new()
--- slotmap:add("Apple")
--- slotmap:add("Banana")
--- for index, value in pairs(slotmap) do
---   print(index, value)
--- end
--- ```
function SlotMap.__pairs(self)
	return next, self[1]
end

local function ipairs_next(state, current_index)
	local data = state[1]
	local start_index = (current_index and current_index + 1) or math.mininteger or -99999999999999
	-- Scan linearly from the last index + 1 up to the highest possible index
	for i = start_index, state[2] do
		if rawget(data, i) ~= nil then
			return i, data[i]
		end
	end
end

--- Iterate over active elements using `ipairs()`.<br>
--- Ordered numeric iteration that safely skips over "holes" (removed elements).<br>
--- Guarantees ascending numeric order, unlike `pairs()`.
---@param self SlotMap The SlotMap instance.
---@return function iterator Iterator function.
---@return table state Snapshot state table (data reference and max bound).
---@return integer? initial Initial control variable.
---@usage <br>
--- ```
--- local slotmap = SlotMap.new()
--- local id1 = slotmap:add("Apple")
--- local id2 = slotmap:add("Banana")
--- slotmap:remove(id2)
--- local id3 = slotmap:add("Cherry")
--- for index, value in ipairs(slotmap) do
---   print(index, value) -- 1 "Apple", 3 "Cherry"
--- end
--- ```
function SlotMap.__ipairs(self)
	-- We pass a lightweight state table, so the iterator closes over nothing
	return ipairs_next, {
		self[1],
		self[3] - 1
	}
end

--- Get string representation of the SlotMap.<br>
--- Returns a string showing the count.
---@param self SlotMap The SlotMap instance.
---@return string string String representation of the SlotMap.
---@usage <br>
--- ```
--- local slotmap = SlotMap.new()
--- slotmap:add(1)
--- slotmap:add(2)
--- print(tostring(slotmap)) -- "SlotMap(count=2)"
--- ```
function SlotMap.__tostring(self)
	return string_format("SlotMap(count=%d)", self[2])
end

--- Get the number of active elements.
---@param self SlotMap The SlotMap instance.
---@return integer count Number of active elements.
---@usage <br>
--- ```
--- local slotmap = SlotMap.new()
--- slotmap:add(1)
--- slotmap:add(2)
--- print(slotmap:count()) -- 2
--- ```
function SlotMap.count(self)
	return self[2]
end

--- Check if the SlotMap is empty.
---@param self SlotMap The SlotMap instance.
---@return boolean empty `true` if the SlotMap is empty, `false` otherwise.
---@usage <br>
--- ```
--- local slotmap = SlotMap.new()
--- print(slotmap:isEmpty()) -- true
--- slotmap:add(1)
--- print(slotmap:isEmpty()) -- false
--- ```
function SlotMap.isEmpty(self)
	return self[2] == 0
end

--- Clear all elements from the SlotMap.<br>
--- Resets the data table and count, but preserves the next_index for uniqueness.
---@param self SlotMap The SlotMap instance.
---@usage <br>
--- ```
--- local slotmap = SlotMap.new()
--- slotmap:add(1)
--- slotmap:add(2)
--- slotmap:clear()
--- print(slotmap:isEmpty()) -- true
--- ```
function SlotMap.clear(self)
	self[1] = {}
	self[2] = 0
	self[3] = math.mininteger or -99999999999999
end

--- Check if an index exists in the SlotMap.<br>
--- Returns `true` if the index has an active value.
---@param self SlotMap The SlotMap instance.
---@param index integer The index to check for.
---@return boolean result `true` if the index exists, `false` otherwise.
---@usage <br>
--- ```
--- local slotmap = SlotMap.new()
--- local id = slotmap:add("Apple")
--- print(slotmap:contains(id)) -- true
--- slotmap:remove(id)
--- print(slotmap:contains(id)) -- false
--- ```
function SlotMap.contains(self, index)
	return rawget(self[1], index) ~= nil
end

function SlotMap._iter_values(state, _)
	local key, value = next(state[1], state[2])
	if key ~= nil then
		state[2] = key
		return value
	end
end

--- Return an iterator over the SlotMap values.<br>
--- Yields each value in the SlotMap in no particular order.
---@param self SlotMap The SlotMap instance.
---@return function iterator Iterator that yields each value.
---@return table state The iterator state table.
---@return nil initial Initial control variable.
---@usage <br>
--- ```
--- local slotmap = SlotMap.new()
--- slotmap:add("Apple")
--- slotmap:add("Banana")
--- slotmap:add("Cherry")
--- for value in slotmap:iterator() do
---   print(value)
--- end
--- ```
function SlotMap.iterator(self)
	return SlotMap._iter_values, { self[1] }, nil
end

-- Deprecated aliases (naming standard: snake_case). Kept for compatibility.
SlotMap.is_empty = SlotMap.isEmpty

-- Export
return SlotMap
