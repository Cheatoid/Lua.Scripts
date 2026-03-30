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
local string_match = string.match
local string_rep = string.rep
local string_sub = string.sub
local math_random = math.random
local table_concat = table.concat

-- Hijack string metatable
if debug and debug.getmetatable then
	-- if debug.getmetatable is available, use it instead
	local STRING = debug.getmetatable("")
	local STRING_index = STRING.__index or string
	function STRING.__index(self, key, ...)
		local value = string[key]
		if value ~= nil then
			return value
		end
		-- string[key] ==> string.sub(string, key, key)
		if tonumber(key) then
			return string_sub(self, key, key)
		end
		return STRING_index(self, key, ...)
	end
else
	local STRING = getmetatable("")
	function STRING.__index(self, key)
		local value = string[key]
		if value ~= nil then
			return value
		end
		-- string[key] ==> string.sub(string, key, key)
		if tonumber(key) then
			return string_sub(self, key, key)
		end
	end
end

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
function string.iterate_lines(input)
	return string_gmatch(input, ITERATE_LINES_PATTERN)
end

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
function string.lines(self)
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
function string.iter_explode(self, sep)
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
function string.iter_explode_pattern(self, pat)
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
function string.iter_chunk_split(self, size)
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

--- Split a string into fixed-size chunks and return them as a table.
--- @param self string Input string to split into chunks.
--- @param size integer Size of each chunk (default: 1, must be > 0).
--- @return table array Table containing each chunk as a separate element.
--- @usage <br>
--- ```
--- "abcdefg":chunks(3) -- { "abc", "def", "g" }
--- ```
function string.chunks(self, size)
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

string.Chunks = string.chunks

--- Split a string into fixed-size chunks and return them as a table.
--- Uses a for loop with step size for chunking.
--- @param self string Input string to split into chunks.
--- @param size integer Size of each chunk (must be > 0).
--- @return table array Table containing each chunk as a separate element.
--- @usage <br>
--- ```
--- "abcdefg":chunk(3) -- { "abc", "def", "g" }
--- ```
function string.chunk(self, size)
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

string.Chunk = string.chunk

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
string.ToTable = string.to_table

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
function string.replace(self, search_value, replace_value)
	local tbl = string_explode(self, search_value)
	return next(tbl) and table_concat(tbl, replace_value) or self
end

string.Replace = string.replace

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
--- ```
local pattern_safe = function(str)
	return (string_gsub(str, SAFE_PATTERN, SAFE_PATTERN_ESCAPE))
end

string.pattern_safe = pattern_safe
string.patternSafe = pattern_safe

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
--- ```
local pattern_safe_zero = function(str)
	return (string_gsub(str, ".", PATTERN_SAFE_ESCAPE_REPLACEMENTS))
end

string.pattern_safe_zero = pattern_safe_zero
string.patternSafeZero = pattern_safe_zero

--- Remove leading and trailing characters from a string.
--- @param self string Input string to trim.
--- @param char string|nil Character pattern to trim (default: whitespace "%s").
--- @return string string Trimmed string.
--- @usage <br>
--- ```
--- "  hello  ":trim() -- "hello"
--- "xxhelloxx":trim("x") -- "hello"
--- ```
local string_trim = function(self, char)
	char = char and string_gsub(char, SAFE_PATTERN, SAFE_PATTERN_ESCAPE) or "%s"
	local match = string_match(self, "^" .. char .. "*(.-)" .. char .. "*$")
	return match or self
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
	local match = string_match(self, "^" .. char .. "*(.+)$")
	return match or self
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
	local match = string_match(self, "^(.-)" .. char .. "*$")
	return match or self
end

string.trim_right = string_trim_right
string.trimright = string_trim_right
string.TrimRight = string_trim_right

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

--- Generate a random string of the specified length.
--- @param length integer Length of the random string to generate.
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
	length = tonumber(length) or 0
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
