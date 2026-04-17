-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Localized global functions for better performance
local assert = assert
local setmetatable = setmetatable
local next = next
local type = type
local string_format = string.format

--- Define the Set class
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

--- Iterate over set items using `pairs()`.<br>
--- Yields each unique value in the set.
---@param self Set The set instance.
---@return function iterator Iterator that yields each value.
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
	local items = self[1]
	local key
	return function()
		key = next(items, key)
		return key, key
	end
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

--- Return an iterator over the set items.<br>
--- Yields each unique value in the set.
---@param self Set The set instance.
---@return function iterator Iterator that yields each value.
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
	local items = self[1]
	local key
	return function()
		key = next(items, key)
		return key
	end
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

--[[ Test the Set class
if true then
	-- Create a new Set
	local set = Set.new()
	-- Test that the set is initially empty
	assert(set:isEmpty(), "Set should be empty initially")
	-- Test add operation
	set:add(1)
	assert(set:count() == 1, "Set should have 1 item after add")
	assert(set:contains(1), "Set should contain the added value")
	-- Test adding duplicate
	set:add(1)
	assert(set:count() == 1, "Set should still have 1 item after adding duplicate")
	-- Test add multiple values
	set:add(2)
	set:add(3)
	assert(set:count() == 3, "Set should have 3 items after adding multiple values")
	-- Test contains
	assert(set:contains(2), "Set should contain 2")
	assert(set:contains(3), "Set should contain 3")
	assert(not set:contains(4), "Set should not contain 4")
	-- Test remove operation
	set:remove(2)
	assert(set:count() == 2, "Set should have 2 items after remove")
	assert(not set:contains(2), "Set should not contain removed value")
	-- Test __pairs metamethod (unordered iteration) after remove (hole)
	local pairs_count = 0
	for key, value in pairs(set) do
		pairs_count = pairs_count + 1
	end
	assert(pairs_count == 2, "pairs() should iterate over 2 items after remove")
	-- Test remove non-existent value
	set:remove(99)
	assert(set:count() == 2, "Set should still have 2 items after removing non-existent value")
	-- Test iterator
	local iterated = {}
	for value in set:iterator() do
		iterated[value] = true
	end
	assert(iterated[1] or iterated[3], "Iterator should return values from the set")
	assert(not set:isEmpty(), "Set should not be empty after non-destructive iterator")
	-- Test union
	local set1 = Set.new()
	set1:add(1)
	set1:add(2)
	local set2 = Set.new()
	set2:add(2)
	set2:add(3)
	local union = set1:union(set2)
	assert(union:count() == 3, "Union should have 3 items")
	assert(union:contains(1), "Union should contain 1")
	assert(union:contains(2), "Union should contain 2")
	assert(union:contains(3), "Union should contain 3")
	-- Test intersection
	local intersection = set1:intersection(set2)
	assert(intersection:count() == 1, "Intersection should have 1 item")
	assert(intersection:contains(2), "Intersection should contain 2")
	-- Test difference
	local difference = set1:difference(set2)
	assert(difference:count() == 1, "Difference should have 1 item")
	assert(difference:contains(1), "Difference should contain 1")
	assert(not difference:contains(2), "Difference should not contain 2")
	-- Test subset
	local subset = Set.new()
	subset:add(1)
	assert(subset:isSubset(set1), "Subset should be subset of set1")
	assert(not set1:isSubset(subset), "set1 should not be subset of subset")
	-- Test superset
	assert(set1:isSuperset(subset), "set1 should be superset of subset")
	assert(not subset:isSuperset(set1), "subset should not be superset of set1")
	-- Test equals
	local set3 = Set.new()
	set3:add(1)
	set3:add(2)
	assert(set1:equals(set3), "Identical sets should be equal")
	assert(not set1:equals(set2), "Different sets should not be equal")
	-- Test add with nil
	local status, err = pcall(function() set:add(nil) end)
	assert(not status and string.find(err, "cannot add a nil value to the set"),
		"Adding nil should throw an error")
	-- Test clear
	set:clear()
	assert(set:isEmpty(), "Set should be empty after clear")
	assert(set:count() == 0, "Set should have count 0 after clear")
	-- Test with different types of values
	set:add("string")
	set:add(123)
	local test_table = { key = "value" }
	local test_function = function() return "function" end
	set:add(test_table)
	set:add(test_function)
	assert(set:count() == 4, "Set should handle different types of values")
	assert(set:contains("string"), "Set should contain string")
	assert(set:contains(123), "Set should contain number")
	assert(set:contains(test_table), "Set should contain table")
	assert(set:contains(test_function), "Set should contain function")
	-- Test empty set operations
	local empty = Set.new()
	assert(empty:isEmpty(), "Empty set should be empty")
	assert(empty:union(set):equals(set), "Union with empty should equal original")
	assert(empty:intersection(set):isEmpty(), "Intersection with empty should be empty")
	assert(empty:difference(set):isEmpty(), "Difference of empty should be empty")
	assert(set:difference(empty):equals(set), "Difference with empty should equal original")
	assert(empty:isSubset(set), "Empty set is subset of any set")
	assert(empty:isSuperset(empty), "Empty set is superset of empty set")
	assert(not empty:isSuperset(set), "Empty set is not superset of non-empty set")
	assert(not set:equals(empty), "Non-empty set should not equal empty set")
	print("All tests passed ✔")
end
--]]

-- Export
return Set
