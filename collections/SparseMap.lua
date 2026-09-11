-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Localized global functions for better performance
local error = error
local setmetatable = setmetatable
local string_format = string.format
local table_sort = table.sort

--- A hash map implementation using dense arrays with O(1) insertion, lookup, and removal. Maintains a sparse lookup table mapping keys to dense indices.<br>
--- Perfect for scenarios requiring fast key-value operations with predictable iteration order.
---@generic K
---@generic V
---@class SparseMap<K, V>
---@field [1] table<K, integer> Sparse key-to-index lookup table.
---@field [2] K[] Dense keys.
---@field [3] V[] Dense values.
---@field [4] integer Number of active entries.
---@field [5] integer Allocated dense capacity.
local SparseMap = {}
SparseMap.__index = SparseMap

--- Create a new SparseMap instance.<br>
--- A hash map with O(1) insertion, lookup, and removal.
---@generic K
---@generic V
---@param initial_capacity? integer Initial dense capacity.
---@return SparseMap<K, V>
---@usage <br>
--- ```
--- local map = SparseMap.new()
--- map:set("a", 1)
--- map:set("b", 2)
--- print(map:get("a")) -- 1
--- ```
function SparseMap.new(initial_capacity)
	initial_capacity = initial_capacity or 0

	if initial_capacity < 0 then
		return error("initial_capacity must be >= 0", 2)
	end

	return setmetatable({
		{},
		{},
		{},
		0,
		initial_capacity,
	}, SparseMap)
end

--- Returns the number of active entries.
---@param self SparseMap The SparseMap instance.
---@return integer count Number of active entries.
---@usage <br>
--- ```
--- local map = SparseMap.new()
--- map:set("a", 1)
--- print(map:size()) -- 1
--- ```
function SparseMap.size(self)
	return self[4]
end

--- Returns whether the map contains no entries.
---@param self SparseMap The SparseMap instance.
---@return boolean empty `true` if the map is empty, `false` otherwise.
---@usage <br>
--- ```
--- local map = SparseMap.new()
--- print(map:is_empty()) -- true
--- map:set("a", 1)
--- print(map:is_empty()) -- false
--- ```
function SparseMap.is_empty(self)
	return self[4] == 0
end

--- Returns the number of entries the dense storage is reserved for.
---@param self SparseMap The SparseMap instance.
---@return integer capacity Number of reserved dense slots.
function SparseMap.get_capacity(self)
	return self[5]
end

--- Returns the number of unused reserved dense slots.
---@param self SparseMap The SparseMap instance.
---@return integer free Number of unused reserved dense slots.
function SparseMap.free_capacity(self)
	return self[5] - self[4]
end

--- Ensures that the dense storage can hold at least `capacity` entries.<br>
--- Lua tables grow dynamically, so this is primarily an API-level capacity hint. LuaJIT may still resize the underlying tables as necessary.
---@param self SparseMap The SparseMap instance.
---@param capacity integer Minimum desired capacity.
---@return SparseMap<K, V> self
function SparseMap.reserve(self, capacity)
	if capacity > self[5] then
		self[5] = capacity
	end

	return self
end

--- Returns whether a key exists in the map.
---@param self SparseMap The SparseMap instance.
---@param key K The key to check.
---@return boolean result `true` if the key exists, `false` otherwise.
---@usage <br>
--- ```
--- local map = SparseMap.new()
--- map:set("a", 1)
--- print(map:contains("a")) -- true
--- print(map:contains("b")) -- false
--- ```
function SparseMap.contains(self, key)
	local index = self[1][key]

	if index == nil then
		return false
	end

	return self[2][index] == key
end

--- Returns the dense index associated with a key.<br>
--- The returned index can be used with `SparseMap:get_key_at()` and `SparseMap:get_value_at()`.
---@param self SparseMap The SparseMap instance.
---@param key K The key to look up.
---@return integer? dense_index The dense index, or `nil` if the key is not found.
function SparseMap.get_index(self, key)
	local index = self[1][key]

	if index == nil then
		return nil
	end

	return index
end

--- Returns the key stored at a dense index.
---@param self SparseMap The SparseMap instance.
---@param index integer The dense index.
---@return K? key The key at the index, or `nil` if out of range.
function SparseMap.get_key_at(self, index)
	return self[2][index]
