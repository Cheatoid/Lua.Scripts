-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Augment existing standard table library.

-- Localized global functions for better performance
local next = next
local rawget = rawget
local rawset = rawset
local select = select
local setmetatable = setmetatable
local tostring = tostring
local type = type
local math_random = math.random
local string_lower = string.lower
local string_rep = string.rep
local string_upper = string.upper
---@diagnostic disable-next-line: unnecessary-assert
local table = assert(_G.table, "table library is missing")
local table_sort = table.sort

local function table_isempty(t)
	return next(t) == nil
end

table.is_empty = table_isempty

local function table_clear(t)
	for k in next, t do
		t[k] = nil
	end
end

table.clear = table_clear
table.empty = table_clear

local function table_count(t)
	local amount = 0

	for _ in next, t do
		amount = amount + 1
	end

	return amount
end

table.count = table_count

local function table_keys(t, out)
	out = out or {}

	for k in next, t do
		out[#out + 1] = k
	end

	return out
end

table.keys = table_keys

local function table_values(t, out)
	out = out or {}

	for _, v in next, t do
		out[#out + 1] = v
	end

	return out
end

table.values = table_values

local function table_keys_values(t, out)
	out = out or {}

	for k, v in next, t do
		out[#out + 1] = { [1] = k, [2] = v }
	end

	return out
end

table.keys_values = table_keys_values

local function table_keys_values_named(t, out)
	out = out or {}

	for k, v in next, t do
		out[#out + 1] = { k = k, v = v }
	end

	return out
end

table.keys_values_named = table_keys_values_named

local function fast_keys(t, f)
	-- TODO: benchmark this vs goto.
	local f2 = f -- upvalue
	local k = next(t)
	if k ~= nil then
		f2(k)
		return function()
			local f3 = f2 -- upvalue
			local k = next(t, k) -- shadow
			while k ~= nil do
				f3(k)
				k = next(t, k)
			end
		end
	end
end

table.fast_keys = fast_keys

local function fast_values(t, f)
	-- TODO: benchmark this vs goto.
	local f2 = f -- upvalue
	local k, v = next(t)
	if k ~= nil then
		f2(v)
		return function()
			local f3 = f2  -- upvalue
			local k, v = next(t, k) -- shadow
			while k ~= nil do
				f3(v)
				k = next(t, k)
			end
		end
	end
end

table.fast_values = fast_values

local function fast_keys_values(t, f)
	-- TODO: benchmark this vs goto.
	local f2 = f -- upvalue
	local k, v = next(t)
	if k ~= nil then
		f2(k, v)
		return function()
			local f3 = f2  -- upvalue
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

	local table_pack = table.pack or function(...)
		return { n = select(HASH, ...), ... }
	end

	table.pack = table_pack

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

local function shallow_copy(t, out)
	out = out or {}

	for key, value in next, t do
		out[key] = value
	end

	return out
end

table.shallow_copy = shallow_copy

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

local function table_array(t)
	local arr, i = {}, 0

	for _, value in next, t do
		i = i + 1
		arr[i] = value
	end

	return arr
end

table.array = table_array

local function table_numeric(t, out)
	out = out or {}

	for i = 1, #t do
		out[i] = t[i]
	end

	return out
end

table.numeric = table_numeric

local function table_enum(t)
	local result = {}

	for key, value in next, t do
		result[key] = value
		result[value] = key
	end

	return result
end

table.enum = table_enum

local function table_inverse(t)
	local result = {}

	for key, value in next, t do
		result[value] = key
	end

	return result
end

table.inverse = table_inverse
table.invert = table_inverse

local function table_ensure(tbl, key, def)
	if tbl[key] == nil then
		tbl[key] = def
		return def
	end
	return tbl[key]
end

table.ensure = table_ensure

local function table_ensure_lazy(tbl, key, def, ...)
	if tbl[key] == nil then
		def = def(...)
		tbl[key] = def
		return def
	end
	return tbl[key]
end

table.ensure_lazy = table_ensure_lazy

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

local function table_lowercase_keys(t, out)
	out = out or {}
	for k, v in next, t do
		out[string_lower(k)] = v
	end
	return out
end

table.lowercase_keys = table_lowercase_keys
table.lowercase = table_lowercase_keys

local function table_uppercase_keys(t, out)
	out = out or {}
	for k, v in next, t do
		out[string_upper(k)] = v
	end
	return out
end

table.uppercase_keys = table_uppercase_keys
table.uppercase = table_uppercase_keys

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

local function table_rotate_right(t, amount)
	amount = tonumber(amount) or 0
	if amount <= 0 then return shallow_copy(t) end

	local n = #t
	if amount >= n then return shallow_copy(t) end

	return table_rotate_left(t, n - amount)
end

table.rotate_right = table_rotate_right

local function table_rotate(t, rotation)
	rotation = tonumber(rotation) or 0
	if rotation < 0 then
		return table_rotate_left(t, -rotation)
	end
	return table_rotate_right(t, rotation)
end

table.rotate = table_rotate

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

local function table_switch(value)
	local cases = {}
	local default_case

	local builder = {
		case = function(self, case_value, handler)
			cases[case_value] = handler
			return self
		end,

		default = function(self, handler)
			default_case = handler
			return self
		end,

		cases = function(self, case_values, handler)
			for _, case_value in next, case_values do
				cases[case_value] = handler
			end
			return self
		end,

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

		bake = function()
			local lookup = shallow_copy(cases)
			if default_case ~= nil then
				-- Store default case under a special key
				lookup.__default = default_case
			end
			return lookup
		end,

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

		get_cases = function()
			return shallow_copy(cases)
		end,

		get_default = function()
			return default_case
		end,

		clear = function(self)
			cases = {}
			default_case = nil
			return self
		end,
	}

	return builder
end

table.switch = table_switch

local function table_case(value)
	local mappings = {}
	local default_value

	local case_obj = {
		when = function(self, case_value, return_value)
			mappings[case_value] = return_value
			return self
		end,

		otherwise = function(self, return_value)
			default_value = return_value
			return self
		end,

		eval = function()
			return mappings[value] or default_value
		end,
	}

	return case_obj
end

table.case = table_case

local function table_weak_keys()
	return setmetatable({}, { __mode = "k" })
end

table.weak_keys = table_weak_keys

local function table_weak_values()
	return setmetatable({}, { __mode = "v" })
end

table.weak_values = table_weak_values

local function table_weak()
	return setmetatable({}, { __mode = "kv" })
end

table.weak = table_weak

local function table_randomize(t)
	local n = #t
	for i = n, 2, -1 do
		local j = math_random(i)
		t[i], t[j] = t[j], t[i]
	end
	return t
end

table.randomize = table_randomize

local function table_add(dest, source)
	-- Safety check: if tables are the same, nothing to do
	if dest == source then return dest end

	-- Type validation: both must be tables
	if type(source) ~= "table" then return dest end
	if type(dest) ~= "table" then dest = {} end

	for _, v in next, source do
		dest[#dest + 1] = v
	end

	return dest
end

table.add = table_add

local function table_merge(dest, source)
	-- Safety check: if tables are the same, nothing to do
	if dest == source then return dest end

	-- Type validation: both must be tables
	if type(source) ~= "table" then return dest end
	if type(dest) ~= "table" then dest = {} end

	for k, v in next, source do
		dest[k] = v
	end

	return dest
end

table.merge = table_merge

local function table_merge_preserve(dest, source)
	-- Safety check: if tables are the same, nothing to do
	if dest == source then return dest end

	-- Type validation: both must be tables
	if type(source) ~= "table" then return dest end
	if type(dest) ~= "table" then dest = {} end

	for k, v in next, source do
		if dest[k] == nil then
			dest[k] = v
		end
	end

	return dest
end

table.merge_preserve = table_merge_preserve

--- Comparison function for descending sort
local function table_sortdesc_cmp(a, b)
	return a > b
end

local function table_sortdesc(t)
	table_sort(t, table_sortdesc_cmp)
	return t
end

table.sortdesc = table_sortdesc

local function table_print(t, writer, indent, seen)
	seen = seen or {}
	indent = indent or 0
	local keys = table_keys(t)

	table_sort(keys, function(a, b)
		if type(a) == "number" and type(b) == "number" then return a < b end
		return tostring(a) < tostring(b)
	end)

	seen[t] = true

	for i = 1, #keys do
		local key = keys[i]
		local value = t[key]
		key = type(key) == "string" and "[\"" .. key .. "\"]" or "[" .. tostring(key) .. "]"
		writer(string_rep("\t", indent))

		if type(value) == "table" and not seen[value] then
			seen[value] = true
			writer(key, ":\n")
			table_print(value, writer, indent + 2, seen)
			seen[value] = nil
		else
			writer(key, "\t=\t", tostring(value), "\n")
		end
	end
end

table.print = table_print

-- Import dump_table module functionality
local dump_table_module = require("../standalone/dump_table")
table.dump = dump_table_module.dump
table.dump_print = dump_table_module.print

-- Export (for compatibility)
return table
