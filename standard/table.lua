-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Augment existing standard table library

-- Localized global functions for better performance
local error = error
local getmetatable = getmetatable
local ipairs = ipairs
local next = next
local rawget = rawget
local rawset = rawset
local select = select
local setmetatable = setmetatable
local tonumber = tonumber
local tostring = tostring
local type = type
--local math_ceil = math.ceil
local math_floor = math.floor
local math_random = math.random
local string = require "string"
local string_explode = string.explode
local string_find = string.find
local string_gsub = string.gsub
local string_lower = string.lower
local string_match = string.match
local string_rep = string.rep
local string_sub = string.sub
local string_upper = string.upper
local table = assert(_G.table, "table library is missing") ---@as tablelib
local table_concat = table.concat
local table_move = table.move -- Lua 5.3+
local table_sort = table.sort
local table_unpack = table.unpack or unpack

if not table.move then
	function table.move(sourceTbl, from, to, dest, destTbl)
		if type(sourceTbl) ~= "table" then
			return error("bad argument #1 to 'move' (table expected, got " .. type(sourceTbl) .. ")", 2)
		end
		if type(from) ~= "number" then
			return error("bad argument #2 to 'move' (number expected, got " .. type(from) .. ")", 2)
		end
		if type(to) ~= "number" then
			return error("bad argument #3 to 'move' (number expected, got " .. type(to) .. ")", 2)
		end
		if type(dest) ~= "number" then
			return error("bad argument #4 to 'move' (number expected, got " .. type(dest) .. ")", 2)
		end
		if destTbl ~= nil then
			if type(destTbl) ~= "table" then
				return error("bad argument #5 to 'move' (table expected, got " .. type(destTbl) .. ")", 2)
			end
		else
			destTbl = sourceTbl
		end

		local buffer = { table_unpack(sourceTbl, from, to) }

		dest = math_floor(dest - 1)
		for i = 1, to - from + 1 do
			destTbl[dest + i] = buffer[i]
		end

		return destTbl
	end
end

local table_sortasc = function(a, b)
	return a < b
end

local table_sortasc_num_str = function(a, b)
	if type(a) == "number" and type(b) == "number" then
		return a < b
	end
	return tostring(a) < tostring(b)
end

--- Comparison function for descending sort
local table_sortdesc_cmp = function(a, b)
	return a > b
end

--- Comparison function for sorting by field
local table_sort_by_field_cmp = function(a, b)
	if a[2] ~= b[2] then -- key
		return a[2] < b[2]
	end
	return a[1] < b[1] -- index
end

local table_is_empty = function(t)
	return next(t) == nil
end

table.is_empty = table_is_empty

local table_is_array = function(t)
	if type(t) ~= "table" then
		return false
	end

	local n = #t
	local count = 0

	for k in next, t do
		count = count + 1
		-- Every key must be a positive integer within [1, n].
		-- This avoids relying on next's (undefined) iteration order.
		if type(k) ~= "number" or k < 1 or k > n or k % 1 ~= 0 then
			return false
		end
	end

	-- Ensure no nil gaps (sparse arrays are not proper arrays)
	return count == n
end

table.is_array = table_is_array

local table_is_array_like = function(t)
	if type(t) ~= "table" then
		return false
	end

	for k in next, t do
		if type(k) ~= "number" then
			return false
		end
	end

	return true
end

table.is_array_like = table_is_array_like

local table_is_enum = function(t)
	if type(t) ~= "table" or getmetatable(t) ~= nil then
		return false
	end

	for k, v in next, t do
		if type(k) ~= "string" or type(v) ~= "number" then
			return false
		end
	end

	return true
end

table.is_enum = table_is_enum

local table_has_key = function(t, k)
	return rawget(t, k) ~= nil
end

table.has_key = table_has_key

local table_clear = function(t)
	for k in next, t do
		t[k] = nil
	end
	return t
end

table.clear = table_clear
table.empty = table_clear -- alias

local table_clear_range = function(t, a, b)
	for i = a or 1, b or #b do
		t[i] = nil
	end
	return t
end

table.clear_range = table_clear_range

local table_count = function(t)
	local amount = 0

	for _ in next, t do
		amount = amount + 1
	end

	return amount
end

table.count = table_count