end

--- Returns the value stored at a dense index.
---@param self SparseMap The SparseMap instance.
---@param index integer The dense index.
---@return V? value The value at the index, or `nil` if out of range.
function SparseMap.get_value_at(self, index)
	return self[3][index]
end

--- Returns both the key and value stored at a dense index.
---@param self SparseMap The SparseMap instance.
---@param index integer The dense index.
---@return K? key The key at the index, or `nil` if out of range.
---@return V? value The value at the index, or `nil` if out of range.
function SparseMap.get_entry_at(self, index)
	return self[2][index], self[3][index]
end

--- Returns the value associated with a key.
---@param self SparseMap The SparseMap instance.
---@param key K The key to look up.
---@return V? value The value associated with the key, or `nil` if not found.
---@usage <br>
--- ```
--- local map = SparseMap.new()
--- map:set("a", 1)
--- print(map:get("a")) -- 1
--- print(map:get("b")) -- nil
--- ```
function SparseMap.get(self, key)
	local index = self[1][key]

	if index == nil then
		return nil
	end

	return self[3][index]
end

--- Returns the value associated with a key, or `default` when missing.
---@param self SparseMap The SparseMap instance.
---@param key K The key to look up.
---@param default V The default value to return when the key is missing.
---@return V value The value associated with the key, or `default`.
function SparseMap.get_or(self, key, default)
	local index = self[1][key]

	if index == nil then
		return default
	end

	return self[3][index]
end

--- Inserts or replaces a key/value pair.<br>
--- If the key already exists, its value is replaced without changing its dense index.
---@param self SparseMap The SparseMap instance.
---@param key K The key to insert or update.
---@param value V The value to associate with the key.
---@return V? previous_value Previous value, or `nil` if the key was absent.
---@usage <br>
--- ```
--- local map = SparseMap.new()
--- map:set("a", 1)
--- print(map:set("a", 2)) -- 1
--- print(map:get("a")) -- 2
--- ```
function SparseMap.set(self, key, value)
	local sparse = self[1]
	local index = sparse[key]

	if index ~= nil then
		local previous_value = self[3][index]
		self[3][index] = value

		return previous_value
	end

	local count = self[4] + 1

	sparse[key] = count
	self[2][count] = key
	self[3][count] = value

	self[4] = count

	if count > self[5] then
		self[5] = count
	end

	return nil
end

--- Adds a key/value pair only if the key does not already exist.<br>
--- Returns `false` if the key already exists without modifying the existing entry.
---@param self SparseMap The SparseMap instance.
---@param key K The key to add.
---@param value V The value to associate with the key.
---@return boolean inserted `true` if the entry was inserted, `false` if the key already exists.
---@usage <br>
--- ```
--- local map = SparseMap.new()
--- print(map:add("a", 1)) -- true
--- print(map:add("a", 2)) -- false
--- print(map:get("a")) -- 1
--- ```
function SparseMap.add(self, key, value)
	local sparse = self[1]

	if sparse[key] ~= nil then
		return false
	end

	local count = self[4] + 1

	sparse[key] = count
	self[2][count] = key
	self[3][count] = value

	self[4] = count

	if count > self[5] then
		self[5] = count
	end

	return true
end

--- Removes a key from the map.<br>
--- Uses swap-with-last, making removal O(1). Dense ordering is not preserved.
---@param self SparseMap The SparseMap instance.
---@param key K The key to remove.
---@return V? removed_value The removed value, or `nil` if the key was not found.
---@usage <br>
--- ```
--- local map = SparseMap.new()
--- map:set("a", 1)
--- map:set("b", 2)
--- print(map:remove("a")) -- 1
--- print(map:contains("a")) -- false
--- ```
function SparseMap.remove(self, key)
	local sparse = self[1]
	local index = sparse[key]

	if index == nil then
		return nil
	end

	local dense_keys = self[2]
	local dense_values = self[3]

	local count = self[4]
	local removed_value = dense_values[index]

	if index ~= count then
		local last_key = dense_keys[count]
		local last_value = dense_values[count]

		dense_keys[index] = last_key
		dense_values[index] = last_value

		sparse[last_key] = index
	end

	dense_keys[count] = nil
	dense_values[count] = nil
	sparse[key] = nil

	self[4] = count - 1

	return removed_value
