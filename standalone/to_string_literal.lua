-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Transform Lua string back to source string literal (binary-safe)

-- Localized global functions for better performance
local load
-- Best-effort for GMod/LuaJIT/Lua compatibility
if _G.gmod then
	load = _G.CompileString
else
	---@diagnostic disable-next-line: access-invisible
	load = _G.load or _G.loadstring
end
local next = next
local pcall = pcall
local tostring = tostring
local type = type
local math_floor = math.floor
local string_byte = string.byte
local string_char = string.char
local string_find = string.find
local string_format = string.format
local string_gsub = string.gsub
local string_rep = string.rep
local table_concat = table.concat

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

----------------------------------------------------------------------
-- Detect which named escapes this Lua runtime supports
----------------------------------------------------------------------

local escape_candidates = {
	["\\a"] = "\a",
	["\\b"] = "\b",
	["\\f"] = "\f",
	["\\n"] = "\n",
	["\\r"] = "\r",
	["\\t"] = "\t",
	["\\v"] = "\v",
	["\\\\"] = "\\",
	["\\\""] = "\"",
	["\\'"] = "'",
}

local function detect_supported_escapes()
	local supported = {}
	local esc, expected = next(escape_candidates) -- TODO/FIXME: actually iterate full ASCII range

	while esc do
		local fn = load("return '" .. esc .. "'")
		if fn then
			local ok, result = pcall(fn)
			if ok and result == expected then
				supported[expected] = esc
			end
		end
		esc, expected = next(escape_candidates, esc)
	end

	return supported
end

----------------------------------------------------------------------
-- Build the 256-entry lookup table
----------------------------------------------------------------------

-- Safe printable check
local function is_printable_ascii(b)
	return 32 <= b and b <= 126
end

local function build_lookup()
	local escmap = detect_supported_escapes()
	local t = {}

	for i = 0, 255 do
		local c = string_char(i)
		local named = escmap[c]
		if named then
			t[i] = named
		elseif is_printable_ascii(i) then
			t[i] = c
		else
			t[i] = string_format("\\x%02x", i)
		end
	end

	return t
end

local ESC = build_lookup()

----------------------------------------------------------------------
-- Build ESC_CHAR_TABLE for gsub("(.)", table)
----------------------------------------------------------------------

local ESC_CHAR_TABLE = {}
for i = 0, 255 do
	ESC_CHAR_TABLE[string_char(i)] = ESC[i]
end

-- Hex formatter helper
local function hex_byte(b, upper)
	return string_format(upper and "\\x%02X" or "\\x%02x", b)
end

--- Find a safe long-bracket depth for string `s`.<br>
--- Determines the appropriate depth for Lua long brackets to avoid conflicts with the string content.<br>
--- Long brackets use the form `[=...[` and `]=...]` where the number of `=` signs determines the depth.
---
---@param s string The string to check for potential conflicts
---@param requested_depth boolean|integer|nil The desired depth:
--- - `true`: Use depth 0 (no `=` tokens), i.e. `[[...]]`
--- - `number >= 0`: Use that exact depth, i.e. `[=...[...] =...]`
--- - `nil`: Do not attempt long-bracket
---
---@return integer|nil depth The safe depth to use, or `nil` if no safe depth found.
---
---@usage <br>
--- ```
--- find_safe_long_bracket_depth("hello", true) -- returns 0 (safe for [[...]])
--- find_safe_long_bracket_depth("contains ]=]", 1) -- returns 2 or higher
--- find_safe_long_bracket_depth("contains ]]]]]", 0) -- returns nil (no safe depth)
--- ```
local function find_safe_long_bracket_depth(s, requested_depth)
	if requested_depth == nil then return end

	local max_depth = 32 -- reasonable upper bound
	local start_depth

	if requested_depth == true then
		-- user explicitly asked for depth 0 (no '=')
		start_depth = 0
	elseif type(requested_depth) == "number" and requested_depth >= 0 then
		start_depth = math_floor(requested_depth)
	else
		-- invalid argument: do not attempt long-bracket
		return
	end

	for depth = start_depth, max_depth do
		local closing = "]" .. string_rep("=", depth) .. "]"
		if not string_find(s, closing, 1, true) then
			return depth
		end
	end
