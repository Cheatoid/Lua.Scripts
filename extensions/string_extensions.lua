-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Localized global functions for better performance
local type = type
local tonumber = tonumber
local tostring = tostring

-- Localized frequently used string functions for better performance
local string = string
local string_find = string.find
local string_sub = string.sub
local string_gmatch = string.gmatch

-- Hijack string metatable
if debug and debug.getmetatable then
	local STRING = debug.getmetatable("")
	local STRING_index = STRING.__index or string
	function STRING.__index(self, index, ...)
		-- string[index] ==> string.sub(string, index, index)
		if type(index) == "number" then
			return string_sub(self, index, index)
		end
		return STRING_index(self, index, ...)
	end
end

local iterateLinesPattern = "[^\n]+"

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
	return string_gmatch(input, iterateLinesPattern)
end

local carriageReturnChar = "\r"
local newlineChar = "\n"

--- Split a string into lines and return them as a table.
--- Handles both \n and \r\n line endings properly.
--- @param input string Input string to split into lines.
--- @return table lines Table containing each line as a separate string.
--- @usage <br>
--- ```
--- -- Returns: {"line 1", "line 2", "line 3"}
--- local lines = lines("line 1\nline 2\r\nline 3")
--- for i, line in ipairs(lines) do
---   print(i, line)
--- end
--- ```
function string.lines(input)
	local len = #input --string_len(input) -- Total length of the input string
	local lines = {}
	local lineCounter = 0
	local pos = 1
	while pos <= len do
		-- Look for the next literal newline character starting at pos
		local newlineStart, newlineEnd = string_find(input, newlineChar, pos, true) -- plain search, no pattern matching
		if newlineStart then
			local lineEnd = newlineStart - 1
			-- If the character immediately before the newline is a carriage return, adjust lineEnd
			if lineEnd >= pos and string_sub(input, lineEnd, lineEnd) == carriageReturnChar then
				lineEnd = lineEnd - 1
			end
			lineCounter = lineCounter + 1
			lines[lineCounter] = string_sub(input, pos, lineEnd)
			pos = newlineEnd + 1
		else
			-- No more newline found; capture the rest of the string
			lineCounter = lineCounter + 1
			lines[lineCounter] = string_sub(input, pos)
			break
		end
	end
	return lines
end

--- Split a string using a plain separator and return an iterator.
--- The separator is treated as plain text (not a pattern).
--- @param s string Input string to split.
--- @param sep string Plain separator used to split (default: ",").
--- @return function iterator Iterator that yields string parts.
--- @usage <br>
--- ```
--- -- Outputs: "a", "b", "", "c", ""
--- for part in iter_explode("a,b,,c,", ",") do
---   print(part)
--- end
--- ```
function string.iter_explode(s, sep)
	if type(s) ~= "string" then s = tostring(s or "") end
	sep = sep or ","
	if type(sep) ~= "string" then sep = tostring(sep) end

	local len = #s
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

		local a, b = string_find(s, sep, start, true)
		if not a then
			-- last field (remainder)
			local res = string_sub(s, start, len)
			start = len + 1
			return res
		end

		local res = string_sub(s, start, a - 1)
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
--- @param s string Input string to split.
--- @param pat string Lua pattern used as separator (default: ",").
--- @return function iterator Iterator that yields string parts.
--- @usage <br>
--- ```
--- -- Outputs: "a", "b", "c"
--- for part in iter_explode_pattern("a1b2c", "%d") do
---   print(part)
--- end
--- ```
function string.iter_explode_pattern(s, pat)
	if type(s) ~= "string" then s = tostring(s or "") end
	pat = pat or ","
	if type(pat) ~= "string" then pat = tostring(pat) end

	local len = #s
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

		local a, b = string_find(s, pat, start)
		if not a then
			local res = string_sub(s, start, len)
			start = len + 1
			return res
		end

		local res = string_sub(s, start, a - 1)
		start = b + 1
		if start > len then
			pending_trailing_empty = true
		end
		return res
	end
end

--- Split a string into fixed-size chunks and return an iterator.
--- @param s string Input string to split into chunks.
--- @param size number Size of each chunk (default: 1, must be > 0).
--- @return function iterator Iterator that yields string chunks.
--- @usage <br>
--- ```
--- -- Outputs: "abc", "def", "g"
--- for chunk in iter_chunk_split("abcdefg", 3) do
---   print(chunk)
--- end
--- ```
function string.iter_chunk_split(s, size)
	if type(s) ~= "string" then s = tostring(s or "") end
	size = tonumber(size) or 1
	if size <= 0 then error("size must be > 0") end

	local len = #s
	local pos = 1

	return function()
		if pos > len then return nil end
		local e = pos + size - 1
		if e > len then e = len end
		local res = string_sub(s, pos, e)
		pos = e + 1
		return res
	end
end
