-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Augment existing global table library

local next = next
local type = type
local setmetatable = setmetatable
local string_lower = string.lower
local isstring = function(v) return type(v) == "string" end

local table = assert(_G.table, "table library not found")

local function table_array(tbl)
	local arr, i = {}, 0
	for _, v in next, tbl do
		i = i + 1
		arr[i] = v
	end
	return arr
end
table.array = table_array

local function table_enum(tbl)
	local result = {}
	for k, v in next, tbl do
		result[k] = v
		result[v] = k
	end
	return result
end
table.enum = table_enum

local function table_inverse(tbl)
	local result = {}
	for k, v in next, tbl do
		result[v] = k
	end
	return result
end
table.inverse = table_inverse

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