end

--- Convert a string value to a Lua source string literal (binary-safe).<br>
--- This function produces a properly escaped Lua string literal that can be used in Lua source code.<br>
--- It handles all byte values including null and control characters, and supports both quoted strings and long brackets.
---
---@param s string The input value to convert (string or any value that can be converted to string)
---@param opts table|nil Optional table with configuration options:
--- - `quote` (string): '"' or "'" - type of quotes to use (default: '"')
--- - `escape_nonascii` (boolean): whether to escape non-ASCII bytes (default: true)
--- - `upper_hex` (boolean): whether to use uppercase hex digits (default: true)
--- - `allow_long_bracket` (boolean|number): true for depth 0 [[...]], or number >=0 for specific depth (default: false)
--- - `skip_quotes` (boolean): whether to skip adding surrounding quotes (default: false)
---@return string string A valid Lua string literal ready for use in source code
---@usage <br>
--- ```
--- to_string_literal("hello") -- "hello"
---
--- to_string_literal("hello\nworld") -- "hello\\nworld"
---
--- to_string_literal("multi\nline", { allow_long_bracket = true }) -- [[multi\nline]]
--- ```
local function to_string_literal(s, opts)
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

	-- skip_quotes option - if true, don't add surrounding quotes
	local skip_quotes = opts.skip_quotes or false

	-- If allowed and safe, return long-bracket form with chosen depth.
	if allow_long_bracket_depth ~= nil then
		local depth = find_safe_long_bracket_depth(s, allow_long_bracket_depth)
		if depth ~= nil then
			local eq = string_rep("=", depth)
			if skip_quotes then
				return s -- Return raw content without brackets when skip_quotes is true
			end
			return "[" .. eq .. "[" .. s .. "]" .. eq .. "]"
		end
		-- If no safe depth found, fall back to escaped short form below
	end

	-- Build result pieces in a table (avoid repeated concatenation)
	local out = {}
	local function append(x) out[#out + 1] = x end

	-- Opening quote (skip if skip_quotes is true)
	if not skip_quotes then
		append(quote)
	end

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

	-- Closing quote (skip if skip_quotes is true)
	if not skip_quotes then
		append(quote)
	end

	return table_concat(out)
end

----------------------------------------------------------------------
-- Raw literal functions
----------------------------------------------------------------------

--- Convert string to raw literal using fast loop method.<br>
--- This is the fastest implementation that iterates through the string
--- byte-by-byte using a pre-built lookup table.
---
---@param s string The input string to convert.
---@return string string A raw literal with all non-printable characters escaped.
local function to_raw_literal(s)
	local out = {}
	local n = #s
	for i = 1, n do
		out[i] = ESC[string_byte(s, i)]
	end
	return table_concat(out)
end

local raw_literal_gsub_func = function(c)
	return ESC[string_byte(c)]
end
--- Convert string to raw literal using gsub with function callback.<br>
--- This version uses `string.gsub` with a function that looks up each character
--- in the escape table. Slightly slower than the loop version but more concise.
---
---@param s string The input string to convert.
---@return string string A raw literal with all non-printable characters escaped.
local function to_raw_literal_gsub(s)
	return (string_gsub(s, ".", raw_literal_gsub_func))
end

--- Convert string to raw literal using gsub with table lookup.<br>
--- This version uses `string.gsub` with a capture pattern and table lookup.<br>
--- It's the most concise implementation, but may be slightly slower than
--- the function callback version.
---
---@param s string The input string to convert.
---@return string string A raw literal with all non-printable characters escaped.
local function to_raw_literal_gsub_table(s)
	return (string_gsub(s, "(.)", ESC_CHAR_TABLE))
end

-- Export
return setmetatable({
	to_string_literal = to_string_literal,
	ESC = ESC,
	ESC_CHAR_TABLE = ESC_CHAR_TABLE,
	to_raw_literal = to_raw_literal,
	to_raw_literal_gsub = to_raw_literal_gsub,
	to_raw_literal_gsub_table = to_raw_literal_gsub_table,
}, {
	__call = function(_, ...)
		return to_string_literal(...)
	end
})
