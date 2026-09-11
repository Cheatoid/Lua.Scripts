-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Localized global functions for better performance
local assert = assert
local next = next
local setmetatable = setmetatable
local type = type
local string_format = string.format

--- Define the Set class.<br>
--- A collection of unique values with O(1) lookups and insertions. Automatically handles duplicates and provides fast membership testing.<br>
--- Perfect for tracking unique items, removing duplicates, or fast lookups.
---@class Set
---@field [1] table Table storing set items (keys are values, values are true)
local Set = {}
Set.__index = Set

--- Create a new Set instance.<br>
--- A collection of unique values with O(1) lookups.
---@return Set set New Set instance.
---@usage <br>
--- ```
--- local set = Set.new()
--- set:add(1)
--- set:add(2)
--- set:add(1) -- Duplicate, ignored
--- print(set:count()) -- 2
--- ```
function Set.new()
	return setmetatable({ {} }, Set)
end

Set.__call = Set.new

--- Get the number of items using `#` operator.<br>
--- Allows using `#set` instead of `set:count()`.
---@param self Set The set instance.
---@return integer count Number of unique items in the set.
---@usage <br>
--- ```
--- local set = Set.new()
--- set:add(1)
--- set:add(2)
--- print(#set) -- 2
--- ```
function Set.__len(self)
	local count = 0
	for _ in next, self[1] do
		count = count + 1
	end
	return count
end

function Set._iter_pairs(state, _)
	local key = next(state[1], state[2])
	if key ~= nil then
		state[2] = key
		return key, key
	end
end

--- Iterate over set items using `pairs()`.<br>
--- Yields each unique value in the set.
---@param self Set The set instance.
---@return function iterator Iterator that yields each value.
---@return table state The iterator state table.
---@return nil initial Initial control variable.
---@usage <br>
--- ```
--- local set = Set.new()
--- set:add(1)
--- set:add(2)
--- for value in pairs(set) do
---   print(value)
--- end
--- ```
function Set.__pairs(self)
	return Set._iter_pairs, { self[1] }, nil
end

--- Get string representation of the set.<br>
--- Returns a string showing the count.
---@param self Set The set instance.
---@return string string String representation of the set.
---@usage <br>
--- ```
--- local set = Set.new()
--- set:add(1)
--- set:add(2)
--- print(tostring(set)) -- "Set(count=2)"
--- ```
function Set.__tostring(self)
	local count = 0
	for _ in next, self[1] do
		count = count + 1
	end
	return string_format("Set(count=%d)", count)
end

--- Get the number of items in the set.
---@param self Set The set instance.
---@return integer count Number of unique items in the set.
---@usage <br>
--- ```
--- local set = Set.new()
--- set:add(1)
--- set:add(2)
--- print(set:count()) -- 2
--- ```
function Set.count(self)
	local count = 0
	for _ in next, self[1] do
		count = count + 1
	end
	return count
end

--- Check if the set is empty.
---@param self Set The set instance.
---@return boolean empty `true` if the set is empty, `false` otherwise.
---@usage <br>
--- ```
--- local set = Set.new()
--- print(set:isEmpty()) -- true
--- set:add(1)
--- print(set:isEmpty()) -- false
--- ```
function Set.isEmpty(self)
	return next(self[1]) == nil
end

--- Clear all items from the set.
---@param self Set The set instance.
---@usage <br>
--- ```
--- local set = Set.new()
--- set:add(1)
--- set:add(2)
--- set:clear()
--- print(set:isEmpty()) -- true
--- ```
function Set.clear(self)
	self[1] = {}
end

--- Add a value to the set.<br>
--- Duplicate values are ignored (sets contain unique values).
---@param self Set The set instance.
---@param value any The value to add (cannot be `nil`).
---@usage <br>
--- ```
--- local set = Set.new()
--- set:add(1)
--- set:add(2)
--- set:add(1) -- Duplicate, ignored
--- print(set:count()) -- 2
--- ```
function Set.add(self, value)
	assert(value ~= nil, "cannot add a nil value to the set")
	self[1][value] = true
end

--- Remove a value from the set.<br>
--- Does nothing if the value is not in the set.
---@param self Set The set instance.
---@param value any The value to remove.
---@usage <br>
--- ```
--- local set = Set.new()
--- set:add(1)
--- set:add(2)
--- set:remove(1)
--- print(set:contains(1)) -- false
--- ```
function Set.remove(self, value)
	self[1][value] = nil
end

--- Check if a value exists in the set.
---@param self Set The set instance.
---@param value any The value to check for.
---@return boolean result `true` if the value is in the set, `false` otherwise.
---@usage <br>
--- ```
--- local set = Set.new()
--- set:add(1)
--- print(set:contains(1)) -- true
--- print(set:contains(2)) -- false
--- ```
function Set.contains(self, value)
	return self[1][value] ~= nil
end

function Set._iter_values(state, _)
	local key = next(state[1], state[2])
	if key ~= nil then
		state[2] = key
		return key
	end
end