end

--- Removes the entry at a dense index.<br>
--- Uses swap-with-last, making removal O(1). Dense ordering is not preserved.
---@param self SparseMap The SparseMap instance.
---@param index integer The dense index to remove.
---@return K? removed_key The removed key, or `nil` if the index was out of range.
---@return V? removed_value The removed value, or `nil` if the index was out of range.
---@usage <br>
--- ```
--- local map = SparseMap.new()
--- map:set("a", 1)
--- map:set("b", 2)
--- local key, value = map:remove_at(1)
--- print(key, value) -- "a", 1
--- ```
function SparseMap.remove_at(self, index)
	local count = self[4]

	if index < 1 or index > count then
		return nil, nil
	end

	local sparse = self[1]
	local dense_keys = self[2]
	local dense_values = self[3]

	local key = dense_keys[index]
	local value = dense_values[index]

	if index ~= count then
		local last_key = dense_keys[count]
		local last_value = dense_values[count]

		dense_keys[index] = last_key
		dense_values[index] = last_value

		sparse[last_key] = index
	end

	dense_keys[count] = nil
	dense_values[count] = nil
	sparse[key] = nil

	self[4] = count - 1

	return key, value
end

--- Removes all entries from the map.<br>
--- The backing tables are replaced.
---@param self SparseMap The SparseMap instance.
---@return SparseMap<K, V> self
function SparseMap.clear(self)
	self[1] = {}
	self[2] = {}
	self[3] = {}
	self[4] = 0

	return self
end

function SparseMap._iter(state, _)
	state[2] = state[2] + 1

	if state[2] <= state[1][4] then
		return state[2], state[1][2][state[2]], state[1][3][state[2]]
	end
end

--- Iterates over all active entries.<br>
--- Yields `dense_index, key, value` for each entry. Walks the dense arrays and is typically faster than iterating over the sparse hash table.
---@param self SparseMap The SparseMap instance.
---@return fun() iterator Iterator that yields dense_index, key, value pairs.
---@return table state The iterator state table.
---@return integer initial Initial control variable.
---@usage <br>
--- ```
--- local map = SparseMap.new()
--- map:set("a", 1)
--- map:set("b", 2)
--- for index, key, value in map:iter() do
---   print(index, key, value)
--- end
--- ```
function SparseMap.iter(self)
	return SparseMap._iter, { self, 0 }, 0
end

function SparseMap._iter_keys(state, _)
	state[2] = state[2] + 1

	if state[2] <= state[1][4] then
		return state[1][2][state[2]]
	end
end

--- Iterates over all keys.
---@param self SparseMap The SparseMap instance.
---@return fun() iterator Iterator that yields each key.
---@return table state The iterator state table.
---@return integer initial Initial control variable.
---@usage <br>
--- ```
--- local map = SparseMap.new()
--- map:set("a", 1)
--- map:set("b", 2)
--- for key in map:keys() do
---   print(key)
--- end
--- ```
function SparseMap.keys(self)
	return SparseMap._iter_keys, { self, 0 }, 0
end

function SparseMap._iter_values(state, _)
	state[2] = state[2] + 1

	if state[2] <= state[1][4] then
		return state[1][3][state[2]]
	end
end

--- Iterates over all values.
---@param self SparseMap The SparseMap instance.
---@return fun() iterator Iterator that yields each value.
---@return table state The iterator state table.
---@return integer initial Initial control variable.
---@usage <br>
--- ```
--- local map = SparseMap.new()
--- map:set("a", 1)
--- map:set("b", 2)
--- for value in map:values() do
---   print(value)
--- end
--- ```
function SparseMap.values(self)
	return SparseMap._iter_values, { self, 0 }, 0
end

--- Calls a function for every active entry.
---@param self SparseMap The SparseMap instance.
---@param fn fun(key: K, value: V, dense_index: integer) The function to call for each entry.
---@usage <br>
--- ```
--- local map = SparseMap.new()
--- map:set("a", 1)
--- map:set("b", 2)
--- map:for_each(function(key, value, index)
---   print(key, value, index)
--- end)
--- ```
function SparseMap.for_each(self, fn)
	local count = self[4]
	local keys = self[2]
	local values = self[3]

	for i = 1, count do
		fn(keys[i], values[i], i)
	end
