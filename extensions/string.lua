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

-- xor cipher: string ~ string
do
	local string_byte = string.byte
	local string_char = string.char
	local string_gsub = string.gsub

	local bxor
	local ok, fn = pcall(loadstring or load, [[return function(a, b) return a ~ b end]])
	if ok and type(fn) == "function" then
		bxor = fn()
	else
		bxor = function(a, b)
			a, b = a % 256, b % 256
			local res, bit = 0, 1
			while a > 0 or b > 0 do
				if ((a % 2) + (b % 2)) % 2 == 1 then res = res + bit end
				a = math_floor(a * 0.5)
				b = math_floor(b * 0.5)
				bit = bit * 2
			end
			return res
		end
	end

	STRING.__bxor = function(s, k)
		s = tostring(s or "")
		k = tostring(k or "")
		local key_len = #k
		if key_len == 0 then return error("xor cipher key cannot be empty", 2) end
		return (string_gsub(s, '()(.)', function(i, x)
			local ki = ((i - 1) % key_len) + 1
			return string_char(bxor(string_byte(x), string_byte(k, ki, ki)))
		end))
	end
end

-- Export (for compatibility)
return STRING
