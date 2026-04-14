-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Localized global functions for better performance
local next = next
local tostring = tostring
local type = type
local string_format = string.format
local table_concat = table.concat

local function default_eq(a, b)
	return a == b
end

local function copy_array(t)
	local out = {}
	for i = 1, #t do
		out[i] = t[i]
	end
	return out
end

--- Pretty-print a path (keys) for debugging.<br>
--- Converts a path array from table_find.find to a human-readable string.
---@param path table Path array from table_find.find (array of {key, key_string} pairs).
---@return string path_string Human-readable path string with " -> " separators.
---@usage <br>
--- ```
--- local t = {a = {x = 1, y = {z = 42}}}
--- local results = table_find.find(t, 42)
--- for _, path in next, results do
---   print(table_find.path_to_string(path)) -- "a" -> "y" -> "z"
--- end
--- ```
local function path_to_string(path)
	local parts = {}
	for i = 1, #path do
		local k, ks = path[i]
		if type(k) == "string" then
			ks = string_format("%q", k) -- TODO/CONS: use to_string_literal?
		else
			ks = tostring(k)
		end
		parts[#parts + 1] = ks
	end
	return table_concat(parts, " -> ")
end

--- Search for values in a table and return paths to matches.<br>
--- Performs iterative depth-first search with cycle detection and configurable options.
---@param haystack table Table to search/traverse (haystack)
---@param needle_or_pred any Either value to match (uses ==), or a predicate `function(value, key, parent, path) -> boolean`
---@param opts table|nil Options table (optional):<br>
--- - `max_depth` (number, default = math.huge): Limit max search depth
--- - `first` (boolean, default = false): Whether to stop at first match
--- - `search_keys` (boolean, default = false): Also test keys for match
--- - `compare` (function(a, b) -> boolean): Custom comparator when needle provided
--- - `return_values` (boolean, default = false): Return {path=..., value=...} entries instead of just paths
--- - `include_root` (boolean, default = false): If true and root table itself matches, include empty path {}
---@usage <br>
--- ```
--- local t = {
---   a = { x = 1, y = { z = 42 } },
---   b = { z = 42 },
--- }
--- t.a.y.self = t -- create a cycle
--- -- Find all occurrences of 42
--- for _, p in next, table_find.find(t, 42) do
---   print(table_find.path_to_string(p))
--- end
--- -- Possible output:
--- -- "a" -> "y" -> "z"
--- -- "b" -> "z"
---
--- -- Find first occurrence only (early exit)
--- local first = table_find.find(t, 42, { first = true })
--- print("first:", table_find.path_to_string(first[1]))
---
--- -- Use predicate: find numeric values > 10
--- local big = table_find.find(t, function(v, k, parent, path) return type(v) == "number" and v > 10 end)
--- for _, r in next, big do print(table_find.path_to_string(r)) end
---
--- -- Return values with paths
--- for _, entry in next, table_find.find(t, 42, { return_values = true }) do
---   print(table_find.path_to_string(entry.path), "=", entry.value)
--- end
--- ```
local function table_find(haystack, needle_or_pred, opts)
	assert(type(haystack) == "table", "haystack must be a table")
	opts = opts or {}
	local max_depth = opts.max_depth or math.huge
	local first_only = opts.first or false
	local search_keys = opts.search_keys or false
	local cmp = opts.compare
	local return_values = opts.return_values or false
	local include_root = opts.include_root or false

	local is_pred = type(needle_or_pred) == "function"
	local needle = needle_or_pred
	if not is_pred and cmp == nil then cmp = default_eq end

	local results = {}
	local visited = setmetatable({}, { __mode = "k" }) -- weak keys to avoid memory retention

	-- Iterative DFS stack: each frame `{t=table, last_key=nil, path=array, depth=number}`
	local stack = {}
	local function push_frame(t, path, depth)
		stack[#stack + 1] = { t = t, last = nil, path = path, depth = depth }
	end

	-- Optionally test root table itself (rare)
	if include_root then
		local ok
		if is_pred then
			ok = needle(haystack, nil, nil, {})
		else
			ok = cmp(haystack, needle)
		end
		if ok then
			if return_values then
				results[1] = { path = {}, value = haystack }
			else
				results[1] = {}
			end
			if first_only then return results end
		end
	end

	visited[haystack] = true
	push_frame(haystack, {}, 0)

	while #stack > 0 do
		local frame = stack[#stack]
		local t = frame.t
		local last = frame.last
		local path = frame.path
		local depth = frame.depth

		local k, v = next(t, last)
		if k == nil then
			-- Finished this table
			stack[#stack] = nil
		else
			-- Advance iterator
			frame.last = k

			-- Check key match if requested
			if search_keys then
				local key_match --= false
				if is_pred then
					-- Predicate receives (value, key, parent, path)
					key_match = needle(k, k, t, path)
				else
					key_match = cmp(k, needle)
				end
				if key_match then
					local found_path = copy_array(path)
					found_path[#found_path + 1] = k
					if return_values then
						results[#results + 1] = { path = found_path, value = v }
					else
						results[#results + 1] = found_path
					end
					if first_only then return results end
				end
			end

			-- Check value match
			local match --= false
			if is_pred then
				-- Predicate signature: (value, key, parent_table, path)
				match = needle(v, k, t, path)
			else
				match = cmp(v, needle)
			end

			if match then
				local found_path = copy_array(path)
				found_path[#found_path + 1] = k
				if return_values then
					results[#results + 1] = { path = found_path, value = v }
				else
					results[#results + 1] = found_path
				end
				if first_only then return results end
			end

			-- If value is a table, descend (if not visited and depth allows)
			if type(v) == "table" and not visited[v] and (depth + 1) <= max_depth then
				visited[v] = true
				local new_path = copy_array(path)
				new_path[#new_path + 1] = k
				push_frame(v, new_path, depth + 1)
			end
		end
	end

	return results
end

-- Export
return {
	find = table_find,
	path_to_string = path_to_string,
}
