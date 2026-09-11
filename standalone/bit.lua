-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

--[[
Complete 32-bit bitwise operations library for LuaJIT/5.1+ and later.
This module does not use native bitwise operations for band/bor/bxor, instead it uses fold for vararg support.
Also, bnot is masked (it returns unsigned integer).
It is also more feature-rich than bits/bitwise module.

Implements the full bit32 library API from Lua 5.2 plus extras:

Core:
band(a, ...) Bitwise AND (vararg)
bor(a, ...) Bitwise OR (vararg)
bxor(a, ...) Bitwise XOR (vararg)
bnot(a) Bitwise NOT

Shifts:
lshift(a, disp) Logical left shift
rshift(a, disp) Logical right shift
arshift(a, disp) Arithmetic right shift (sign-extending)

Rotates:
rol(a, disp) Rotate left
ror(a, disp) Rotate right

Test & fields:
btest(a, ...) True if band(a, ...) ~= 0
extract(f, w, [o]) Extract width-bits at offset
replace(f, v, w, [o]) Replace width-bits at offset

Counts:
countlz(a) Count leading zeros (0..32)
countrz(a) Count trailing zeros (0..32)
popcount(a) Population count (number of 1-bits)

Bytes:
bswap(a) Reverse byte order
getbyte(a, i) Get byte at index 0..3 (0 = LSB)
setbyte(a, v, i) Set byte at index 0..3

Conversion:
tosigned(a) Interpret as signed (-2^31 .. 2^31-1)
tounsigned(a) Normalize to unsigned 0..2^32-1
frombytes(b0,b1,b2,b3) Four bytes -> u32 (b0 = LSB)
tobytes(a) u32 -> four bytes (b0 = LSB)
tohex(a, [prefix]) u32 -> "0xDEADBEEF"
fromhex(s) "DEADBEEF" / "0xDEADBEEF" -> u32

Binary I/O:
pack_le(a) u32 -> 4-byte little-endian string
pack_be(a) u32 -> 4-byte big-endian string
unpack_le(s, [i]) 4-byte LE string -> u32
unpack_be(s, [i]) 4-byte BE string -> u32

8-bit:
pack_i8(a) i8 -> 1-byte string
pack_u8(a) u8 -> 1-byte string
unpack_i8(s, [i]) 1-byte string -> i8 (-128..127)
unpack_u8(s, [i]) 1-byte string -> u8 (0..255)

16-bit:
pack_i16_le(a) i16 -> 2-byte little-endian string
pack_i16_be(a) i16 -> 2-byte big-endian string
pack_u16_le(a) u16 -> 2-byte little-endian string
pack_u16_be(a) u16 -> 2-byte big-endian string
unpack_i16_le(s, [i]) 2-byte LE string -> i16 (-32768..32767)
unpack_i16_be(s, [i]) 2-byte BE string -> i16 (-32768..32767)
unpack_u16_le(s, [i]) 2-byte LE string -> u16 (0..65535)
unpack_u16_be(s, [i]) 2-byte BE string -> u16 (0..65535)

All values are treated as 32-bit unsigned integers (0 .. 0xFFFFFFFF).
Out-of-range inputs are masked automatically.

Usage:
```
local bit = require "standalone/bit"

local a = bit.band(0xFF00FF00, 0x0F0F0F0F) -- 0x00000000
local b = bit.bor(0xFF00, 0x00FF) -- 0x0000FFFF
local c = bit.lshift(1, 8) -- 0x00000100
local d = bit.popcount(0xFF00FF00) -- 16

-- Drop-in bit32 replacement:
bit32 = require "standalone/bit"
```
]]

-- Localized global functions for better performance
local error = error
local type = type
local tonumber = tonumber
local math_floor = math.floor
local string_byte = string.byte
local string_char = string.char
local string_match = string.match
local string_sub = string.sub
local string_upper = string.upper
local table_concat = table.concat

-- Import dependencies
local bits = require "bits"
local fold = require "fold"

