-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Lua string literal parser module
--
-- Uses skip-ahead scanning for short strings and plain `string.find` for long brackets.
-- Returns a result table with the following structure:
--   Success: { ok = true, value = ..., next_index = ..., raw = ..., kind = ... }
--     value      - decoded string
--     next_index - 1-based index immediately after the parsed literal
--     raw        - raw substring from the input
--     kind       - 1 = short, 2 = long
--   Failure: { ok = false, error = ..., error_pos = ... }
--     error      - error code (one of E_* constants)
--     error_pos  - 1-based index of the problematic character (or #s + 1 for EOF)
--
-- Options (passed as third argument to `parse`):
--   allow_short             (boolean, default true) - enable short quoted strings
--   allow_long              (boolean, default true) - enable long bracket strings [=*[ ... ]=*]
--   allow_escapes           (boolean, default true) - interpret backslash escapes in short strings
--   allow_numeric_escapes   (boolean, default true) - interpret \ddd numeric escapes (only if allow_escapes)
--   remove_initial_newline  (boolean, default true) - remove initial newline in long bracket content
--   escape_map              (table,   default DEFAULT_ESC_MAP) - mapping for single-char escapes
--
-- Error codes are exported as module fields:
--   E_NOT_STRING   - not a string literal at position
--   E_UNTERM_SHORT - unterminated short string
--   E_UNTERM_LONG  - unterminated long bracket string

-- Localized global functions for better performance
local tonumber                                           = tonumber
local string_find, string_sub, string_match, string_gsub = string.find, string.sub, string.match, string.gsub
local string_char, string_byte, string_rep               = string.char, string.byte, string.rep

-- Error codes
local ERR_NOT_STRING                                     = 1
local ERR_UNTERM_SHORT                                   = 2
local ERR_UNTERM_LONG                                    = 3

local BYTE_DQ, BYTE_SQ, BYTE_LBR, BYTE_NL, BYTE_BS       = 34, 39, 91, 10, 92
local DEFAULT_ESC_MAP                                    = {
	a = "\a",
	b = "\b",
	f = "\f",
	n = "\n",
	r = "\r",
	t = "\t",
	v = "\v",
	["\\"] = "\\",
	['"'] = '"',
	["'"] = "'",
	["z"] = "\0",
}

local function to_numeric_escape(d)
	return string_char(tonumber(d))
end

---@class parse_string.Options
---@field allow_short boolean|nil Enable short quoted strings (default: true)
---@field allow_long boolean|nil Enable long bracket strings [=*[ ... ]=*] (default: true)
---@field allow_escapes boolean|nil Interpret backslash escapes in short strings (default: true)
---@field allow_numeric_escapes boolean|nil Interpret \ddd numeric escapes (only if allow_escapes) (default: true)
---@field remove_initial_newline boolean|nil Remove initial newline in long bracket content (default: true)
---@field escape_map table|nil Mapping for single-char escapes (default: DEFAULT_ESC_MAP)

-- TODO: Benchmark and optimize...

--- Parse a Lua string literal starting at position `i` in `s`.<br>
--- Supports short quoted strings with escapes and long bracket strings.
---@param s string Input text.
---@param i integer|nil Index where a string literal starts (default: 1).
---@param opts parse_string.Options|nil Optional behaviour overrides.
---@return table result Result table with ok, value, next_index, raw, kind on success; or ok, error, error_pos on failure.
local function parse_string_literal(s, i, opts)
	local n = #s
	i = i or 1
	if i < 0 then i = n + 1 + i end
	if i < 1 then i = 1 end
	local cbyte = string_byte(s, i)
	if not cbyte then return { ok = false, error = ERR_NOT_STRING, error_pos = i } end

	opts = opts or {}

	-- Short quoted string: "..." or '...'
	if (opts.allow_short ~= false) and (cbyte == BYTE_DQ or cbyte == BYTE_SQ) then
		local qchar = string_char(cbyte)
		local start = i + 1
		local j = start

		while true do
			local next_q = string_find(s, qchar, j, true)
			if not next_q then return { ok = false, error = ERR_UNTERM_SHORT, error_pos = n + 1 } end

			-- Fast path: No backslashes at all before this quote
			local first_bs = string_find(s, "\\", j, true)
			if not first_bs or first_bs > next_q then
				return {
					ok = true,
					value = string_sub(s, start, next_q - 1),
					next_index = next_q + 1,
					raw = string_sub(s, i, next_q),
					kind = 1
				}
			end

			-- Skip escape processing if disabled
			if opts.allow_escapes == false then
				return {
					ok = true,
					value = string_sub(s, start, next_q - 1),
					next_index = next_q + 1,
					raw = string_sub(s, i, next_q),
					kind = 1
				}
			end

			-- Check if quote is escaped by an odd number of backslashes
			local bs_count = 0
			local p = next_q - 1
			while p >= start and string_byte(s, p) == BYTE_BS do
				bs_count = bs_count + 1
				p = p - 1
			end

			if bs_count % 2 == 0 then
				local raw_content = string_sub(s, start, next_q - 1)
				local clean_val = raw_content

				-- Explicitly handle \DDD numeric escapes
				if opts.allow_numeric_escapes ~= false then
					clean_val = string_gsub(clean_val, "\\(%d%d?%d?)", to_numeric_escape)
				end

				-- Handle standard character escapes
				clean_val = string_gsub(clean_val, "\\(.)", opts.escape_map or DEFAULT_ESC_MAP)
				return { ok = true, value = clean_val, next_index = next_q + 1, raw = string_sub(s, i, next_q), kind = 1 }
			end

			-- Quote is escaped; continue searching from after this quote
			j = next_q + 1
		end
	end

	-- Long bracket strings: [=*[ ... ]=*]
	if (opts.allow_long ~= false) and cbyte == BYTE_LBR then
		local eq = string_match(s, "^%[(=*)%[", i)
		if eq then
			local level = #eq
			local close_seq = "]" .. string_rep("=", level) .. "]"
			local s_idx, e_idx = string_find(s, close_seq, i + level + 2, true)
			if not s_idx then return { ok = false, error = ERR_UNTERM_LONG, error_pos = i + level + 2 } end

			local content_start = i + level + 2
			if opts.remove_initial_newline ~= false and string_byte(s, content_start) == BYTE_NL then
				content_start = content_start + 1
			end

			return {
				ok = true,
				value = string_sub(s, content_start, s_idx - 1),
				next_index = e_idx + 1,
				raw = string_sub(s, i, e_idx),
				kind = 2
			}
		end
	end

	return { ok = false, error = ERR_NOT_STRING, error_pos = i }
end

-- Export
return setmetatable({
	parse = parse_string_literal,
	E_NOT_STRING = ERR_NOT_STRING,
	E_UNTERM_SHORT = ERR_UNTERM_SHORT,
	E_UNTERM_LONG = ERR_UNTERM_LONG,
	DEFAULT_ESC_MAP = DEFAULT_ESC_MAP,
}, {
	__call = function(_, ...) return parse_string_literal(...) end
})