end

--- Rebuilds the sparse lookup table after dense arrays are reordered.
---@param self SparseMap The SparseMap instance.
---@return SparseMap<K, V> self
function SparseMap.rebuild_indices(self)
	local sparse = self[1]
	local keys = self[2]
	local count = self[4]

	for i = 1, count do
		sparse[keys[i]] = i
	end

	return self
end

--- Sorts the map using a comparator over dense indices.<br>
--- The comparator receives `key_a, value_a, key_b, value_b` and must return `true` when A should appear before B. Sorting is performed in-place.
---@param self SparseMap The SparseMap instance.
---@param comparator fun(key_a: K, value_a: V, key_b: K, value_b: V): boolean The comparison function.
---@return SparseMap<K, V> self
function SparseMap.sort(self, comparator)
	local count = self[4]

	if count < 2 then
		return self
	end

	local keys = self[2]
	local values = self[3]

	local order = {}

	for i = 1, count do
		order[i] = i
	end

	table_sort(order, function(a, b)
		return comparator(
			keys[a],
			values[a],
			keys[b],
			values[b]
		)
	end)

	local new_keys = {}
	local new_values = {}

	for i = 1, count do
		local old_index = order[i]

		new_keys[i] = keys[old_index]
		new_values[i] = values[old_index]
	end

	self[2] = new_keys
	self[3] = new_values

	SparseMap.rebuild_indices(self)

	return self
end

--- Sorts entries by key.<br>
--- For comparable keys such as numbers or strings.
---@param self SparseMap The SparseMap instance.
---@param ascending? boolean Sort ascending when `true` or `nil`; descending when `false`.
---@return SparseMap<K, V> self
---@usage <br>
--- ```
--- local map = SparseMap.new()
--- map:set("c", 3)
--- map:set("a", 1)
--- map:set("b", 2)
--- map:sort_by_key()
--- for key, value in map:iter() do
---   print(key, value)
--- end
--- -- Outputs: a 1, b 2, c 3
--- ```
function SparseMap.sort_by_key(self, ascending)
	if ascending == false then
		return SparseMap.sort(self, function(a, _, b, _)
			return a > b
		end)
	end

	return SparseMap.sort(self, function(a, _, b, _)
		return a < b
	end)
end

--- Sorts entries by value.<br>
--- For comparable values such as numbers or strings.
---@param self SparseMap The SparseMap instance.
---@param ascending? boolean Sort ascending when `true` or `nil`; descending when `false`.
---@return SparseMap<K, V> self
function SparseMap.sort_by_value(self, ascending)
	if ascending == false then
		return SparseMap.sort(self, function(_, a, _, b)
			return a > b
		end)
	end

	return SparseMap.sort(self, function(_, a, _, b)
		return a < b
	end)
end

--- Sorts entries by numeric key in ascending order.
---@param self SparseMap The SparseMap instance.
---@return SparseMap<K, V> self
function SparseMap.sort_by_key_ascending(self)
	return SparseMap.sort_by_key(self, true)
end

--- Sorts entries by numeric key in descending order.
---@param self SparseMap The SparseMap instance.
---@return SparseMap<K, V> self
function SparseMap.sort_by_key_descending(self)
	return SparseMap.sort_by_key(self, false)
end

--- Sorts entries by numeric value in ascending order.
---@param self SparseMap The SparseMap instance.
---@return SparseMap<K, V> self
function SparseMap.sort_by_value_ascending(self)
	return SparseMap.sort_by_value(self, true)
end

--- Sorts entries by numeric value in descending order.
---@param self SparseMap The SparseMap instance.
---@return SparseMap<K, V> self
function SparseMap.sort_by_value_descending(self)
	return SparseMap.sort_by_value(self, false)
end

--- Returns the dense index of the minimum value.<br>
--- Returns `nil` when the map is empty.
---@param self SparseMap The SparseMap instance.
---@return integer? dense_index The dense index of the minimum value, or `nil` if empty.
function SparseMap.min_index(self)
	local count = self[4]

	if count == 0 then
		return nil
	end

	local values = self[3]

	local best_index = 1
	local best_value = values[1]

	for i = 2, count do
		local value = values[i]

		if value < best_value then
			best_index = i
			best_value = value
		end
	end

	return best_index
