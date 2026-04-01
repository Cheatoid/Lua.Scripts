-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Augment existing standard table library.

local next = next
local rawget = rawget
local rawset = rawset
local select = select
local setmetatable = setmetatable
local type = type
local math_random = math.random
local string_upper = string.upper

local table = assert(_G.table, "table library not found")

--- Check if a table is empty.
--- Returns true if the table has no key-value pairs.
--- @param t table Table to check.
--- @return boolean empty True if the table is empty, false otherwise.
--- @usage <br>
--- ```
--- local empty = {}
--- local full = {a = 1}
--- print(table.is_empty(empty)) -- true
--- print(table.is_empty(full))  -- false
--- ```
local function table_isempty(t)
	return next(t) == nil
end

table.is_empty = table_isempty

--- Clear all key-value pairs from a table.
--- Removes all entries from the table in-place.
--- @param t table Table to clear.
--- @return nil
--- @usage <br>
--- ```
--- local t = {a = 1, b = 2, c = 3}
--- table.clear(t)
--- print(next(t)) -- nil (table is now empty)
--- ```
local function table_clear(t)
	for k in next, t do
		t[k] = nil
	end
end

table.clear = table_clear
table.empty = table_clear

--- Count the number of key-value pairs in a table.
--- Returns the total number of entries in the table.
--- @param t table Table to count entries in.
--- @return integer count Number of key-value pairs in the table.
--- @usage <br>
--- ```
--- local t = {a = 1, b = 2, c = 3}
--- print(table.count(t)) -- 3
--- ```
local function table_count(t)
	local amount = 0

	for _ in next, t do
		amount = amount + 1
	end

	return amount
end

table.count = table_count

