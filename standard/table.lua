-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Augment existing standard table library

-- Localized global functions for better performance
local ipairs = ipairs
local next = next
local rawget = rawget
local rawset = rawset
local select = select
local getmetatable = getmetatable
local setmetatable = setmetatable
local tonumber = tonumber
local tostring = tostring
local type = type
local math_ceil = math.ceil
local math_random = math.random
local string_find = string.find
local string_gsub = string.gsub
local string_lower = string.lower
local string_match = string.match
local string_rep = string.rep
local string_sub = string.sub
local string_upper = string.upper
---@diagnostic disable-next-line: unnecessary-assert
local table = assert(_G.table, "table library is missing")
local table_move = table.move -- Lua 5.3+
local table_sort = table.sort

--- Comparison function for descending sort
local function table_sortdesc_cmp(a, b)
	return a > b
end

local function table_is_empty(t)
	return next(t) == nil
end

table.is_empty = table_is_empty

local function table_is_array(t)
	local n = #t

	for k in next, t do
		-- Every key must be a positive integer within [1, n].
		-- This avoids relying on next's (undefined) iteration order.
		if type(k) ~= "number" or k < 1 or k > n or k % 1 ~= 0 then
			return false
		end
	end

	return true
end

table.is_array = table_is_array

local function table_is_array_like(t)
	for k in next, t do
		if type(k) ~= "number" then
			return false
		end
	end
	return true
end

table.is_array_like = table_is_array_like

local function table_is_enum(t)
	if getmetatable(t) ~= nil then
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

local function table_has_key(t, k)
	return rawget(t, k) ~= nil
end

table.has_key = table_has_key

local function table_clear(t)
	for k in next, t do
		t[k] = nil
	end
	return t
end

table.clear = table_clear
table.empty = table_clear -- alias

local function table_clear_range(t, a, b)
	for i = a or 1, b or #b do
		t[i] = nil
	end
	return t
end

table.clear_range = table_clear_range

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

local function fast_iter(f, t, ...)
	-- NOTE: do not use this on large table (stack overflow)!
	-- TODO: benchmark this vs goto.
	local k, v = ...
	if k == nil then return end
	f(k, v) -- TODO/CONS: terminate if this returns a non-nil value?
	return fast_iter(t, next(t))
end

table.fast_iter = fast_iter

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
		return { ..., n = select(HASH, ...) }
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

local function table_emit(t, name, ...)
	local f = t[name]
	if f then
		return f(...)
	end
end

table.emit = table_emit

local function table_emit_with_args(t, name, ...)
	local f = t[name]
	if f then
		return f(t, name, ...)
	end
end

table.emit_with_args = table_emit_with_args

local function table_invoke(t, name, ...)
	local f = t[name]
	if f then
		return f(t, ...)
	end
end

table.invoke = table_invoke

local function table_initmeta(t, mt, init)
	if init then
		for k, v in next, init do
			rawset(t, k, v)
		end
	end
	return setmetatable(t, mt)
end

table.initmeta = table_initmeta

local function table_foreach(t, f)
	for k, v in next, t do
		f(k, v) -- TODO/CONS: terminate if this returns a non-nil value?
	end
end

table.foreach = table_foreach

local function table_foreachi(t, funcs)
	if funcs then
		for i = 1, #t do
			local f = funcs[i]
			if f then
				f(i, t[i]) -- TODO/CONS: terminate if this returns a non-nil value?
			end
		end
	else
		return function(funcs)
			for i = 1, #t do
				local f = funcs[i]
				if f then
					f(i, t[i]) -- TODO/CONS: terminate if this returns a non-nil value?
				end
			end
		end
	end
end

table.foreachi = table_foreachi

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

local function table_copy_array(t, out)
	out = out or {}

	for i = 1, #t do
		out[i] = t[i]
	end

	return out
end

table.copy_array = table_copy_array

local function table_array(t, out)
	out = out or {}
	local i = 0

	for _, value in next, t do
		i = i + 1
		out[i] = value
	end

	return out
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
table.invert = table_inverse -- alias

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
	-- Create a new table if none is provided
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
table.lowercase = table_lowercase_keys -- alias

local function table_uppercase_keys(t, out)
	out = out or {}
	for k, v in next, t do
		out[string_upper(k)] = v
	end
	return out
end

table.uppercase_keys = table_uppercase_keys
table.uppercase = table_uppercase_keys -- alias

-- Optimized version using table.move (Lua 5.3+)
local function table_remove_first_optimized(arr, numElements)
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
local function table_remove_first_fallback(arr, numElements)
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

local function table_remove_last(arr, numElements)
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

local function table_unique(t)
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