end

--- Returns the dense index of the maximum value.<br>
--- Returns `nil` when the map is empty.
---@param self SparseMap The SparseMap instance.
---@return integer? dense_index The dense index of the maximum value, or `nil` if empty.
function SparseMap.max_index(self)
	local count = self[4]

	if count == 0 then
		return nil
	end

	local values = self[3]

	local best_index = 1
	local best_value = values[1]

	for i = 2, count do
		local value = values[i]

		if value > best_value then
			best_index = i
			best_value = value
		end
	end

	return best_index
end

--- Returns the key and value of the minimum value.<br>
--- Returns `nil, nil` for an empty map.
---@param self SparseMap The SparseMap instance.
---@return K? key The key of the minimum value, or `nil` if empty.
---@return V? value The minimum value, or `nil` if empty.
function SparseMap.min(self)
	local index = SparseMap.min_index(self)

	if index == nil then
		return nil, nil
	end

	return self[2][index],
		self[3][index]
end

--- Returns the key and value of the maximum value.<br>
--- Returns `nil, nil` for an empty map.
---@param self SparseMap The SparseMap instance.
---@return K? key The key of the maximum value, or `nil` if empty.
---@return V? value The maximum value, or `nil` if empty.
function SparseMap.max(self)
	local index = SparseMap.max_index(self)

	if index == nil then
		return nil, nil
	end

	return self[2][index],
		self[3][index]
end

--- Removes every entry for which the predicate returns true.<br>
--- Because removal is O(1), this operates efficiently even when many entries are removed.
---@param self SparseMap The SparseMap instance.
---@param predicate fun(key: K, value: V, dense_index: integer): boolean The predicate function. Returns `true` to remove the entry.
---@return integer removed_count The number of entries removed.
function SparseMap.remove_if(self, predicate)
	local removed_count = 0
	local i = 1

	while i <= self[4] do
		local key = self[2][i]
		local value = self[3][i]

		if predicate(key, value, i) then
			SparseMap.remove_at(self, i)
			removed_count = removed_count + 1

			-- Do not increment i. The last element was moved here.
		else
			i = i + 1
		end
	end

	return removed_count
end

--- Creates an independent copy of the SparseMap.
---@param self SparseMap The SparseMap instance.
---@return SparseMap<K, V> result A new SparseMap with the same entries.
function SparseMap.clone(self)
	local result = SparseMap.new(self[5])

	local count = self[4]
	local source_keys = self[2]
	local source_values = self[3]

	local dense_keys = result[2]
	local dense_values = result[3]
	local sparse = result[1]

	for i = 1, count do
		local key = source_keys[i]

		dense_keys[i] = key
		dense_values[i] = source_values[i]
		sparse[key] = i
	end

	result[4] = count

	return result
end

--- Returns the dense key array.<br>
--- The returned table is the actual internal storage. Modifying it can invalidate the sparse lookup table.
---@param self SparseMap The SparseMap instance.
---@return K[] dense_keys The dense key array.
function SparseMap.get_dense_keys(self)
	return self[2]
end

--- Returns the dense value array.<br>
--- The returned table is the actual internal storage. Modifying it can invalidate the sparse map.
---@param self SparseMap The SparseMap instance.
---@return V[] dense_values The dense value array.
function SparseMap.get_dense_values(self)
	return self[3]
end

--- Returns the sparse key-to-index table.<br>
--- The returned table is the actual internal storage. Modifying it can invalidate the sparse map.
---@param self SparseMap The SparseMap instance.
---@return table<K, integer> sparse The sparse lookup table.
function SparseMap.get_sparse_indices(self)
	return self[1]
end

--- Returns a string representation of the map.
---@param self SparseMap The SparseMap instance.
---@return string string String representation of the SparseMap.
---@usage <br>
--- ```
--- local map = SparseMap.new()
--- map:set("a", 1)
--- print(tostring(map)) -- "SparseMap(size=1, capacity=1)"
--- ```
function SparseMap.__tostring(self)
	return string_format(
		"SparseMap(size=%d, capacity=%d)",
		self[4],
		self[5]
	)
end

-- Export
return SparseMap