--- Get all keys from a table.
--- Returns an array containing all keys from the input table.
--- @param t table Input table to extract keys from.
--- @param out table|nil out Optional output table to store keys in (default: new table).
--- @return table keys Array containing all keys from the input table.
--- @usage <br>
--- ```
--- local t = {a = 1, b = 2, c = 3}
--- local keys = table.keys(t)
--- -- keys might be: {"a", "b", "c"} (order not guaranteed)
--- ```
local function table_keys(t, out)
	out = out or {}

	for k in next, t do
		out[#out + 1] = k
	end

	return out
end

table.keys = table_keys

--- Get all values from a table.
--- Returns an array containing all values from the input table.
--- @param t table Input table to extract values from.
--- @param out table|nil out Optional output table to store values in (default: new table).
--- @return table values Array containing all values from the input table.
--- @usage <br>
--- ```
--- local t = {a = 1, b = 2, c = 3}
--- local values = table.values(t)
--- -- values might be: {1, 2, 3} (order not guaranteed)
--- ```
local function table_values(t, out)
	out = out or {}

	for _, v in next, t do
		out[#out + 1] = v
	end

	return out
end

table.values = table_values

--- Get all key-value pairs from a table as array of arrays.
--- Returns an array where each element is a 2-element array {key, value}.
--- @param t table Input table to extract key-value pairs from.
--- @param out table|nil out Optional output table to store pairs in (default: new table).
--- @return table pairs Array of {key, value} arrays.
--- @usage <br>
--- ```
--- local t = {a = 1, b = 2}
--- local pairs = table.keys_values(t)
--- -- pairs might be: {{"a", 1}, {"b", 2}} (order not guaranteed)
--- ```
local function table_keys_values(t, out)
	out = out or {}

	for k, v in next, t do
		out[#out + 1] = { [1] = k, [2] = v }
	end

	return out
end

table.keys_values = table_keys_values

--- Get all key-value pairs from a table as array of objects.
--- Returns an array where each element is a table {k = key, v = value}.
--- @param t table Input table to extract key-value pairs from.
--- @param out table|nil out Optional output table to store pairs in (default: new table).
--- @return table pairs Array of {k = key, v = value} tables.
--- @usage <br>
--- ```
--- local t = {a = 1, b = 2}
--- local pairs = table.keys_values_named(t)
--- -- pairs might be: {{k = "a", v = 1}, {k = "b", v = 2}} (order not guaranteed)
--- ```
local function table_keys_values_named(t, out)
	out = out or {}

	for k, v in next, t do
		out[#out + 1] = { k = k, v = v }
	end

	return out
end

table.keys_values_named = table_keys_values_named

--- Fast iteration over table keys with callback function.
--- Calls the provided function for each key in the table. Returns a function that can be called to continue iteration.
--- @param t table Table to iterate over.
--- @param f function Callback function to call for each key.
--- @return function|nil continuation Function to continue iteration, or nil if table is empty.
--- @usage <br>
--- ```
--- local t = {a = 1, b = 2, c = 3}
--- local cont = table.fast_keys(t, function(k) print(k) end)
--- if cont then cont() end -- Continue iteration
--- ```
local function fast_keys(t, f)
	-- TODO: benchmark this vs goto.
	local f2 = f -- upvalue
	local k = next(t)
	if k ~= nil then
		f2(k)
		return function()
			local f3 = f2     -- upvalue
			local k = next(t, k) -- shadow
			while k ~= nil do
				f3(k)
				k = next(t, k)
			end
		end
	end
end

table.fast_keys = fast_keys

--- Fast iteration over table values with callback function.
--- Calls the provided function for each value in the table. Returns a function that can be called to continue iteration.
--- @param t table Table to iterate over.
--- @param f function Callback function to call for each value.
--- @return function|nil continuation Function to continue iteration, or nil if table is empty.
--- @usage <br>
--- ```
--- local t = {a = 1, b = 2, c = 3}
--- local cont = table.fast_values(t, function(v) print(v) end)
--- if cont then cont() end -- Continue iteration
--- ```
local function fast_values(t, f)
	-- TODO: benchmark this vs goto.
	local f2 = f -- upvalue
	local k, v = next(t)
	if k ~= nil then
		f2(v)
		return function()
			local f3 = f2        -- upvalue
			local k, v = next(t, k) -- shadow
			while k ~= nil do
				f3(v)
				k = next(t, k)
			end
		end
	end
end

table.fast_values = fast_values

--- Fast iteration over table key-value pairs with callback function.
--- Calls the provided function for each key-value pair in the table. Returns a function that can be called to continue iteration.
--- @param t table Table to iterate over.
--- @param f function Callback function to call for each key-value pair (function(key, value)).
--- @return function|nil continuation Function to continue iteration, or nil if table is empty.
--- @usage <br>
--- ```
--- local t = {a = 1, b = 2, c = 3}
--- local cont = table.fast_keys_values(t, function(k, v) print(k, v) end)
--- if cont then cont() end -- Continue iteration
--- ```
local function fast_keys_values(t, f)
	-- TODO: benchmark this vs goto.
	local f2 = f -- upvalue
	local k, v = next(t)
	if k ~= nil then
		f2(k, v)
		return function()
			local f3 = f2        -- upvalue
			local k, v = next(t, k) -- shadow
			while k ~= nil do
				f3(k, v)
				k = next(t, k)
			end
		end
	end
end

table.fast_keys_values = fast_keys_values

local table_unpack = table.unpack or unpack
table.unpack = table_unpack

do
	local HASH = "#"

	--- Pack arguments into a table with n field.
	--- Creates a table containing all arguments with an 'n' field indicating the count.
	--- @param ... any Arguments to pack.
	--- @return table packed Table containing arguments with n field.
	--- @usage <br>
	--- ```
	--- local packed = table.pack(1, 2, 3)
	--- -- packed is: {1, 2, 3, n = 3}
	--- ```
	local table_pack = table.pack or function(...)
		return { n = select(HASH, ...), ... }
	end

	table.pack = table_pack

	--- Unwraps arguments, optionally unpacking a single table argument.
	--- If there's exactly one argument and it's a table, unpacks it and returns its contents.
	--- Otherwise returns the arguments as-is.
	--- @param ... any Variable number of arguments to unwrap.
	--- @return ... any unwrapped The unwrapped arguments, or unpacked table contents if single table argument.
	local function table_unwrap(...)
		local argc = select(HASH, ...)
		if argc == 0 then return end
		if argc == 1 then
			local value = (...) -- select(1, ...)
			if type(value) == "table" then
				return table_unpack(value)
			end
		end
		return ...
	end

	table.unwrap = table_unwrap
end

--- Create a shallow copy of a table.
--- Copies all key-value pairs from the source table to a new table (doesn't copy nested tables).
--- @param t table Source table to copy.
--- @param out table|nil Optional output table to copy into (default: new table).
--- @return table copy Shallow copy of the source table.
--- @usage <br>
--- ```
--- local original = {a = 1, b = 2}
--- local copy = table.shallow_copy(original)
--- copy.a = 10 -- Doesn't affect original
--- print(original.a) -- 1
--- ```
local function shallow_copy(t, out)
	out = out or {}

	for key, value in next, t do
		out[key] = value
	end

	return out
end

table.shallow_copy = shallow_copy

--- Create a deep copy of a table.
--- Recursively copies all key-value pairs, including nested tables (handles circular references).
--- @param t table Source table to copy.
--- @param seen table|nil Internal table for tracking visited tables (for circular reference handling).
--- @param out table|nil Optional output table to copy into (default: new table).
--- @return table copy Deep copy of the source table.
--- @usage <br>
--- ```
--- local original = {a = {x = 1}, b = 2}
--- local copy = table.deep_copy(original)
--- copy.a.x = 10 -- Doesn't affect original
--- print(original.a.x) -- 1
--- ```
local function deep_copy(t, seen, out)
	seen = seen or {}
	if seen[t] then
		return seen[t]
	end
	out = out or {}
	seen[t] = out

	for key, value in next, t do
		if type(value) == "table" then
			out[key] = deep_copy(value, seen, out)
		else
			out[key] = value
		end
	end

	return out
end

table.deep_copy = deep_copy

--- Create a deep copy of a table with metatables.
--- Recursively copies all key-value pairs including metatables (handles circular references).
--- @param t table Source table to copy.
--- @param seen table|nil Internal table for tracking visited tables (for circular reference handling).
--- @param out table|nil Optional output table to copy into (default: new table).
--- @return table copy Deep copy with metatables preserved.
--- @usage <br>
--- ```
--- local mt = {__index = function() return "default" end}
--- local original = setmetatable({a = 1}, mt)
--- local copy = table.deep_copy_with_meta(original)
--- -- copy has the same metatable as original
--- ```
local function deep_copy_with_meta(t, seen, out)
	seen = seen or {}
	if seen[t] then
		return seen[t]
	end
	out = out or {}
	seen[t] = out

	-- Prefer debug.getmetatable if available, fallback to getmetatable
	local meta = (debug and debug.getmetatable or getmetatable)(t)

	for key, value in next, t do
		if type(value) == "table" then
			out[key] = deep_copy_with_meta(value, seen)
		else
			out[key] = value
		end
	end

	-- Copy metatable if it exists
	if meta then
		(debug and debug.setmetatable or setmetatable)(out, deep_copy_with_meta(meta, seen))
	end

	return out
end

table.deep_copy_with_meta = deep_copy_with_meta

--- Convert a table to a dense array (numeric indices only).
--- Extracts all values from the input table and returns them in a new array with sequential numeric indices.
--- @param t table Input table to convert to array.
--- @return table array New array containing all values from the input table.
--- @usage <br>
--- ```
--- -- Returns: {10, 20, 30}
--- local arr = table.array({a = 10, b = 20, c = 30})
--- for i, v in ipairs(arr) do
---   print(i, v)
--- end
--- ```
local function table_array(t)
	local arr, i = {}, 0

	for _, value in next, t do
		i = i + 1
		arr[i] = value
	end

	return arr
end

table.array = table_array

--- Extract numeric-indexed elements from a table.
--- Returns a new table containing only elements with numeric indices (1, 2, 3, ...).
--- @param t table Input table to extract numeric elements from.
--- @param out table|nil Optional output table to copy into (default: new table).
--- @return table numeric Table containing only numeric-indexed elements.
--- @usage <br>
--- ```
--- local t = {a = 1, b = 2, [3] = 3, [4] = 4}
--- local numeric = table.numeric(t)
--- -- numeric is: {[3] = 3, [4] = 4}
--- ```
local function table_numeric(t, out)
	out = out or {}

	for i = 1, #t do
		out[i] = t[i]
	end

	return out
end

table.numeric = table_numeric

--- Create an enumeration table with bidirectional mapping.
--- Creates a new table where each key maps to its value and each value maps back to its key.
--- @param t table Input table to create enumeration from.
--- @return table enum New table with bidirectional key-value mapping.
--- @usage <br>
--- ```
--- -- Returns: {RED = "red", "red" = "RED", BLUE = "blue", "blue" = "BLUE"}
--- local colors = table.enum({RED = "red", BLUE = "blue"})
--- print(colors.RED)     -- "red"
--- print(colors["red"])  -- "RED"
--- ```
local function table_enum(t)
	local result = {}

	for key, value in next, t do
		result[key] = value
		result[value] = key
	end

	return result
end

table.enum = table_enum

--- Create an inverse mapping of a table.
--- Creates a new table where values become keys and keys become values.
--- @param t table Input table to invert.
--- @return table inverted New table with inverted key-value mapping.
--- @usage <br>
--- ```
--- -- Returns: {[10] = "a", [20] = "b", [30] = "c"}
--- local inverted = table.inverse({a = 10, b = 20, c = 30})
--- print(inverted[10])  -- "a"
--- print(inverted[20])  -- "b"
--- ```
local function table_inverse(t)
	local result = {}

	for key, value in next, t do
		result[value] = key
	end

	return result
end

table.inverse = table_inverse
table.invert = table_inverse

--- Ensures a key exists in a table, setting it to a default value if it doesn't.
--- @param tbl table The table to check.
--- @param key any The key to check.
--- @param def any The default value to set if the key doesn't exist.
--- @return any any The value of the key (either the existing value or the default value).
local function table_ensure(tbl, key, def)
	if tbl[key] == nil then
		tbl[key] = def
		return def
	end
	return tbl[key]
end

table.ensure = table_ensure

--- Ensures a key exists in a table, lazily creating it with a factory function if it doesn't.
--- The factory function is only called when the key is missing, and its return value is stored.
--- @param tbl table The table to check and modify.
--- @param key any The key to check for existence.
--- @param def function A factory function that creates the default value. Called with additional arguments.
--- @param ... any Additional arguments passed to the factory function.
--- @return any any The existing value of the key, or the newly created value from the factory function.
local function table_ensure_lazy(tbl, key, def, ...)
	if tbl[key] == nil then
		def = def(...)
		tbl[key] = def
		return def
	end
	return tbl[key]
end

table.ensure_lazy = table_ensure_lazy

--- Creates a case-insensitive wrapper for any table or creates a new case-insensitive table.
--- Allows reading/writing string keys regardless of case.
--- @param t table|nil The table to wrap. If nil, creates a new empty table.
--- @return table table Case-insensitive wrapper for the target table.
local function table_make_case_insensitive(t)
	-- Create new table if none provided
	if not t then
		t = {}
	end

	local wrapper = {} -- proxy

	-- Metamethods for case-insensitive access
	wrapper.__index = function(self, key)
		if type(key) ~= "string" then return rawget(self, key) end
		local v = rawget(self, string_upper(key))
		if v ~= nil then return v end
		return rawget(t, string_upper(key))
	end

	wrapper.__newindex = function(self, key, value)
		if type(key) ~= "string" then
			rawset(self, key, value)
			return
		end
		local upper_key = string_upper(key)
		rawset(self, upper_key, value)
		t[upper_key] = value
	end

	-- Set up the metatable
	return setmetatable(wrapper, wrapper)
end

table.make_case_insensitive = table_make_case_insensitive

--- Create a case-insensitive wrapper for a table.
--- Returns a proxy table that allows case-insensitive access to string keys while preserving original keys.
--- @param t table Input table to make case-insensitive.
--- @return table proxy Case-insensitive proxy table that wraps the original.
--- @usage <br>
--- ```
--- local config = {Name = "John", Age = 25}
--- local ci_config = table.make_case_insensitive(config)
--- print(ci_config.name)  -- "John" (case-insensitive access)
--- print(ci_config.NAME)  -- "John" (case-insensitive access)
--- ci_config.age = 30     -- Updates original table
--- print(config.Age)      -- 30
--- ```
local function table_case_insensitive(t)
	local key_map = {}
	-- Properly pre-fill the lookup with original keys
	for key in next, t do
		if type(key) == "string" then
			key_map[string_upper(key)] = key
		end
	end
	return setmetatable({}, {
		__index = function(_, key)
			if type(key) == "string" then
				local original = key_map[string_upper(key)]
				if original ~= nil then
					return t[original]
				end
			end
			return t[key]
		end,
		__newindex = function(_, key, value)
			if type(key) == "string" then
				local ukey = string_upper(key)
				if key_map[ukey] ~= nil then
					t[key_map[ukey]] = value
				else
					key_map[ukey] = key
					t[key] = value
				end
			else
				t[key] = value
			end
		end,
		__pairs = function()
			return next, t
		end,
		__ipairs = function()
			return ipairs(t)
		end,
		__len = function()
			return #t
		end,
	})
end

table.case_insensitive = table_case_insensitive

--- Remove the first N elements from an array in-place.
--- Efficiently removes the specified number of elements from the beginning of an array by shifting remaining elements.
--- @param arr table Array to remove elements from (modified in-place).
--- @param numElements integer Number of elements to remove from the beginning (default: 1).
--- @return table array The modified array with elements removed.
--- @usage <br>
--- ```
--- local arr = {1, 2, 3, 4, 5}
--- table.remove_first(arr, 2)
--- -- arr is now: {3, 4, 5}
---
--- local arr2 = {1, 2}
--- table.remove_first(arr2, 5)
--- -- arr2 is now: {}
--- ```
local function table_remove_first(arr, numElements)
	-- Avoid calling table.remove for performance reasons.
	local n = #arr
	if n <= numElements then
		-- If the table has numElements or fewer elements, clear it entirely.
		--for i = 1, n do arr[i] = nil end
		return {}
	end
	-- Shift elements left by numElements positions.
	--for i = numElements + 1, n do arr[i - numElements] = arr[i] end
	-- Nil out the freed-up (tail) entries.
	--for i = n, n - numElements + 1, -1 do arr[i] = nil end
	-- Move numElements while clearing the tail.
	for i = n, numElements + 1, -1 do
		arr[i - numElements] = arr[i]
		arr[i] = nil
	end
	return arr
end

table.remove_first = table_remove_first

--- Remove the last N elements from an array in-place.
--- Efficiently removes the specified number of elements from the end of an array.
--- @param arr table Array to remove elements from (modified in-place).
--- @param numElements integer Number of elements to remove from the end (default: 1).
--- @return table array The modified array with elements removed.
--- @usage <br>
--- ```
--- local arr = {1, 2, 3, 4, 5}
--- table.remove_last(arr, 2)
--- -- arr is now: {1, 2, 3}
---
--- local arr2 = {1, 2}
--- table.remove_last(arr2, 5)
--- -- arr2 is now: {}
--- ```
local function table_remove_last(arr, numElements)
	-- Avoid calling table.remove for performance reasons.
	local n = #arr
	if n <= numElements then
		-- If the table has numElements or fewer elements, clear it entirely.
		for i = 1, n do arr[i] = nil end
		return arr
	end
	-- Nil out the last numElements entries.
	for i = n, n - numElements + 1, -1 do
		arr[i] = nil
	end
	return arr
end

table.remove_last = table_remove_last

--- Remove duplicate values from a table.
--- Creates a new table containing only the first occurrence of each unique value from the input table.
--- @param t table Input table to remove duplicates from.
--- @return table unique_table New table with duplicate values removed.
--- @usage <br>
--- ```
--- local arr = {1, 2, 3, 2, 4, 1, 5}
--- local unique = table.unique(arr)
--- -- unique is now: {1, 2, 3, 4, 5}
---
--- local mixed = {"a", "b", "a", "c", "b"}
--- local unique_mixed = table.unique(mixed)
--- -- unique_mixed is now: {"a", "b", "c"}
--- ```
local function table_unique(t)
	local seen = {}
	local result = {}
	local index = 0

	for _, value in next, t do
		if not seen[value] then
			seen[value] = true
			index = index + 1
			result[index] = value
		end
	end

	return result
end

table.unique = table_unique

--- Extract a slice of elements from an array.
--- Returns a new table containing elements from start_index to end_index (inclusive).
--- Supports negative indexes like string.sub (e.g., -1 = last element, -2 = second to last).
--- @param t table Input array to slice from.
--- @param start_index integer Starting index (1-based, supports negative, default: 1).
--- @param end_index integer|nil Ending index (inclusive, supports negative, default: #t).
--- @return table slice New array containing the sliced elements.
--- @usage <br>
--- ```
--- local arr = {1, 2, 3, 4, 5}
--- table.slice(arr, 2, 4)    -- {2, 3, 4}
--- table.slice(arr, 3)       -- {3, 4, 5}
--- table.slice(arr, 1, 2)    -- {1, 2}
--- table.slice(arr, -2)      -- {4, 5} (last 2 elements)
--- table.slice(arr, -3, -1)  -- {3, 4, 5} (last 3 elements)
--- table.slice(arr, -4, 2)   -- {2} (4th from last to 2nd)
--- ```
local function table_slice(t, start_index, end_index)
	local n = #t
	start_index = start_index or 1
	end_index = end_index or n

	-- Handle negative indexes (like string.sub)
	if start_index < 0 then start_index = n + start_index + 1 end
	if end_index < 0 then end_index = n + end_index + 1 end

	if start_index < 1 then start_index = 1 end
	if end_index > n then end_index = n end
	if start_index > end_index then return {} end

	local result = {}
	local j = 1
	for i = start_index, end_index do
		result[j] = t[i]
		j = j + 1
	end

	return result
end

table.slice = table_slice

--- Split an array into chunks of specified size.
--- Returns a new array where each element is a sub-array containing up to chunk_size elements.
--- @param t table Input array to split into chunks.
--- @param chunk_size integer Size of each chunk (must be > 0, default: 1).
--- @return table chunks Array of chunk arrays.
--- @usage <br>
--- ```
--- local arr = {1, 2, 3, 4, 5, 6, 7}
--- table.chunks(arr, 3) -- {{1, 2, 3}, {4, 5, 6}, {7}}
--- table.chunks(arr, 2) -- {{1, 2}, {3, 4}, {5, 6}, {7}}
--- ```
local function table_chunks(t, chunk_size)
	chunk_size = chunk_size or 1
	if chunk_size <= 0 then return error("chunk_size must be > 0") end

	local n = #t
	local chunks = {}
	local chunk_count = 0

	for i = 1, n, chunk_size do
		local end_index = i + chunk_size - 1
		if end_index > n then end_index = n end

		chunk_count = chunk_count + 1
		chunks[chunk_count] = table_slice(t, i, end_index)
	end

	return chunks
end

table.chunks = table_chunks

--- Rotate an array left by the specified amount.
--- Elements are shifted left, with elements that fall off the beginning wrapping around to the end.
--- @param t table Input array to rotate.
--- @param amount integer Number of positions to rotate left.
--- @return table rotated New array with elements rotated left.
--- @usage <br>
--- ```
--- local arr = {1, 2, 3, 4, 5}
--- table.rotate_left(arr, 2) -- {3, 4, 5, 1, 2}
--- ```
local function table_rotate_left(t, amount)
	amount = tonumber(amount) or 0
	if amount <= 0 then return shallow_copy(t) end

	local n = #t
	if amount >= n then return shallow_copy(t) end

	local result = {}
	local j = 1

	-- Copy elements from amount+1 to end
	for i = amount + 1, n do
		result[j] = t[i]
		j = j + 1
	end

	-- Copy elements from 1 to amount
	for i = 1, amount do
		result[j] = t[i]
		j = j + 1
	end

	return result
end

table.rotate_left = table_rotate_left

--- Rotate an array right by the specified amount.
--- Elements are shifted right, with elements that fall off the end wrapping around to the beginning.
--- @param t table Input array to rotate.
--- @param amount integer Number of positions to rotate right.
--- @return table rotated New array with elements rotated right.
--- @usage <br>
--- ```
--- local arr = {1, 2, 3, 4, 5}
--- table.rotate_right(arr, 2) -- {4, 5, 1, 2, 3}
--- ```
local function table_rotate_right(t, amount)
	amount = tonumber(amount) or 0
	if amount <= 0 then return shallow_copy(t) end

	local n = #t
	if amount >= n then return shallow_copy(t) end

	return table_rotate_left(t, n - amount)
end

table.rotate_right = table_rotate_right

--- Rotate an array by the specified amount.
--- Positive amounts rotate right, negative amounts rotate left.
--- @param t table Input array to rotate.
--- @param rotation integer Number of positions to rotate (negative = left, positive = right).
--- @return table rotated New array with elements rotated.
--- @usage <br>
--- ```
--- local arr = {1, 2, 3, 4, 5}
--- table.rotate(arr, 2)  -- {4, 5, 1, 2, 3} (rotate right 2)
--- table.rotate(arr, -2) -- {3, 4, 5, 1, 2} (rotate left 2)
--- ```
local function table_rotate(t, rotation)
	rotation = tonumber(rotation) or 0
	if rotation < 0 then
		return table_rotate_left(t, -rotation)
	end
	return table_rotate_right(t, rotation)
end

table.rotate = table_rotate

--- Reverse the order of elements in an array.
--- Returns a new array with elements in reverse order (last element becomes first, etc.).
--- @param t table Input array to reverse.
--- @return table reversed New array with elements in reverse order.
--- @usage <br>
--- ```
--- local arr = {1, 2, 3, 4, 5}
--- table.reverse(arr) -- {5, 4, 3, 2, 1}
---
--- local chars = {"a", "b", "c"}
--- table.reverse(chars) -- {"c", "b", "a"}
--- ```
local function table_reverse(t)
	local n = #t
	local out = {}

	-- Copy elements in reverse order
	for i = 1, n do
		out[i] = t[n - i + 1]
	end

	return out
end

table.reverse = table_reverse

--- Create a switch-case table builder.
--- Provides a fluent interface for building switch-case mappings that can be baked into optimized lookup tables.
--- @param value any|nil Optional default value to switch on (can be nil for dynamic evaluation).
--- @return table builder A switch-case builder object with chaining methods.
--- @usage <br>
--- ```
--- local switch_builder = table.switch()
---   :case("monday", "Start of week")
---   :case("friday", "End of week")
---   :default("Mid week")
---
--- -- Bake into optimized lookup table
--- local lookup = switch_builder:bake()
--- print(lookup["monday"])  -- "Start of week"
--- print(lookup["tuesday"]) -- "Mid week"
---
--- -- Or evaluate dynamically
--- local result = switch_builder:eval("friday") -- "End of week"
--- ```
local function table_switch(value)
	local cases = {}
	local default_case

	local builder = {
		--- Add a case handler for a specific value.
		--- @param case_value any The value to match.
		--- @param handler any The value or function to return when this case matches.
		--- @return table builder The builder object for chaining.
		case = function(self, case_value, handler)
			cases[case_value] = handler
			return self
		end,

		--- Set the default case handler.
		--- @param handler any The value or function to return when no cases match.
		--- @return table builder The builder object for chaining.
		default = function(self, handler)
			default_case = handler
			return self
		end,

		--- Add multiple cases with the same handler.
		--- @param case_values table Array of case values.
		--- @param handler any The value or function to return when any case matches.
		--- @return table builder The builder object for chaining.
		cases = function(self, case_values, handler)
			for _, case_value in next, case_values do
				cases[case_value] = handler
			end
			return self
		end,

		--- Evaluate the switch and execute the matching case.
		--- @param v any The value to switch on.
		--- @return any result The result of the executed case handler.
		eval = function(_, v)
			if v == nil then
				v = value
			end
			local handler = cases[v] or default_case
			if handler then
				if type(handler) == "function" then
					return handler(v)
				end
				return handler
			end
		end,

		--- Bake the switch into an optimized lookup table.
		--- Creates a table with direct key-value lookups for maximum performance.
		--- @return table lookup Optimized lookup table with baked cases.
		bake = function()
			local lookup = shallow_copy(cases)
			if default_case ~= nil then
				-- Store default case under a special key
				lookup.__default = default_case
			end
			return lookup
		end,

		--- Create a function that performs the switch lookup.
		--- Returns a function that can be called repeatedly with values to get results.
		--- @return function switch_func A function that performs the switch lookup.
		bake_function = function(self)
			local lookup = self:bake()
			return function(v)
				local result = lookup[v]
				if result == nil then
					result = lookup.__default
				end
				if result and type(result) == "function" then
					return result(v)
				end
				return result
			end
		end,

		--- Get all configured cases as a table.
		--- @return table all_cases Table containing all case-value pairs.
		get_cases = function()
			return shallow_copy(cases)
		end,

		--- Get the default case handler.
		--- @return any default_case The default case handler.
		get_default = function()
			return default_case
		end,

		--- Clear all cases and default handler.
		--- @return table builder The builder object for chaining.
		clear = function(self)
			cases = {}
			default_case = nil
			return self
		end,
	}

	return builder
end

table.switch = table_switch

--- Create a case function for simple value mapping.
--- Alternative syntax for switch with direct value mapping.
--- @param value any The value to switch on.
--- @return table case A case object for chaining.
--- @usage <br>
--- ```
--- local result = case(status)
---   :when("active", "Running")
---   :when("inactive", "Stopped")
---   :when("error", "Failed")
---   :otherwise("Unknown")
--- ```
local function table_case(value)
	local mappings = {}
	local default_value

	local case_obj = {
		--- Map a case value to a return value.
		--- @param case_value any The value to match.
		--- @param return_value any The value to return when this case matches.
		--- @return table case The case object for chaining.
		when = function(self, case_value, return_value)
			mappings[case_value] = return_value
			return self
		end,

		--- Set the default return value.
		--- @param return_value any The value to return when no cases match.
		--- @return table case The case object for chaining.
		otherwise = function(self, return_value)
			default_value = return_value
			return self
		end,

		--- Evaluate and return the matched value.
		--- @return any value The matched value or default.
		eval = function()
			return mappings[value] or default_value
		end,
	}

	return case_obj
end

table.case = table_case

--- Create a weak table with weak keys.
--- @return table table A table with weak key references.
local function table_weak_keys()
	return setmetatable({}, { __mode = "k" })
end

table.weak_keys = table_weak_keys

--- Create a weak table with weak values.
--- @return table table A table with weak value references.
local function table_weak_values()
	return setmetatable({}, { __mode = "v" })
end

table.weak_values = table_weak_values

--- Create a weak table with weak keys and values.
--- @return table table A table with weak key and value references.
local function table_weak()
	return setmetatable({}, { __mode = "kv" })
end

table.weak = table_weak

--- Randomize the order of elements in a table using the Fisher-Yates shuffle algorithm.
--- This function shuffles the elements in-place and returns the same table for chaining.
--- @param t table The table to randomize (modified in-place).
--- @return table table The same table with elements randomized.
--- @usage <br>
--- ```
--- local arr = {1, 2, 3, 4, 5}
--- table.randomize(arr)
--- -- arr might now be: {3, 1, 5, 2, 4}
---
--- local colors = {"red", "green", "blue", "yellow"}
--- table.randomize(colors)
--- -- colors might now be: {"blue", "yellow", "red", "green"}
--- ```
local function table_randomize(t)
	local n = #t
	for i = n, 2, -1 do
		local j = math_random(i)
		t[i], t[j] = t[j], t[i]
	end
	return t
end

table.randomize = table_randomize

-- Export (for compatibility)
return table