-- Constants
local WIDTH = 32
local MOD = 4294967296      -- 2^32
local ALL_ONES = 0xFFFFFFFF -- 2^32 - 1
local HIGH_BIT = 0x80000000 -- 2^31

-- My precious forward declarations for performance
local band, bor, bxor, bnot
local lshift, rshift, arshift
local rol, ror
local btest, extract, replace
local countlz, countrz, popcount
local bswap, getbyte, setbyte
local tosigned, tounsigned, frombytes, tobytes
local tohex, fromhex
local pack_le, pack_be, unpack_le, unpack_be

-- Use native bitwise operations when available
local detected_runtime = require("detect_runtime")()
if detected_runtime.actual_major >= 5 and detected_runtime.actual_minor >= 3 then
	-- NOTE: do not use native band/bor/bxor/bnot in this module
	lshift, rshift, arshift = bits.lshift, bits.rshift, bits.arshift
	rol, ror = bits.rol, bits.ror
	bswap = bits.bswap
end

--- Internal: normalize any value to unsigned 32-bit integer
local function u32(n)
	n = tonumber(n) or 0
	if n < 0 then
		n = n % MOD         -- 2's complement wrap for negatives
	end
	return math_floor(n) % MOD -- truncate + mask
end

----------------------------------------------------------------------
-- Binary operation helpers
----------------------------------------------------------------------

local function op_and(x, y)
	x, y = u32(x), u32(y)
	local r, b = 0, 1
	while x > 0 or y > 0 do
		if x % 2 == 1 and y % 2 == 1 then
			r = r + b
		end
		x = math_floor(x * 0.5)
		y = math_floor(y * 0.5)
		b = b * 2
	end
	return r
end

local function op_or(x, y)
	x, y = u32(x), u32(y)
	local r, b = 0, 1
	while x > 0 or y > 0 do
		if x % 2 == 1 or y % 2 == 1 then
			r = r + b
		end
		x = math_floor(x * 0.5)
		y = math_floor(y * 0.5)
		b = b * 2
	end
	return r
end

local function op_xor(x, y)
	x, y = u32(x), u32(y)
	local r, b = 0, 1
	while x > 0 or y > 0 do
		local xa, ya = x % 2, y % 2
		if xa ~= ya then
			r = r + b
		end
		x = math_floor(x * 0.5)
		y = math_floor(y * 0.5)
		b = b * 2
	end
	return r
end

----------------------------------------------------------------------
-- Core bitwise operations
----------------------------------------------------------------------

--- Bitwise AND of one or more values
---@param a integer First operand
---@param ... integer Additional operands
---@return integer # Result of bitwise AND
band = function(a, ...)
	a = u32(a)
	return fold(op_and, a, ...)
end

--- Bitwise OR of one or more values
---@param a integer First operand
---@param ... integer Additional operands
---@return integer # Result of bitwise OR
bor = function(a, ...)
	a = u32(a)
	return fold(op_or, a, ...)
end

--- Bitwise XOR of one or more values
---@param a integer First operand
---@param ... integer Additional operands
---@return integer # Result of bitwise XOR
bxor = function(a, ...)
	a = u32(a)
	return fold(op_xor, a, ...)
end

