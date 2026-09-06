-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Utilities for raw/direct (metamethod-bypassing) table access.
--
-- Provides a set of functions that use `rawget` and `rawset` to interact with
-- tables, ensuring that any metatable-defined `__index` or `__newindex`
-- metamethods are ignored. This is particularly useful for internal library
-- logic, serialization, or when implementing custom proxy behaviors.
--
-- Usage example:
-- ```
-- local table_raw = require "table_raw"
--
-- local t = setmetatable({ x = 10 }, {
--   __index = function() return "intercepted" end,
--   __newindex = function() return error("read-only") end
-- })
--
-- print(t.x)                   -- "intercepted"
-- print(table_raw.get(t, "x")) -- 10
--
-- table_raw.set(t, "y", 20)    -- works, bypasses error
-- print(table_raw.get(t, "y")) -- 20
-- ```

-- Localized global functions for better performance
local assert = assert
local next = next
local rawget = rawget
local rawset = rawset
local select = select
local tostring = tostring
local type = type
local table_sort = table.sort
local table_unpack = table.unpack or unpack

----------------------------------------------------------------------
-- Module definition
----------------------------------------------------------------------

--- Utilities for raw/direct table access.
---@class table_raw
local M = {}

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------

--- Comparison function for sorting table keys by their string representation.
---@param a any First key.
---@param b any Second key.
---@return boolean less True if tostring(a) < tostring(b).
local function compare_keys(a, b)
	return tostring(a) < tostring(b)
end

----------------------------------------------------------------------
-- Raw access
----------------------------------------------------------------------

--- Set one field directly (bypasses `__newindex`).<br>
--- Returns `t`, allowing for method chaining.
---@param t table The target table.
---@param key any The key to set.
---@param value any The value to assign.
---@return table t The target table.
---@usage <br>
--- ```
--- table_raw.set(table_raw.set(t, "x", 1), "y", 2)
--- ```
function M.set(t, key, value)
	assert(type(t) == "table", "expected table, got " .. type(t))
	rawset(t, key, value)
	return t
end

--- Set many fields at once using raw access.<br>
--- Supports two calling conventions: passing key/value pairs directly, or
--- passing a single table containing the defaults.
---@param t table The target table.
---@param ... any Either a single table of defaults, or multiple key/value pairs.
---@return table t The target table.
---@usage <br>
--- ```
--- -- key/value pairs
--- table_raw.fill(self, "x", x, "y", y)
---
--- -- defaults table
--- table_raw.fill(self, { x = x, y = y })
--- ```
function M.fill(t, ...)
	assert(type(t) == "table", "expected table, got " .. type(t))

	local n = select("#", ...)
	if n == 1 then
		local src = (...)
		assert(type(src) == "table", "single argument must be a table of defaults")
		for k, v in next, src do
			rawset(t, k, v)
		end
		return t
	end

	assert(n % 2 == 0, "expected key/value pairs (even number of args)")
	for i = 1, n, 2 do
		-- parens force exactly one value each, even if keys are nil-heavy
		rawset(t, (select(i, ...)), (select(i + 1, ...)))
	end
	return t
end

--- Read one field directly (bypasses `__index`), with a default fallback.<br>
--- Returns the value if it exists (is not nil), otherwise returns the default.
---@param t table The target table.
---@param key any The key to read.
---@param default any The fallback value if the key is missing.
---@return any value The raw value or the default.
function M.get(t, key, default)
	assert(type(t) == "table", "expected table, got " .. type(t))
	local v = rawget(t, key)
	if v == nil then
		return default
	end
	return v
end

--- Read several fields at once using raw access.<br>
--- Returns the requested values as multiple return values.
---@param t table The target table.
---@param ... any The keys to extract.
---@return ... any values The raw values corresponding to the provided keys.
---@usage <br>
--- ```
--- local x, y = table_raw.pick(self, "x", "y")
--- ```
function M.pick(t, ...)
	assert(type(t) == "table", "expected table, got " .. type(t))
	local n = select("#", ...)
	local out = {}
	for i = 1, n do
		out[i] = rawget(t, (select(i, ...)))
	end
	return table_unpack(out, 1, n)
end

----------------------------------------------------------------------
-- Iteration
----------------------------------------------------------------------

--- Iterate over keys stored *directly* on the table `t`.<br>
--- Excludes anything visible only through `__index` inheritance.<br>
--- The keys are sorted by their string representation.
---@param t table The target table.
---@return function iterator Stateless iterator returning one key per call.
function M.keys(t)
	assert(type(t) == "table", "expected table, got " .. type(t))
	local keys = {}
	for k in next, t do
		keys[#keys + 1] = k
	end
	table_sort(keys, compare_keys)
	local i = 0
	return function()
		i = i + 1
		local k = keys[i]
		if k ~= nil then
			return k
		end
	end
end

--- Iterate over fields stored *directly* on the table `t`.<br>
--- Excludes anything visible only through `__index` inheritance.<br>
--- The fields are yielded in key-sorted order.
---@param t table The target table.
---@return fun(): (any, any) iterator Stateless iterator returning key and value per call.
function M.pairs(t)
	assert(type(t) == "table", "expected table, got " .. type(t))
	local keys = {}
	for k in next, t do
		keys[#keys + 1] = k
	end
	table_sort(keys, compare_keys)
	local i = 0
	return function()
		i = i + 1
		local k = keys[i]
		if k ~= nil then
			return k, rawget(t, k)
		end
	end
end

----------------------------------------------------------------------
-- Migration
----------------------------------------------------------------------

--- Migrate all raw fields from `src` into `dst`, then clear `src`.<br>
--- Keys already present in `dst` are skipped (not overwritten).<br>
--- Both tables are accessed with `rawget`/`rawset`, so metamethods are never triggered.<br>
--- This is useful for absorbing fields that were set via `rawset` on a proxied or frozen table.
---@param dst table The destination table receiving the fields.
---@param src table The source table whose fields are moved and then cleared.
---@return table dst The destination table.
function M.migrate(dst, src)
	assert(type(dst) == "table", "expected table for dst, got " .. type(dst))
	assert(type(src) == "table", "expected table for src, got " .. type(src))

	-- Snapshot keys first to avoid mutating `src` while iterating it.
	local snapshot = {}
	for k, v in next, src do
		snapshot[k] = v
	end

	for k, v in next, snapshot do
		if rawget(dst, k) == nil then
			rawset(dst, k, v)
		end
		rawset(src, k, nil)
	end

	return dst
end

-- Export
return M
