-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Extend the string-type. This enables custom syntax such as string+string.
-- Tip: Do not import this, unless you are actually going to use such syntax.

-- Localized global functions for better performance
local getmetatable = getmetatable
local tonumber = tonumber
local string = assert(_G.string, "string library is missing")
local string_rep = string.rep
local string_sub = string.sub

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
	-- Preserve indexing into string library
	local value = string[key]
	if value ~= nil then
		return value
	end
	-- string[integer] ==> string.sub(string, integer, integer)
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

-- Export (for compatibility)
return STRING
