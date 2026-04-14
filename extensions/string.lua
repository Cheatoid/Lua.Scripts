-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Extend the string-type. This enables custom syntax such as string+string.
-- Tip: Do not import this, unless you are actually going to use such syntax.

-- Localized global functions for better performance
local getmetatable = getmetatable
local tonumber = tonumber
local tostring = tostring
local math_floor = math.floor
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

-- concatenate: string + string
STRING.__add = function(left, right)
	return left .. right
end

-- repeat: string * integer
STRING.__mul = function(left, right)
	return string_rep(left, right)
end

-- rotate right: string >> integer
STRING.__shr = function(left, right)
	-- string.rotate_right(string, integer)
	left = tostring(left or "")
	local len = #left
	if len == 0 then return left end
	-- floor toward -inf like Lua integer semantics for shifts
	local k = math_floor(tonumber(right) or 0) % len
	if k == 0 then return left end
	return string_sub(left, -k) .. string_sub(left, 1, len - k)
end

-- rotate left: string << integer
STRING.__shl = function(left, right)
	-- string.rotate_left(string, integer)
	left = tostring(left or "")
	local len = #left
	if len == 0 then return left end
	-- floor toward -inf like Lua integer semantics for shifts
	local k = math_floor(tonumber(right) or 0) % len
	if k == 0 then return left end
	return string_sub(left, k + 1) .. string_sub(left, 1, k)
end

-- Export (for compatibility)
return STRING