-- Default predicate for filter: truthy values
local function table_filter_default_pred(v)
	--return v ~= nil and v ~= false
	return not not v
end

local function table_filter(t, pred, opts)
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

local function table_filter_inplace(t, pred, opts)
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

local function table_filter_iter(t, pred)
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

local function table_filter_pattern(t, pattern, opts)
	if type(t) ~= "table" then return {} end
	if type(pattern) ~= "string" then return {} end
	opts = opts or {}
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
			local v_str = tostring(v)
			if string_match(v_str, pattern) then
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
			local v_str = tostring(v)
			if string_match(v_str, pattern) then
				index = index + 1
				out[index] = v
			end
		end
	else
		for k, v in next, t do
			local v_str = tostring(v)
			if string_match(v_str, pattern) then
				out[k] = v
			end
		end
	end
	return out
end

table.filter_pattern = table_filter_pattern

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

local function table_rotated_left(t, amount)
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

table.rotated_left = table_rotated_left

local function table_rotated_right(t, amount)
	amount = tonumber(amount) or 0
	if amount <= 0 then return shallow_copy(t) end

	local n = #t
	if amount >= n then return shallow_copy(t) end

	return table_rotated_left(t, n - amount)
end

table.rotated_right = table_rotated_right

local function table_rotated(t, rotation)
	rotation = tonumber(rotation) or 0
	if rotation < 0 then
		return table_rotated_left(t, -rotation)
	end
	return table_rotated_right(t, rotation)
end

table.rotated = table_rotated

local function table_rotate_left(t, amount)
	amount = tonumber(amount) or 0
	if amount <= 0 then return t end

	local n = #t
	if amount >= n then return t end

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

local function table_rotate_right(t, amount)
	amount = tonumber(amount) or 0
	if amount <= 0 then return t end

	local n = #t
	if amount >= n then return t end

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
	return t
end

table.reverse = table_reverse

local function table_reversed(t)
	local n = #t
	local out = {}

	-- Copy elements in reverse order
	for i = 1, n do
		out[i] = t[n - i + 1]
	end

	return out
end

table.reversed = table_reversed

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

local function table_sortdesc(t)
	table_sort(t, table_sortdesc_cmp)
	return t
end

table.sortdesc = table_sortdesc

local function table_sorted(t, descending)
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

local function table_sort_by(t, key_func)
	table_sort(t, function(a, b)
		local key_a, key_b = key_func(a), key_func(b)
		return key_a < key_b or (key_a == key_b and a < b)
	end)
	return t
end

local function table_sort_by(t, key_func)
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

local function table_sort_by_field(t, field)
	table_sort(t, function(a, b)
		local a_field, b_field = a[field], b[field]
		--return a_field < b_field
		return a_field < b_field or (a_field == b_field and a < b)
	end)
	return t
end

table.sort_by_field = table_sort_by_field

local function table_sort_by_key(t, key_func)
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

local function table_sum(t)
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

local function table_max(t)
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

local function table_min(t)
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

local function table_average(t)
	local sum = 0
	local count = 0
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

local function table_median(t)
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
		return (values[n * 0.5] + values[(n * 0.5) + 1]) * 0.5
	end
	return values[math_ceil(n * 0.5)]
end

table.median = table_median

local function table_stats(t)
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
	writer = writer or print
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

-- Pattern to match bracket notation: ["key"] or ['key'] or [number]
local bracket_pattern = "%s*%[([^%]]*)%]"

local function parse_bracket_key(content)
	-- Check if it's a quoted string
	local quote = string_sub(content, 1, 1)
	if quote == '"' or quote == "'" then
		if string_sub(content, #content, #content) == quote then
			-- Quoted string - extract content and handle escapes
			local inner = string_sub(content, 2, #content - 1)
			-- Replace escape sequences: \" -> ", \' -> ', \\ -> \
			inner = string_gsub(inner, "\\(.)", function(c)
				if c == quote or c == "\\" then
					return c
				end
				-- Keep other escape sequences as-is (e.g., \n, \t)
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

local function table_get_path(t, path, separator)
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

local function table_set_path(t, path, value, separator)
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

local function table_track(t, opts)
	opts = opts or {}

	local base_mt = getmetatable(t)

	local function index_value(k)
		if base_mt and base_mt.__index ~= nil then
			local idx = base_mt.__index
			if type(idx) == "function" then
				return idx(t, k)
			end
			return idx[k]
		end
	end

	local function write_value(k, v)
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

	local function delete_value(k)
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

-- Read-only table wrapper (inline implementation to avoid _G.readonly side effect)
do
	local readonly_newindex = function()
		return error("attempt to modify a read-only table", 2)
	end

	local function table_readonly(t)
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
	table.find = table_find_module.find
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