--- Bitwise NOT (1's complement, unsigned)
---@param a integer Operand
---@return integer # Result of bitwise NOT
bnot = function(a)
	return u32(ALL_ONES - u32(a))
end

----------------------------------------------------------------------
-- Shift operations
----------------------------------------------------------------------

--- Logical left shift
---@param a integer Value to shift
---@param disp integer Number of bits to shift left
---@return integer # Result of left shift
lshift = lshift or function(a, disp)
	a = u32(a)
	disp = math_floor(tonumber(disp) or 0)
	if disp >= WIDTH then return 0 end
	if disp <= -WIDTH then return 0 end
	if disp < 0 then return rshift(a, -disp) end
	return u32(a * (2 ^ disp))
end

--- Logical right shift (zero-fill)
---@param a integer Value to shift
---@param disp integer Number of bits to shift right
---@return integer # Result of right shift
rshift = rshift or function(a, disp)
	a = u32(a)
	disp = math_floor(tonumber(disp) or 0)
	if disp >= WIDTH then return 0 end
	if disp <= -WIDTH then return 0 end
	if disp < 0 then return lshift(a, -disp) end
	return math_floor(a / (2 ^ disp))
end

--- Arithmetic right shift (sign-extending)
---@param a integer Value to shift
---@param disp integer Number of bits to shift right
---@return integer # Result of arithmetic right shift
arshift = arshift or function(a, disp)
	a = u32(a)
	disp = math_floor(tonumber(disp) or 0)

	if disp >= WIDTH then
		return (a >= HIGH_BIT) and ALL_ONES or 0
	end
	if disp <= -WIDTH then
		return 0
	end
	if disp < 0 then
		return lshift(a, -disp)
	end
	if disp == 0 then
		return a
	end

	if a >= HIGH_BIT then
		-- Sign bit set: logical shift + fill high bits with 1s
		local shifted = math_floor(a / (2 ^ disp))
		local sign_mask = ALL_ONES - u32((2 ^ (WIDTH - disp)) - 1)
		return u32(bor(shifted, sign_mask))
	end

	return math_floor(a / (2 ^ disp))
end

----------------------------------------------------------------------
-- Rotate operations
----------------------------------------------------------------------

--- Rotate left
---@param a integer Value to rotate
---@param disp integer Number of bits to rotate
---@return integer # Result of rotate left
rol = rol or function(a, disp)
	a = u32(a)
	disp = math_floor(tonumber(disp) or 0) % WIDTH
	if disp < 0 then disp = disp + WIDTH end
	if disp == 0 then return a end

	local left = u32(a * (2 ^ disp))
	local right = math_floor(a / (2 ^ (WIDTH - disp)))
	return u32(bor(left, right))
end

--- Rotate right
---@param a integer Value to rotate
---@param disp integer Number of bits to rotate
---@return integer # Result of rotate right
ror = ror or function(a, disp)
	a = u32(a)
	disp = math_floor(tonumber(disp) or 0) % WIDTH
	if disp < 0 then disp = disp + WIDTH end
	if disp == 0 then return a end

	local right = math_floor(a / (2 ^ disp))
	local left = u32(a * (2 ^ (WIDTH - disp)))
	return u32(bor(left, right))
end

----------------------------------------------------------------------
-- Test & bit-field operations
----------------------------------------------------------------------

--- Boolean test: returns true if band(a, ...) ~= 0
---@param a integer First operand
---@param ... integer Additional operands
---@return boolean # True if result is non-zero
btest = function(a, ...)
	return band(a, ...) ~= 0
end

--- Extract a bit field
---@param field integer Source integer
---@param width integer Field width in bits (1..32)
---@param offset integer Bit offset from LSB (default 0)
---@return integer # Extracted value
extract = function(field, width, offset)
	field = u32(field)
	width = tonumber(width)
	if not width then return error("width is required", 2) end
	offset = tonumber(offset) or 0

	if width < 0 or width > WIDTH then
		return error("bad argument #2 to 'extract' (width in 0..32)", 2)
	end
	offset = math_floor(offset) % WIDTH
	if width + offset > WIDTH then
		return error("bad argument #2 to 'extract' (width+offset overflow 32)", 2)
	end
	if width == 0 then return 0 end

	local mask = u32((2 ^ width) - 1)
	return rshift(band(field, lshift(mask, offset)), offset)
end

--- Replace a bit field
---@param field integer Source integer
---@param value integer Replacement value (masked to width bits)
---@param width integer Field width in bits (1..32)
---@param offset integer Bit offset from LSB (default 0)
---@return integer # Result with field replaced
replace = function(field, value, width, offset)
	field = u32(field)
	value = u32(value)
	width = tonumber(width)
	if not width then return error("width is required", 2) end
	offset = tonumber(offset) or 0

	if width < 0 or width > WIDTH then
		return error("bad argument #3 to 'replace' (width in 0..32)", 2)
	end
	offset = math_floor(offset) % WIDTH
	if width + offset > WIDTH then
		return error("bad argument #3 to 'replace' (width+offset overflow 32)", 2)
	end
	if width == 0 then return field end

	local mask = lshift(u32((2 ^ width) - 1), offset)
	local v = lshift(value % (2 ^ width), offset)
	return bor(band(field, bnot(mask)), v)
end

----------------------------------------------------------------------
-- Count operations
----------------------------------------------------------------------

--- Count leading zero bits
---@param a integer Value to count
---@return integer # Number of leading zeros (0..32, 32 if a == 0)
countlz = function(a)
	a = u32(a)
	if a == 0 then return WIDTH end
	local count = 0
	for i = WIDTH - 1, 0, -1 do
		if a >= (2 ^ i) then
			return count
		end
		count = count + 1
	end
	return count -- unreachable for a > 0, but satisfies lint
end

--- Count trailing zero bits
---@param a integer Value to count
---@return integer # Number of trailing zeros (0..32, 32 if a == 0)
countrz = function(a)
	a = u32(a)
	if a == 0 then return WIDTH end
	local count = 0
	while a % 2 == 0 do
		count = count + 1
		a = math_floor(a * 0.5)
	end
	return count
end

--- Population count (number of set bits)
---@param a integer Value to count
---@return integer # Number of set bits (0..32)
popcount = function(a)
	a = u32(a)
	local count = 0
	while a > 0 do
		count = count + (a % 2)
		a = math_floor(a * 0.5)
	end
	return count
end

----------------------------------------------------------------------
-- Byte operations
----------------------------------------------------------------------

--- Reverse byte order (big-endian <-> little-endian)
---@param a integer 32-bit value
---@return integer # Byte-swapped value
bswap = bswap or function(a)
	a = u32(a)
	return bor(
		lshift(band(a, 0x000000FF), 24),
		lshift(band(rshift(a, 8), 0xFF), 16),
		lshift(band(rshift(a, 16), 0xFF), 8),
		band(rshift(a, 24), 0xFF)
	)
end

--- Get byte at index (0 = LSB, 3 = MSB)
---@param a integer 32-bit value
---@param index integer Byte index (0..3)
---@return integer # Byte value (0..255)
getbyte = function(a, index)
	a = u32(a)
	index = math_floor(tonumber(index) or 0) % 4
	return band(rshift(a, index * 8), 0xFF)
end

--- Set byte at index (0 = LSB, 3 = MSB)
---@param a integer 32-bit value
---@param value integer Byte value to set (0..255)
---@param index integer Byte index (0..3)
---@return integer # Result with byte set
setbyte = function(a, value, index)
	a = u32(a)
	value = u32(value) % 256
	index = math_floor(tonumber(index) or 0) % 4
	local mask = bnot(lshift(0xFF, index * 8))
	local cleared = band(a, mask)
	return bor(cleared, lshift(value, index * 8))
end

----------------------------------------------------------------------
-- Conversion: signed / unsigned
----------------------------------------------------------------------

--- Interpret a u32 as a signed 32-bit integer
---@param a integer Unsigned 32-bit value
---@return integer # Signed integer (-2^31 .. 2^31-1)
tosigned = function(a)
	a = u32(a)
	if a >= HIGH_BIT then
		return a - MOD
	end
	return a
end

--- Normalize any number to unsigned 32-bit
---@param a number Value to normalize
---@return integer # Unsigned 32-bit integer (0..2^32-1)
tounsigned = function(a)
	return u32(a)
end

----------------------------------------------------------------------
-- Conversion: byte arrays
----------------------------------------------------------------------

--- Build a u32 from four bytes (b0 = LSB, b3 = MSB)
---@param b0 integer Byte 0 (LSB)
---@param b1 integer Byte 1
---@param b2 integer Byte 2
---@param b3 integer Byte 3 (MSB)
---@return integer # 32-bit value
frombytes = function(b0, b1, b2, b3)
	return bor(
		lshift(u32(b3) % 256, 24),
		lshift(u32(b2) % 256, 16),
		lshift(u32(b1) % 256, 8),
		u32(b0) % 256
	)
end

--- Split a u32 into four bytes
---@param a integer 32-bit value
---@return integer # Byte 0 (LSB)
---@return integer # Byte 1
---@return integer # Byte 2
---@return integer # Byte 3 (MSB)
tobytes = function(a)
	a = u32(a)
	return
		band(a, 0xFF),
		band(rshift(a, 8), 0xFF),
		band(rshift(a, 16), 0xFF),
		band(rshift(a, 24), 0xFF)
end

----------------------------------------------------------------------
-- Conversion: hexadecimal strings
----------------------------------------------------------------------

local HEX = "0123456789ABCDEF"

--- Convert u32 to hexadecimal string
---@param a integer 32-bit value
---@param prefix boolean Include "0x" prefix (default true)
---@return string # Hexadecimal string (e.g. "0xDEADBEEF")
tohex = function(a, prefix)
	a = u32(a)
	prefix = (prefix ~= false)

	local parts = {}
	for i = 7, 0, -1 do
		local nibble = band(rshift(a, i * 4), 0xF) + 1
		parts[#parts + 1] = string_sub(HEX, nibble, nibble)
	end

	local hex = table_concat(parts)
	return prefix and ("0x" .. hex) or hex
end

--- Parse a hexadecimal string to u32
---@param s string Hexadecimal string (e.g. "DEADBEEF" or "0xdeadbeef")
---@return integer # 32-bit value
fromhex = function(s)
	if type(s) ~= "string" then
		return error("bad argument #1 to 'fromhex' (string expected)", 2)
	end

	-- Strip optional 0x / 0X prefix
	if string_sub(s, 1, 2) == "0x" or string_sub(s, 1, 2) == "0X" then
		s = string_sub(s, 3)
	end

	-- Strip leading zeros (capture remaining; may be empty)
	s = string_match(s, "^0*(.-)$") or ""
	if s == "" then return 0 end

	-- Limit to 8 hex digits (32 bits); take rightmost 8
	if #s > 8 then
		s = string_sub(s, #s - 7)
	end

	local result = 0
	for i = 1, #s do
		local c = string_upper(string_sub(s, i, i))
		local n
		if c >= "0" and c <= "9" then
			n = tonumber(c)
		elseif c >= "A" and c <= "F" then
			n = string_byte(c) - string_byte("A") + 10
		else
			return error("bad argument #1 to 'fromhex' (invalid hex char '" .. c .. "')", 2)
		end
		result = result * 16 + n
	end
	return u32(result)
end

----------------------------------------------------------------------
-- Binary pack / unpack
----------------------------------------------------------------------

--- Pack u32 into a 4-byte little-endian string
---@param a integer 32-bit value
---@return string # 4-byte little-endian string
pack_le = function(a)
	a = u32(a)
	return string_char(
		band(a, 0xFF),
		band(rshift(a, 8), 0xFF),
		band(rshift(a, 16), 0xFF),
		band(rshift(a, 24), 0xFF)
	)
end

--- Pack u32 into a 4-byte big-endian string
---@param a integer 32-bit value
---@return string # 4-byte big-endian string
pack_be = function(a)
	a = u32(a)
	return string_char(
		band(rshift(a, 24), 0xFF),
		band(rshift(a, 16), 0xFF),
		band(rshift(a, 8), 0xFF),
		band(a, 0xFF)
	)
end

--- Unpack a u32 from a 4-byte little-endian string
---@param s string String of at least 4 bytes
---@param i integer Starting byte index (default 1)
---@return integer # 32-bit value
unpack_le = function(s, i)
	if type(s) ~= "string" or #s < ((i or 1) + 3) then
		return error("bad argument #1 to 'unpack_le' (string too short)", 2)
	end
	i = i or 1
	return bor(
		string_byte(s, i),
		lshift(string_byte(s, i + 1), 8),
		lshift(string_byte(s, i + 2), 16),
		lshift(string_byte(s, i + 3), 24)
	)
end

--- Unpack a u32 from a 4-byte big-endian string
---@param s string String of at least 4 bytes
---@param i integer Starting byte index (default 1)
---@return integer # 32-bit value
unpack_be = function(s, i)
	if type(s) ~= "string" or #s < ((i or 1) + 3) then
		return error("bad argument #1 to 'unpack_be' (string too short)", 2)
	end
	i = i or 1
	return bor(
		lshift(string_byte(s, i), 24),
		lshift(string_byte(s, i + 1), 16),
		lshift(string_byte(s, i + 2), 8),
		string_byte(s, i + 3)
	)
end

----------------------------------------------------------------------
-- 8-bit pack / unpack
----------------------------------------------------------------------

--- Pack a signed 8-bit integer into a 1-byte string
---@param a integer Signed 8-bit value (-128 .. 127)
---@return string # 1-byte string
pack_i8 = function(a)
	a = tonumber(a) or 0
	if a < 0 then a = a + 256 end
	return string_char(a % 256)
end

--- Pack an unsigned 8-bit integer into a 1-byte string
---@param a integer Unsigned 8-bit value (0 .. 255)
---@return string # 1-byte string
pack_u8 = function(a)
	a = u32(a) % 256
	return string_char(a)
end

--- Unpack a signed 8-bit integer from a 1-byte string
---@param s string String of at least 1 byte
---@param i integer Starting byte index (default 1)
---@return integer # Signed 8-bit value (-128 .. 127)
unpack_i8 = function(s, i)
	if type(s) ~= "string" or #s < (i or 1) then
		return error("bad argument #1 to 'unpack_i8' (string too short)", 2)
	end
	i = i or 1
	local v = string_byte(s, i)
	if v >= 128 then v = v - 256 end
	return v
end

--- Unpack an unsigned 8-bit integer from a 1-byte string
---@param s string String of at least 1 byte
---@param i integer Starting byte index (default 1)
---@return integer # Unsigned 8-bit value (0 .. 255)
unpack_u8 = function(s, i)
	if type(s) ~= "string" or #s < (i or 1) then
		return error("bad argument #1 to 'unpack_u8' (string too short)", 2)
	end
	i = i or 1
	return string_byte(s, i)
end

----------------------------------------------------------------------
-- 16-bit pack / unpack
----------------------------------------------------------------------

--- Pack a signed 16-bit integer into a 2-byte little-endian string
---@param a integer Signed 16-bit value (-32768 .. 32767)
---@return string # 2-byte little-endian string
pack_i16_le = function(a)
	a = tonumber(a) or 0
	if a < 0 then a = a + 65536 end
	a = a % 65536
	return string_char(band(a, 0xFF), band(rshift(a, 8), 0xFF))
end

--- Pack a signed 16-bit integer into a 2-byte big-endian string
---@param a integer Signed 16-bit value (-32768 .. 32767)
---@return string # 2-byte big-endian string
pack_i16_be = function(a)
	a = tonumber(a) or 0
	if a < 0 then a = a + 65536 end
	a = a % 65536
	return string_char(band(rshift(a, 8), 0xFF), band(a, 0xFF))
end

--- Pack an unsigned 16-bit integer into a 2-byte little-endian string
---@param a integer Unsigned 16-bit value (0 .. 65535)
---@return string # 2-byte little-endian string
pack_u16_le = function(a)
	a = u32(a) % 65536
	return string_char(band(a, 0xFF), band(rshift(a, 8), 0xFF))
end

--- Pack an unsigned 16-bit integer into a 2-byte big-endian string
---@param a integer Unsigned 16-bit value (0 .. 65535)
---@return string # 2-byte big-endian string
pack_u16_be = function(a)
	a = u32(a) % 65536
	return string_char(band(rshift(a, 8), 0xFF), band(a, 0xFF))
end

--- Unpack a signed 16-bit integer from a 2-byte little-endian string
---@param s string String of at least 2 bytes
---@param i integer Starting byte index (default 1)
---@return integer # Signed 16-bit value (-32768 .. 32767)
unpack_i16_le = function(s, i)
	if type(s) ~= "string" or #s < ((i or 1) + 1) then
		return error("bad argument #1 to 'unpack_i16_le' (string too short)", 2)
	end
	i = i or 1
	local v = bor(string_byte(s, i), lshift(string_byte(s, i + 1), 8))
	if v >= 32768 then v = v - 65536 end
	return v
end

--- Unpack a signed 16-bit integer from a 2-byte big-endian string
---@param s string String of at least 2 bytes
---@param i integer Starting byte index (default 1)
---@return integer # Signed 16-bit value (-32768 .. 32767)
unpack_i16_be = function(s, i)
	if type(s) ~= "string" or #s < ((i or 1) + 1) then
		return error("bad argument #1 to 'unpack_i16_be' (string too short)", 2)
	end
	i = i or 1
	local v = bor(lshift(string_byte(s, i), 8), string_byte(s, i + 1))
	if v >= 32768 then v = v - 65536 end
	return v
end

--- Unpack an unsigned 16-bit integer from a 2-byte little-endian string
---@param s string String of at least 2 bytes
---@param i integer Starting byte index (default 1)
---@return integer # Unsigned 16-bit value (0 .. 65535)
unpack_u16_le = function(s, i)
	if type(s) ~= "string" or #s < ((i or 1) + 1) then
		return error("bad argument #1 to 'unpack_u16_le' (string too short)", 2)
	end
	i = i or 1
	return bor(string_byte(s, i), lshift(string_byte(s, i + 1), 8))
end

--- Unpack an unsigned 16-bit integer from a 2-byte big-endian string
---@param s string String of at least 2 bytes
---@param i integer Starting byte index (default 1)
---@return integer # Unsigned 16-bit value (0 .. 65535)
unpack_u16_be = function(s, i)
	if type(s) ~= "string" or #s < ((i or 1) + 1) then
		return error("bad argument #1 to 'unpack_u16_be' (string too short)", 2)
	end
	i = i or 1
	return bor(lshift(string_byte(s, i), 8), string_byte(s, i + 1))
end

-- Export
return {
	WIDTH = WIDTH,
	MAXVALUE = ALL_ONES,
	HIGH_BIT = HIGH_BIT,
	u32 = u32,
	band = band,
	bor = bor,
	bxor = bxor,
	bnot = bnot,
	lshift = lshift,
	rshift = rshift,
	arshift = arshift,
	rol = rol,
	ror = ror,
	btest = btest,
	extract = extract,
	replace = replace,
	countlz = countlz,
	countrz = countrz,
	popcount = popcount,
	bswap = bswap,
	getbyte = getbyte,
	setbyte = setbyte,
	tosigned = tosigned,
	tounsigned = tounsigned,
	frombytes = frombytes,
	tobytes = tobytes,
	tohex = tohex,
	fromhex = fromhex,
	pack_le = pack_le,
	pack_be = pack_be,
	unpack_le = unpack_le,
	unpack_be = unpack_be,
	pack_i8 = pack_i8,
	pack_u8 = pack_u8,
	unpack_i8 = unpack_i8,
	unpack_u8 = unpack_u8,
	pack_i16_le = pack_i16_le,
	pack_i16_be = pack_i16_be,
	pack_u16_le = pack_u16_le,
	pack_u16_be = pack_u16_be,
	unpack_i16_le = unpack_i16_le,
	unpack_i16_be = unpack_i16_be,
	unpack_u16_le = unpack_u16_le,
	unpack_u16_be = unpack_u16_be,
}
