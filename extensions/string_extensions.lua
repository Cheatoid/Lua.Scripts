-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Localized frequently used string functions for better performance
local string_find = string.find
local string_sub = string.sub
local string_gmatch = string.gmatch

local iterateLinesPattern = "[^\n]+"
local function iterate_lines(input)
	return string_gmatch(input, iterateLinesPattern)
end

local carriageReturnChar = "\r"
local newlineChar = "\n"
local function lines(input)
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
