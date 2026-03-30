-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Iterative table dumper utility 😎
-- Quick usage example:
--local n, lines = dump(_G, "_G", {
--	max_depth = 1,
--	filter = function(fullPath, k, v)
--		if k == "math" then print(fullPath) return true end
--		return false
--	end
--})
--for i = 1, n do print(lines[i]) end

-- Localize global functions for better performance
local type = type
local tostring = tostring
local next = next
local print = print
local string_format = string.format
local string_match = string.match

--------------------------------------------------------------------------------
-- Private helper functions
--------------------------------------------------------------------------------
local function is_identifier(s)
	-- TODO/CONS: perhaps use load to check if it's a valid identifier because LuaJIT supports unicode identifiers
	return type(s) == "string" and string_match(s, "^[A-Za-z_][A-Za-z0-9_]*$") ~= nil
end

local function format_key(k)
	local kt = type(k)
	if kt == "string" then
		if is_identifier(k) then
			return "." .. k
		end
		return "[" .. string_format("%q", k) .. "]" -- TODO/FIXME: use to_string_literal because %q fu**s up on newline
	end
	-- number, boolean, or other types all use bracket notation
	return "[" .. tostring(k) .. "]"
end

local function format_value(v)
	if v == nil then return "nil" end
	local vt = type(v)
	if vt == "string" then
		return string_format("%q", v)
	end
	if vt == "number" or vt == "boolean" then
		return tostring(v)
	end
	return "<" .. vt .. ":" .. tostring(v) .. ">"
end

--- Iterative table dumper with optional depth limit and filter.
--- @param root table The table or value to dump.
--- @param start_path string|nil The initial path string (e.g., "_G" or "data").
--- @param opts table|nil Optional configuration table:
---  - `max_depth` boolean: maximum depth to traverse (default: nil = unlimited)
---  - `filter`: function(path, key, value) -> boolean (return false to skip)
--- @return number count Total amount of lines
--- @return table lines Array of lines
local function dump_table(root, start_path, opts)
	opts = opts or {}

	-- If root is not a table, return single-line output
	if type(root) ~= "table" then
		return 1, { start_path .. " = " .. format_value(root) }
	end

	-- Validate start_path
	if start_path == nil or start_path == "" then
		start_path = "root"
	end

	-- Stack implemented as array with top index (avoid table.insert/remove)
	-- Each frame: { tbl, path, last, depth }
	local stack = {}
	local top = 0

	-- visited: table -> first seen path (for cycle detection)
	local visited = {}

	-- Output lines collected
	local out = {}
	local out_n = 0

	-- Optional filter and max_depth
	local filter = opts.filter
	local max_depth = opts.max_depth

	-- Push root
	top = top + 1
	stack[top] = { tbl = root, path = start_path, last = nil, depth = 1 }
	visited[root] = start_path

	-- TODO/FIXME: refactor to avoid goto (continue); extract to a local module-scope function
	while top > 0 do
		local frame = stack[top]
		local t, frame_path, frame_depth = frame.tbl, frame.path, frame.depth
		local k, v = next(t, frame.last)

		if k == nil then
			-- Pop frame
			stack[top] = nil
			top = top - 1
		else
			-- Advance iterator
			frame.last = k
			local key_part = format_key(k)
			local full_path = frame_path .. key_part

			-- Apply filter if provided
			if filter and filter(full_path, k, v) == false then
				-- Skip this key-value pair
				goto continue
			end

			if type(v) == "table" then
				local seen = visited[v]
				if seen then
					-- Cycle detected
					out_n = out_n + 1
					out[out_n] = full_path .. " = <cycle to " .. seen .. ">"
				elseif max_depth and frame_depth >= max_depth then
					-- Depth limit reached
					out_n = out_n + 1
					out[out_n] = full_path .. " = <table:depth_limit>"
				else
					-- Push child table
					visited[v] = full_path
					out_n = out_n + 1
					out[out_n] = full_path .. " = <table>"
					top = top + 1
					stack[top] = { tbl = v, path = full_path, last = nil, depth = frame_depth + 1 }
				end
			else
				out_n = out_n + 1
				out[out_n] = full_path .. " = " .. format_value(v)
			end

			::continue::
		end
	end

	return out_n, out
end

--- Convenience wrapper that prints directly.
--- @param root table The table or value to dump.
--- @param start_path string|nil The initial path string.
--- @param opts table|nil Optional table with max_depth and/or filter.
local function print_dump_table(root, start_path, opts)
	local n, lines = dump_table(root, start_path, opts)
	for i = 1, n do
		print(lines[i])
	end
	return n
end

-- Export
return {
	is_identifier = is_identifier,
	fkey = format_key,
	fvalue = format_value,
	dump = dump_table,
	print = print_dump_table,
}
