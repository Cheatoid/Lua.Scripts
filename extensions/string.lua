-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Localized global functions for better performance
local type = type
local tonumber = tonumber
local tostring = tostring
local string = string
local string_char = string.char
local string_find = string.find
local string_gmatch = string.gmatch
local string_gsub = string.gsub
local string_lower = string.lower
local string_match = string.match
local string_rep = string.rep
local string_sub = string.sub
local string_upper = string.upper
local math_random = math.random
local table_concat = table.concat

-- Hijack string metatable 😎
local STRING
-- If debug.getmetatable is available, use it instead, otherwise fallback to getmetatable
if debug and debug.getmetatable then
	STRING = debug.getmetatable("") or {}
	if debug.setmetatable then
		debug.setmetatable("", STRING)
	end
else
	STRING = getmetatable("")
end

STRING.__index = STRING.__index or function(self, key)
	local value = string[key]
	if value ~= nil then
		return value
	end
	-- string[key] ==> string.sub(string, key, key)
	if tonumber(key) then
		return string_sub(self, key, key)
	end
end

-- string + string ==> string .. string
STRING.__add = function(left, right)
	return left .. right
end

-- string * number ==> string.rep(string, number)
STRING.__mul = function(left, right)
	return string_rep(left, right)
end

do
	local ITERATE_LINES_PATTERN = "[^\n]+"

	--- Iterate over lines in a string using an iterator.
	--- Returns each line (excluding newline characters) as it's encountered.
	--- @param input string Input string to iterate over.
	--- @return function iterator Iterator that yields each line as a separate string.
	--- @usage <br>
	--- ```
	--- -- Outputs: "line 1", "line 2", "line 3"
	--- for line in iterate_lines("line 1\nline 2\nline 3") do
	---   print(line)
	--- end
	--- ```
	local string_iterate_lines = function(input)
		return string_gmatch(input, ITERATE_LINES_PATTERN)
	end

	string.iterate_lines = string_iterate_lines
	string.iterateLines = string_iterate_lines
	string.IterateLines = string_iterate_lines
end

do
	local CARRIAGE_RETURN_CHAR = "\r"
	local NEWLINE_CHAR = "\n"

	--- Split a string into lines and return them as a table.
	--- Handles both \n and \r\n line endings properly.
	--- @param self string Input string to split into lines.
	--- @return table lines Table containing each line as a separate string.
	--- @usage <br>
	--- ```
	--- -- Returns: { "line 1", "line 2", "line 3" }
	--- string.lines("line 1\nline 2\r\nline 3")
	--- ```
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

--- Split a string using a plain separator and return an iterator.
--- The separator is treated as plain text (not a pattern).
--- @param self string Input string to split.
--- @param sep string Plain separator used to split (default: ",").
--- @return function iterator Iterator that yields string parts.
--- @usage <br>
--- ```
--- -- Outputs: "a", "b", "", "c", ""
--- for part in "a,b,,c,":iter_explode(",") do
---   print(part)
--- end
--- ```
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

--- Split a string using a Lua pattern as separator and return an iterator.
--- The pattern is treated as a Lua string pattern (not plain text).
--- @param self string Input string to split.
--- @param pat string Lua pattern used as separator (default: ",").
--- @return function iterator Iterator that yields string parts.
--- @usage <br>
--- ```
--- -- Outputs: "a", "b", "c"
--- for part in "a1b2c":iter_explode_pattern("%d") do
---   print(part)
--- end
--- ```
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

--- Split a string into fixed-size chunks and return an iterator.
--- @param self string Input string to split into chunks.
--- @param size integer Size of each chunk (default: 1, must be > 0).
--- @return function iterator Iterator that yields string chunks.
--- @usage <br>
--- ```
--- -- Outputs: "abc", "def", "g"
--- for chunk in "abcdefg":iter_chunk_split(3) do
---   print(chunk)
--- end
--- ```
local string_iter_chunk_split = function(self, size)
	if type(self) ~= "string" then self = tostring(self or "") end
	size = tonumber(size) or 1
	if size <= 0 then return error("size must be > 0") end

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

