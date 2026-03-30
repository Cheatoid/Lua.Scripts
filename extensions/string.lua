-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Localized global functions for better performance
local type = type
local tonumber = tonumber
local tostring = tostring
local string = string
local string_find = string.find
local string_gmatch = string.gmatch
local string_sub = string.sub
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
		if tonumber(key) then
			return string_sub(self, key, key)
		end
	end
end

local iterate_lines_pattern = "[^\n]+"

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
	return string_gmatch(input, iterate_lines_pattern)
end

local carriage_return_char = "\r"
local newline_char = "\n"

--- Split a string into lines and return them as a table.
--- Handles both \n and \r\n line endings properly.
--- @param self string Input string to split into lines.
--- @return table lines Table containing each line as a separate string.
--- @usage <br>
--- ```
--- -- Returns: {"line 1", "line 2", "line 3"}
--- local lines = lines("line 1\nline 2\r\nline 3")
--- for i, line in ipairs(lines) do
---   print(i, line)
--- end
--- ```
function string.lines(self)
	local len = #self -- Total length of the input string
	local lines = {}
	local line_counter = 0
	local pos = 1
	while pos <= len do
		-- Look for the next literal newline character starting at pos (plain search, no pattern matching)
		local newline_start, newline_end = string_find(self, newline_char, pos, true)
		if newline_start then
			local line_end = newline_start - 1
			-- If the character immediately before the newline is a carriage return, adjust lineEnd
			if line_end >= pos and string_sub(self, line_end, line_end) == carriage_return_char then
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
--- for part in iter_explode("a,b,,c,", ",") do
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
--- for part in iter_explode_pattern("a1b2c", "%d") do
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
--- @param size number Size of each chunk (default: 1, must be > 0).
--- @return function iterator Iterator that yields string chunks.
--- @usage <br>
--- ```
--- -- Outputs: "abc", "def", "g"
--- for chunk in iter_chunk_split("abcdefg", 3) do
---   print(chunk)
--- end
--- ```
function string.iter_chunk_split(self, size)
	if type(self) ~= "string" then self = tostring(self or "") end
	size = tonumber(size) or 1
	if size <= 0 then error("size must be > 0") end

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

--- Convert a string to a table of individual characters.
--- Each character in the string becomes a separate table element.
--- @param self string Input string to convert to a table.
--- @return table array Array containing each character as a separate element.
--- @usage <br>
--- ```
--- -- Returns: {"h", "e", "l", "l", "o"}
--- local chars = "hello":to_table()
--- for i, char in ipairs(chars) do
---   print(i, char)
--- end
--- ```
local string_to_table = function(self)
	local tbl = {}
	for i = 1, #self do
		tbl[i] = string_sub(self, i, i)
	end
	return tbl
end
string.to_table = string_to_table

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
--- -- Returns: "Hello World! Hello World!"
--- local result = "Hi there! Hi there!":replace_all("Hi", "Hello")
---
--- -- Returns: "a-b-c-d"
--- local result = "a,b,c,d":replace_all(",", "-")
---
--- -- No changes when search value not found
--- local result = "hello":replace_all("x", "y")  -- Returns: "hello"
--- ```
function string.replace_all(self, search_value, replace_value)
	local tbl = string_explode(self, search_value)
	return next(tbl) and table_concat(tbl, replace_value) or self
end

--- Check if a string starts with the specified prefix.
--- @param self string Input string to check.
--- @param start string Prefix to search for at the beginning of the string.
--- @return boolean boolean True if the string starts with the prefix, false otherwise.
--- @usage <br>
--- ```
--- -- Returns: true
--- local result = "hello world":starts_with("hello")
---
--- -- Returns: false
--- local result = "hello world":starts_with("world")
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
--- -- Returns: true
--- local result = "hello world":ends_with("world")
---
--- -- Returns: false
--- local result = "hello world":ends_with("hello")
--- ```
local string_ends_with = function(self, endStr)
	return endStr == "" or string_sub(self, - #endStr) == endStr
end
string.ends_with = string_ends_with
string.EndsWith = string_ends_with
