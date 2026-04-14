-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Augment existing standard string library

-- Localized global functions for better performance
local tonumber = tonumber
local tostring = tostring
local type = type
local math_floor = math.floor
local math_ceil = math.ceil
local math_min = math.min
local math_max = math.max
local math_random = math.random
local pcall = pcall
---@diagnostic disable-next-line: unnecessary-assert
local string = assert(_G.string, "string library is missing") ---@type string
local string_char = string.char
local string_find = string.find
local string_gmatch = string.gmatch
local string_gsub = string.gsub
local string_lower = string.lower
local string_match = string.match
local string_rep = string.rep
local string_sub = string.sub
local string_upper = string.upper
local string_byte = string.byte
local string_format = string.format
local table_concat = table.concat

-- Check for UTF-8 support
local has_utf8 = type(utf8) == "table" and pcall(function() return utf8.codes("") end)

-- Character classification helpers
do
	-- Only check the first character
	local string_is_upper = function(c) return string_match(c, "^%u") ~= nil end
	local string_is_lower = function(c) return string_match(c, "^%l") ~= nil end
	local string_is_alpha = function(c) return string_match(c, "^%a") ~= nil end
	local string_is_digit = function(c) return string_match(c, "^%d") ~= nil end
	local string_is_space = function(c) return string_match(c, "^%s") ~= nil end
	local string_is_alphanum = function(c) return string_match(c, "^%w") ~= nil end
	local string_is_control = function(c) return string_match(c, "^%c") ~= nil end
	local string_is_punct = function(c) return string_match(c, "^%p") ~= nil end

	-- Precomputed ASCII+character index tables for performance
	local BYTE_LOOKUP, CHAR_LOOKUP, UPPER_LOOKUP, LOWER_LOOKUP, ALPHA_LOOKUP, DIGIT_LOOKUP, SPACE_LOOKUP, ALPHANUM_LOOKUP, CONTROL_LOOKUP, PUNCT_LOOKUP =
		{}, {}, {}, {}, {}, {}, {}, {}, {}, {}
	for ascii = 0, 0xFF do
		local ch = string_char(ascii)
		BYTE_LOOKUP[ascii] = ch
		CHAR_LOOKUP[ch] = ascii
		local isupper = string_is_upper(ch)
		UPPER_LOOKUP[ascii], UPPER_LOOKUP[ch] = isupper, isupper
		local islower = string_is_lower(ch)
		LOWER_LOOKUP[ascii], LOWER_LOOKUP[ch] = islower, islower
		local isalpha = string_is_alpha(ch)
		ALPHA_LOOKUP[ascii], ALPHA_LOOKUP[ch] = isalpha, isalpha
		local isdigit = string_is_digit(ch)
		DIGIT_LOOKUP[ascii], DIGIT_LOOKUP[ch] = isdigit, isdigit
		local isspace = string_is_space(ch)
		SPACE_LOOKUP[ascii], SPACE_LOOKUP[ch] = isspace, isspace
		local isalphanum = string_is_alphanum(ch)
		ALPHANUM_LOOKUP[ascii], ALPHANUM_LOOKUP[ch] = isalphanum, isalphanum
		local iscontrol = string_is_control(ch)
		CONTROL_LOOKUP[ascii], CONTROL_LOOKUP[ch] = iscontrol, iscontrol
		local ispunct = string_is_punct(ch)
		PUNCT_LOOKUP[ascii], PUNCT_LOOKUP[ch] = ispunct, ispunct
	end

	string_is_upper = function(c) return UPPER_LOOKUP[c] end
	string_is_lower = function(c) return LOWER_LOOKUP[c] end
	string_is_alpha = function(c) return ALPHA_LOOKUP[c] end
	string_is_digit = function(c) return DIGIT_LOOKUP[c] end
	string_is_space = function(c) return SPACE_LOOKUP[c] end
	string_is_alphanum = function(c) return ALPHANUM_LOOKUP[c] end
	string_is_control = function(c) return CONTROL_LOOKUP[c] end
	string_is_punct = function(c) return PUNCT_LOOKUP[c] end

	string.is_upper = string_is_upper
	string.isUpper = string_is_upper
	string.IsUpper = string_is_upper

	string.is_lower = string_is_lower
	string.isLower = string_is_lower
	string.IsLower = string_is_lower

	string.is_alpha = string_is_alpha
	string.isAlpha = string_is_alpha
	string.IsAlpha = string_is_alpha

	string.is_digit = string_is_digit
	string.isDigit = string_is_digit
	string.IsDigit = string_is_digit

	string.is_space = string_is_space
	string.isSpace = string_is_space
	string.IsSpace = string_is_space

	string.is_alphanum = string_is_alphanum
	string.isAlphaNum = string_is_alphanum
	string.IsAlphaNum = string_is_alphanum

	string.is_control = string_is_control
	string.isControl = string_is_control
	string.IsControl = string_is_control

	string.is_punct = string_is_punct
	string.isPunct = string_is_punct
	string.IsPunct = string_is_punct
end

local string_is_empty = function(self)
	--return self == ""
	return #self == 0
end

string.is_empty = string_is_empty
string.isEmpty = string_is_empty
string.IsEmpty = string_is_empty

do
	local ITERATE_LINES_PATTERN = "[^\n]+"

	local string_iterate_lines = function(self)
		return string_gmatch(self, ITERATE_LINES_PATTERN)
	end

	string.iterate_lines = string_iterate_lines
	string.iterateLines = string_iterate_lines
	string.IterateLines = string_iterate_lines
end

do
	local CARRIAGE_RETURN_CHAR = "\r"
	local NEWLINE_CHAR = "\n"

	local string_lines = function(self)
		local len = #self -- Total length of the input string
		local lines = {}
		local line_counter = 0
		local pos = 1
		while pos <= len do
			-- Look for the next literal newline character starting at pos (plain search, no pattern matching)
			local newline_start, newline_end = string_find(self, NEWLINE_CHAR, pos, true)
			if newline_start then
				local line_end = newline_start - 1
				-- If the character immediately before the newline is a carriage return, adjust lineEnd
				if line_end >= pos and string_sub(self, line_end, line_end) == CARRIAGE_RETURN_CHAR then
					line_end = line_end - 1
				end
				line_counter = line_counter + 1
				lines[line_counter] = string_sub(self, pos, line_end)
				pos = newline_end + 1
			else
				-- No more newline found; capture the rest of the string
				line_counter = line_counter + 1
				lines[line_counter] = string_sub(self, pos)
				break
			end
		end
		return lines
	end

	string.lines = string_lines
	string.Lines = string_lines
end

local string_iter_explode = function(self, sep)
	if type(self) ~= "string" then self = tostring(self or "") end
	sep = sep or ","
	if type(sep) ~= "string" then sep = tostring(sep) end

	local len = #self
	local start = 1
	local pending_trailing_empty = false

	return function()
		-- handle trailing empty produced by separator at end
		if pending_trailing_empty then
			pending_trailing_empty = false
			return ""
		end

		if start > len then
			-- empty input or already exhausted
			if start == len + 1 then
				-- if input was empty and we haven't yielded anything, yield entire empty string once
				start = len + 2
				return ""
			end
			return nil
		end

		local a, b = string_find(self, sep, start, true)
		if not a then
			-- last field (remainder)
			local res = string_sub(self, start, len)
			start = len + 1
			return res
		end

		local res = string_sub(self, start, a - 1)
		start = b + 1
		if start > len then
			-- separator was at the end -> yield res now and then an empty string next call
			pending_trailing_empty = true
		end
		return res
	end
end

string.iter_explode = string_iter_explode

local string_iter_explode_pattern = function(self, pat)
	if type(self) ~= "string" then self = tostring(self or "") end
	pat = pat or ","
	if type(pat) ~= "string" then pat = tostring(pat) end

	local len = #self
	local start = 1
	local pending_trailing_empty = false

	return function()
		if pending_trailing_empty then
			pending_trailing_empty = false
			return ""
		end

		if start > len then
			if start == len + 1 then
				start = len + 2
				return ""
			end
			return nil
		end

		local a, b = string_find(self, pat, start)
		if not a then
			local res = string_sub(self, start, len)
			start = len + 1
			return res
		end

		local res = string_sub(self, start, a - 1)
		start = b + 1
		if start > len then
			pending_trailing_empty = true
		end
		return res
	end
end

string.iter_explode_pattern = string_iter_explode_pattern

local string_iter_chunk_split = function(self, size)
	if type(self) ~= "string" then self = tostring(self or "") end
	size = tonumber(size) or 1
	if size <= 0 then return error("size must be > 0", 2) end

	local len = #self
	local pos = 1

	return function()
		if pos > len then return nil end
		local e = pos + size - 1
		if e > len then e = len end
		local res = string_sub(self, pos, e)
		pos = e + 1
		return res
	end
end

string.iter_chunk_split = string_iter_chunk_split

local string_chunks = function(self, size)
	if type(self) ~= "string" then self = tostring(self or "") end
	size = tonumber(size) or 1
	if size <= 0 then return error("size must be > 0", 2) end

	local len = #self
	local chunks = {}
	local chunk_counter = 0
	local pos = 1

	while pos <= len do
		local e = pos + size - 1
		if e > len then e = len end
		chunk_counter = chunk_counter + 1
		chunks[chunk_counter] = string_sub(self, pos, e)
		pos = e + 1
	end

	return chunks
end

string.chunks = string_chunks
string.Chunks = string_chunks