--- Split a string into fixed-size chunks and return them as a table.
--- @param self string Input string to split into chunks.
--- @param size integer Size of each chunk (default: 1, must be > 0).
--- @return table array Table containing each chunk as a separate element.
--- @usage <br>
--- ```
--- "abcdefg":chunks(3) -- { "abc", "def", "g" }
--- ```
local string_chunks = function(self, size)
	if type(self) ~= "string" then self = tostring(self or "") end
	size = tonumber(size) or 1
	if size <= 0 then return error("size must be > 0") end

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

--- Split a string into fixed-size chunks and return them as a table.
--- Uses a for loop with step size for chunking.
--- @param self string Input string to split into chunks.
--- @param size integer Size of each chunk (must be > 0).
--- @return table array Table containing each chunk as a separate element.
--- @usage <br>
--- ```
--- "abcdefg":chunk(3) -- { "abc", "def", "g" }
--- ```
local string_chunk = function(self, size)
	if type(self) ~= "string" then self = tostring(self or "") end
	size = tonumber(size) or 1
	if size <= 0 then return error("size must be > 0") end

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

--- Convert a string to a table of individual characters.
--- Each character in the string becomes a separate table element.
--- @param self string Input string to convert to a table.
--- @return table array Array containing each character as a separate element.
--- @usage <br>
--- ```
--- "hello":to_table() -- { "h", "e", "l", "l", "o" }
--- ```
local string_to_table = function(self)
	local tbl = {}
	for i = 1, #self do
		tbl[i] = string_sub(self, i, i)
	end
	return tbl
end

string.to_table = string_to_table
string.ToTable = string_to_table

