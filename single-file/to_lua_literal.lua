-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Transform Lua string back to source string literal (binary safe).

-- Localized globals for better performance (module scope)
local type = type
local tostring = tostring
local string_byte = string.byte
local string_char = string.char
local string_format = string.format
local table_concat = table.concat
local string_find = string.find
local string_rep = string.rep
local math_floor = math.floor

-- Static control-character escape map
local CONTROL_MAP = {
	[7] = "\\a",
	[8] = "\\b",
	[9] = "\\t",
	[10] = "\\n",
	[11] = "\\v",
	[12] = "\\f",
	[13] = "\\r",
}

-- Hex formatter helper
local function hex_byte(b, upper)
	return string_format(upper and "\\x%02X" or "\\x%02x", b)
end

-- Safe printable check
local function is_printable_ascii(b)
	return b >= 32 and b <= 126
end

--- Find a safe long-bracket depth for string `s`.<br>
--- Determines the appropriate depth for Lua long brackets to avoid conflicts with the string content.<br>
--- Long brackets use the form `[=...[` and `]=...]` where the number of `=` signs determines the depth.
---
--- @param s string The string to check for potential conflicts
--- @param requested_depth boolean|number|nil The desired depth:
---  - `true`: Use depth 0 (no `=` tokens), i.e. `[[...]]`
---  - `number >= 0`: Use that exact depth, i.e. `[=...[...] =...]`
---  - `nil`: Do not attempt long-bracket
---
--- @return number|nil depth The safe depth to use, or `nil` if no safe depth found.
---
--- @usage <br>
---   find_safe_long_bracket_depth("hello", true) -- returns 0 (safe for [[...]])
---   find_safe_long_bracket_depth("contains ]=]", 1) -- returns 2 or higher
---   find_safe_long_bracket_depth("contains ]]]]]", 0) -- returns nil (no safe depth)
local function find_safe_long_bracket_depth(s, requested_depth)
	if requested_depth == nil then return nil end

	local max_depth = 32 -- reasonable upper bound
	local start_depth

	if requested_depth == true then
		-- user explicitly asked for depth 0 (no '=')
		start_depth = 0
	elseif type(requested_depth) == "number" and requested_depth >= 0 then
		start_depth = math_floor(requested_depth)
	else
		-- invalid argument: do not attempt long-bracket
		return nil
	end

	for depth = start_depth, max_depth do
		local closing = "]" .. string_rep("=", depth) .. "]"
		if not string_find(s, closing, 1, true) then
			return depth
		end
	end

	return nil
end

--- Convert any value to a Lua source string literal (binary-safe).
--- This function produces a properly escaped Lua string literal that can be
--- used in Lua source code. It handles all byte values including null and
--- control characters, and supports both quoted strings and long brackets.
---
--- @param s string The input value to convert (string or any value that can be converted to string)
--- @param opts table|nil Optional table with configuration options:
---
---  - `quote` (string): '"' or "'" - type of quotes to use (default '"')
---
---  - `escape_nonascii` (boolean): whether to escape non-ASCII bytes (default true)
---
---  - `upper_hex` (boolean): whether to use uppercase hex digits (default true)
---
---  - `allow_long_bracket` (boolean|number): true for depth 0 [[...]], or number >=0 for specific depth (default false)
---
--- @return string string A valid Lua string literal ready for use in source code
---
--- @usage <br>
---   `to_lua_literal("hello")`  ==>  `"hello"`
---
---   `to_lua_literal("hello\nworld")`  ==>  `"hello\\nworld"`
---
---   `to_lua_literal("multi\nline", { allow_long_bracket = true })`  ==>  `[[multi\nline]]`
local function to_lua_literal(s, opts)
	-- Validate and normalize inputs
	if type(s) ~= "string" then
		s = tostring(s or "")
	end
	opts = opts or {}

	-- Explicit option handling
	local quote = opts.quote == "'" and "'" or '"' -- default to double quote
	local escape_nonascii = true
	if opts.escape_nonascii ~= nil then escape_nonascii = not not opts.escape_nonascii end
	local upper_hex = true
	if opts.upper_hex ~= nil then upper_hex = not not opts.upper_hex end

	-- allow_long_bracket acts as a single argument:
	-- true -> use depth 0 (i.e., [[ ... ]])
	-- number -> requested depth (>=0)
	local allow_long_bracket = opts.allow_long_bracket or false
	local allow_long_bracket_depth = nil
	if allow_long_bracket then
		if allow_long_bracket == true then
			allow_long_bracket_depth = 0
		elseif type(allow_long_bracket) == "number" and allow_long_bracket >= 0 then
			allow_long_bracket_depth = math_floor(allow_long_bracket)
		else
			allow_long_bracket_depth = nil
			allow_long_bracket = false
		end
	end

	-- If allowed and safe, return long-bracket form with chosen depth.
	if allow_long_bracket_depth ~= nil then
		local depth = find_safe_long_bracket_depth(s, allow_long_bracket_depth)
		if depth ~= nil then
			local eq = string_rep("=", depth)
			return "[" .. eq .. "[" .. s .. "]" .. eq .. "]"
		end
		-- If no safe depth found, fall back to escaped short form below
	end

	-- Build result pieces in a table (avoid repeated concatenation)
	local out = {}
	local function append(x) out[#out + 1] = x end

	-- Opening quote
	append(quote)

	-- Iterate bytes and emit appropriate escapes
	local len = #s
	for i = 1, len do
		local b = string_byte(s, i)

		if is_printable_ascii(b) then
			-- Printable ASCII: escape backslash and the chosen quote
			if b == 92 then -- backslash '\'
				append("\\\\")
			elseif b == string_byte(quote) then
				if quote == '"' then append('\\"') else append("\\'") end
			else
				append(string_char(b))
			end
		else
			-- Non-printable or control
			local mapped = CONTROL_MAP[b]
			if mapped then
				append(mapped)
			else
				-- For all other bytes (including NUL), use \xHH
				if b >= 128 and not escape_nonascii then
					-- If user opted to keep non-ASCII raw, append raw byte (may produce non-ASCII source)
					append(string_char(b))
				else
					append(hex_byte(b, upper_hex))
				end
			end
		end
	end

	-- Closing quote
	append(quote)

	return table_concat(out)
end

-- Export
return to_lua_literal
