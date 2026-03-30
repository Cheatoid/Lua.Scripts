-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Augment existing standard table library

local next = next
local type = type
local setmetatable = setmetatable
local string_lower = string.lower
local isstring = function(v) return type(v) == "string" end

local table = assert(_G.table, "table library not found")

--- Convert a table to a dense array (numeric indices only).
--- Extracts all values from the input table and returns them in a new array with sequential numeric indices.
--- @param tbl table Input table to convert to array.
--- @return table array New array containing all values from the input table.
--- @usage <br>
--- ```
--- -- Returns: {10, 20, 30}
--- local arr = table.array({a = 10, b = 20, c = 30})
--- for i, v in ipairs(arr) do
---   print(i, v)
--- end
--- ```
local function table_array(tbl)
	local arr, i = {}, 0
	for _, v in next, tbl do
		i = i + 1
		arr[i] = v
	end
	return arr
end
table.array = table_array

--- Create an enumeration table with bidirectional mapping.
--- Creates a new table where each key maps to its value and each value maps back to its key.
--- @param tbl table Input table to create enumeration from.
--- @return table enum_table New table with bidirectional key-value mapping.
--- @usage <br>
--- ```
--- -- Returns: {RED = "red", "red" = "RED", BLUE = "blue", "blue" = "BLUE"}
--- local colors = table.enum({RED = "red", BLUE = "blue"})
--- print(colors.RED)     -- "red"
--- print(colors["red"])  -- "RED"
--- ```
local function table_enum(tbl)
	local result = {}
	for k, v in next, tbl do
		result[k] = v
		result[v] = k
	end
	return result
end
table.enum = table_enum

--- Create an inverse mapping of a table.
--- Creates a new table where values become keys and keys become values.
--- @param tbl table Input table to invert.
--- @return table inverted_table New table with inverted key-value mapping.
--- @usage <br>
--- ```
--- -- Returns: {[10] = "a", [20] = "b", [30] = "c"}
--- local inverted = table.inverse({a = 10, b = 20, c = 30})
--- print(inverted[10])  -- "a"
--- print(inverted[20])  -- "b"
--- ```
local function table_inverse(tbl)
	local result = {}
	for k, v in next, tbl do
		result[v] = k
	end
	return result
end
table.inverse = table_inverse

--- Create a case-insensitive wrapper for a table.
--- Returns a proxy table that allows case-insensitive access to string keys while preserving original keys.
--- @param tbl table Input table to make case-insensitive.
--- @return table proxy Case-insensitive proxy table that wraps the original.
--- @usage <br>
--- ```
--- local config = {Name = "John", Age = 25}
--- local ci_config = table.make_case_insensitive(config)
--- print(ci_config.name)  -- "John" (case-insensitive access)
--- print(ci_config.NAME)  -- "John" (case-insensitive access)
--- ci_config.age = 30     -- Updates original table
--- print(config.Age)       -- 30
--- ```
local function table_make_case_insensitive(tbl)
	local key_map = {}
	-- Properly pre-fill the lookup with original keys
	for k in next, tbl do
		if isstring(k) then
			key_map[string_lower(k)] = k
		end
	end
	return setmetatable({}, {
		__index = function(_, key)
			if isstring(key) then
				local original = key_map[string_lower(key)]
				if original ~= nil then
					return tbl[original]
				end
			end
			return tbl[key]
		end,
		__newindex = function(_, key, value)
			if isstring(key) then
				local lkey = string_lower(key)
				if key_map[lkey] ~= nil then
					tbl[key_map[lkey]] = value
				else
					key_map[lkey] = key
					tbl[key] = value
				end
			else
				tbl[key] = value
			end
		end,
		__pairs = function()
			return pairs(tbl)
		end,
		__ipairs = function()
			return ipairs(tbl)
		end,
		__len = function()
			return #tbl
		end,
	})
end
table.make_case_insensitive = table_make_case_insensitive

--- Remove the first N elements from an array in-place.
--- Efficiently removes the specified number of elements from the beginning of an array by shifting remaining elements.
--- @param arr table Array to remove elements from (modified in-place).
--- @param numElements number Number of elements to remove from the beginning (default: 1).
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

-- TODO: LINQ?