local table_keys = function(t, out)
	out = out or {}

	for k in next, t do
		out[#out + 1] = k
	end

	return out
end

table.keys = table_keys

local table_values = function(t, out)
	out = out or {}

	for _, v in next, t do
		out[#out + 1] = v
	end

	return out
end

table.values = table_values

local table_keys_values = function(t, out)
	out = out or {}

	for k, v in next, t do
		out[#out + 1] = { [1] = k, [2] = v }
	end

	return out
end

table.keys_values = table_keys_values

local table_keys_values_named = function(t, out)
	out = out or {}

	for k, v in next, t do
		out[#out + 1] = { k = k, v = v }
	end

	return out
end

table.keys_values_named = table_keys_values_named

local function fast_iter(f, t, ...)
	-- NOTE: do not use this on large table (stack overflow)!
	-- TODO: benchmark this vs goto.
	local k, v = ...
	if k == nil then return end
	f(k, v) -- TODO/CONS: terminate if this returns a non-nil value?
	return fast_iter(f, t, next(t))
end

table.fast_iter = fast_iter

local next_iter = function(f, t)
	local k = next(t)
	while k ~= nil do
		f(k, t[k])
		k = next(t, k)
	end
end

table.next_iter = next_iter

local fast_keys = function(t, f)
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

local fast_values = function(t, f)
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

local fast_keys_values = function(t, f)
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

table.unpack = table_unpack

do
	local HASH = "#"

	local table_pack = table.pack or function(...)
		return { n = select(HASH, ...), ... }
	end

	table.pack = table_pack

	local table_unwrap = function(...)
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

local table_emit = function(t, name, ...)
	local f = t[name]
	if f then
		return f(...)
	end
end

table.emit = table_emit

local table_emit_with_args = function(t, name, ...)
	local f = t[name]
	if f then
		return f(t, name, ...)
	end
end

table.emit_with_args = table_emit_with_args

local table_invoke = function(t, name, ...)
	local f = t[name]
	if f then
		return f(t, ...)
	end
end

table.invoke = table_invoke

local table_initmeta = function(t, mt, init)
	if init then
		for k, v in next, init do
			rawset(t, k, v)
		end
	end
	return setmetatable(t, mt)
end

table.initmeta = table_initmeta

local table_foreach = function(t, f)
	for k, v in next, t do
		f(k, v) -- TODO/CONS: terminate if this returns a non-nil value?
	end
end

table.foreach = table_foreach

local table_foreachi = function(t, f)
	if type(f) ~= "function" then
		return error("bad argument #2 to 'foreachi' (function expected)", 2)
	end

	for i = 1, #t do
		f(i, t[i])
	end
end

table.foreachi = table_foreachi

local shallow_copy = function(t, out)
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
			out[key] = deep_copy(value, seen)
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

	-- Prefer debug.getmetatable if available, otherwise fallback to getmetatable
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

local table_copy_array = function(t, out)
	out = out or {}

	for i = 1, #t do
		out[i] = t[i]
	end

	return out
end

table.copy_array = table_copy_array

local table_array = function(t, out)
	out = out or {}

	-- Collect keys and sort for deterministic ordering
	local keys = {}
	for k in next, t do
		keys[#keys + 1] = k
	end
	table_sort(keys, table_sortasc_num_str)

	for i = 1, #keys do
		out[i] = t[keys[i]]
	end

	return out
end

table.array = table_array

local table_numeric = function(t, out)
	out = out or {}

	for i = 1, #t do
		out[i] = t[i]
	end

	return out
end

table.numeric = table_numeric

local table_enum = function(t)
	local result = {}

	for key, value in next, t do
		result[key] = value
		-- NOTE: This will error if the table contains any NaN values
		result[value] = key
	end

	return result
end

table.enum = table_enum

local table_inverse = function(t)
	local result = {}

	for key, value in next, t do
		-- NOTE: This will error if the table contains any NaN values
		result[value] = key
	end

	return result
end

table.inverse = table_inverse
table.invert = table_inverse -- alias

local table_ensure = function(tbl, key, def)
	if tbl[key] == nil then
		tbl[key] = def
		return def
	end
	return tbl[key]
end

table.ensure = table_ensure

local table_ensure_lazy = function(tbl, key, def, ...)
	if tbl[key] == nil then
		def = def(...)
		tbl[key] = def
		return def
	end
	return tbl[key]
end

table.ensure_lazy = table_ensure_lazy

local table_make_case_insensitive = function(t)
	-- Create a new table if none is provided
	if not t then
		t = {}
	end

	local wrapper = {} -- proxy

	-- Helper to find a case-insensitive match in t
	local function find_case_insensitive(key)
		local ukey = string_upper(key)
		for k, v in next, t do
			if type(k) == "string" and string_upper(k) == ukey then
				return k, v
			end
		end
		return nil, nil
	end

	-- Metamethods for case-insensitive access
	wrapper.__index = function(self, key)
		if type(key) ~= "string" then return rawget(self, key) end
		-- Check wrapper's own storage first (cached uppercase lookups)
		local v = rawget(self, string_upper(key))
		if v ~= nil then return v end
		-- Search t case-insensitively
		local _, found_v = find_case_insensitive(key)
		return found_v
	end

	wrapper.__newindex = function(self, key, value)
		if type(key) ~= "string" then
			rawset(self, key, value)
			return
		end
		local upper_key = string_upper(key)
		rawset(self, upper_key, value)
		-- Update t: find existing case-insensitive match or set new key
		local orig_key = find_case_insensitive(key)
		if orig_key ~= nil then
			t[orig_key] = value
		else
			t[key] = value
		end
	end

	-- Set up the metatable
	return setmetatable(wrapper, wrapper)
end

table.make_case_insensitive = table_make_case_insensitive

local table_case_insensitive = function(t)
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

local table_lowercase_keys = function(t, out)
	out = out or {}
	for k, v in next, t do
		if type(k) == "string" then
			out[string_lower(k)] = v
		else
			out[k] = v
		end
	end
	return out
end

table.lowercase_keys = table_lowercase_keys
table.lowercase = table_lowercase_keys -- alias

local table_uppercase_keys = function(t, out)
	out = out or {}
	for k, v in next, t do
		if type(k) == "string" then
			out[string_upper(k)] = v
		else
			out[k] = v
		end
	end
	return out
end

table.uppercase_keys = table_uppercase_keys
table.uppercase = table_uppercase_keys -- alias

-- Optimized version using table.move (Lua 5.3+)
local table_remove_first_optimized = function(arr, numElements)
	numElements = tonumber(numElements) or 1

	-- Avoid calling table.remove for performance reasons
	local n = #arr
	if n <= numElements then
		-- If the table has numElements or fewer elements, clear it entirely
		for i = 1, n do arr[i] = nil end
		return arr
	end
	-- Shift elements left by numElements positions using table.move (C implementation)
	table_move(arr, numElements + 1, n, 1)
	-- Nil out the freed-up (tail) entries
	for i = n - numElements + 1, n do
		arr[i] = nil
	end
	return arr
end

-- Fallback version for older Lua versions
local table_remove_first_fallback = function(arr, numElements)
	numElements = tonumber(numElements) or 1

	-- Avoid calling table.remove for performance reasons
	local n = #arr
	if n <= numElements then
		-- If the table has numElements or fewer elements, clear it entirely
		for i = 1, n do arr[i] = nil end
		return arr
	end
	-- Shift elements left by numElements positions
	for i = numElements + 1, n do
		arr[i - numElements] = arr[i]
	end
	-- Nil out the freed-up (tail) entries
	for i = n, n - numElements + 1, -1 do
		arr[i] = nil
	end
	return arr
end

-- Choose optimal implementation based on table.move availability
local table_remove_first = table_move and table_remove_first_optimized or table_remove_first_fallback

table.remove_first = table_remove_first

local table_remove_last = function(arr, numElements)
	numElements = tonumber(numElements) or 1

	-- Avoid calling table.remove for performance reasons
	local n = #arr
	if n <= numElements then
		-- If the table has numElements or fewer elements, clear it entirely
		for i = 1, n do arr[i] = nil end
		return arr
	end
	-- Nil out the last numElements entries
	for i = n, n - numElements + 1, -1 do
		arr[i] = nil
	end
	return arr
end

table.remove_last = table_remove_last

local table_unique = function(t)
	local seen, result, index = {}, {}, 0

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

local table_pick = function(t, keys)
	local result = {}
	for i = 1, #keys do
		local k = keys[i]
		if t[k] ~= nil then
			result[k] = t[k]
		end
	end
	return result
end

table.pick = table_pick

local table_omit = function(t, keys)
	local omit_map = {}
	for i = 1, #keys do
		omit_map[keys[i]] = true
	end
	local result = {}
	for k, v in next, t do
		if not omit_map[k] then
			result[k] = v
		end
	end
	return result
end

table.omit = table_omit

do
	local flatten_rec
	flatten_rec = function(flat, value, max_depth, cur_depth, stack)
		if type(value) ~= "table" then
			flat[#flat + 1] = value
			return
		end
		-- Cycle guard (recursion stack only)
		if stack[value] then
			return
		end
		-- Depth limit: keep the table as a leaf
		if max_depth and cur_depth > max_depth then
			flat[#flat + 1] = value
			return
		end
		stack[value] = true
		-- Single pass over all key-value pairs (order not guaranteed)
		for _, item in next, value do
			flatten_rec(flat, item, max_depth, cur_depth + 1, stack)
		end
		stack[value] = nil
	end

	local table_flatten = function(t, depth)
		if type(t) ~= "table" then
			return { t }
		end
		local flat, stack = {}, {}
		flatten_rec(flat, t, depth, 0, stack)
		return flat
	end

	table.flatten = table_flatten
end

local table_map = function(t, f)
	local result = {}
	for k, v in next, t do
		result[k] = f(v, k)
	end
	return result
end

table.map = table_map

local table_where = function(t, predicate)
	local result = {}
	for k, v in next, t do
		if predicate(v, k) then
			result[k] = v
		end
	end
	return result
end

table.where = table_where

local table_reduce = function(t, f, init)
	local acc = init
	for k, v in next, t do
		acc = f(acc, v, k)
	end
	return acc
end

table.reduce = table_reduce

--- Default predicate for filter: truthy values
local table_filter_default_pred = function(v)
	--return v ~= nil and v ~= false
	return not not v
end

local table_filter = function(t, pred, opts)
	if type(t) ~= "table" then return {} end
	pred = pred or table_filter_default_pred
	opts = opts or {}

	local is_array = opts.array
	if is_array == nil then
		-- autodetect: treat as array if it has a length > 0
		is_array = (#t > 0)
	end

	if is_array then
		local n = #t
		local out = {}
		local index = 0
		for i = 1, n do
			local v = t[i]
			if pred(v, i, t) then
				index = index + 1
				out[index] = v
			end
		end
		return out
	else
		-- map mode: preserve keys by default
		local out = {}
		if opts.keep_keys == false then
			local index = 0
			for k, v in next, t do
				if pred(v, k, t) then
					index = index + 1
					out[index] = v
				end
			end
		else
			for k, v in next, t do
				if pred(v, k, t) then
					out[k] = v
				end
			end
		end
		return out
	end
end

table.filter = table_filter

local table_filter_inplace = function(t, pred, opts)
	if type(t) ~= "table" then return t end
	pred = pred or table_filter_default_pred
	opts = opts or {}

	local is_array = opts.array
	if is_array == nil then
		is_array = (#t > 0)
	end

	if is_array then
		-- compact in place: two-index write/read
		local n = #t
		local write = 1
		for read = 1, n do
			local v = t[read]
			if pred(v, read, t) then
				if write ~= read then
					t[write] = v
				end
				write = write + 1
			end
		end
		-- nil out tail
		for i = write, n do
			t[i] = nil
		end
		return t
	else
		-- map mode: remove keys that don't match
		for k, v in next, t do
			if not pred(v, k, t) then
				t[k] = nil
			end
		end
		return t
	end
end

table.filter_inplace = table_filter_inplace

local table_filter_iter = function(t, pred)
	pred = pred or table_filter_default_pred
	local iter_k, iter_v, state = next, nil, t
	return function()
		while true do
			local k, v = iter_k(t, iter_v)
			iter_v = k
			if k == nil then return nil end
			if pred(v, k, t) then
				return k, v
			end
		end
	end
end

table.filter_iter = table_filter_iter

local table_filter_pattern = function(t, pattern, opts)
	if type(t) ~= "table" then return {} end
	if type(pattern) ~= "string" then return {} end
	opts = opts or {}
	local match_keys = opts.match_keys or false
	local match_values = opts.match_values ~= false
	local is_array = opts.array
	if is_array == nil then
		is_array = #t > 0
	end
	if is_array then
		local n = #t
		local out = {}
		local index = 0
		for i = 1, n do
			local v = t[i]
			local matches
			if match_values then
				local v_str = tostring(v)
				matches = string_match(v_str, pattern)
			end
			if not matches and match_keys and type(i) == "string" then
				matches = string_match(i, pattern)
			end
			if matches then
				index = index + 1
				out[index] = v
			end
		end
		return out
	end
	local out = {}
	if opts.keep_keys == false then
		local index = 0
		for k, v in next, t do
			local matches
			if match_values then
				local v_str = tostring(v)
				matches = string_match(v_str, pattern)
			end
			if not matches and match_keys and type(k) == "string" then
				matches = string_match(k, pattern)
			end
			if matches then
				index = index + 1
				out[index] = v
			end
		end
	else
		for k, v in next, t do
			local matches
			if match_values then
				local v_str = tostring(v)
				matches = string_match(v_str, pattern)
			end
			if not matches and match_keys and type(k) == "string" then
				matches = string_match(k, pattern)
			end
			if matches then
				out[k] = v
			end
		end
	end
	return out
end

table.filter_pattern = table_filter_pattern

local table_concat_safe = function(t, sep)
	local result = {}
	for i = 1, #t do
		result[i] = tostring(t[i])
	end
	return table_concat(result, sep or " ")
end

table.concat_safe = table_concat_safe

local table_slice = function(t, start_index, end_index)
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

local table_chunks = function(t, chunk_size)
	chunk_size = chunk_size or 1
	if chunk_size <= 0 then return error("chunk_size must be > 0", 2) end

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

local table_rotated_left = function(t, amount)
	amount = tonumber(amount) or 0
	local n = #t
	if n == 0 then return shallow_copy(t) end
	amount = amount % n
	if amount <= 0 then return shallow_copy(t) end

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

table.rotated_left = table_rotated_left

local table_rotated_right = function(t, amount)
	amount = tonumber(amount) or 0
	local n = #t
	if n == 0 then return shallow_copy(t) end
	amount = amount % n
	if amount <= 0 then return shallow_copy(t) end

	return table_rotated_left(t, n - amount)
end

table.rotated_right = table_rotated_right

local table_rotated = function(t, rotation)
	rotation = tonumber(rotation) or 0
	if rotation < 0 then
		return table_rotated_left(t, -rotation)
	end
	return table_rotated_right(t, rotation)
end

table.rotated = table_rotated

local table_rotated2D = table_move and
	function(grid, horizontal, vertical)
		local rows = #grid
		if rows == 0 then return {} end
		local cols = #grid[1]
		if cols == 0 then return grid end

		-- convention: horizontal < 0 = left, > 0 = right
		--             vertical   < 0 = up,   > 0 = down
		-- engine canonicalizes to "left by kh, up by kv" -> negate inputs
		local kh = (-(horizontal or 0)) % cols
		local kv = (-(vertical or 0)) % rows

		if kv == 0 and kh == 0 then
			return grid
		end

		if kh == 0 then
			-- pure vertical: rows moved by reference (O(rows), not O(rows*cols))
			local out = {}
			for i = 1, rows do
				out[i] = grid[(i - 1 + kv) % rows + 1]
			end
			return out
		end

		-- horizontal component present (pure horizontal OR diagonal):
		-- the vertical half is free - just offset the source row
		local out = {}
		for i = 1, rows do
			local src = grid[(i - 1 + kv) % rows + 1]
			local new = {}
			out[i] = new
			table_move(src, kh + 1, cols, 1, new) -- tail -> front
			table_move(src, 1, kh, cols - kh + 1, new) -- head -> tail (wrap)
		end
		return out
	end
	or
	function(grid, horizontal, vertical)
		local rows = #grid
		if rows == 0 then return {} end

		local cols = #grid[1]
		if cols == 0 then return grid end

		-- convention: horizontal < 0 = left, > 0 = right
		--             vertical   < 0 = up,   > 0 = down
		-- engine canonicalizes to "left by kh, up by kv" -> negate inputs
		local kh = (-(horizontal or 0)) % cols
		local kv = (-(vertical or 0)) % rows

		if kv == 0 and kh == 0 then
			return grid
		end

		if kh == 0 then
			-- pure vertical: rows moved by reference (O(rows), not O(rows*cols))
			local out = {}
			for i = 1, rows do
				out[i] = grid[(i - 1 + kv) % rows + 1]
			end
			return out
		end

		-- horizontal component present (pure horizontal OR diagonal):
		-- the vertical half is free - just offset the source row
		local out = {}

		for i = 1, rows do
			local src = grid[(i - 1 + kv) % rows + 1]
			local new = {}
			out[i] = new

			-- tail -> front
			local dst = 1
			for j = kh + 1, cols do
				new[dst] = src[j]
				dst = dst + 1
			end

			-- head -> tail
			for j = 1, kh do
				new[dst] = src[j]
				dst = dst + 1
			end
		end

		return out
	end

table.rotated2D = table_rotated2D

local table_rotate_left = function(t, amount)
	amount = tonumber(amount) or 0
	local n = #t
	if n == 0 then return t end
	amount = amount % n
	if amount <= 0 then return t end

	-- Store elements to be rotated
	local temp = {}
	for i = 1, amount do
		temp[i] = t[i]
	end

	-- Shift elements left
	for i = 1, n - amount do
		t[i] = t[i + amount]
	end

	-- Move rotated elements to end
	for i = 1, amount do
		t[n - amount + i] = temp[i]
	end

	return t
end

table.rotate_left = table_rotate_left

local table_rotate_right = function(t, amount)
	amount = tonumber(amount) or 0
	local n = #t
	if n == 0 then return t end
	amount = amount % n
	if amount <= 0 then return t end

	return table_rotate_left(t, n - amount)
end

table.rotate_right = table_rotate_right

local table_rotate = function(t, rotation)
	rotation = tonumber(rotation) or 0
	if rotation < 0 then
		return table_rotate_left(t, -rotation)
	end
	return table_rotate_right(t, rotation)
end

table.rotate = table_rotate

local table_rotate2D = table_move and
	function(grid, horizontal, vertical)
		local rows = #grid
		if rows == 0 then return grid end
		local cols = #grid[1]
		if cols == 0 then return grid end

		-- convention: horizontal < 0 = left, > 0 = right
		--             vertical   < 0 = up,   > 0 = down
		-- engine canonicalizes to "left by kh, up by kv" -> negate inputs
		local kh = (-(horizontal or 0)) % cols
		local kv = (-(vertical or 0)) % rows

		if kv == 0 and kh == 0 then
			return grid
		end

		-- vertical shift: rotate rows up by kv (in-place)
		if kv ~= 0 then
			local new_rows = {}
			for i = 1, rows do
				new_rows[i] = grid[(i - 1 + kv) % rows + 1]
			end
			for i = 1, rows do
				grid[i] = new_rows[i]
			end
		end

		-- horizontal shift: rotate each row left by kh (in-place)
		if kh ~= 0 then
			for i = 1, rows do
				local row = grid[i]
				local temp = {}
				-- save head (1..kh)
				table_move(row, 1, kh, 1, temp)
				-- move tail (kh+1..cols) to front (1..cols-kh)
				table_move(row, kh + 1, cols, 1, row)
				-- move saved head to end (cols-kh+1..cols)
				table_move(temp, 1, kh, cols - kh + 1, row)
			end
		end

		return grid
	end
	or
	function(grid, horizontal, vertical)
		local rows = #grid
		if rows == 0 then return grid end
		local cols = #grid[1]
		if cols == 0 then return grid end

		local kh = (-(horizontal or 0)) % cols
		local kv = (-(vertical or 0)) % rows

		if kv == 0 and kh == 0 then
			return grid
		end

		-- vertical shift: rotate rows up by kv (in-place)
		if kv ~= 0 then
			local new_rows = {}
			for i = 1, rows do
				new_rows[i] = grid[(i - 1 + kv) % rows + 1]
			end
			for i = 1, rows do
				grid[i] = new_rows[i]
			end
		end

		-- horizontal shift: rotate each row left by kh using three-reverses
		if kh ~= 0 then
			for i = 1, rows do
				local row = grid[i]
				-- reverse whole row
				local a, b = 1, cols
				while a < b do
					row[a], row[b] = row[b], row[a]
					a = a + 1
					b = b - 1
				end
				-- reverse first kh
				a, b = 1, kh
				while a < b do
					row[a], row[b] = row[b], row[a]
					a = a + 1
					b = b - 1
				end
				-- reverse remaining (kh+1..cols)
				a, b = kh + 1, cols
				while a < b do
					row[a], row[b] = row[b], row[a]
					a = a + 1
					b = b - 1
				end
			end
		end

		return grid
	end

table.rotate2D = table_rotate2D

local table_reverse = function(t)
	--[[
	local n, i = #t, 1
	local j = n
	while i < j do
		--local tmp = t[i]
		--t[i] = t[j]
		--t[j] = tmp
		t[i], t[j] = t[j], t[i]
		i = i + 1
		j = j - 1
	end
	]]
	local n = #t
	for i = 1, math_floor(n / 2) do
		local j = n - i + 1
		t[i], t[j] = t[j], t[i]
	end
	return t
end

table.reverse = table_reverse

local table_reversed = function(t)
	local n = #t
	local out = {}

	-- Copy elements in reverse order
	for i = 1, n do
		out[i] = t[n - i + 1]
	end

	return out
end

table.reversed = table_reversed

local table_switch = function(value)
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
			local handler = cases[v]
			if handler == nil then
				handler = default_case
			end
			if handler ~= nil then
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

local table_case = function(value)
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
			local result = mappings[value]
			if result == nil then
				result = default_value
			end
			return result
		end,
	}

	return case_obj
end

table.case = table_case

local table_weak_keys = function()
	return setmetatable({}, { __mode = "k" })
end

table.weak_keys = table_weak_keys

local table_weak_values = function()
	return setmetatable({}, { __mode = "v" })
end

table.weak_values = table_weak_values

local table_weak = function()
	return setmetatable({}, { __mode = "kv" })
end

table.weak = table_weak

local table_randomize = function(t)
	local n = #t
	for i = n, 2, -1 do
		local j = math_random(i)
		t[i], t[j] = t[j], t[i]
	end
	return t
end

table.randomize = table_randomize

local table_random_choice = function(t)
	local n = #t
	if n == 0 then return nil end
	return t[math_random(1, n)]
end

table.random_choice = table_random_choice

local table_add = function(dest, source)
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

local table_merge = function(dest, source)
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

local table_merge_preserve = function(dest, source)
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

local table_sortdesc = function(t)
	table_sort(t, table_sortdesc_cmp)
	return t
end

table.sortdesc = table_sortdesc

local table_sorted = function(t, descending)
	local keys = {}
	for k in next, t do
		keys[#keys + 1] = k
	end

	if descending then
		table_sort(keys, table_sortdesc_cmp)
	else
		table_sort(keys) -- use default C function for performance (ascending sort)
	end

	local index = 0
	return function()
		index = index + 1
		local k = keys[index]
		if k then
			return k, t[k]
		end
	end
end

table.sorted = table_sorted

local table_sorted_keys = function(t, descending)
	local keys = table_keys(t)
	if descending then
		table_sort(keys, table_sortdesc_cmp)
	else
		table_sort(keys) -- use default C function for performance (ascending sort)
	end
	return keys
end

table.sorted_keys = table_sorted_keys

local table_sort_by = function(t, key_func)
	table_sort(t, function(a, b)
		local key_a, key_b = key_func(a), key_func(b)
		return key_a < key_b or (key_a == key_b and a < b)
	end)
	return t
end

local table_sort_by = function(t, key_func)
	-- Precompute all keys once (O(n) instead of O(2 * n log n))
	local keys = {}
	for i = 1, #t do
		keys[i] = key_func(t[i])
	end

	local len = #t
	local indices = {}
	for i = 1, len do
		indices[i] = i
	end

	-- Sort indices by precomputed keys
	table_sort(indices, function(a, b)
		local key_a, key_b = keys[a], keys[b]
		return key_a < key_b or (key_a == key_b and a < b)
	end)

	-- Rebuild sorted table
	local sorted = {}
	for i = 1, len do
		sorted[i] = t[indices[i]]
	end

	-- Copy back to original table
	for i = 1, len do
		t[i] = sorted[i]
	end

	return t
end

table.sort_by = table_sort_by

local table_sort_by_field = function(t, field)
	local indexed = {}

	for i = 1, #t do
		indexed[i] = { [1] = i, [2] = t[i][field], [3] = t[i] }
	end

	table_sort(indexed, table_sort_by_field_cmp)

	for i = 1, #indexed do
		t[i] = indexed[i][3]
	end

	return t
end

table.sort_by_field = table_sort_by_field

local table_sort_by_key = function(t, key_func)
	-- Pre-compute keys to avoid calling key_func multiple times
	local key_map = {}
	for i = 1, #t do
		local v = t[i]
		key_map[v] = key_func(v)
	end
	table_sort(t, function(a, b)
		local key_a, key_b = key_map[a], key_map[b]
		return key_a < key_b or (key_a == key_b and a < b)
	end)
	return t
end

table.sort_by_key = table_sort_by_key

local table_sum = function(t)
	local sum = 0
	for _, v in next, t do
		local num = tonumber(v)
		if num then
			sum = sum + num
		end
	end
	return sum
end

table.sum = table_sum

local table_max = function(t)
	local max_val
	for _, v in next, t do
		local num = tonumber(v)
		if num then
			if max_val == nil or num > max_val then
				max_val = num
			end
		end
	end
	return max_val
end

table.max = table_max

local table_min = function(t)
	local min_val
	for _, v in next, t do
		local num = tonumber(v)
		if num then
			if min_val == nil or num < min_val then
				min_val = num
			end
		end
	end
	return min_val
end

table.min = table_min

local table_average = function(t)
	local sum, count = 0, 0
	for _, v in next, t do
		local num = tonumber(v)
		if num then
			sum = sum + num
			count = count + 1
		end
	end
	return count > 0 and sum / count or 0
end

table.average = table_average
table.avg = table_average -- alias

local table_median = function(t)
	local values = {}
	for _, v in next, t do
		local num = tonumber(v)
		if num then
			values[#values + 1] = num
		end
	end

	local n = #values
	if n == 0 then return 0 end

	table_sort(values)

	if n % 2 == 0 then
		local mid = math_floor(n / 2)
		return (values[mid] + values[mid + 1]) * 0.5
	end
	return values[math_floor(n / 2) + 1]
end

table.median = table_median

local table_stats = function(t)
	local sum = 0
	local count = 0
	local min_val, max_val

	for _, v in next, t do
		local num = tonumber(v)
		if num then
			sum = sum + num
			count = count + 1
			if min_val == nil or num < min_val then min_val = num end
			if max_val == nil or num > max_val then max_val = num end
		end
	end

	return {
		sum = sum,
		count = count,
		min = min_val or 0,
		max = max_val or 0,
		average = count > 0 and sum / count or 0,
		range = (max_val or 0) - (min_val or 0)
	}
end

table.stats = table_stats

local function table_print(t, writer, indent, seen)
	writer = writer or io.write
	seen = seen or {}
	indent = indent or 0
	local keys = table_keys(t)

	table_sort(keys, table_sortasc_num_str)

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
		else
			writer(key, "\t=\t", tostring(value), "\n")
		end
	end
end

table.print = table_print

-- Pattern to match bracket notation: ["key"] or ['key'] or [number]
local bracket_pattern = "%s*%[([^%]]*)%]"

local parse_bracket_key = function(content)
	-- Check if it's a quoted string
	local quote = string_sub(content, 1, 1)
	if quote == '"' or quote == "'" then
		if string_sub(content, #content, #content) == quote then
			-- Quoted string - extract content and handle escapes
			local inner = string_sub(content, 2, #content - 1)
			-- Replace escape sequences: \" -> ", \' -> ', \\ => \
			inner = string_gsub(inner, "\\(.)", function(c)
				if c == quote or c == "\\" then
					return c
				end
				-- Keep other escape sequences as-is (e.g. \n, \t)
				return "\\" .. c
			end)
			return inner
		end
	end
	-- Not a quoted string - try to parse as number
	local num = tonumber(content)
	if num then
		return num
	end
	return content
end

local table_get_path = function(t, path, separator)
	if type(t) ~= "table" then return nil end
	if type(path) ~= "string" or path == "" then return nil end

	separator = separator or "."
	local current = t

	-- Pattern to match dot notation segments (excluding bracket char)
	local separator_escaped = string_gsub(separator, "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
	local dot_pattern = "([^" .. separator_escaped .. "%[]+)"

	local pos = 1
	local len = #path

	while pos <= len do
		local key

		-- Check for bracket notation at current position
		local bracket_start, bracket_end, bracket_content = string_find(path, bracket_pattern, pos)
		if bracket_start == pos then
			-- Extract key from bracket
			key = parse_bracket_key(bracket_content)
			pos = bracket_end + 1
		else
			-- Try dot notation segment
			local dot_start, dot_end, dot_key = string_find(path, dot_pattern, pos)
			if dot_start == pos then
				key = dot_key
				pos = dot_end + 1

				-- Skip separator if present
				if string_sub(path, pos, pos + #separator - 1) == separator then
					pos = pos + #separator
				end
			else
				-- No more segments found
				break
			end
		end

		-- Skip any whitespace between segments
		while pos <= len and string_sub(path, pos, pos) == " " do
			pos = pos + 1
		end

		-- Traverse to next level
		if type(current) ~= "table" then
			return nil
		end

		current = current[key]
		if current == nil then
			return nil
		end
	end

	return current
end

table.get_path = table_get_path

local table_set_path = function(t, path, value, separator)
	if type(t) ~= "table" then return nil end
	if type(path) ~= "string" or path == "" then return nil end

	separator = separator or "."
	local current = t

	-- Pattern to match dot notation segments (excluding bracket char)
	local separator_escaped = string_gsub(separator, "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
	local dot_pattern = "([^" .. separator_escaped .. "%[]+)"

	local pos = 1
	local len = #path
	local last_key

	while pos <= len do
		local key
		local bracket_start, bracket_end, bracket_content = string_find(path, bracket_pattern, pos)
		if bracket_start == pos then
			key = parse_bracket_key(bracket_content)
			pos = bracket_end + 1
		else
			local dot_start, dot_end, dot_key = string_find(path, dot_pattern, pos)
			if dot_start == pos then
				key = dot_key
				pos = dot_end + 1

				if string_sub(path, pos, pos + #separator - 1) == separator then
					pos = pos + #separator
				end
			else
				break
			end
		end

		while pos <= len and string_sub(path, pos, pos) == " " do
			pos = pos + 1
		end

		if key == nil then
			return nil
		end

		last_key = key

		if pos <= len then
			if type(current) ~= "table" then
				return nil
			end

			local next_node = current[key]
			if next_node == nil then
				next_node = {}
				current[key] = next_node
			elseif type(next_node) ~= "table" then
				return nil
			end
			current = next_node
		end
	end

	if last_key == nil or type(current) ~= "table" then
		return nil
	end

	current[last_key] = value
	return true
end

table.set_path = table_set_path

local table_get = function(t, path, default)
	if type(t) ~= "table" then return default end
	local keys = type(path) == "string" and string_explode(path, ".") or path
	local cur = t
	for _, key in next, keys do
		if type(cur) ~= "table" then return default end
		cur = cur[key]
		if cur == nil then return default end
	end
	return cur
end

table.get = table_get

local table_set = function(t, path, value)
	local keys = type(path) == "string" and string_explode(path, ".") or path
	local cur = t
	for i = 1, #keys - 1 do
		local key = keys[i]
		if cur[key] == nil then cur[key] = {} end
		if type(cur[key]) ~= "table" then
			return error("cannot traverse: " .. tostring(key) .. " is not a table", 2)
		end
		cur = cur[key]
	end
	cur[keys[#keys]] = value
	return t
end

table.set = table_set

--- Treat table as a stack: push value to end
local table_push = function(t, ...)
	local n = select("#", ...)
	if n == 1 then
		t[#t + 1] = (...)
	else
		local len = #t
		for i = 1, n do
			t[len + i] = select(i, ...)
		end
	end
	return t
end

table.push = table_push
table.enqueue = table_push -- alias

--- Treat table as a stack: pop value from end
local table_pop = function(t)
	local n = #t
	if n == 0 then return nil end
	local val = t[n]
	t[n] = nil
	return val
end

table.pop = table_pop

--- Treat table as a queue: dequeue value from front (O(n) due to shift)
local table_dequeue = function(t)
	local n = #t
	if n == 0 then return nil end
	local val = t[1]
	-- Use optimized remove_first which handles table.move internally
	table_remove_first(t, 1)
	return val
end

table.dequeue = table_dequeue

--- Peek at the top of a stack or front of a queue without removing
local table_peek = function(t)
	return t[#t]
end

table.peek = table_peek
table.top = table_peek -- alias

--- Binary search on a sorted array
--- Returns index if found, or insertion point (negative) if not found
local table_binary_search = function(t, target, cmp)
	cmp = cmp or table_sortasc
	local lo, hi = 1, #t
	while lo <= hi do
		local mid = math_floor((lo + hi) * 0.5)
		local val = t[mid]
		if cmp(val, target) then
			lo = mid + 1
		elseif cmp(target, val) then
			hi = mid - 1
		else
			return mid -- exact match
		end
	end
	return -lo -- not found, return negative insertion point
end

table.binary_search = table_binary_search

--- Partition an array in-place around a pivot (Lomuto scheme)
--- Returns the final index of the pivot
local table_partition = function(t, lo, hi, cmp)
	cmp = cmp or table_sortasc
	local pivot = t[hi]
	local i = lo
	for j = lo, hi - 1 do
		if cmp(t[j], pivot) then
			t[i], t[j] = t[j], t[i]
			i = i + 1
		end
	end
	t[i], t[hi] = t[hi], t[i]
	return i
end

table.partition = table_partition

--- Set union: returns new table with unique values from both arrays
local table_union = function(a, b)
	local seen, result, idx = {}, {}, 0
	for _, v in next, a do
		if not seen[v] then
			seen[v] = true
			idx = idx + 1
			result[idx] = v
		end
	end
	for _, v in next, b do
		if not seen[v] then
			seen[v] = true
			idx = idx + 1
			result[idx] = v
		end
	end
	return result
end

table.union = table_union

--- Set intersection: returns new table with values present in both arrays
local table_intersection = function(a, b)
	local seen, result, idx = {}, {}, 0
	for _, v in next, a do seen[v] = true end
	for _, v in next, b do
		if seen[v] then
			idx = idx + 1
			result[idx] = v
			seen[v] = false -- prevent duplicates if b has dupes
		end
	end
	return result
end

table.intersection = table_intersection

--- Set difference: returns values in 'a' that are not in 'b'
local table_difference = function(a, b)
	local exclude, result, idx = {}, {}, 0
	for _, v in next, b do exclude[v] = true end
	for _, v in next, a do
		if not exclude[v] then
			idx = idx + 1
			result[idx] = v
		end
	end
	return result
end

table.difference = table_difference

--- Check if two tables contain the same elements (order-independent, multiset)
local table_set_equals = function(a, b)
	local counts_a = {}
	local total_a = 0
	for _, v in next, a do
		counts_a[v] = (counts_a[v] or 0) + 1
		total_a = total_a + 1
	end

	local counts_b = {}
	local total_b = 0
	for _, v in next, b do
		counts_b[v] = (counts_b[v] or 0) + 1
		total_b = total_b + 1
	end

	if total_a ~= total_b then return false end

	for k, v in next, counts_a do
		if counts_b[k] ~= v then
			return false
		end
	end

	return true
end

table.set_equals = table_set_equals

--- Zip multiple arrays into an array of tuples
local table_zip = function(...)
	local args = { ... }
	local n_args = select("#", ...)
	if n_args == 0 then return {} end
	local min_len = #args[1]
	for i = 2, n_args do
		local l = #args[i]
		if l < min_len then min_len = l end
	end
	local result = {}
	for i = 1, min_len do
		local tuple = {}
		for j = 1, n_args do
			tuple[j] = args[j][i]
		end
		result[i] = tuple
	end
	return result
end

table.zip = table_zip

--- Min-heap sift-down for priority queue implementations
local table_heap_sift_down = function(t, i, n, cmp)
	cmp = cmp or table_sortasc
	while true do
		local smallest = i
		local left = i * 2
		local right = left + 1
		if left <= n and cmp(t[left], t[smallest]) then
			smallest = left
		end
		if right <= n and cmp(t[right], t[smallest]) then
			smallest = right
		end
		if smallest == i then break end
		t[i], t[smallest] = t[smallest], t[i]
		i = smallest
	end
end

table.heap_sift_down = table_heap_sift_down

--- Build a min-heap in-place from an unsorted array
local table_heapify = function(t, cmp)
	local n = #t
	for i = math_floor(n * 0.5), 1, -1 do
		table_heap_sift_down(t, i, n, cmp)
	end
	return t
end

table.heapify = table_heapify

local function create_proxy(t)
	return setmetatable({}, {
		__index    = function(_, k) return rawget(t, k) end,
		__newindex = function(_, k, v) rawset(t, k, v) end,
	})
end

table.create_proxy = create_proxy

local table_track = function(t, opts)
	opts = opts or {}

	local base_mt = getmetatable(t)

	local index_value = function(k)
		if base_mt and base_mt.__index ~= nil then
			local idx = base_mt.__index
			if type(idx) == "function" then
				return idx(t, k)
			end
			return idx[k]
		end
	end

	local write_value = function(k, v)
		if base_mt and base_mt.__newindex ~= nil then
			local ni = base_mt.__newindex
			if type(ni) == "function" then
				ni(t, k, v)
			else
				ni[k] = v
			end
		else
			rawset(t, k, v)
		end
	end

	local delete_value = function(k)
		if base_mt and base_mt.__newindex ~= nil then
			local ni = base_mt.__newindex
			if type(ni) == "function" then
				ni(t, k, nil)
			else
				ni[k] = nil
			end
		else
			rawset(t, k, nil)
		end
	end

	-- Proxy
	return setmetatable({}, {
		__index = function(_, k)
			local v = rawget(t, k)
			if v == nil then
				v = index_value(k)
			end
			if opts.on_read then
				opts.on_read(t, k, v)
			end
			return v
		end,

		__newindex = function(_, k, v)
			local old = rawget(t, k)
			local existed = old ~= nil

			if v == nil then
				if existed then
					delete_value(k)
					if opts.on_delete then
						opts.on_delete(t, k, old)
					end
				end
			else
				write_value(k, v)
				if existed then
					if opts.on_update then
						opts.on_update(t, k, old, v)
					elseif opts.on_write then
						opts.on_write(t, k, old, v)
					end
				else
					if opts.on_create then
						opts.on_create(t, k, v)
					elseif opts.on_write then
						opts.on_write(t, k, nil, v)
					end
				end
			end
		end,

		__pairs = function()
			if base_mt and base_mt.__pairs then
				return base_mt.__pairs(t)
			end
			return next, t
		end,

		__ipairs = function()
			if base_mt and base_mt.__ipairs then
				return base_mt.__ipairs(t)
			end
			return ipairs(t)
		end,

		__len = function()
			if base_mt and base_mt.__len then
				return base_mt.__len(t)
			end
			return #t
		end,

		__tostring = function()
			if base_mt and base_mt.__tostring then
				return base_mt.__tostring(t)
			end
			return tostring(t)
		end
	})
end

table.track = table_track
table.monitor = table_track -- alias

local table_autotable
do
	-- Metatable shared by all proxies
	local autotable_mt = {
		__index = function(t, key)
			-- Retrieve the raw value; nil means the key does not exist
			local value = rawget(t, key)
			if value == nil then
				-- Create a new proxy table for the missing key and store it
				local nested = table_autotable() -- recurse for further nesting
				rawset(t, key, nested)
				return nested
			end
			return value
		end,
		__newindex = function(t, key, value)
			-- Direct assignment - no automatic creation
			return rawset(t, key, value)
		end,
	}

	function table_autotable(base)
		return setmetatable(base or {}, autotable_mt)
	end

	table.autotable = table_autotable
end

local table_defaultdict = function(default_factory, opts)
	if type(default_factory) ~= "function" then
		return error("default_factory must be a function", 2)
	end
	opts = opts or {}

	local store = {}
	local explicit_keys = {}

	local methods = {}

	function methods:to_table()
		local plain = {}
		for k, v in next, store do
			plain[k] = v
		end
		return plain
	end

	local iter = function(_, k)
		local nk = next(explicit_keys, k)
		if nk ~= nil then
			return nk, rawget(store, nk)
		end
	end
	function methods:explicit_pairs()
		return iter, nil, nil
	end

	function methods:freeze()
		opts.frozen = true
	end

	function methods:is_explicit(key)
		return explicit_keys[key] == true
	end

	return setmetatable({}, {
		__index = function(_, key)
			-- Check methods first
			if methods[key] then
				return methods[key]
			end
			-- Check store for explicit values (including explicitly-set nil)
			if explicit_keys[key] then
				return rawget(store, key)
			end
			if opts.frozen then
				return nil
			end
			-- Auto-vivify default value
			local value = default_factory()
			rawset(store, key, value)
			return value
		end,
		__newindex = function(_, key, value)
			if opts.frozen then
				return error("attempt to modify a frozen defaultdict", 2)
			end
			rawset(store, key, value)
			explicit_keys[key] = true
		end,
		__default_factory = default_factory,
	})
end

table.defaultdict = table_defaultdict

-- Read-only table wrapper (inline implementation to avoid _G.readonly side effect)
do
	local readonly_newindex = function()
		return error("attempt to modify a read-only table", 2)
	end

	local table_readonly = function(t)
		return setmetatable({}, {
			__index = t,
			__newindex = readonly_newindex,
			__pairs = function() return next, t end,
			__ipairs = function() return ipairs(t) end,
			__len = function() return #t end,
			__tostring = function() return tostring(t) end,
			__metatable = false,
		})
	end

	table.readonly = table_readonly
end

-- Import table_find module functionality (for convenience)
do
	local table_find_module = require "../standalone/table_find"
	local table_find_full = table_find_module.find

	-- Simple wrapper: find first match and return its key
	table.find = function(t, needle)
		local results = table_find_full(t, needle, { first = true })
		if #results == 0 then
			return nil
		end
		local path = results[1]
		return path[#path]
	end

	-- Also expose the full path-finding version
	table.find_paths = table_find_full
	table.path_to_string = table_find_module.path_to_string
end

-- Import dump_table module functionality (for convenience)
do
	local dump_table_module = require "../standalone/dump_table"
	table.dump = dump_table_module.dump
	table.dump_print = dump_table_module.print
end

-- Import pretty printing modules (for convenience)
do
	local pretty_grid = require "../standalone/pretty_grid"
	local pretty_hex_dump = require "../standalone/pretty_hex_dump"
	local pretty_print_structure = require "../standalone/pretty_print_structure"
	table.pretty_grid = pretty_grid
	table.pretty_hex_dump = pretty_hex_dump
	table.pretty_print_structure = pretty_print_structure
end

-- Export (for compatibility)
return table
