-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

--- Bit manipulation compatibility library for Lua 5.3+ (when running legacy scripts).<br>
--- Bitwise operations are performed without masking in this module.
local bit = {}

--- Bitwise AND operation
---@param x integer First operand
---@param y integer Second operand
---@return integer # Result of x & y
function bit.band(x, y)
	return x & y
end

--- Bitwise OR operation
---@param x integer First operand
---@param y integer Second operand
---@return integer # Result of x | y
function bit.bor(x, y)
	return x | y
end

--- Bitwise XOR operation
---@param x integer First operand
---@param y integer Second operand
---@return integer # Result of x ~ y
function bit.bxor(x, y)
	return x ~ y
end

--- Bitwise NOT operation
---@param x integer Operand
---@return integer # Result of ~x (signed)
function bit.bnot(x)
	return ~x
end

--- Left shift operation
---@param x integer Value to shift
---@param n integer Number of bits to shift left
---@return integer # Result of x << n
function bit.lshift(x, n)
	return x << n
end

--- Right shift operation (logical)
---@param x integer Value to shift
---@param n integer Number of bits to shift right
---@return integer # Result of x >> n
function bit.rshift(x, n)
	return x >> n
end

--- Arithmetic right shift operation
---@param x integer Value to shift
---@param n integer Number of bits to shift right
---@return integer # Result of arithmetic right shift
function bit.arshift(x, n)
	-- For positive numbers, same as logical shift
	if x >= 0 then
		return x >> n
	end
	-- For negative numbers, preserve sign bit
	local mask = (1 << (32 - n)) - 1
	return ((x >> n) & ~mask) | (x & mask)
end

--- Circular left rotation
---@param x integer Value to rotate
---@param n integer Number of bits to rotate
---@return integer # Result of circular left rotation
function bit.rol(x, n)
	n = n & 31
	return ((x << n) & 0xffffffff) | (x >> (32 - n))
end

--- Circular right rotation
---@param x integer Value to rotate
---@param n integer Number of bits to rotate
---@return integer # Result of circular right rotation
function bit.ror(x, n)
	n = n & 31
	return (x >> n) | ((x << (32 - n)) & 0xffffffff)
end

--- Swap bytes in 32-bit value
---@param x integer 32-bit value
---@return integer # Byte-swapped value
function bit.bswap(x)
	return ((x & 0xff) << 24) | ((x & 0xff00) << 8) | ((x >> 8) & 0xff00) | ((x >> 24) & 0xff)
end

--- Extract bits from a value
---@param x integer Source value
---@return integer # Extracted bits
function bit.tobit(x)
	x = x & 0xffffffff
	return x >= 0x80000000 and x - 0x100000000 or x
end

do
	local string_format, string_rep = string.format, string.rep

	--- Convert to unsigned 32-bit integer hex string
	---@param x integer Value to convert
	---@return string # Unsigned 32-bit integer hex string
	function bit.tohex(x, n)
		local hex = string_format("%x", x & 0xffffffff)
		return string_rep("0", (n or 8) - #hex) .. hex
	end
end

-- Export
--_G.bit = bit
return bit