local string_chunk = function(self, size)
	if type(self) ~= "string" then self = tostring(self or "") end
	size = tonumber(size) or 1
	if size <= 0 then return error("size must be > 0", 2) end

	local len = #self
	local result = {}
	-- Total amount of chunks can be precomputed using: math.ceil(#str / size)
	local c = 1
	for i = 1, len, size do
		result[c - 1] = string_sub(self, i, i + size - 1)
		c = c + 1
	end
	return result
end

string.chunk = string_chunk
string.Chunk = string_chunk

local string_to_table = function(self)
	local t = {}
	for i = 1, #self do
		t[i] = string_sub(self, i, i)
	end
	return t
end

string.to_table = string_to_table
string.ToTable = string_to_table

local string_explode = function(self, separator, with_pattern)
	if #separator == 0 then return string_to_table(self) end
	local result, current_pos, index = {}, 1, 1
	for i = 1, #self do
		local start_pos, end_pos = string_find(self, separator, current_pos, not with_pattern)
		if not start_pos then break end
		result[index] = string_sub(self, current_pos, start_pos - 1)
		index = index + 1
		current_pos = end_pos + 1
	end
	result[index] = string_sub(self, current_pos)
	return result
end

string.explode = string_explode

-- Non-UTF-8 version of string.split
local function string_split_no_utf8(str, delimiter, max_splits)
	if not str or str == "" then return {} end
	delimiter = delimiter or "%s+"
	max_splits = max_splits or math.huge

	if delimiter == "" then
		-- Split into individual characters
		local result = {}
		for i = 1, #str do
			result[#result + 1] = string_sub(str, i, i)
		end
		return result
	end

	local result = {}
	local count = 0
	local start = 1
	local is_pattern = true -- treat delimiter as Lua pattern

	while count < max_splits do
		local s, e = string_find(str, delimiter, start, not is_pattern)
		if not s then break end
		result[#result + 1] = string_sub(str, start, s - 1)
		count = count + 1
		start = e + 1
	end

	-- Add remaining
	result[#result + 1] = string_sub(str, start)

	return result
end

local string_split_utf8
if has_utf8 then
	-- Localize UTF-8 functions if available
	local utf8_codes = utf8.codes
	local utf8_char = utf8.char

	-- UTF-8 version of string.split
	function string_split_utf8(str, delimiter, max_splits)
		if not str or str == "" then return {} end
		delimiter = delimiter or "%s+"
		max_splits = max_splits or math.huge

		if delimiter == "" then
			-- Split into individual characters
			local result = {}
			for _, cp in utf8_codes(str) do
				result[#result + 1] = utf8_char(cp)
			end
			return result
		end

		local result = {}
		local count = 0
		local start = 1
		local is_pattern = true -- treat delimiter as Lua pattern

		while count < max_splits do
			local s, e = string_find(str, delimiter, start, not is_pattern)
			if not s then break end
			result[#result + 1] = string_sub(str, start, s - 1)
			count = count + 1
			start = e + 1
		end

		-- Add remaining
		result[#result + 1] = string_sub(str, start)

		return result
	end
end

-- Assign the appropriate version based on UTF-8 availability
string.split = has_utf8 and string_split_utf8 or string_split_no_utf8

local string_replace = function(self, search_value, replace_value)
	local tbl = string_explode(self, search_value)
	return next(tbl) and table_concat(tbl, replace_value) or self
end

string.replace = string_replace
string.Replace = string_replace

local string_starts_with = function(self, start)
	return string_sub(self, 1, #start) == start
end

string.starts_with = string_starts_with
string.StartsWith = string_starts_with
string.StartWith = string_starts_with

local string_ends_with = function(self, endStr)
	local len = #endStr
	return len == 0 or string_sub(self, -len) == endStr
end

string.ends_with = string_ends_with
string.EndsWith = string_ends_with

local string_left = function(self, length)
	length = tonumber(length) or 0
	if length <= 0 then return "" end
	return string_sub(self, 1, length)
end

string.left = string_left
string.Left = string_left

local string_right = function(self, length)
	length = tonumber(length) or 0
	if length <= 0 then return "" end
	return string_sub(self, -length)
end

string.right = string_right
string.Right = string_right

local string_pad_left = function(self, total_width, char)
	total_width = tonumber(total_width) or 0
	char = char or " "
	if #self >= total_width then return self end
	return string_rep(char, total_width - #self) .. self
end

string.pad_left = string_pad_left
string.padleft = string_pad_left
string.PadLeft = string_pad_left

local string_pad_right = function(self, total_width, char)
	total_width = tonumber(total_width) or 0
	char = char or " "
	if #self >= total_width then return self end
	return self .. string_rep(char, total_width - #self)
end

string.pad_right = string_pad_right
string.padright = string_pad_right
string.PadRight = string_pad_right

local function string_padl(self, total_width, char)
	char = char or " "
	local s = tostring(self or "")
	local slen = #s
	if slen >= total_width then return s end
	return string_rep(char, total_width - slen) .. s
end

string.padl = string_padl
string.padL = string_padl
string.PadL = string_padl

local function string_padr(self, total_width, char)
	char = char or " "
	local s = tostring(self or "")
	local slen = #s
	if slen >= total_width then return s end
	return s .. string_rep(char, total_width - slen)
end

string.padr = string_padr
string.padR = string_padr
string.PadR = string_padr

local function string_pad_center(self, total_width, char)
	char = char or " "
	local s = tostring(self or "")
	local slen = #s
	if slen >= total_width then return s end
	local total_pad = total_width - slen
	local left_pad = math_floor(total_pad * 0.5)
	return string_rep(char, left_pad) .. s .. string_rep(char, total_pad - left_pad)
end

string.pad_center = string_pad_center
string.padcenter = string_pad_center
string.PadCenter = string_pad_center

do
	local PATTERN_SAFE_ESCAPE_REPLACEMENTS = {
		["\0"] = "%z", -- NOTE: using %z instead of \\0, in case the next char is a digit, which would fu** up a Lua string
		["$"] = "%$",
		["%"] = "%%",
		["("] = "%(",
		[")"] = "%)",
		["*"] = "%*",
		["+"] = "%+",
		["-"] = "%-",
		["."] = "%.",
		["?"] = "%?",
		["["] = "%[",
		["]"] = "%]",
		["^"] = "%^",
	}

	local pattern_safe_zero = function(str)
		return (string_gsub(str, ".", PATTERN_SAFE_ESCAPE_REPLACEMENTS))
	end

	string.pattern_safe_zero = pattern_safe_zero
	string.patternSafeZero = pattern_safe_zero
	string.PatternSafeZero = pattern_safe_zero
end

do
	local HTML_ESCAPE_MAP = {
		["&"] = "&amp;",
		["<"] = "&lt;",
		[">"] = "&gt;",
		['"'] = "&quot;",
		["'"] = "&#39;",
		["/"] = "&#x2F;",
	}

	function string.escape_html(str)
		if not str then return "" end
		return (string_gsub(str, "[&<>\"\'/]", HTML_ESCAPE_MAP))
	end

	string.escapeHTML = string.escape_html
	string.EscapeHTML = string.escape_html

	local HTML_UNESCAPE_MAP = {
		["&amp;"] = "&",
		["&lt;"] = "<",
		["&gt;"] = ">",
		["&quot;"] = '"',
		["&#39;"] = "'",
		["&#x27;"] = "'",
		["&#x2F;"] = "/",
		["&#47;"] = "/",
		["&apos;"] = "'",
		["&nbsp;"] = " ",
	}

	if has_utf8 then
		local utf8_char = utf8.char

		function string.unescape_html(str)
			if not str then return "" end
			-- Named entities
			str = string_gsub(str, "&(%w+);", function(name)
				return HTML_UNESCAPE_MAP["&" .. name .. ";"] or ("&" .. name .. ";")
			end)
			-- Decimal numeric entities
			str = string_gsub(str, "&#(%d+);", function(num)
				local cp = tonumber(num)
				if cp and cp >= 0 and cp <= 0x10FFFF then
					return utf8_char(cp)
				end
				return "&#" .. num .. ";"
			end)
			-- Hex numeric entities
			str = string_gsub(str, "&#x(%x+);", function(hex)
				local cp = tonumber(hex, 16)
				if cp and cp >= 0 and cp <= 0x10FFFF then
					return utf8_char(cp)
				end
				return "&#x" .. hex .. ";"
			end)
			return str
		end
	else
		function string.unescape_html(str)
			if not str then return "" end
			-- Named entities
			str = string_gsub(str, "&(%w+);", function(name)
				return HTML_UNESCAPE_MAP["&" .. name .. ";"] or ("&" .. name .. ";")
			end)
			-- Decimal numeric entities
			str = string_gsub(str, "&#(%d+);", function(num)
				local cp = tonumber(num)
				if cp and cp >= 0 and cp <= 0xFF then
					return string_char(cp)
				end
				return "&#" .. num .. ";"
			end)
			-- Hex numeric entities
			str = string_gsub(str, "&#x(%x+);", function(hex)
				local cp = tonumber(hex, 16)
				if cp and cp >= 0 and cp <= 0xFF then
					return string_char(cp)
				end
				return "&#x" .. hex .. ";"
			end)
			return str
		end
	end
	string.unescapeHTML = string.unescape_html
	string.UnescapeHTML = string.unescape_html
end

local string_trim
do
	local SAFE_PATTERN = "([%^%$%(%)%%%.%[%]%*%+%-%?])" -- NOTE: This version does not handle NUL
	local SAFE_PATTERN_ESCAPE = "%%%1"

	local pattern_safe = function(str)
		return (string_gsub(str, SAFE_PATTERN, SAFE_PATTERN_ESCAPE))
	end

	string.pattern_safe = pattern_safe
	string.patternSafe = pattern_safe
	string.PatternSafe = pattern_safe

	string_trim = function(self, char)
		char = char and string_gsub(char, SAFE_PATTERN, SAFE_PATTERN_ESCAPE) or "%s"
		return (string_match(self, "^" .. char .. "*(.-)" .. char .. "*$")) or self
	end

	string.trim = string_trim
	string.Trim = string_trim

	local string_trim_left = function(self, char)
		char = char and string_gsub(char, SAFE_PATTERN, SAFE_PATTERN_ESCAPE) or "%s"
		return (string_match(self, "^" .. char .. "*(.+)$")) or self
	end

	string.trim_left = string_trim_left
	string.trimleft = string_trim_left
	string.TrimLeft = string_trim_left

	local string_trim_right = function(self, char)
		char = char and string_gsub(char, SAFE_PATTERN, SAFE_PATTERN_ESCAPE) or "%s"
		return (string_match(self, "^(.-)" .. char .. "*$")) or self
	end

	string.trim_right = string_trim_right
	string.trimright = string_trim_right
	string.TrimRight = string_trim_right
end

local string_rotate_left = function(self, amount)
	amount = tonumber(amount) or 0
	if amount <= 0 then return self end
	if amount >= #self then return self end
	return string_sub(self, amount + 1) .. string_sub(self, 1, amount)
end

string.rotate_left = string_rotate_left
string.rotateleft = string_rotate_left
string.RotateLeft = string_rotate_left

local string_rotate_right = function(self, amount)
	amount = tonumber(amount) or 0
	if amount <= 0 then return self end
	if amount >= #self then return self end
	return string_rotate_left(self, #self - amount)
end

string.rotate_right = string_rotate_right
string.rotateright = string_rotate_right
string.RotateRight = string_rotate_right

local string_rotate = function(self, rotation)
	rotation = tonumber(rotation) or 0
	if rotation < 0 then
		return string_rotate_left(self, -rotation)
	end
	return string_rotate_right(self, rotation)
end

string.rotate = string_rotate
string.Rotate = string_rotate

local string_contains = function(self, substring)
	return string_find(self, substring, 1, true) ~= nil
end

string.contains = string_contains
string.Contains = string_contains

local string_index_of = function(self, substring)
	return (string_find(self, substring, 1, true))
end

string.index_of = string_index_of
string.indexof = string_index_of
string.IndexOf = string_index_of

local string_last_index_of = function(self, substring)
	local last_pos
	local current_pos = 1

	repeat
		local pos = string_find(self, substring, current_pos, true)
		if pos then
			last_pos = pos
			current_pos = pos + 1
		end
	until not pos

	return last_pos
end

string.last_index_of = string_last_index_of
string.lastindexof = string_last_index_of
string.LastIndexOf = string_last_index_of

if has_utf8 then
	local utf8_codes = utf8.codes
	local utf8_char = utf8.char

	function string.reverse(self)
		if type(self) ~= "string" then self = tostring(self or "") end
		local result = {}
		for cp in utf8_codes(self) do
			result[#result + 1] = utf8_char(cp)
		end
		-- Reverse the array
		for i = 1, math_floor(#result / 2) do
			result[i], result[#result - i + 1] = result[#result - i + 1], result[i]
		end
		return table_concat(result)
	end
else
	function string.reverse(self)
		if type(self) ~= "string" then self = tostring(self or "") end
		local len = #self
		local result = {}
		for i = len, 1, -1 do
			result[#result + 1] = string_sub(self, i, i)
		end
		return table_concat(result)
	end
end

string.Reverse = string.reverse

local string_random = function(length, min, max)
	length = tonumber(length) or 1
	min = tonumber(min) or 0
	max = tonumber(max) or 255
	if length <= 0 then return "" end
	local result = {}
	for i = 1, length do
		result[i] = string_char(math_random(min, max))
	end
	return table_concat(result)
end

string.random = string_random
string.Random = string_random
string.RandomString = string_random

do
	local function string_split_path(key)
		local parts = {}
		for part in string_gmatch(key, "[^%.]+") do
			parts[#parts + 1] = part
		end
		return parts
	end

	string.split_path = string_split_path
	string.SplitPath = string_split_path

	-- Path separator constants
	local PATH_SEPARATOR_WINDOWS = "\\"
	local PATH_SEPARATOR_UNIX = "/"
	local CURRENT_DIR = "."
	local PARENT_DIR = ".."

	local string_normalize_path_separators = function(self, separator)
		separator = separator or PATH_SEPARATOR_UNIX
		if separator ~= PATH_SEPARATOR_WINDOWS and separator ~= PATH_SEPARATOR_UNIX then
			separator = PATH_SEPARATOR_UNIX
		end
		-- Replace both types of separators with the target
		return (string_gsub((string_gsub(self, PATH_SEPARATOR_WINDOWS, separator)), PATH_SEPARATOR_UNIX, separator))
	end

	string.normalize_path_separators = string_normalize_path_separators
	string.normalizePathSeparators = string_normalize_path_separators
	string.NormalizePathSeparators = string_normalize_path_separators

	local string_to_unix_path = function(self)
		return string_normalize_path_separators(self, PATH_SEPARATOR_UNIX)
	end

	string.to_unix_path = string_to_unix_path
	string.toUnixPath = string_to_unix_path
	string.ToUnixPath = string_to_unix_path

	local string_to_windows_path = function(self)
		return string_normalize_path_separators(self, PATH_SEPARATOR_WINDOWS)
	end

	string.to_windows_path = string_to_windows_path
	string.toWindowsPath = string_to_windows_path
	string.ToWindowsPath = string_to_windows_path

	local string_normalize_path = function(self, separator)
		separator = separator or PATH_SEPARATOR_UNIX
		if separator ~= PATH_SEPARATOR_WINDOWS and separator ~= PATH_SEPARATOR_UNIX then
			separator = PATH_SEPARATOR_UNIX
		end

		-- First normalize all separators to a common format
		local path = string_normalize_path_separators(self, PATH_SEPARATOR_UNIX)

		-- Split path into components
		local components = {}
		local start_absolute --= false

		-- Handle absolute paths
		if string_sub(path, 1, 1) == PATH_SEPARATOR_UNIX then
			start_absolute = true
			path = string_sub(path, 2)
		end

		-- Split by separator
		for component in string_gmatch(path, "([^" .. PATH_SEPARATOR_UNIX .. "]+)") do
			if component == PARENT_DIR then
				-- Remove the previous component if possible
				if #components > 0 and components[#components] ~= PARENT_DIR then
					components[#components] = nil
				elseif not start_absolute then
					-- Keep leading .. for relative paths
					components[#components + 1] = component
				end
			elseif component ~= CURRENT_DIR then
				-- Add non-current directory components
				components[#components + 1] = component
			end
		end

		-- Reconstruct the path
		local result = ""
		if start_absolute then
			result = PATH_SEPARATOR_UNIX
		end

		if #components > 0 then
			result = result .. table_concat(components, PATH_SEPARATOR_UNIX)
		elseif start_absolute then
			-- Root path
			result = PATH_SEPARATOR_UNIX
		else
			-- Empty relative path
			result = CURRENT_DIR
		end

		-- Convert to requested separator format
		if separator ~= PATH_SEPARATOR_UNIX then
			result = string_gsub(result, PATH_SEPARATOR_UNIX, separator)
		end

		return result
	end

	string.normalize_path = string_normalize_path
	string.normalizePath = string_normalize_path
	string.NormalizePath = string_normalize_path

	local string_path_dir = function(self)
		-- Normalize separators first
		local path = string_to_unix_path(self)

		-- Find the last separator
		local last_sep = string_find(path, PATH_SEPARATOR_UNIX, -1, true)
		if last_sep then
			return string_sub(path, 1, last_sep - 1)
		end
		return ""
	end

	string.path_dir = string_path_dir
	string.pathDir = string_path_dir
	string.dirname = string_path_dir
	string.PathDir = string_path_dir
	string.DirName = string_path_dir

	local string_path_file = function(self)
		-- Normalize separators first
		local path = string_to_unix_path(self)

		-- Find the last separator
		local last_sep = string_find(path, PATH_SEPARATOR_UNIX, -1, true)
		if last_sep then
			return string_sub(path, last_sep + 1)
		end
		return path
	end

	string.path_file = string_path_file
	string.pathFile = string_path_file
	string.basename = string_path_file
	string.PathFile = string_path_file
	string.BaseName = string_path_file

	local string_path_ext = function(self)
		local filename = string_path_file(self)

		-- Find the last dot
		local last_dot = string_find(filename, ".", -1, true)
		if last_dot and last_dot > 1 then
			return string_sub(filename, last_dot + 1)
		end
		return ""
	end

	string.path_ext = string_path_ext
	string.pathExt = string_path_ext
	string.extension = string_path_ext
	string.PathExt = string_path_ext
	string.Extension = string_path_ext

	local string_path_name = function(self)
		local filename = string_path_file(self)

		-- Find the last dot
		local last_dot = string_find(filename, ".", -1, true)
		if last_dot and last_dot > 1 then
			return string_sub(filename, 1, last_dot - 1)
		end
		return filename
	end

	string.path_name = string_path_name
	string.pathName = string_path_name
	string.name_without_ext = string_path_name
	string.PathName = string_path_name
	string.NameWithoutExt = string_path_name

	local string_path_join = function(...)
		local components = {}
		for i = 1, select("#", ...) do
			local component = tostring(select(i, ...))
			if component and component ~= "" then
				components[#components + 1] = component
			end
		end

		if #components == 0 then
			return ""
		end

		-- Join with forward slash first
		local path = table_concat(components, PATH_SEPARATOR_UNIX)

		-- Normalize the result
		return string_normalize_path(path, PATH_SEPARATOR_UNIX)
	end

	string.path_join = string_path_join
	string.pathJoin = string_path_join
	string.PathJoin = string_path_join

	local string_is_absolute_path = function(self)
		if type(self) ~= "string" or #self == 0 then
			return false
		end

		-- Check for Unix-style absolute path
		if string_sub(self, 1, 1) == PATH_SEPARATOR_UNIX then
			return true
		end

		-- Check for Windows drive letter (e.g., "C:")
		if #self >= 2 and string_match(self, "^[%a%A]:") then
			return true
		end

		return false
	end

	string.is_absolute_path = string_is_absolute_path
	string.isAbsolutePath = string_is_absolute_path
	string.IsAbsolutePath = string_is_absolute_path

	local string_to_absolute_path = function(self, base_path)
		base_path = base_path or CURRENT_DIR

		-- If self is already absolute, just normalize it
		if string_is_absolute_path(self) then
			return string_normalize_path(self)
		end

		-- Join base path with relative path and normalize
		return string_normalize_path(base_path .. PATH_SEPARATOR_UNIX .. self)
	end

	string.to_absolute_path = string_to_absolute_path
	string.toAbsolutePath = string_to_absolute_path
	string.ToAbsolutePath = string_to_absolute_path

	local string_is_relative_path = function(self)
		if type(self) ~= "string" or #self == 0 then
			return false
		end
		return not string_is_absolute_path(self)
	end

	string.is_relative_path = string_is_relative_path
	string.isRelativePath = string_is_relative_path
	string.IsRelativePath = string_is_relative_path

	local string_path_relative = function(self, base_path)
		if type(self) ~= "string" or #self == 0 then return self end
		if type(base_path) ~= "string" or #base_path == 0 then return self end

		-- Normalize both paths
		local target = string_normalize_path(string_to_unix_path(self))
		local base = string_normalize_path(string_to_unix_path(base_path))

		-- If target is absolute but base is relative, return target normalized
		if string_is_absolute_path(target) and not string_is_absolute_path(base) then
			return target
		end

		-- If both are relative, return target normalized
		if not string_is_absolute_path(target) and not string_is_absolute_path(base) then
			return target
		end

		-- Split both paths into components
		local target_parts = {}
		for part in string_gmatch(target, "([^/]+)") do
			target_parts[#target_parts + 1] = part
		end

		local base_parts = {}
		for part in string_gmatch(base, "([^/]+)") do
			base_parts[#base_parts + 1] = part
		end

		-- Find common prefix
		local common_len = 0
		local min_len = math_floor(math_min(#target_parts, #base_parts))
		for i = 1, min_len do
			if target_parts[i] == base_parts[i] then
				common_len = i
			else
				break
			end
		end

		-- Build relative path
		local result = {}

		-- Add .. for remaining base parts
		for i = common_len + 1, #base_parts do
			result[#result + 1] = PARENT_DIR
		end

		-- Add remaining target parts
		for i = common_len + 1, #target_parts do
			result[#result + 1] = target_parts[i]
		end

		if #result == 0 then
			return CURRENT_DIR
		end

		return table_concat(result, PATH_SEPARATOR_UNIX)
	end

	string.path_relative = string_path_relative
	string.pathRelative = string_path_relative
	string.PathRelative = string_path_relative

	local string_path_split = function(self)
		local path = string_normalize_path(string_to_unix_path(self))
		local dir = string_path_dir(path)
		local file = string_path_file(path)
		return dir, file
	end

	string.path_split = string_path_split
	string.pathSplit = string_path_split
	string.PathSplit = string_path_split

	local string_path_split_ext = function(self)
		local filename = string_path_file(self)
		local name = string_path_name(filename)
		local ext = string_path_ext(filename)
		return name, ext
	end

	string.path_split_ext = string_path_split_ext
	string.pathSplitExt = string_path_split_ext
	string.PathSplitExt = string_path_split_ext

	local string_path_has_extension = function(self)
		local ext = string_path_ext(self)
		return ext ~= ""
	end

	string.path_has_extension = string_path_has_extension
	string.pathHasExtension = string_path_has_extension
	string.PathHasExtension = string_path_has_extension

	local string_path_change_extension = function(self, new_ext)
		local dir = string_path_dir(self)
		local name = string_path_name(self)

		-- Add dot if not present
		if new_ext and #new_ext > 0 and string_sub(new_ext, 1, 1) ~= "." then
			new_ext = "." .. new_ext
		end

		if dir and #dir > 0 then
			return dir .. PATH_SEPARATOR_UNIX .. name .. (new_ext or "")
		end
		return name .. (new_ext or "")
	end

	string.path_change_extension = string_path_change_extension
	string.pathChangeExtension = string_path_change_extension
	string.PathChangeExtension = string_path_change_extension

	local string_path_add_extension = function(self, ext)
		if string_path_has_extension(self) then
			return self
		end
		return string_path_change_extension(self, ext)
	end

	string.path_add_extension = string_path_add_extension
	string.pathAddExtension = string_path_add_extension
	string.PathAddExtension = string_path_add_extension

	local string_path_remove_extension = function(self)
		return string_path_change_extension(self, "")
	end

	string.path_remove_extension = string_path_remove_extension
	string.pathRemoveExtension = string_path_remove_extension
	string.PathRemoveExtension = string_path_remove_extension

	local string_path_common_prefix = function(self, other)
		if type(self) ~= "string" or #self == 0 then return "" end
		if type(other) ~= "string" or #other == 0 then return "" end

		local path1 = string_normalize_path(string_to_unix_path(self))
		local path2 = string_normalize_path(string_to_unix_path(other))

		local parts1 = {}
		for part in string_gmatch(path1, "([^/]+)") do
			parts1[#parts1 + 1] = part
		end

		local parts2 = {}
		for part in string_gmatch(path2, "([^/]+)") do
			parts2[#parts2 + 1] = part
		end

		local common = {}
		local min_len = math_floor(math_min(#parts1, #parts2))
		for i = 1, min_len do
			if parts1[i] == parts2[i] then
				common[#common + 1] = parts1[i]
			else
				break
			end
		end

		if #common == 0 then
			return ""
		end

		return table_concat(common, PATH_SEPARATOR_UNIX)
	end

	string.path_common_prefix = string_path_common_prefix
	string.pathCommonPrefix = string_path_common_prefix
	string.PathCommonPrefix = string_path_common_prefix

	local string_path_components = function(self)
		local path = string_normalize_path(string_to_unix_path(self))
		local components = {}
		for part in string_gmatch(path, "([^/]+)") do
			components[#components + 1] = part
		end
		return components
	end

	string.path_components = string_path_components
	string.pathComponents = string_path_components
	string.PathComponents = string_path_components

	local string_path_from_components = function(components, separator)
		separator = separator or PATH_SEPARATOR_UNIX
		if type(components) ~= "table" then return "" end
		return table_concat(components, separator)
	end

	string.path_from_components = string_path_from_components
	string.pathFromComponents = string_path_from_components
	string.PathFromComponents = string_path_from_components

	local string_path_trim_trailing_separator = function(self, separator)
		separator = separator or PATH_SEPARATOR_UNIX
		local path = self
		while #path > 0 and string_sub(path, -1) == separator do
			path = string_sub(path, 1, -2)
		end
		return path
	end

	string.path_trim_trailing_separator = string_path_trim_trailing_separator
	string.pathTrimTrailingSeparator = string_path_trim_trailing_separator
	string.PathTrimTrailingSeparator = string_path_trim_trailing_separator

	local string_path_has_trailing_separator = function(self, separator)
		separator = separator or PATH_SEPARATOR_UNIX
		return #self > 0 and string_sub(self, -1) == separator
	end

	string.path_has_trailing_separator = string_path_has_trailing_separator
	string.pathHasTrailingSeparator = string_path_has_trailing_separator
	string.PathHasTrailingSeparator = string_path_has_trailing_separator

	local string_path_trim_leading_separator = function(self, separator)
		separator = separator or PATH_SEPARATOR_UNIX
		local path = self
		while #path > 0 and string_sub(path, 1, 1) == separator do
			path = string_sub(path, 2)
		end
		return path
	end

	string.path_trim_leading_separator = string_path_trim_leading_separator
	string.pathTrimLeadingSeparator = string_path_trim_leading_separator
	string.PathTrimLeadingSeparator = string_path_trim_leading_separator

	local string_path_has_leading_separator = function(self, separator)
		separator = separator or PATH_SEPARATOR_UNIX
		return #self > 0 and string_sub(self, 1, 1) == separator
	end

	string.path_has_leading_separator = string_path_has_leading_separator
	string.pathHasLeadingSeparator = string_path_has_leading_separator
	string.PathHasLeadingSeparator = string_path_has_leading_separator

	local string_path_is_same = function(self, other)
		if type(self) ~= "string" or type(other) ~= "string" then
			return false
		end
		local p1 = string_normalize_path(string_to_unix_path(self))
		local p2 = string_normalize_path(string_to_unix_path(other))
		return p1 == p2
	end

	string.path_is_same = string_path_is_same
	string.pathIsSame = string_path_is_same
	string.PathIsSame = string_path_is_same

	local string_path_get_drive = function(self)
		if #self >= 2 and string_match(self, "^[%a%A]:") then
			return string_sub(self, 1, 2)
		end
		return ""
	end

	string.path_get_drive = string_path_get_drive
	string.pathGetDrive = string_path_get_drive
	string.PathGetDrive = string_path_get_drive

	local string_path_without_drive = function(self)
		local drive = string_path_get_drive(self)
		if #drive > 0 then
			return string_sub(self, 3)
		end
		return self
	end

	string.path_without_drive = string_path_without_drive
	string.pathWithoutDrive = string_path_without_drive
	string.PathWithoutDrive = string_path_without_drive

	local string_path_get_root = function(self)
		local path = string_to_unix_path(self)

		-- Unix root
		if string_sub(path, 1, 1) == PATH_SEPARATOR_UNIX then
			return PATH_SEPARATOR_UNIX
		end

		-- Windows drive root
		local drive = string_path_get_drive(self)
		if #drive > 0 then
			return drive .. PATH_SEPARATOR_WINDOWS
		end

		return ""
	end

	string.path_get_root = string_path_get_root
	string.pathGetRoot = string_path_get_root
	string.PathGetRoot = string_path_get_root

	local string_path_is_root = function(self)
		local root = string_path_get_root(self)
		local normalized = string_normalize_path(string_to_unix_path(self))
		return normalized == root or normalized == string_to_unix_path(root)
	end

	string.path_is_root = string_path_is_root
	string.pathIsRoot = string_path_is_root
	string.PathIsRoot = string_path_is_root

	local string_path_ancestor = function(self, potential_ancestor)
		if type(self) ~= "string" or type(potential_ancestor) ~= "string" then
			return false
		end

		local path = string_normalize_path(string_to_unix_path(self))
		local ancestor = string_normalize_path(string_to_unix_path(potential_ancestor))

		-- Ancestor must be a prefix
		if #ancestor >= #path then
			return path == ancestor
		end

		-- Check if ancestor is a prefix and ends with separator or path continues
		local prefix = string_sub(path, 1, #ancestor)
		if prefix ~= ancestor then
			return false
		end

		-- If ancestor doesn't end with separator, the next char in path must be separator
		if string_sub(ancestor, -1) ~= PATH_SEPARATOR_UNIX then
			return string_sub(path, #ancestor + 1, #ancestor + 1) == PATH_SEPARATOR_UNIX
		end

		return true
	end

	string.path_ancestor = string_path_ancestor
	string.pathAncestor = string_path_ancestor
	string.PathAncestor = string_path_ancestor

	local string_path_clean = function(self)
		-- Replace backslashes with forward slashes
		local path = string_gsub(self, "\\", "/")
		-- Collapse multiple slashes into one
		path = string_gsub(path, "/+", "/")
		-- Remove trailing slash unless it's the root
		if #path > 1 then
			path = string_gsub(path, "/$", "")
		end
		return path
	end

	string.path_clean = string_path_clean
	string.pathClean = string_path_clean
	string.PathClean = string_path_clean

	local string_path_parent = function(self)
		local path = string_normalize_path(string_to_unix_path(self))
		local dir = string_path_dir(path)
		if #dir == 0 then
			return CURRENT_DIR
		end
		return dir
	end

	string.path_parent = string_path_parent
	string.pathParent = string_path_parent
	string.PathParent = string_path_parent

	local string_path_has_parent = function(self)
		local path = string_normalize_path(string_to_unix_path(self))
		local dir = string_path_dir(path)
		return #dir > 0 and dir ~= CURRENT_DIR
	end

	string.path_has_parent = string_path_has_parent
	string.pathHasParent = string_path_has_parent
	string.PathHasParent = string_path_has_parent

	local string_path_depth = function(self)
		local path = string_normalize_path(string_to_unix_path(self))
		local components = string_path_components(path)
		return #components
	end

	string.path_depth = string_path_depth
	string.pathDepth = string_path_depth
	string.PathDepth = string_path_depth

	local string_path_is_child = function(self, parent)
		if type(self) ~= "string" or type(parent) ~= "string" then
			return false
		end
		return string_path_ancestor(parent, self)
	end

	string.path_is_child = string_path_is_child
	string.pathIsChild = string_path_is_child
	string.PathIsChild = string_path_is_child

	local string_path_sanitize = function(self)
		-- Remove invalid characters for filesystem paths (Windows/Unix)
		-- Invalid on Windows: <>:"/\|?* and control chars
		-- Invalid on Unix: / and null
		local result = self
		-- Remove control characters (0-31)
		result = string_gsub(result, "[%c]+", "")
		-- Remove Windows-invalid characters: <>:"|?*
		result = string_gsub(result, '[<>:"|?*]', "")
		-- Replace multiple spaces with single space
		result = string_gsub(result, "%s+", " ")
		-- Trim leading/trailing spaces
		result = string_trim(result)
		return result
	end

	string.path_sanitize = string_path_sanitize
	string.pathSanitize = string_path_sanitize
	string.PathSanitize = string_path_sanitize

	local string_path_make_absolute = function(self, base_path)
		return string_to_absolute_path(self, base_path)
	end

	string.path_make_absolute = string_path_make_absolute
	string.pathMakeAbsolute = string_path_make_absolute
	string.PathMakeAbsolute = string_path_make_absolute

	local string_path_make_relative = function(self, base_path)
		return string_path_relative(self, base_path)
	end

	string.path_make_relative = string_path_make_relative
	string.pathMakeRelative = string_path_make_relative
	string.PathMakeRelative = string_path_make_relative
end

local function string_detect_casing_style(self)
	if type(self) ~= "string" or #self == 0 then
		return "unknown"
	end

	local has_underscore = string_find(self, "_", 1, true) ~= nil
	local has_hyphen = string_find(self, "-", 1, true) ~= nil
	local has_space = string_find(self, " ", 1, true) ~= nil
	local first_char = string_sub(self, 1, 1)
	local is_first_upper = first_char == string_upper(first_char) and first_char ~= string_lower(first_char)
	local is_first_lower = first_char == string_lower(first_char) and first_char ~= string_upper(first_char)
	local is_all_upper = self == string_upper(self)
	local is_all_lower = self == string_lower(self)

	-- Check for SCREAMING_SNAKE_CASE (all uppercase with underscores)
	if has_underscore and is_all_upper then
		return "SCREAMING_SNAKE_CASE"
	end

	-- Check for snake_case (has underscores, not all uppercase)
	if has_underscore then
		return "snake_case"
	end

	-- Check for kebab-case (has hyphens)
	if has_hyphen then
		return "kebab-case"
	end

	-- Check for space case (has spaces)
	if has_space then
		if is_all_upper then
			return "UPPER_SPACE_CASE"
		end
		return "space_case"
	end

	-- Check for all uppercase without separators
	if is_all_upper and not is_first_lower then
		return "UPPERCASE"
	end

	-- Check for all lowercase without separators
	if is_all_lower then
		return "lowercase"
	end

	-- Check for PascalCase (first letter uppercase, no separators, mixed case)
	if is_first_upper and not has_underscore and not has_hyphen and not has_space then
		return "PascalCase"
	end

	-- Check for camelCase (first letter lowercase, no separators, mixed case)
	if is_first_lower and not has_underscore and not has_hyphen and not has_space then
		return "camelCase"
	end

	return "unknown"
end

string.detect_casing_style = string_detect_casing_style
string.detectCasingStyle = string_detect_casing_style
string.DetectCasingStyle = string_detect_casing_style

local string_to_snake_case = function(self)
	if type(self) ~= "string" then self = tostring(self or "") end

	-- Replace hyphens and spaces with underscores
	local result = string_gsub(self, "[-%s]+", "_")

	-- Insert underscores before uppercase letters (camelCase/PascalCase conversion)
	result = string_gsub(result, "(%l)(%u)", "%1_%2")

	-- Convert multiple underscores to single underscore
	result = string_gsub(result, "_+", "_")

	-- Convert to lowercase
	result = string_gsub(result, "(%u+)", function(upper)
		return (string_gsub(string_lower(upper), "_", ""))
	end)

	-- Remove leading/trailing underscores
	result = string_trim(result, "_")

	return result
end

string.to_snake_case = string_to_snake_case
string.toSnakeCase = string_to_snake_case
string.ToSnakeCase = string_to_snake_case

local string_to_camel_case = function(self)
	if type(self) ~= "string" then self = tostring(self or "") end

	-- Replace hyphens and underscores with spaces
	local result = string_gsub(self, "[-_]+", " ")

	-- Convert to lowercase and capitalize words after the first
	result = string_gsub(result, "(%S+)", function(word, pos)
		return pos == 1 and string_lower(word) or (string_gsub(word, "^%l", string_upper))
	end)

	-- Remove spaces
	result = string_gsub(result, "%s+", "")

	return result
end

string.to_camel_case = string_to_camel_case
string.toCamelCase = string_to_camel_case
string.ToCamelCase = string_to_camel_case

local string_to_pascal_case = function(self)
	if type(self) ~= "string" then self = tostring(self or "") end

	-- Replace hyphens and underscores with spaces
	local result = string_gsub(self, "[-_]+", " ")

	-- Capitalize first letter of each word
	result = string_gsub(result, "(%S+)", function(word)
		return (string_gsub(word, "^%l", string_upper))
	end)

	-- Remove spaces
	result = string_gsub(result, "%s+", "")

	return result
end

string.to_pascal_case = string_to_pascal_case
string.toPascalCase = string_to_pascal_case
string.ToPascalCase = string_to_pascal_case

local function resolve_absolute_range(len, start_index, end_index) -- TODO/FIXME: alias of util.resolve_absolute_range
	-- Default range is the entire string
	start_index = tonumber(start_index) or 1
	end_index = tonumber(end_index) or len

	-- Handle negative indices (count from end)
	if start_index < 0 then
		start_index = len + start_index + 1
	elseif start_index == 0 then
		start_index = 1
	end

	if end_index < 0 then
		end_index = len + end_index + 1
	elseif end_index == 0 then
		end_index = 1
	end

	-- Clamp indices to valid range
	if start_index < 1 then start_index = 1 end
	if end_index > len then end_index = len end

	return start_index, end_index, start_index > end_index
end

string.resolve_absolute_range = resolve_absolute_range
string.resolveAbsoluteRange = resolve_absolute_range
string.ResolveAbsoluteRange = resolve_absolute_range

local function string_is_printable(self, start_index, end_index)
	if type(self) ~= "string" then return false end

	local len = #self
	if len == 0 then return true end

	start_index, end_index = resolve_absolute_range(len, start_index, end_index)

	-- Empty range is considered printable
	if start_index > end_index then return true end

	-- Check each character in the range
	for i = start_index, end_index do
		local b = string_byte(self, i)
		if b < 32 or b > 126 then
			return false
		end
	end

	return true
end

string.is_printable = string_is_printable
string.isPrintable = string_is_printable
string.IsPrintable = string_is_printable

local function string_url_encode(self)
	if type(self) ~= "string" then self = tostring(self or "") end

	local result = {}
	for i = 1, #self do
		local byte = string_byte(self, i)
		-- Encode characters that are not unreserved (A-Z, a-z, 0-9, hyphen, period, underscore, tilde)
		if (byte >= 48 and byte <= 57) or (byte >= 65 and byte <= 90) or (byte >= 97 and byte <= 122) or byte == 45 or byte == 46 or byte == 95 or byte == 126 then
			result[#result + 1] = string_sub(self, i, i)
		else
			result[#result + 1] = string_format("%%%02X", byte)
		end
	end
	return table_concat(result)
end

string.url_encode = string_url_encode
string.urlEncode = string_url_encode
string.UrlEncode = string_url_encode

local function string_url_decode(self)
	if type(self) ~= "string" then self = tostring(self or "") end

	local result = {}
	local i = 1
	while i <= #self do
		local char = string_sub(self, i, i)
		if char == "%" and i + 2 <= #self then
			local hex = string_sub(self, i + 1, i + 2)
			local byte = tonumber(hex, 16)
			if byte then
				result[#result + 1] = string_char(byte)
				i = i + 3
			else
				result[#result + 1] = char
				i = i + 1
			end
		elseif char == "+" then
			result[#result + 1] = " "
			i = i + 1
		else
			result[#result + 1] = char
			i = i + 1
		end
	end
	return table_concat(result)
end

string.url_decode = string_url_decode
string.urlDecode = string_url_decode
string.UrlDecode = string_url_decode

local function string_parse_query(self)
	if type(self) ~= "string" then self = tostring(self or "") end

	local result = {}
	if #self == 0 then return result end

	for pair in string_gmatch(self, "([^&=]+)=?([^&]*)") do
		local key, value = string_match(pair, "^([^=]*)=(.*)$")
		if key then
			key = string_url_decode(key)
			value = value ~= "" and string_url_decode(value) or ""
			if result[key] then
				if type(result[key]) == "table" then
					result[key][#result[key] + 1] = value
				else
					result[key] = { result[key], value }
				end
			else
				result[key] = value
			end
		end
	end

	return result
end

string.parse_query = string_parse_query
string.parseQuery = string_parse_query
string.ParseQuery = string_parse_query

local function string_build_query(tbl, sep)
	if type(tbl) ~= "table" then return "" end
	sep = sep or "&"

	local result = {}
	local function add_pair(key, value)
		local encoded_key = string_url_encode(tostring(key))
		if type(value) == "table" then
			for _, v in next, value do
				result[#result + 1] = encoded_key .. "=" .. string_url_encode(tostring(v))
			end
		else
			result[#result + 1] = encoded_key .. "=" .. string_url_encode(tostring(value))
		end
	end

	for key, value in next, tbl do
		add_pair(key, value)
	end

	return table_concat(result, sep)
end

string.build_query = string_build_query
string.buildQuery = string_build_query
string.BuildQuery = string_build_query

local function string_parse_url(self)
	if type(self) ~= "string" then self = tostring(self or "") end

	local result = {
		scheme = "",
		username = "",
		password = "",
		host = "",
		port = "",
		path = "",
		query = "",
		fragment = "",
		authority = "",
	}

	if #self == 0 then return result end

	-- Extract fragment
	local fragment_start = string_find(self, "#", 1, true)
	if fragment_start then
		result.fragment = string_sub(self, fragment_start + 1)
		self = string_sub(self, 1, fragment_start - 1)
	end

	-- Extract query
	local query_start = string_find(self, "?", 1, true)
	if query_start then
		result.query = string_sub(self, query_start + 1)
		self = string_sub(self, 1, query_start - 1)
	end

	-- Extract scheme
	local scheme_end = string_find(self, "://", 1, true)
	if scheme_end then
		result.scheme = string_sub(self, 1, scheme_end - 1)
		self = string_sub(self, scheme_end + 3)
	end

	-- Extract authority (everything before first / after scheme)
	local path_start = string_find(self, "/", 1, true)
	if not path_start and #self > 0 then
		-- No path, entire string is authority
		result.authority = self
		self = ""
	elseif path_start then
		result.authority = string_sub(self, 1, path_start - 1)
		result.path = string_sub(self, path_start)
		self = ""
	end

	-- Parse authority
	if #result.authority > 0 then
		local auth = result.authority

		-- Extract userinfo (username:password@)
		local userinfo_end = string_find(auth, "@", 1, true)
		if userinfo_end then
			local userinfo = string_sub(auth, 1, userinfo_end - 1)
			auth = string_sub(auth, userinfo_end + 1)

			-- Split username and password
			local pass_start = string_find(userinfo, ":", 1, true)
			if pass_start then
				result.username = string_sub(userinfo, 1, pass_start - 1)
				result.password = string_sub(userinfo, pass_start + 1)
			else
				result.username = userinfo
			end
		end

		-- Extract port
		local port_start = string_find(auth, ":", 1, true)
		if port_start then
			result.host = string_sub(auth, 1, port_start - 1)
			result.port = string_sub(auth, port_start + 1)
		else
			result.host = auth
		end
	end

	-- Default path to "/" if empty and scheme is present
	if #result.path == 0 and #result.scheme > 0 then
		result.path = "/"
	end

	return result
end

string.parse_url = string_parse_url
string.parseUrl = string_parse_url
string.ParseUrl = string_parse_url

local function string_url_scheme(self)
	local parsed = string_parse_url(self)
	return parsed.scheme
end

string.url_scheme = string_url_scheme
string.urlScheme = string_url_scheme
string.UrlScheme = string_url_scheme

local function string_url_host(self)
	local parsed = string_parse_url(self)
	return parsed.host
end

string.url_host = string_url_host
string.urlHost = string_url_host
string.UrlHost = string_url_host

local function string_url_port(self)
	local parsed = string_parse_url(self)
	return parsed.port
end

string.url_port = string_url_port
string.urlPort = string_url_port
string.UrlPort = string_url_port

local function string_url_path(self)
	local parsed = string_parse_url(self)
	return parsed.path
end

string.url_path = string_url_path
string.urlPath = string_url_path
string.UrlPath = string_url_path

local function string_url_query(self)
	local parsed = string_parse_url(self)
	return parsed.query
end

string.url_query = string_url_query
string.urlQuery = string_url_query
string.UrlQuery = string_url_query

local function string_url_fragment(self)
	local parsed = string_parse_url(self)
	return parsed.fragment
end

string.url_fragment = string_url_fragment
string.urlFragment = string_url_fragment
string.UrlFragment = string_url_fragment

local function string_url_username(self)
	local parsed = string_parse_url(self)
	return parsed.username
end

string.url_username = string_url_username
string.urlUsername = string_url_username
string.UrlUsername = string_url_username

local function string_url_password(self)
	local parsed = string_parse_url(self)
	return parsed.password
end

string.url_password = string_url_password
string.urlPassword = string_url_password
string.UrlPassword = string_url_password

local function string_url_authority(self)
	local parsed = string_parse_url(self)
	return parsed.authority
end

string.url_authority = string_url_authority
string.urlAuthority = string_url_authority
string.UrlAuthority = string_url_authority

local function string_is_absolute_url(self)
	local parsed = string_parse_url(self)
	return #parsed.scheme > 0
end

string.is_absolute_url = string_is_absolute_url
string.isAbsoluteUrl = string_is_absolute_url
string.IsAbsoluteUrl = string_is_absolute_url

local function string_resolve_url(relative, base)
	if type(relative) ~= "string" then relative = tostring(relative or "") end
	if type(base) ~= "string" then base = tostring(base or "") end

	-- If relative URL is absolute, return it
	if string_is_absolute_url(relative) then
		return relative
	end

	-- Parse base URL
	local base_parsed = string_parse_url(base)

	-- If base has no scheme, return relative as-is
	if #base_parsed.scheme == 0 then
		return relative
	end

	-- If relative starts with //, use scheme from base
	if string_sub(relative, 1, 2) == "//" then
		return base_parsed.scheme .. ":" .. relative
	end

	-- If relative starts with /, use scheme and authority from base
	if string_sub(relative, 1, 1) == "/" then
		local has_double_slash = string_sub(relative, 1, 2) == "//"
		if has_double_slash then
			return base_parsed.scheme .. ":" .. relative
		else
			local authority = base_parsed.authority
			if #authority > 0 then
				return base_parsed.scheme .. "://" .. authority .. relative
			else
				return base_parsed.scheme .. ":" .. relative
			end
		end
	end

	-- Merge paths
	local base_path = base_parsed.path
	local relative_path = relative

	-- Remove filename from base path
	local last_slash = string_find(base_path, "/", -1, true)
	if last_slash then
		base_path = string_sub(base_path, 1, last_slash)
	else
		base_path = "/"
	end

	-- Combine paths
	local combined_path = base_path .. relative_path

	-- Normalize path (remove . and ..)
	local path_parts = {}
	for part in string_gmatch(combined_path, "([^/]+)") do
		if part == ".." then
			if #path_parts > 0 then
				path_parts[#path_parts] = nil
			end
		elseif part ~= "." then
			path_parts[#path_parts + 1] = part
		end
	end

	local resolved_path = "/" .. table_concat(path_parts, "/")

	-- Reconstruct URL
	local result = base_parsed.scheme .. "://"
	if #base_parsed.username > 0 then
		result = result .. base_parsed.username
		if #base_parsed.password > 0 then
			result = result .. ":" .. base_parsed.password
		end
		result = result .. "@"
	end
	result = result .. base_parsed.host
	if #base_parsed.port > 0 then
		result = result .. ":" .. base_parsed.port
	end
	result = result .. resolved_path

	return result
end

string.resolve_url = string_resolve_url
string.resolveUrl = string_resolve_url
string.ResolveUrl = string_resolve_url

local function string_split_url(full_url)
	if type(full_url) ~= "string" then full_url = tostring(full_url or "") end

	-- Build base URL from scheme + authority
	local scheme = string_url_scheme(full_url)
	local authority = string_url_authority(full_url)
	local base_url = scheme .. "://" .. authority

	-- Remove trailing slash from base_url (47 is the ASCII code for "/")
	if string_byte(base_url, #base_url) == 47 then
		base_url = string_sub(base_url, 1, -2)
	end

	-- Build endpoint from path + query + fragment
	local path = string_url_path(full_url)
	local query = string_url_query(full_url)
	local fragment = string_url_fragment(full_url)

	local endpoint = path
	if #query > 0 then
		endpoint = endpoint .. "?" .. query
	end
	if #fragment > 0 then
		endpoint = endpoint .. "#" .. fragment
	end

	-- Ensure endpoint starts with "/" (ASCII code 47)
	if #endpoint == 0 or string_byte(endpoint, 1) ~= 47 then
		endpoint = "/" .. endpoint
	end

	return base_url, endpoint
end

string.split_url = string_split_url
string.splitUrl = string_split_url
string.SplitUrl = string_split_url

-- ANSI CSI pattern (simple SGR/CSI matcher)
local ANSI_PATTERN = "\27%[[%d;]*[A-Za-z]"

local string_ulen
-- Visible length ignoring ANSI sequences (character count, UTF-8 aware)
local visible_length
if has_utf8 then
	string_ulen = utf8.len
	function visible_length(s)
		if not s or s == "" then return 0 end
		local clean = (string_gsub(s, ANSI_PATTERN, ""))
		return string_ulen(clean)
	end
else
	string_ulen = string.len or function(s) return #s end
	function visible_length(s)
		if not s or s == "" then return 0 end
		local clean = (string_gsub(s, ANSI_PATTERN, ""))
		return #clean
	end
end

string.ulen = string_ulen
string.visible_length = visible_length
string.visibleLength = visible_length
string.VisibleLength = visible_length

-- UTF-8 safe substring by character indices (1-based inclusive)
local utf8_sub
if has_utf8 then
	local utf8_offset = utf8.offset

	function utf8_sub(s, i, j)
		if not s then return "" end
		i = i or 1
		j = j or -1
		local start_pos = utf8_offset(s, i)
		if not start_pos then return "" end
		local end_pos
		if j == -1 then
			end_pos = #s
		else
			local next_pos = utf8_offset(s, j + 1)
			end_pos = (next_pos and next_pos - 1) or #s
		end
		return string_sub(s, start_pos, end_pos)
	end
else
	function utf8_sub(s, i, j)
		if not s then return "" end
		i = i or 1
		j = j or #s
		return string_sub(s, i, j)
	end
end

string.substring = utf8_sub
string.Substring = utf8_sub

-- Helper: repeat a string to length (visual width)
local function repeat_fill(ch, count)
	if count <= 0 then return "" end
	return string_rep(ch, count)
end

-- Strip ANSI escape sequences from string
local function strip_ansi(s)
	if not s or s == "" then return "" end
	return (string_gsub(s, ANSI_PATTERN, ""))
end

string.strip_ansi = strip_ansi
string.stripAnsi = strip_ansi
string.StripAnsi = strip_ansi

-- Safe tostring that returns empty string for nil
local function safe_tostring(v)
	if v == nil then return "" end
	return tostring(v)
end

string.safe = safe_tostring
string.Safe = safe_tostring

-- Truncate at end with ellipsis
local function string_truncate(s, width, opts)
	opts = opts or {}
	local ell = opts.ellipsis or "..." -- …
	width = tonumber(width) or 0
	if width <= 0 then return "" end
	if string_ulen(s) <= width then return s end
	local ell_len = #ell
	if ell_len >= width then
		return utf8_sub(ell, 1, width)
	end
	local keep = width - ell_len
	local left = string_sub(s, 1, keep)
	return left .. ell
end

string.truncate = string_truncate
string.Truncate = string_truncate

-- Truncate in the middle, keep start and end, insert ellipsis
local function string_truncate_middle(s, width, opts)
	opts = opts or {}
	local ell = opts.ellipsis or "..." -- …
	width = tonumber(width) or 0
	if width <= 0 then return "" end
	if #s <= width then return s end
	local ell_len = #ell
	if ell_len >= width then return string_sub(ell, 1, width) end
	local keep = width - ell_len
	local left_keep = math_ceil(keep / 2)
	local right_keep = keep - left_keep
	local left = string_sub(s, 1, left_keep)
	local right = string_sub(s, -right_keep, -1)
	return left .. ell .. right
end

string.truncate_middle = string_truncate_middle
string.truncateMiddle = string_truncate_middle
string.TruncateMiddle = string_truncate_middle

-- Abbreviate a phrase intelligently
local function string_abbreviate(s, max_len, opts)
	opts = opts or {}
	local mode = opts.mode or "initials"
	max_len = tonumber(max_len) or 0
	if max_len <= 0 then return "" end
	if visible_length(s) <= max_len then return s end

	local words = {}
	for w in string_gmatch(s, "[^%s%-%_]+") do
		words[#words + 1] = w
	end
	if #words <= 1 then
		return string_truncate_middle(s, max_len, opts)
	end

	if mode == "initials" then
		local ab = {}
		for i = 1, #words do
			local w = words[i]
			local ch = utf8_sub(w, 1, 1)
			ab[#ab + 1] = ch
		end
		local joined = table_concat(ab)
		if visible_length(joined) <= max_len then return joined end
		return utf8_sub(joined, 1, max_len)
	end

	local n = #words
	local per = math_max(1, math_floor(max_len / n))
	local parts = {}
	for i = 1, n do
		local w = words[i]
		local take = per
		if i == n then take = max_len - (per * (n - 1)) end
		parts[#parts + 1] = utf8_sub(w, 1, take)
	end
	local joined = table_concat(parts, "")
	if visible_length(joined) <= max_len then return joined end
	return string_truncate_middle(joined, max_len, opts)
end

string.abbreviate = string_abbreviate
string.Abbreviate = string_abbreviate

-- Indent text with prefix repeated count times
local function string_indent(text, prefix, count)
	prefix = prefix or " "
	count = tonumber(count) or 2
	local pad = repeat_fill(prefix, count)
	local out_lines = {}
	for line in string_gmatch(tostring(text), "([^\n]*)\n?") do
		out_lines[#out_lines + 1] = pad .. line
	end
	return table_concat(out_lines, "\n")
end

string.indent = string_indent
string.Indent = string_indent

-- Dedent text by removing leading spaces or prefix
local function string_dedent(text, count_or_prefix)
	local lines = {}
	for line in string_gmatch(tostring(text), "([^\n]*)\n?") do
		lines[#lines + 1] = line
	end
	if #lines == 0 then return "" end

	if type(count_or_prefix) == "string" then
		local pref = count_or_prefix
		local pref_len = #pref
		for i = 1, #lines do
			local ln = lines[i]
			if string_sub(ln, 1, pref_len) == pref then
				lines[i] = string_sub(ln, pref_len + 1)
			end
		end
		return table_concat(lines, "\n")
	end

	if type(count_or_prefix) == "number" then
		local cnt = count_or_prefix
		for i = 1, #lines do
			local ln = lines[i]
			local j = 1
			while j <= cnt and string_sub(ln, 1, 1) == " " do
				ln = string_sub(ln, 2)
				j = j + 1
			end
			lines[i] = ln
		end
		return table_concat(lines, "\n")
	end

	local min_indent
	for i = 1, #lines do
		local ln = lines[i]
		if string_match(ln, "%S") then
			local indent = string_match(ln, "^(%s*)")
			local l = #indent
			if min_indent == nil or l < min_indent then min_indent = l end
		end
	end
	if not min_indent or min_indent == 0 then return table_concat(lines, "\n") end
	for i = 1, #lines do
		local ln = lines[i]
		if #ln >= min_indent then
			lines[i] = string_sub(ln, min_indent + 1)
		end
	end
	return table_concat(lines, "\n")
end

string.dedent = string_dedent
string.Dedent = string_dedent

do
	-- Template engine (mustache-like)
	-- Features: {{key}} escaped, {{{key}}} raw, {{#section}}...{{/section}}, {{^section}}...{{/section}}
	local template_cache = setmetatable({}, { __mode = "v" })

	local function resolve_path(ctx, path)
		if path == "" then return nil end
		local cur = ctx
		for part in string_gmatch(path, "[^%.]+") do
			if type(cur) ~= "table" then return nil end
			cur = cur[part]
			if cur == nil then return nil end
		end
		return cur
	end

	local function apply_filter(val, filter)
		if not filter or filter == "" then return val end
		local f = string_lower(filter)
		if f == "upper" then return string_upper(tostring(val)) end
		if f == "lower" then return string_lower(tostring(val)) end
		if f == "trim" then
			local s = tostring(val)
			s = string_gsub(s, "^%s+", "")
			s = string_gsub(s, "%s+$", "")
			return s
		end
		if f == "json" then
			if type(val) == "string" then return string_format("%q", val) end
			if type(val) == "number" or type(val) == "boolean" then return tostring(val) end
			return tostring(val)
		end
		if type(val) == "table" and type(val[filter]) == "function" then
			return val[filter](val)
		end
		return val
	end

	local function default_escape(s)
		return safe_tostring(s)
	end

	local function string_compile_template(tpl)
		if template_cache[tpl] then return template_cache[tpl] end

		local tokens = {}
		local i = 1
		local len = #tpl
		while i <= len do
			local s, e, triple = string_find(tpl, "(%{%{%{.-%}%}%})", i)
			local s2, e2, tag = string_find(tpl, "(%{%{.-%}%})", i)
			if s and (not s2 or s < s2) then
				if s > i then tokens[#tokens + 1] = { type = "text", text = string_sub(tpl, i, s - 1) } end
				local inner = string_sub(tpl, s + 3, e - 3)
				tokens[#tokens + 1] = { type = "raw", expr = inner }
				i = e + 1
			elseif s2 then
				if s2 > i then tokens[#tokens + 1] = { type = "text", text = string_sub(tpl, i, s2 - 1) } end
				local inner = string_sub(tpl, s2 + 2, e2 - 2)
				if string_match(inner, "^#") then
					tokens[#tokens + 1] = { type = "section_start", name = string_sub(inner, 2) }
				elseif string_match(inner, "^/") then
					tokens[#tokens + 1] = { type = "section_end", name = string_sub(inner, 2) }
				elseif string_match(inner, "^%?") then
					tokens[#tokens + 1] = { type = "inverted_start", name = string_sub(inner, 2) }
				elseif string_match(inner, "^!") then
				else
					tokens[#tokens + 1] = { type = "var", expr = inner }
				end
				i = e2 + 1
			else
				tokens[#tokens + 1] = { type = "text", text = string_sub(tpl, i) }
				break
			end
		end

		local function build_ast(toklist, pos)
			local ast = {}
			pos = pos or 1
			while pos <= #toklist do
				local t = toklist[pos]
				if t.type == "text" or t.type == "var" or t.type == "raw" then
					ast[#ast + 1] = t
					pos = pos + 1
				elseif t.type == "section_start" then
					local name = t.name
					local subtree, newpos = build_ast(toklist, pos + 1)
					ast[#ast + 1] = { type = "section", name = name, body = subtree }
					pos = newpos
				elseif t.type == "inverted_start" then
					local name = t.name
					local subtree, newpos = build_ast(toklist, pos + 1)
					ast[#ast + 1] = { type = "inverted", name = name, body = subtree }
					pos = newpos
				elseif t.type == "section_end" then
					return ast, pos + 1
				else
					pos = pos + 1
				end
			end
			return ast, pos
		end

		local ast = build_ast(tokens, 1)

		local function render_ast(ast_node, ctx, buf, opts)
			opts = opts or {}
			local escape_fn = opts.escape or default_escape
			for i = 1, #ast_node do
				local node = ast_node[i]
				if node.type == "text" then
					buf[#buf + 1] = node.text
				elseif node.type == "var" then
					local expr = node.expr
					local name, filter = string_match(expr, "^%s*([^|%s]+)%s*|?%s*(%S*)")
					if not name then name = expr end
					local val = resolve_path(ctx, name) or ""
					val = apply_filter(val, filter)
					buf[#buf + 1] = escape_fn(val)
				elseif node.type == "raw" then
					local name = string_match(node.expr, "^%s*(.-)%s*$")
					local val = resolve_path(ctx, name) or ""
					buf[#buf + 1] = safe_tostring(val)
				elseif node.type == "section" then
					local name = string_match(node.name, "^%s*(.-)%s*$")
					local val = resolve_path(ctx, name)
					if type(val) == "table" then
						local is_array = true
						local count = 0
						for k, _ in pairs(val) do
							count = count + 1
							if type(k) ~= "number" then is_array = false end
						end
						if is_array then
							for j = 1, count do
								local item = val[j]
								if type(item) == "table" then
									local merged = setmetatable(item, { __index = ctx })
									render_ast(node.body, merged, buf, opts)
								else
									local merged = setmetatable({ ["."] = item }, { __index = ctx })
									render_ast(node.body, merged, buf, opts)
								end
							end
						else
							if next(val) ~= nil then
								local merged = setmetatable(val, { __index = ctx })
								render_ast(node.body, merged, buf, opts)
							end
						end
					elseif val then
						render_ast(node.body, ctx, buf, opts)
					end
				elseif node.type == "inverted" then
					local name = string_match(node.name, "^%s*(.-)%s*$")
					local val = resolve_path(ctx, name)
					local empty = (val == nil) or (val == false) or (type(val) == "table" and next(val) == nil)
					if empty then
						render_ast(node.body, ctx, buf, opts)
					end
				end
			end
		end

		local function renderer(context, opts)
			local buf = {}
			render_ast(ast, context or {}, buf, opts or {})
			return table_concat(buf)
		end

		template_cache[tpl] = renderer
		return renderer
	end

	string.compile_template = string_compile_template
	string.compileTemplate = string_compile_template
	string.CompileTemplate = string_compile_template

	local function string_template(tpl, ctx, opts)
		local fn = string_compile_template(tpl)
		return fn(ctx or {}, opts or {})
	end

	string.template = string_template
	string.Template = string_template
end

-- Simple string alignment
local function string_align(str, alignment, width, pad_char)
	pad_char = pad_char or " "
	local str_width = #str
	local pad = width - str_width
	if pad <= 0 then return str end
	if alignment == "left" then
		return str .. string_rep(pad_char, pad)
	end
	if alignment == "right" then
		return string_rep(pad_char, pad) .. str
	end
	if alignment == "center" then
		local left = math_floor(pad / 2)
		local right = pad - left
		return string_rep(pad_char, left) .. str .. string_rep(pad_char, right)
	end
	return str
end

string.align = string_align
string.Align = string_align

do
	-- Pad or trim to target visual width, preserving ANSI sequences at ends
	local function pad_or_trim_visual(s, target, align, fill)
		fill = fill or " "
		local vis = visible_length(s)
		if vis == target then return s end
		if vis < target then
			local pad = target - vis
			if align == "left" then
				return s .. repeat_fill(fill, pad)
			end
			if align == "right" then
				return repeat_fill(fill, pad) .. s
			end
			local l = math_floor(pad / 2)
			local r = pad - l
			return repeat_fill(fill, l) .. s .. repeat_fill(fill, r)
		end
		if align == "left" then
			return utf8_sub(s, 1, target)
		end
		if align == "right" then
			return utf8_sub(s, -target, -1)
		end
		local left = math_ceil(target / 2)
		local right = target - left
		return utf8_sub(s, 1, left) .. utf8_sub(s, -right, -1)
	end

	-- Align string with ANSI sequence awareness
	local function string_align_ansi(str, alignment, width, pad_char)
		alignment = alignment or "left"
		width = tonumber(width) or 0
		pad_char = pad_char or " "
		if width <= 0 then return str end
		return pad_or_trim_visual(str, width, alignment, pad_char)
	end

	string.align_ansi = string_align_ansi
	string.alignAnsi = string_align_ansi
	string.AlignAnsi = string_align_ansi

	-- Box drawing styles
	local box_styles = {
		single = { tl = "┌", tr = "┐", bl = "└", br = "┘", h = "─", v = "│" },
		double = { tl = "╔", tr = "╗", bl = "╚", br = "╝", h = "═", v = "║" },
		round  = { tl = "╭", tr = "╮", bl = "╰", br = "╯", h = "─", v = "│" },
		bold   = { tl = "┏", tr = "┓", bl = "┗", br = "┛", h = "━", v = "┃" },
		ascii  = { tl = "+", tr = "+", bl = "+", br = "+", h = "-", v = "|" },
	}

	-- Draw a box around text (multi-line)
	local function string_box(str, options)
		options = options or {}
		local style = options.style or "single"
		local padding = tonumber(options.padding) or 1
		local margin = tonumber(options.margin) or 0
		local title = options.title
		local align = options.align or "left"
		local forced_width = options.width and tonumber(options.width) or nil

		local ch = box_styles[style] or box_styles["single"]

		local lines = {}
		local maxw = 0
		for line in string_gmatch(tostring(str), "([^\n]*)\n?") do
			lines[#lines + 1] = line
			local l = visible_length(line)
			if l > maxw then maxw = l end
		end
		if forced_width and forced_width > maxw then maxw = forced_width end

		local inner_width = maxw + padding * 2

		local top = ch.tl .. string_rep(ch.h, inner_width) .. ch.tr
		if title and title ~= "" then
			local t = " " .. title .. " "
			local tvis = visible_length(t)
			if tvis < inner_width then
				local left = math_floor((inner_width - tvis) / 2)
				local right = inner_width - tvis - left
				top = ch.tl .. string_rep(ch.h, left) .. t .. string_rep(ch.h, right) .. ch.tr
			else
				local tshort = pad_or_trim_visual(t, inner_width, "center", " ")
				top = ch.tl .. tshort .. ch.tr
			end
		end

		local out_lines = {}
		for i = 1, margin do out_lines[#out_lines + 1] = "" end
		out_lines[#out_lines + 1] = top

		for i = 1, #lines do
			local ln = lines[i]
			local padded = string_align(ln, align, maxw, " ")
			local inner = string_rep(" ", padding) .. padded .. string_rep(" ", padding)
			out_lines[#out_lines + 1] = ch.v .. inner .. ch.v
		end

		local bottom = ch.bl .. string_rep(ch.h, inner_width) .. ch.br
		out_lines[#out_lines + 1] = bottom
		for i = 1, margin do out_lines[#out_lines + 1] = "" end

		return table_concat(out_lines, "\n")
	end

	string.box = string_box
	string.Box = string_box
end

do
	local partials = { "▏", "▎", "▍", "▌", "▋", "▊", "▉" }
	-- Create a progress bar
	local function string_progress_bar(current, total, width, options)
		options = options or {}
		local w = tonumber(width) or options.width or 30
		local fill = options.fill or "█"
		local empty = options.empty or "░"
		local show_percent = options.show_percent
		if show_percent == nil then show_percent = true end
		local caps = options.caps
		if caps == nil then caps = true end
		local unicode_fraction = options.unicode_fraction
		if unicode_fraction == nil then unicode_fraction = true end

		current = tonumber(current) or 0
		total = tonumber(total) or 1
		if total <= 0 then total = 1 end
		local ratio = math_max(0, math_min(1, current / total))

		local inner_w = w
		local left_label = options.left_label or ""
		local right_label = options.right_label or ""
		if caps then inner_w = inner_w - 2 end
		if inner_w < 1 then inner_w = 1 end

		local filled = math_floor(ratio * inner_w)
		local rem = ratio * inner_w - filled

		local frac_char = ""
		if unicode_fraction and rem > 0 then
			local idx = math_floor(rem * #partials + 0.5)
			if idx >= 1 and idx <= #partials then frac_char = partials[idx] end
		end

		local bar = ""
		if filled > 0 then bar = bar .. string_rep(fill, filled) end
		if frac_char ~= "" then bar = bar .. frac_char end
		local filled_vis = visible_length(bar)
		local empty_count = inner_w - filled_vis
		if empty_count > 0 then bar = bar .. string_rep(empty, empty_count) end

		if caps then bar = "[" .. bar .. "]" end

		local percent_text = ""
		if show_percent then
			percent_text = string_format(" %3d%%", math_floor(ratio * 100 + 0.5))
		end

		local left = (left_label ~= "" and (left_label .. " ") or "")
		local right = (right_label ~= "" and (" " .. right_label) or "")

		return left .. bar .. percent_text .. right
	end

	string.progress_bar = string_progress_bar
	string.progressBar = string_progress_bar
	string.ProgressBar = string_progress_bar
end

do
	-- XOR cipher implementation
	local bit_bxor
	if _VERSION >= "Lua 5.3" then
		-- Use built-in bitwise operator in Lua 5.3+
		bit_bxor = load([[return function(a, b) return a ~ b end]])()
	elseif type(bit32) == "table" and type(bit32.bxor) == "function" then
		-- Use bit32 library if available (Lua 5.2)
		bit_bxor = bit32.bxor
	elseif type(bit) == "table" and type(bit.bxor) == "function" then
		-- Use bit library if available (LuaJIT/5.1)
		bit_bxor = bit.bxor
	else
		-- Fallback pure Lua implementation (matches bitwise.lua bxor)
		local function tobit(x)
			local n = tonumber(x) or 0
			n = math_floor(n)
			if n < 0 then n = n % 0x100000000 end
			return n % 0x100000000
		end

		bit_bxor = function(a, b)
			a = tobit(a)
			b = tobit(b)
			local res = 0
			local bit = 1
			while a > 0 or b > 0 do
				local abit = a % 2
				local bbit = b % 2
				if (abit + bbit) % 2 == 1 then res = res + bit end
				a = math_floor(a / 2)
				b = math_floor(b / 2)
				bit = bit * 2
			end
			return res % 0x100000000
		end
	end

	local function string_xor_cipher(s, k)
		if type(s) ~= "string" then
			return error("string expected, got " .. type(s), 2)
		end
		if type(k) == "table" then
			k = tostring(k)
		end
		if type(k) ~= "string" then
			return error("string expected for key, got " .. type(k), 2)
		end
		local key_len = #k
		if key_len == 0 then
			return error("key cannot be empty", 2)
		end
		return (string_gsub(s, '()(.)', function(i, x)
			local ki = ((i - 1) % key_len) + 1
			--return string_char(string_byte(x) ~ string_byte(k, ki, ki))
			return string_char(bit_bxor(string_byte(x), string_byte(k, ki, ki)))
		end))
	end

	string.xor_cipher = string_xor_cipher
	string.xorCipher = string_xor_cipher
	string.XorCipher = string_xor_cipher
end

local string_surround = function(self, wrapper)
	self = self or ""
	wrapper = wrapper or ""
	return wrapper .. self .. wrapper
end

string.surround = string_surround
string.Surround = string_surround

local string_between = function(self, open, close)
	if not self or not open or not close then return nil end
	local s, e = string_find(self, open, 1, true)
	if not s then return nil end
	local s2, e2 = string_find(self, close, e + 1, true)
	if not s2 then return nil end
	return string_sub(self, e + 1, s2 - 1)
end

string.between = string_between
string.Between = string_between

local string_remove_non_printable = function(self)
	return (string_gsub(self, "[%c]", ""))
end

string.remove_non_printable = string_remove_non_printable
string.removeNonPrintable = string_remove_non_printable
string.RemoveNonPrintable = string_remove_non_printable

local string_remove_non_ascii = function(self)
	return (string_gsub(self, "[\128-\255]", ""))
end

string.remove_non_ascii = string_remove_non_ascii
string.removeNonASCII = string_remove_non_ascii
string.RemoveNonASCII = string_remove_non_ascii

local string_truncate_words = function(self, max_words, suffix)
	suffix = suffix or "~"
	max_words = tonumber(max_words) or 0
	if max_words <= 0 then return "" end

	local count = 0
	local last_pos = 0

	for pos in string_gmatch(self, "()%S+") do
		count = count + 1
		if count > max_words then
			return string_sub(self, 1, last_pos - 1) .. suffix
		end
		last_pos = pos
	end

	return self
end

string.truncate_words = string_truncate_words
string.truncateWords = string_truncate_words
string.TruncateWords = string_truncate_words

local string_append_if_empty = function(self, suffix)
	if self == "" then return self .. (suffix or "") end
	return self
end

string.append_if_empty = string_append_if_empty
string.appendIfEmpty = string_append_if_empty
string.AppendIfEmpty = string_append_if_empty

local string_prepend_if_empty = function(self, prefix)
	if self == "" then return (prefix or "") .. self end
	return self
end

string.prepend_if_empty = string_prepend_if_empty
string.prependIfEmpty = string_prepend_if_empty
string.PrependIfEmpty = string_prepend_if_empty

local string_append_if_not_empty = function(self, suffix)
	if self ~= "" then return self .. (suffix or "") end
	return self
end

string.append_if_not_empty = string_append_if_not_empty
string.appendIfNotEmpty = string_append_if_not_empty
string.AppendIfNotEmpty = string_append_if_not_empty

local string_prepend_if_not_empty = function(self, prefix)
	if self ~= "" then return (prefix or "") .. self end
	return self
end

string.prepend_if_not_empty = string_prepend_if_not_empty
string.prependIfNotEmpty = string_prepend_if_not_empty
string.PrependIfNotEmpty = string_prepend_if_not_empty

local string_count = function(self, pattern, plain)
	local c, i = 0, 1
	while true do
		local s, e = string_find(self, pattern, i, plain)
		if not s then break end
		c = c + 1
		i = e + 1
	end
	return c
end

string.count = string_count
string.Count = string_count

local string_splice = function(self, start, deleteCount, insert)
	local len = #self
	start = tonumber(start) or 1
	deleteCount = tonumber(deleteCount) or 0
	insert = insert or ""

	if start < 1 then start = 1 end
	if start > len then start = len + 1 end

	local before = string_sub(self, 1, start - 1)
	local after = string_sub(self, start + deleteCount)

	return before .. insert .. after
end

string.splice = string_splice
string.Splice = string_splice

-- Export (for compatibility)
return string