--- Split a string into parts using a separator and return as a table.
--- Supports both plain text and pattern-based separators.
--- @param self string Input string to split.
--- @param separator string Separator to split on (can be empty string or pattern).
--- @param with_pattern boolean|nil If true, treats separator as Lua pattern; if false, as plain text (default: false).
--- @return table array Array containing the split string parts.
--- @usage <br>
--- ```
--- -- Plain text separator: returns {"a", "b", "c"}
--- local parts = "a,b,c":explode(",", false)
---
--- -- Pattern separator: returns {"a", "b", "c"}
--- local parts = "a1b2c":explode("%d", true)
---
--- -- Empty separator: returns {"h", "e", "l", "l", "o"}
--- local chars = "hello":explode("", false)
--- ```
local string_explode = function(self, separator, with_pattern)
	if #separator == 0 then return string_to_table(self) end
	local ret, current_pos = {}, 1
	for i = 1, #self do
		local start_pos, end_pos = string_find(self, separator, current_pos, not with_pattern)
		if not start_pos then break end
		ret[i] = string_sub(self, current_pos, start_pos - 1)
		current_pos = end_pos + 1
	end
	ret[#ret + 1] = string_sub(self, current_pos)
	return ret
end

string.explode = string_explode
string.split = string_explode

--- Replace all occurrences of a search value with a replacement value.
--- Uses plain text search (not patterns) for maximum performance.
--- @param self string Input string to perform replacements on.
--- @param search_value string Value to search for (treated as plain text).
--- @param replace_value string Value to replace with (treated as plain text).
--- @return string string New string with all replacements applied.
--- @usage <br>
--- ```
--- "Hi there! Hi there!":replace("Hi", "Hello") -- "Hello there! Hello there!"
--- "a,b,c,d":replace(",", "-") -- "a-b-c-d"
--- "hello":replace("x", "y") -- "hello"
--- ```
local string_replace = function(self, search_value, replace_value)
	local tbl = string_explode(self, search_value)
	return next(tbl) and table_concat(tbl, replace_value) or self
end

string.replace = string_replace
string.Replace = string_replace

--- Check if a string starts with the specified prefix.
--- @param self string Input string to check.
--- @param start string Prefix to search for at the beginning of the string.
--- @return boolean boolean True if the string starts with the prefix, false otherwise.
--- @usage <br>
--- ```
--- "hello world":starts_with("hello") -- true
--- "hello world":starts_with("world") -- false
--- ```
local string_starts_with = function(self, start)
	return string_sub(self, 1, #start) == start
end

string.starts_with = string_starts_with
string.StartsWith = string_starts_with
string.StartWith = string_starts_with

--- Check if a string ends with the specified suffix.
--- @param self string Input string to check.
--- @param endStr string Suffix to search for at the end of the string.
--- @return boolean boolean True if the string ends with the suffix, false otherwise.
--- @usage <br>
--- ```
--- "hello world":ends_with("world") -- true
--- "hello world":ends_with("hello") -- false
--- ```
local string_ends_with = function(self, endStr)
	local len = #endStr
	return len == 0 or string_sub(self, -len) == endStr
end

string.ends_with = string_ends_with
string.EndsWith = string_ends_with

--- Get the leftmost characters from a string.
--- @param self string Input string to extract from.
--- @param length integer Number of characters to extract from the left.
--- @return string string Leftmost characters.
--- @usage <br>
--- ```
--- "hello":left(3) -- "hel"
--- ```
local string_left = function(self, length)
	length = tonumber(length) or 0
	if length <= 0 then return "" end
	return string_sub(self, 1, length)
end

string.left = string_left
string.Left = string_left

--- Get the rightmost characters from a string.
--- @param self string Input string to extract from.
--- @param length integer Number of characters to extract from the right.
--- @return string string Rightmost characters.
--- @usage <br>
--- ```
--- "hello":right(3) -- "llo"
--- ```
local string_right = function(self, length)
	length = tonumber(length) or 0
	if length <= 0 then return "" end
	return string_sub(self, -length)
end

string.right = string_right
string.Right = string_right

--- Pad a string on the left to reach the specified total width.
--- @param self string Input string to pad.
--- @param totalWidth integer Total width the padded string should reach.
--- @param char string|nil Character to use for padding (default: space " ").
--- @return string string Left-padded string.
--- @usage <br>
--- ```
--- "hello":pad_left(8) -- "   hello"
---
--- "hello":pad_left(7, "x") -- "xxhello"
--- ```
local string_pad_left = function(self, totalWidth, char)
	totalWidth = tonumber(totalWidth) or 0
	char = char or " "
	if #self >= totalWidth then return self end
	return string_rep(char, totalWidth - #self) .. self
end

string.pad_left = string_pad_left
string.padleft = string_pad_left
string.PadLeft = string_pad_left

--- Pad a string on the right to reach the specified total width.
--- @param self string Input string to pad.
--- @param totalWidth integer Total width the padded string should reach.
--- @param char string string|nil Character to use for padding (default: space " ").
--- @return string string Right-padded string.
--- @usage <br>
--- ```
--- "hello":pad_right(8) -- "hello   "
--- "hello":pad_right(7, "x") -- "helloxx"
--- ```
local string_pad_right = function(self, totalWidth, char)
	totalWidth = tonumber(totalWidth) or 0
	char = char or " "
	if #self >= totalWidth then return self end
	return self .. string_rep(char, totalWidth - #self)
end

string.pad_right = string_pad_right
string.padright = string_pad_right
string.PadRight = string_pad_right

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

	--- Escape special Lua pattern characters in a string using lookup table.
	--- Makes a string safe to use in Lua pattern matching operations.
	--- @param str string Input string to escape.
	--- @return string string Pattern-safe string with special characters escaped.
	--- @usage <br>
	--- ```
	--- "hello+world":pattern_safe_zero() -- "hello%+world"
	--- "[test]":pattern_safe_zero() -- "%[test%]"
	--- "hello\0world":pattern_safe_zero() -- "hello%zworld"
	--- ```
	local pattern_safe_zero = function(str)
		return (string_gsub(str, ".", PATTERN_SAFE_ESCAPE_REPLACEMENTS))
	end

	string.pattern_safe_zero = pattern_safe_zero
	string.patternSafeZero = pattern_safe_zero
	string.PatternSafeZero = pattern_safe_zero
end

local string_trim
do
	local SAFE_PATTERN = "([%^%$%(%)%%%.%[%]%*%+%-%?])" -- NOTE: This version does not handle NUL
	local SAFE_PATTERN_ESCAPE = "%%%1"

	--- Escape special Lua pattern characters in a string.
	--- Makes a string safe to use in Lua pattern matching operations.
	--- @param str string Input string to escape.
	--- @return string string Pattern-safe string with special characters escaped.
	--- @usage <br>
	--- ```
	--- pattern_safe("hello+world") -- "hello%+world"
	--- pattern_safe("[test]") -- "%[test%]"
	--- pattern_safe("hello\0world") -- "hello" .. '\0' .. "world"
	--- ```
	local pattern_safe = function(str)
		return (string_gsub(str, SAFE_PATTERN, SAFE_PATTERN_ESCAPE))
	end

	string.pattern_safe = pattern_safe
	string.patternSafe = pattern_safe
	string.PatternSafe = pattern_safe

	--- Remove leading and trailing characters from a string.
	--- @param self string Input string to trim.
	--- @param char string|nil Character pattern to trim (default: whitespace "%s").
	--- @return string string Trimmed string.
	--- @usage <br>
	--- ```
	--- "  hello  ":trim() -- "hello"
	--- "xxhelloxx":trim("x") -- "hello"
	--- ```
	string_trim = function(self, char)
		char = char and string_gsub(char, SAFE_PATTERN, SAFE_PATTERN_ESCAPE) or "%s"
		return (string_match(self, "^" .. char .. "*(.-)" .. char .. "*$")) or self
	end

	string.trim = string_trim
	string.Trim = string_trim

	--- Remove leading characters from a string.
	--- @param self string Input string to trim from the left.
	--- @param char string|nil Character pattern to trim (default: whitespace "%s").
	--- @return string string Left-trimmed string.
	--- @usage <br>
	--- ```
	--- "  hello  ":trim_left() -- "hello  "
	--- "xxhelloxx":trim_left("x") -- "helloxx"
	--- ```
	local string_trim_left = function(self, char)
		char = char and string_gsub(char, SAFE_PATTERN, SAFE_PATTERN_ESCAPE) or "%s"
		return (string_match(self, "^" .. char .. "*(.+)$")) or self
	end

	string.trim_left = string_trim_left
	string.trimleft = string_trim_left
	string.TrimLeft = string_trim_left

	--- Remove trailing characters from a string.
	--- @param self string Input string to trim from the right.
	--- @param char string|nil Character pattern to trim (default: whitespace "%s").
	--- @return string string Right-trimmed string.
	--- @usage <br>
	--- ```
	--- "  hello  ":trim_right() -- "  hello"
	--- "xxhelloxx":trim_right("x") -- "xxhello"
	--- ```
	local string_trim_right = function(self, char)
		char = char and string_gsub(char, SAFE_PATTERN, SAFE_PATTERN_ESCAPE) or "%s"
		return (string_match(self, "^(.-)" .. char .. "*$")) or self
	end

	string.trim_right = string_trim_right
	string.trimright = string_trim_right
	string.TrimRight = string_trim_right
end

--- Rotate a string left by the specified amount.
--- @param self string Input string to rotate.
--- @param amount integer Number of characters to rotate left.
--- @return string string Left-rotated string.
--- @usage <br>
--- ```
--- "hello":rotate_left(2) -- "llohe"
--- ```
local string_rotate_left = function(self, amount)
	amount = tonumber(amount) or 0
	if amount <= 0 then return self end
	if amount >= #self then return self end
	return string_sub(self, amount + 1) .. string_sub(self, 1, amount)
end

string.rotate_left = string_rotate_left
string.rotateleft = string_rotate_left
string.RotateLeft = string_rotate_left

--- Rotate a string right by the specified amount.
--- @param self string Input string to rotate.
--- @param amount integer Number of characters to rotate right.
--- @return string string Right-rotated string.
--- @usage <br>
--- ```
--- "hello":rotate_right(2) -- "lohel"
--- ```
local string_rotate_right = function(self, amount)
	amount = tonumber(amount) or 0
	if amount <= 0 then return self end
	if amount >= #self then return self end
	return string_rotate_left(self, #self - amount)
end

string.rotate_right = string_rotate_right
string.rotateright = string_rotate_right
string.RotateRight = string_rotate_right

--- Rotate a string by the specified amount (positive = right, negative = left).
--- @param self string Input string to rotate.
--- @param rotation integer Number of characters to rotate (negative = left, positive = right).
--- @return string string Rotated string.
--- @usage <br>
--- ```
--- "hello":rotate(2) -- "lohel" (rotate right 2)
--- "hello":rotate(-2) -- "llohe" (rotate left 2)
--- ```
local string_rotate = function(self, rotation)
	rotation = tonumber(rotation) or 0
	if rotation < 0 then
		return string_rotate_left(self, -rotation)
	end
	return string_rotate_right(self, rotation)
end

string.rotate = string_rotate
string.Rotate = string_rotate

--- Check if a string contains the specified substring.
--- @param self string Input string to search within.
--- @param substring string Substring to search for.
--- @return boolean boolean True if the substring is found, false otherwise.
--- @usage <br>
--- ```
--- "hello world":contains("world") -- true
--- "hello world":contains("test")  -- false
--- ```
local string_contains = function(self, substring)
	return string_find(self, substring, 1, true) ~= nil
end

string.contains = string_contains
string.Contains = string_contains

--- Find the first occurrence of a substring in a string.
--- @param self string Input string to search within.
--- @param substring string Substring to search for.
--- @return number|nil number Starting position of the substring (1-based), or nil if not found.
--- @usage <br>
--- ```
--- "hello world":index_of("world") -- 7
--- "hello world":index_of("test")  -- nil
--- "banana":index_of("na") -- 3
--- ```
local string_index_of = function(self, substring)
	return (string_find(self, substring, 1, true))
end

string.index_of = string_index_of
string.indexof = string_index_of
string.IndexOf = string_index_of

--- Find the last occurrence of a substring in a string.
--- @param self string Input string to search within.
--- @param substring string Substring to search for.
--- @return number|nil number Starting position of the last occurrence (1-based), or nil if not found.
--- @usage <br>
--- ```
--- "hello world hello":last_index_of("hello") -- 13
--- "hello world":last_index_of("test") -- nil
--- "banana":last_index_of("na") -- 5
--- ```
local string_last_index_of = function(self, substring)
	local last_pos = nil
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

--- Generate a random string of the specified length.
--- @param length integer|nil Length of the random string to generate (default: 1).
--- @param min integer|nil Minimum character code (default: 0).
--- @param max integer|nil Maximum character code (default: 255).
--- @return string string Randomly generated string.
--- @usage <br>
--- ```
--- -- Generate 10 random characters (default 0-255)
--- local result = string.random(10)
---
--- -- Generate 5 random printable ASCII characters
--- local result = string.random(5, 32, 126)
--- ```
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

-- Path separator constants
local PATH_SEPARATOR_WINDOWS = "\\"
local PATH_SEPARATOR_UNIX = "/"
local CURRENT_DIR = "."
local PARENT_DIR = ".."

--- Splits a dot-separated path into its component parts.
--- @param key string The dot-separated path string to split.
--- @return table array Array of path components.
--- @usage <br>
--- ```
--- local parts = string.split_path("module.submodule.value")
--- -- Returns {"module", "submodule", "value"}
--- ```
local function string_split_path(key)
	local parts = {}
	for part in string_gmatch(key, "[^%.]+") do
		parts[#parts + 1] = part
	end
	return parts
end

string.split_path = string_split_path
string.SplitPath = string_split_path

--- Normalize path separators to the specified format.
--- Converts all path separators to either forward slash or backslash.
--- @param self string Input path string to normalize.
--- @param separator string|nil Target separator (default: "/" for Unix-style).
--- @return string string Path with normalized separators.
--- @usage <br>
--- ```
--- "folder\\subfolder/file":normalize_path_separators() -- "folder/subfolder/file"
--- "folder/subfolder/file":normalize_path_separators("\\") -- "folder\\subfolder\\file"
--- ```
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

--- Convert path separators to Unix-style (forward slash).
--- @param self string Input path string to convert.
--- @return string string Path with Unix-style separators.
--- @usage <br>
--- ```
--- "folder\\subfolder\\file":to_unix_path() -- "folder/subfolder/file"
--- ```
local string_to_unix_path = function(self)
	return string_normalize_path_separators(self, PATH_SEPARATOR_UNIX)
end

string.to_unix_path = string_to_unix_path
string.toUnixPath = string_to_unix_path
string.ToUnixPath = string_to_unix_path

--- Convert path separators to Windows-style (backslash).
--- @param self string Input path string to convert.
--- @return string string Path with Windows-style separators.
--- @usage <br>
--- ```
--- "folder/subfolder/file":to_windows_path() -- "folder\\subfolder\\file"
--- ```
local string_to_windows_path = function(self)
	return string_normalize_path_separators(self, PATH_SEPARATOR_WINDOWS)
end

string.to_windows_path = string_to_windows_path
string.toWindowsPath = string_to_windows_path
string.ToWindowsPath = string_to_windows_path

--- Normalize a file path by resolving parent directory references and removing redundant separators.
--- Handles ".." and "." components and removes duplicate separators.
--- @param self string Input path string to normalize.
--- @param separator string|nil Path separator to use in result (default: "/").
--- @return string string Normalized path.
--- @usage <br>
--- ```
--- "folder/../subfolder/./file":normalize_path() -- "subfolder/file"
--- "folder//subfolder/../file":normalize_path() -- "folder/file"
--- ```
local string_normalize_path = function(self, separator)
	separator = separator or PATH_SEPARATOR_UNIX
	if separator ~= PATH_SEPARATOR_WINDOWS and separator ~= PATH_SEPARATOR_UNIX then
		separator = PATH_SEPARATOR_UNIX
	end

	-- First normalize all separators to a common format
	local path = string_normalize_path_separators(self, PATH_SEPARATOR_UNIX)

	-- Split path into components
	local components = {}
	local start_absolute = false

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

--- Get the directory portion of a file path.
--- @param self string Input file path.
--- @return string string Directory path without the filename.
--- @usage <br>
--- ```
--- "folder/subfolder/file.txt":path_dir() -- "folder/subfolder"
--- "file.txt":path_dir() -- ""
--- ```
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

--- Get the filename portion of a file path.
--- @param self string Input file path.
--- @return string string Filename without directory path.
--- @usage <br>
--- ```
--- "folder/subfolder/file.txt":path_file() -- "file.txt"
--- "file.txt":path_file() -- "file.txt"
--- ```
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

--- Get the file extension from a file path.
--- @param self string Input file path.
--- @return string string File extension (without dot), or empty string if no extension.
--- @usage <br>
--- ```
--- "file.txt":path_ext() -- "txt"
--- "folder/file.tar.gz":path_ext() -- "gz"
--- "file":path_ext() -- ""
--- ```
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

--- Get the filename without extension from a file path.
--- @param self string Input file path.
--- @return string string Filename without extension.
--- @usage <br>
--- ```
--- "file.txt":path_name() -- "file"
--- "folder/file.tar.gz":path_name() -- "file.tar"
--- "file":path_name() -- "file"
--- ```
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

--- Join multiple path components into a single path.
--- Handles separator insertion and normalizes the result.
--- @param ... string Path components to join.
--- @return string string Joined path.
--- @usage <br>
--- ```
--- string.path_join("folder", "subfolder", "file.txt") -- "folder/subfolder/file.txt"
--- string.path_join("folder/", "/subfolder/", "file.txt") -- "folder/subfolder/file.txt"
--- ```
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

--- Check if a path is absolute.
--- @param self string Input path to check.
--- @return boolean boolean True if path is absolute, false otherwise.
--- @usage <br>
--- ```
--- "/folder/file":is_absolute_path() -- true
--- "C:\\folder\\file":is_absolute_path() -- true
--- "folder/file":is_absolute_path() -- false
--- ```
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

--- Convert a relative path to an absolute path based on a base path.
--- @param self string Relative path to convert.
--- @param base_path string Base directory path (default: current directory).
--- @return string string Absolute path.
--- @usage <br>
--- ```
--- "file.txt":to_absolute_path("/base/folder") -- "/base/folder/file.txt"
--- "../file.txt":to_absolute_path("/base/folder") -- "/base/file.txt"
--- ```
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

--- Convert a string to snake_case.
--- Converts spaces, hyphens, camelCase, and PascalCase to lowercase with underscores.
--- @param self string Input string to convert.
--- @return string string Snake case version of the input.
--- @usage <br>
--- ```
--- "Hello World":to_snake_case() -- "hello_world"
--- "helloWorld":to_snake_case() -- "hello_world"
--- "HelloWorld":to_snake_case() -- "hello_world"
--- "hello-world":to_snake_case() -- "hello_world"
--- ```
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
		return string_gsub(string_lower(upper), "_", "")
	end)

	-- Remove leading/trailing underscores
	result = string_trim(result, "_")

	return result
end

string.to_snake_case = string_to_snake_case
string.toSnakeCase = string_to_snake_case
string.ToSnakeCase = string_to_snake_case

--- Convert a string to camelCase.
--- First character is lowercase, subsequent word boundaries are capitalized.
--- @param self string Input string to convert.
--- @return string string Camel case version of the input.
--- @usage <br>
--- ```
--- "hello world":to_camel_case() -- "helloWorld"
--- "hello_world":to_camel_case() -- "helloWorld"
--- "hello-world":to_camel_case() -- "helloWorld"
--- "HelloWorld":to_camel_case() -- "helloWorld"
--- ```
local string_to_camel_case = function(self)
	if type(self) ~= "string" then self = tostring(self or "") end

	-- Replace hyphens and underscores with spaces
	local result = string_gsub(self, "[-_]+", " ")

	-- Convert to lowercase and capitalize words after the first
	result = string_gsub(result, "(%S+)", function(word, pos)
		if pos == 1 then
			return string_lower(word)
		else
			return string_gsub(word, "^%l", string_upper)
		end
	end)

	-- Remove spaces
	result = string_gsub(result, "%s+", "")

	return result
end

string.to_camel_case = string_to_camel_case
string.toCamelCase = string_to_camel_case
string.ToCamelCase = string_to_camel_case

--- Convert a string to PascalCase.
--- All words are capitalized and concatenated without separators.
--- @param self string Input string to convert.
--- @return string string Pascal case version of the input.
--- @usage <br>
--- ```
--- "hello world":to_pascal_case() -- "HelloWorld"
--- "hello_world":to_pascal_case() -- "HelloWorld"
--- "hello-world":to_pascal_case() -- "HelloWorld"
--- "helloWorld":to_pascal_case() -- "HelloWorld"
--- ```
local string_to_pascal_case = function(self)
	if type(self) ~= "string" then self = tostring(self or "") end

	-- Replace hyphens and underscores with spaces
	local result = string_gsub(self, "[-_]+", " ")

	-- Capitalize first letter of each word
	result = string_gsub(result, "(%S+)", function(word)
		return string_gsub(word, "^%l", string_upper)
	end)

	-- Remove spaces
	result = string_gsub(result, "%s+", "")

	return result
end

string.to_pascal_case = string_to_pascal_case
string.toPascalCase = string_to_pascal_case
string.ToPascalCase = string_to_pascal_case