--- Return an iterator over the set items.<br>
--- Yields each unique value in the set.
---@param self Set The set instance.
---@return function iterator Iterator that yields each value.
---@return table state The iterator state table.
---@return nil initial Initial control variable.
---@usage <br>
--- ```
--- local set = Set.new()
--- set:add(1)
--- set:add(2)
--- set:add(3)
--- for value in set:iterator() do
---   print(value)
--- end
--- ```
function Set.iterator(self)
	return Set._iter_values, { self[1] }, nil
end

--- Create a new set that is the union of this set and another.<br>
--- Contains all values from both sets.
---@param self Set The set instance.
---@param other Set The other set to union with.
---@return Set result New set containing the union.
---@usage <br>
--- ```
--- local set1 = Set.new()
--- set1:add(1)
--- set1:add(2)
--- local set2 = Set.new()
--- set2:add(2)
--- set2:add(3)
--- local union = set1:union(set2)
--- print(union:count()) -- 3 (contains 1, 2, 3)
--- ```
function Set.union(self, other)
	assert(type(other) == "table" and other[1] ~= nil, "argument must be a Set")
	local result = Set.new()
	for key in next, self[1] do
		result[1][key] = true
	end
	for key in next, other[1] do
		result[1][key] = true
	end
	return result
end

--- Create a new set that is the intersection of this set and another.<br>
--- Contains only values present in both sets.
---@param self Set The set instance.
---@param other Set The other set to intersect with.
---@return Set result New set containing the intersection.
---@usage <br>
--- ```
--- local set1 = Set.new()
--- set1:add(1)
--- set1:add(2)
--- local set2 = Set.new()
--- set2:add(2)
--- set2:add(3)
--- local intersection = set1:intersection(set2)
--- print(intersection:count()) -- 1 (contains 2)
--- ```
function Set.intersection(self, other)
	assert(type(other) == "table" and other[1] ~= nil, "argument must be a Set")
	local result = Set.new()
	for key in next, self[1] do
		if other[1][key] then
			result[1][key] = true
		end
	end
	return result
end

--- Create a new set that is the difference of this set and another.<br>
--- Contains values in this set but not in the other set.
---@param self Set The set instance.
---@param other Set The other set to difference with.
---@return Set result New set containing the difference.
---@usage <br>
--- ```
--- local set1 = Set.new()
--- set1:add(1)
--- set1:add(2)
--- local set2 = Set.new()
--- set2:add(2)
--- set2:add(3)
--- local difference = set1:difference(set2)
--- print(difference:count()) -- 1 (contains 1)
--- ```
function Set.difference(self, other)
	assert(type(other) == "table" and other[1] ~= nil, "argument must be a Set")
	local result = Set.new()
	for key in next, self[1] do
		if not other[1][key] then
			result[1][key] = true
		end
	end
	return result
end

--- Check if this set is a subset of another set.<br>
--- Returns `true` if all values in this set are in the other set.
---@param self Set The set instance.
---@param other Set The other set to check against.
---@return boolean result `true` if this is a subset of other, `false` otherwise.
---@usage <br>
--- ```
--- local set1 = Set.new()
--- set1:add(1)
--- local set2 = Set.new()
--- set2:add(1)
--- set2:add(2)
--- print(set1:isSubset(set2)) -- true
--- ```
function Set.isSubset(self, other)
	assert(type(other) == "table" and other[1] ~= nil, "argument must be a Set")
	for key in next, self[1] do
		if not other[1][key] then
			return false
		end
	end
	return true
end

--- Check if this set is a superset of another set.<br>
--- Returns `true` if all values in the other set are in this set.
---@param self Set The set instance.
---@param other Set The other set to check against.
---@return boolean result `true` if this is a superset of other, `false` otherwise.
---@usage <br>
--- ```
--- local set1 = Set.new()
--- set1:add(1)
--- set1:add(2)
--- local set2 = Set.new()
--- set2:add(1)
--- print(set1:isSuperset(set2)) -- true
--- ```
function Set.isSuperset(self, other)
	assert(type(other) == "table" and other[1] ~= nil, "argument must be a Set")
	for key in next, other[1] do
		if not self[1][key] then
			return false
		end
	end
	return true
end

--- Check if two sets are equal.<br>
--- Returns `true` if both sets contain the same values.
---@param self Set The set instance.
---@param other Set The other set to compare with.
---@return boolean result `true` if sets are equal, `false` otherwise.
---@usage <br>
--- ```
--- local set1 = Set.new()
--- set1:add(1)
--- set1:add(2)
--- local set2 = Set.new()
--- set2:add(1)
--- set2:add(2)
--- print(set1:equals(set2)) -- true
--- ```
function Set.equals(self, other)
	assert(type(other) == "table" and other[1] ~= nil, "argument must be a Set")
	local selfCount = Set.count(self)
	local otherCount = Set.count(other)
	if selfCount ~= otherCount then
		return false
	end
	for key in next, self[1] do
		if not other[1][key] then
			return false
		end
	end
	return true
end

-- Deprecated aliases (naming standard: snake_case). Kept for compatibility.
Set.is_empty = Set.isEmpty
Set.is_subset = Set.isSubset
Set.is_superset = Set.isSuperset

-- Export
return Set
