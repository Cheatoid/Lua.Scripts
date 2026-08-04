-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Low-level bitwise stuff (what am i doing with my life)... 🤠

local bits = {}

local EXP_BIAS = 1023
local MIN_NORMAL = 2 ^ -1022
local MANT_BITS = 52
local U32 = 4294967296 -- 2 ^ 32 (0x100000000)

local SUBNORMAL_SCALE_1 = 2 ^ 1000
local SUBNORMAL_SCALE_2 = 2 ^ 74

local select = select
--local tonumber = tonumber
--local math_ceil = math.ceil
local math_floor = math.floor
local math_huge = math.huge
local math_log = math.log
local math_modf = math.modf
local LOG2 = math_log(2)
-- ldexp fallback
local ldexp = function(m, e)
	return m * (2.0 ^ e)
end
-- frexp fallback: returns mantissa m in [0.5,1) (or 0) and integer exponent e such that x = m * 2^e
local frexp = function(x)
	if x == 0 then return 0.0, 0 end
	if x ~= x then return 0 / 0, 0 end -- NaN
	if x == math_huge or x == -math_huge then
		return (x < 0) and -0.5 or 0.5, 1024 -- Sentinel exponent for infinities
	end
	local sign = 1
	if x < 0 then
		sign, x = -1, -x
	end
	-- Estimate exponent
	local e = math_floor(math_log(x) / LOG2) + 1
	local m = x / (2 ^ e)
	-- Adjust to ensure m in [0.5, 1)
	if m < 0.5 then
		e = e - 1
		m = m * 2
	elseif m >= 1.0 then
		e = e + 1
		m = m / 2
	end
	return sign * m, e
end
local math_frexp = math.frexp or frexp
local math_ldexp = math.ldexp or ldexp
local string_byte = string.byte
local string_format = string.format
local string_gsub = string.gsub
local string_pack = string.pack     -- Lua 5.3+
local string_sub = string.sub
local string_unpack = string.unpack -- Lua 5.3+
local table_concat = table.concat

local detected_runtime = require("detect_runtime")()

-- Fallback bitwise operations for environments without bit library
local bit
if detected_runtime.capabilities.bitwise then
	-- Load bit compatibility layer for 5.3+ and "LuaJIT 3"
	bit = require "5_3/bit"
else
	-- Fallback (5.2/5.1/LuaJIT)
	--bit = _G.bit32 or _G.bit or require "bit"
	bit = require "bitwise" -- LuaJIT/5.1+
end

local bit_tobit, bit_band, bit_bor, bit_lshift, bit_rshift, bit_bnot, bit_bxor
if bit then
	bit_tobit = bit.tobit
	bit_band = bit.band
	bit_bor = bit.bor
	bit_lshift = bit.lshift
	bit_rshift = bit.rshift
	bit_bnot = bit.bnot
	bit_bxor = bit.bxor
else
	local m    = function(n)
		--return bit_band(n, 0xFFFFFFFF)
		return n % U32
	end

	--- Convert to signed 32-bit integer range [-2^31, 2^31-1]
	---@param x number Input value
	---@return integer integer Signed 32-bit integer
	bit_tobit  = function(x)
		x = x % U32
		return x >= 0x80000000 and x - U32 or x
	end

	--- Bitwise AND (a & b)
	---@param a integer First operand
	---@param b integer Second operand
	---@return integer integer Bitwise AND of a and b
	bit_band   = function(a, b)
		local result = 0
		local c = 1
		while a > 0 or b > 0 do
			if (a % 2) == 1 and (b % 2) == 1 then
				result = result + c
			end
			a, b, c = math_floor(a * 0.5), math_floor(b * 0.5), c * 2
		end
		return result
	end

	--- Bitwise OR (a | b)
	---@param a integer First operand
	---@param b integer Second operand
	---@return integer integer Bitwise OR of a and b
	bit_bor    = function(a, b)
		local result = 0
		local c = 1
		while a > 0 or b > 0 do
			if (a % 2) == 1 or (b % 2) == 1 then
				result = result + c
			end
			a, b, c = math_floor(a * 0.5), math_floor(b * 0.5), c * 2
		end
		return result
	end

	--- Left shift operation (multiply by 2^b; a << b)
	---@param a integer The value to shift
	---@param b integer Number of bits to shift left
	---@return integer integer Result of a << b
	bit_lshift = function(a, b)
		--return a * (2 ^ b)
		return m(m(a) * 2 ^ b)
	end

	--- Right shift operation (divide by 2^b; a >> b)
	---@param a integer The value to shift
	---@param b integer Number of bits to shift right
	---@return integer integer Result of a >> b
	bit_rshift = function(a, b)
		return math_floor(a * (0.5 ^ b))
	end

	--- Bitwise NOT operation (2's complement; ~a)
	---@param a integer The value to complement
	---@return integer integer Bitwise NOT of a
	bit_bnot   = function(a)
		--return 0xFFFFFFFF - a
		return m(U32 - 1 - m(a))
	end

	--- Bitwise XOR operation (a ~ b)
	---@param a integer First operand
	---@param b integer Second operand
	---@return integer integer Bitwise XOR of a and b
	bit_bxor   = function(a, b)
		local result = 0
		local c = 1
		while a > 0 or b > 0 do
			if (a % 2) ~= (b % 2) then
				result = result + c
			end
			a, b, c = math_floor(a * 0.5), math_floor(b * 0.5), c * 2
		end
		return result
	end
end

--- Bitwise NOT of n masked to a given bit width
---@param n integer Value to complement
---@param width integer Number of bits (1-31, or 32 for full unsigned NOT)
---@return integer integer Bitwise NOT of n within the specified bit width
local bit_bnot32                = function(n, width)
	return (width >= 32 or width < 1) and (-1 - n) or (2 ^ width - 1 - n)
end

--- Safe OR fold for bit.bor implementations that only accept two arguments
---@param ... integer Values to OR together
---@return integer integer Bitwise OR of all arguments
local bit_bor32                 = function(...)
	local n = select("#", ...)
	if n == 0 then
		return 0
	end

	local r = select(1, ...)
	for i = 2, n do
		r = bit_bor(r, select(i, ...))
	end

	return r
end

--- Safe XOR fold for bit.bxor implementations that only accept two arguments
---@param ... integer Values to XOR together
---@return integer integer Bitwise XOR of all arguments
local bit_bxor32                = function(...)
	local n = select("#", ...)
	if n == 0 then
		return 0
	end

	local r = select(1, ...)
	for i = 2, n do
		r = bit_bxor(r, select(i, ...))
	end

	return r
end

--- Rotate left operation (barrel shift, wraps around)
---@param a integer Value to rotate
---@param b integer Number of bits to rotate left (modulo 32)
---@return integer integer Rotated value
local bit_rol                   = bit.rol or function(a, b)
	b = b % 32 -- bit_band(b, 31)
	return bit_band(bit_bor(bit_lshift(a, b), bit_rshift(a, (32 - b))), 0xFFFFFFFF)
end

--- Rotate right operation (barrel shift, wraps around)
---@param a integer Value to rotate
---@param b integer Number of bits to rotate right (modulo 32)
---@return integer integer Rotated value
local bit_ror                   = bit.ror or function(a, b)
	b = b % 32 -- bit_band(b, 31)
	return bit_band(bit_bor(bit_rshift(a, b), bit_lshift(a, (32 - b))), 0xFFFFFFFF)
end

--- Arithmetic right shift (sign-extending)
---@param a integer Value to shift
---@param b integer Number of bits to shift right (modulo 32)
---@return integer integer Sign-extended shifted value
local bit_arshift               = bit.arshift or function(a, b)
	b = b % 32 -- bit_band(b, 31)
	local r = bit_rshift(a, b)
	if bit_band(a, 0x80000000) ~= 0 and b > 0 then
		r = bit_bor(r, bit_lshift((bit_lshift(1, b) - 1), (32 - b)))
	end
	return r
end

bits.bit                        = bit -- require "bitwise"
bits.tobit                      = bit_tobit
bits.band                       = bit_band
bits.bor                        = bit_bor
bits.lshift                     = bit_lshift
bits.rshift                     = bit_rshift
bits.bnot                       = bit_bnot
bits.bxor                       = bit_bxor
bits.bnot32                     = bit_bnot32
bits.bor32                      = bit_bor32
bits.bxor32                     = bit_bxor32
bits.rol                        = bit_rol
bits.ror                        = bit_ror
bits.arshift                    = bit_arshift

--- Normalize a value to a signed 32-bit integer [-2^31, 2^31-1]
---@param n number Input value
---@return integer integer Signed 32-bit integer
local to_int32                  = function(n)
	-- Try to coerce strings, booleans, etc. to number
	--n = tonumber(n)
	--if not n then return end
	-- Remove fractional part (toward zero, like typical int cast)
	--n = (n >= 0 and math_floor or math_ceil)(n)
	-- Use modf to extract integer part (most accurate)
	n = (math_modf(n))
	-- Normalize into unsigned 32-bit range [0, 2^32-1]
	n = n % U32
	-- Map to signed 32-bit range [-2^31, 2^31-1]
	if n >= 2147483648 then
		n = n - U32
	end
	return n
end

bits.to_i32                     = to_int32

--- Normalize a value to an unsigned 32-bit integer [0, 2^32-1]
---@param x number Input value
---@return integer integer Unsigned 32-bit integer
local to_uint32                 = function(x)
	--return tonumber(string_format("%u", x))
	--return x | 0
	--return bit_band(x, 0xFFFFFFFF)
	--return math_floor(x % 0x100000000)
	--return (math_modf(x)) & 0xFFFFFFFF
	--return bit_band(math.tointeger(x), 0xFFFFFFFF)
	return x % U32
end

bits.to_u32                     = to_uint32

--- Fast unsigned normalization using bit.tobit
---@param x number Input value
---@return integer integer Unsigned 32-bit integer
local to_u32_fast               = function(x)
	-- bit.tobit ensures a 32-bit signed representation
	local s = bit_tobit(x)
	-- If negative, add 2^32 to get unsigned value
	return s < 0 and s + U32 or s
end

bits.to_u32_fast                = to_u32_fast

-- If bit.tobit isn't available for some reason, fallback to bit.band + branch:
--local to_u32_fast               = function(x)
--	local s = bit_band(x, U32MASK) -- still may be negative signed 32-bit
--	if s < 0 then return s + U32 else return s end
--end

--local canonical_nan_mantissa    = function()
--	-- Choose a representable mantissa for NaN payload (cannot recover arbitrary payloads numerically)
--	return TWO51
--end

--- Extract the signed 32-bit low-word of a double's IEEE-754 binary64 bit pattern
---@param n number Input double
---@return integer integer Signed 32-bit low word
local double_to_int32_low_fast  = string_pack and string_unpack and
	function(n)
		if n == 0 then return 0 end
		return string_unpack(">i4", string_pack(">d", n), 5)
	end
	or
	function(n)
		if n == 0 then
			return 0
		end
		if n < 0 then
			n = -n
		end
		if n >= MIN_NORMAL then
			local m, _ = math_frexp(n)
			local frac = 2 * m - 1
			local hi20 = math_floor(frac * (2 ^ 20))
			local lo_frac = frac * (2 ^ 20) - hi20
			local lo32 = math_floor(lo_frac * U32 + 0.5)
			return bit_tobit(lo32 % U32)
		end
		local mantissa = math_floor(n * SUBNORMAL_SCALE_1 * SUBNORMAL_SCALE_2 + 0.5)
		return bit_tobit(mantissa % U32)
	end

bits.double_to_int32_low_fast   = double_to_int32_low_fast

--- Extract the unsigned 32-bit low-word of a double's IEEE-754 binary64 bit pattern
---@param n number Input double
---@return integer integer Unsigned 32-bit low word
local double_to_uint32_low      = string_pack and string_unpack and
	function(n)
		if n ~= n then return 0xFFFFFFFF end
		return string_unpack(">I4", string_pack(">d", n), 5)
	end
	or
	function(n)
		if n ~= n then
			return 0xFFFFFFFF
		end
		if n == math_huge or n == -math_huge or n == 0 then
			return 0
		end
		if n < 0 then
			n = -n
		end
		if n >= MIN_NORMAL then
			local m, _ = math_frexp(n)
			local frac = 2 * m - 1
			local hi20 = math_floor(frac * (2 ^ 20))
			local lo_frac = frac * (2 ^ 20) - hi20
			local lo32 = math_floor(lo_frac * U32 + 0.5)
			return lo32 % U32
		end
		local mantissa = math_floor(n * SUBNORMAL_SCALE_1 * SUBNORMAL_SCALE_2 + 0.5)
		return mantissa % U32
	end

bits.double_to_uint32_low       = double_to_uint32_low

--- Extract the signed 32-bit high-word of a double's IEEE-754 binary64 bit pattern
---@param n number Input double
---@return integer integer Signed 32-bit high word
local double_to_int32_high_fast = string_pack and string_unpack and
	function(n)
		if n == 0 then return 0 end
		return string_unpack(">i4", string_pack(">d", n), 1)
	end
	or
	function(n)
		if n == 0 then
			return 0
		end
		local sign = 0
		if n < 0 then
			sign, n = 1, -n
		end
		if n >= MIN_NORMAL then
			local m, e = math_frexp(n) -- n = m * 2^e
			return to_u32_fast(
				bit_bor32(
					bit_lshift(sign, 31),
					bit_lshift(e + (EXP_BIAS - 1), 20),
					math_floor(math_floor((2 * m - 1) * 2 ^ MANT_BITS + 0.5) / U32)
				)
			)
		end
		return to_u32_fast(
			bit_bor32(
				bit_lshift(sign, 31),
				0,
				math_floor(math_floor(n * SUBNORMAL_SCALE_1 * SUBNORMAL_SCALE_2 + 0.5) / U32)
			)
		)
	end

bits.double_to_int32_high_fast  = double_to_int32_high_fast

--- Extract the unsigned 32-bit high-word of a double's IEEE-754 binary64 bit pattern
---@param n number Input double
---@return integer integer Unsigned 32-bit high word
local double_to_uint32_high     = string_pack and string_unpack and
	function(n)
		if n ~= n then return 0x7FF80000 end
		return string_unpack(">I4", string_pack(">d", n), 1)
	end
	or
	function(n)
		if n ~= n then
			return 0x7FF80000
		end
		if n == math_huge then
			return 0x7FF00000
		end
		if n == -math_huge then
			return 0xFFF00000
		end
		if n == 0 then
			return 1 / n == -math_huge and 0x80000000 or 0
		end
		local sign = 0
		if n < 0 then
			sign, n = 1, -n
		end
		if n >= MIN_NORMAL then
			local m, e = math_frexp(n) -- n = m * 2^e
			return to_u32_fast(
				bit_bor32(
					bit_lshift(sign, 31),
					bit_lshift(e + (EXP_BIAS - 1), 20),
					math_floor(math_floor((2 * m - 1) * 2 ^ MANT_BITS + 0.5) / U32)
				)
			)
		end
		return to_u32_fast(
			bit_bor32(
				bit_lshift(sign, 31),
				0,
				math_floor(math_floor(n * SUBNORMAL_SCALE_1 * SUBNORMAL_SCALE_2 + 0.5) / U32)
			)
		)
	end

bits.double_to_uint32_high      = double_to_uint32_high

--- Convert a double to its full 64-bit binary string representation
---@param n number Input double
---@return string string 64-character binary string
local double_to_bin64           = string_pack and string_unpack and
	function(n)
		local hi = string_unpack(">I4", string_pack(">d", n), 1)
		local lo = string_unpack(">I4", string_pack(">d", n), 5)
		return u32_to_bin32(hi) .. u32_to_bin32(lo)
	end
	or
	function(n)
		return u32_to_bin32(double_to_uint32_high(n)) .. u32_to_bin32(double_to_uint32_low(n))
	end

bits.double_to_bin64            = double_to_bin64

--- Format a value as a 32-bit hexadecimal string (0xXXXXXXXX)
---@param x number Input value
---@return string string Hex string like "0x3F800000"
local hex32                     = function(x)
	return string_format("0x%08X", to_u32_fast(x))
end

bits.hex32                      = hex32

--print("nan test: " .. hex32(double_to_uint32_high(0 / 0)))
--print("inf test:", double_to_uint32_high(math.huge))
--print("-inf test:", double_to_uint32_high(-math.huge))
--print("positive zero test:", double_to_uint32_high(0))
--print("negative zero test:", double_to_uint32_high(-0))

local u32_to_bin32_buffer       = {} -- Avoid table allocation overhead

--- Convert an unsigned 32-bit value to a 32-character binary string (big-endian)
---@param u integer Unsigned 32-bit value
---@return string string 32-character binary string
local u32_to_bin32              = function(u)
	u = to_u32_fast(u)
	for i = 31, 0, -1 do
		u32_to_bin32_buffer[32 - i] = (bit_band(u, bit_lshift(1, i)) ~= 0) and "1" or "0"
	end
	return table_concat(u32_to_bin32_buffer)
end

bits.u32_to_bin32               = u32_to_bin32

--- Convert a double to its full 64-bit binary string representation
---@param n number Input double
---@return string string 64-character binary string
local double_to_bin64           = function(n)
	-- hi contains sign(1)|exp(11)|mant_top20 ; lo contains mant_low32
	return u32_to_bin32(double_to_uint32_high(n)) .. u32_to_bin32(double_to_uint32_low(n))
end

bits.double_to_bin64            = double_to_bin64

--- Pretty-print a double's binary representation as "s eeeeeeeeeee mmmm..."
---@param n number Input double
---@return string string Formatted binary string with spaces
local pretty_double_bin         = function(n)
	local bin64 = double_to_bin64(n)
	return string_format(
		"%s %s %s",
		string_sub(bin64, 1, 1), -- sign
		string_sub(bin64, 2, 12), -- exponent
		string_sub(bin64, 13, 64) -- mantissa
	)
end

bits.pretty_double_bin          = pretty_double_bin

--- Convert a binary string to an unsigned integer (exact up to 52 bits)
---@param bin string Binary string of "0" and "1" characters
---@return integer integer Unsigned integer value
local bin_to_uint               = function(bin)
	local v = 0
	for i = 1, #bin do
		local c = string_byte(bin, i)
		-- Assume valid '0'/'1'
		v = (v * 2) + (c - 48)
	end
	return v
end

bits.bin_to_uint                = bin_to_uint

--- Convert a 64-bit binary string to a Lua number (double)
---@param bin64 string 64-character binary string (spaces allowed)
---@return number number Reconstructed double value
local bin64_to_double           = string_pack and string_unpack and
	function(bin64)
		-- Strip spaces
		bin64 = string_gsub(bin64, "%s+", "")

		if #bin64 ~= 64 then
			return error("bin64_to_double: input must be 64 bits (spaces allowed)", 2)
		end

		-- Exact IEEE-754 binary64 reconstruction
		local hi = bin_to_uint(string_sub(bin64, 1, 32))
		local lo = bin_to_uint(string_sub(bin64, 33, 64))

		return string_unpack(">d", string_pack(">I4>I4", hi, lo))
	end
	or
	function(bin64)
		-- Strip spaces
		bin64 = string_gsub(bin64, "%s+", "")

		if #bin64 ~= 64 then
			return error("bin64_to_double: input must be 64 bits (spaces allowed)", 2)
		end

		-- Fallback for environments without string.pack/unpack
		local sign_bit  = string_sub(bin64, 1, 1)
		local exp_bits  = string_sub(bin64, 2, 12) -- 11 bits
		local mant_bits = string_sub(bin64, 13, 64) -- 52 bits

		local s         = (sign_bit == "1") and 1 or 0
		local E         = bin_to_uint(exp_bits)
		local mant      = bin_to_uint(mant_bits)

		-- Special cases
		if E == 2047 then
			if mant == 0 then
				return s == 1 and -math_huge or math_huge
			end

			-- Fallback NaN; exact NaN payload cannot be preserved numerically
			return 0 / 0
		end

		if E == 0 then
			if mant == 0 then
				-- Signed zero
				if s == 1 then
					return -0.0
				end

				return 0.0
			end

			-- Subnormal: value = (-1)^s * mant * 2^-1074
			local v = math_ldexp(mant, -1074)
			return s == 1 and -v or v
		end

		-- Normalized: value = (-1)^s * (1 + mant/2^52) * 2^(E - bias)
		local v = math_ldexp(1 + mant / (2 ^ MANT_BITS), E - EXP_BIAS)
		return s == 1 and -v or v
	end

bits.bin64_to_double            = bin64_to_double

--- Check if a number is a power of two (zero excluded)
---@param n number Input number
---@return boolean boolean True if n is positive and a power of two
bits.is_power_of_two            = function(n)
	return n > 0 and bit_band(n, n - 1) == 0
end

--- Calculate the smallest power of two greater than or equal to n
---@param n number Input number
---@return number number Next power of two
bits.next_power_of_two          = function(n)
	n = n - 1
	n = bit_bor(n, bit_rshift(n, 1))
	n = bit_bor(n, bit_rshift(n, 2))
	n = bit_bor(n, bit_rshift(n, 4))
	n = bit_bor(n, bit_rshift(n, 8))
	n = bit_bor(n, bit_rshift(n, 16))
	return n + 1
end

--- Calculate the minimum number of bits required to represent a non-negative integer
---@param n integer Non-negative integer
---@return integer integer Number of bits required
bits.get_required_bits          = function(n)
	-- 0 is a special case: It requires 1 bit to represent (value 0)
	if n == 0 then return 1 end
	local numBits = 0
	while n > 0 do
		numBits = numBits + 1
		--n = bit_rshift(n, 1) -- Limited up to 2^31
		n = math_floor(n * 0.5) -- Shift right by 1 bit (n becomes n/2; n>>1)
	end
	return numBits
end

-- Buggy, do not use this
--bits.get_required_bits2 = function(n)
--	-- If n is 0, return 1. Otherwise, calculate log base 2 and round up.
--	--return n == 0 and 1 or math_ceil(math_log(n + 1, 2))
--	if n == 0 then return 1 end
--	local k = math_floor(math_log(n, 2))
--	return 2 ^ k == n and k + 1 or k -- Explicit power-of-two branch avoids rounding traps
--end

--[[ Quick tests
if true then
	local U32MASK = 0xFFFFFFFF
	local TWO51 = 2 ^ 51
	-- Example round-trip using the pretty printer
	print("real pi", math.pi) -- 3.1415926535898
	local b = pretty_double_bin(3.141592)
	local x = bin64_to_double(b)
	print("pret pi", b, x)
	local expb = "0 10000000000 1001001000011111101011111100100010110000000001111010"
	print("expe b", expb, b == expb)
	assert(string_sub(tostring(x), 1, 7) == "3.14159", "comp pi")

	local tmp
	-- Quick self-test (without pretty_double_bin): known bit pattern for 1.0
	tmp = bin64_to_double("0 01111111111 0000000000000000000000000000000000000000000000000000")
	print("tmp:", tmp)
	assert(tmp == 1.0)

	-- Signed zero test
	tmp = string.gsub(tostring(bin64_to_double("1 00000000000 0000000000000000000000000000000000000000000000000000")),
		"%.0$", "", 1)
	print("tmp:", tmp)
	assert(tmp == "-0")
	-- Infinity test
	tmp = tostring(bin64_to_double("0 11111111111 0000000000000000000000000000000000000000000000000000"))
	print("tmp:", tmp)
	assert(tmp == "inf")
	tmp = tostring(bin64_to_double("1 11111111111 0000000000000000000000000000000000000000000000000000"))
	print("tmp:", tmp)
	assert(tmp == "-inf")
	-- NaN test
	tmp = bin64_to_double("0 11111111111 1000000000000000000000000000000000000000000000000000")
	print("tmp:", tmp)
	assert(tmp ~= tmp, "expected NaN")

	-- Examples
	for _, v in next, { 3.141592653589793, 1.0, -0.0, 0.0, math.huge, -math.huge, 1e-320, 0 / 0 } do
		print(string_format("%g -> %s", v, pretty_double_bin(v)))
	end

	-- Single-call example returning raw 64-bit string
	local raw = double_to_bin64(3.141592653589793)
	print("raw:", raw)
	assert(raw == "0100000000001001001000011111101101010100010001000010110100011000")
	print(double_to_bin64(math.pi))
	print(double_to_int32_high_fast(math.pi))
	print(double_to_int32_low_fast(math.pi))

	-- Demo / quick tests
	for _, v in next, {
		3.141592653589793,
		1.0,
		-0.0,
		0.0,
		math.huge,
		-math.huge,
		1e-320, -- subnormal example
		1e-308, -- normal small
		0 / 0 -- NaN
	} do
		local hi = double_to_uint32_high(v)
		local lo = double_to_uint32_low(v)
		print(string_format("%g -> high=%s low=%s", v, hex32(hi), hex32(lo)))
	end

	-- Demonstrate faster normalization vs modulo
	local s = bit_tobit(bit_lshift(1, 31)) -- normalize to signed 32-bit
	assert(s == -2147483648)            -- signed shift
	assert(to_u32_fast(s) == 2147483648) -- unsigned normalized (fast)
	assert(to_u32_fast(-1) == 4294967295) -- unsigned -1

	local nan = 0 / 0
	local inf = 1 / 0
	assert(0 == bits.get_required_bits(-1))       --> 0
	--assert(-inf == bits.get_required_bits2(-1))     --> -inf
	assert(1 == bits.get_required_bits(0))        --> 1
	assert(1 == bits.get_required_bits(1))        --> 1
	assert(2 == bits.get_required_bits(2))        --> 2
	assert(3 == bits.get_required_bits(5))        --> 3 (binary: 101)
	assert(8 == bits.get_required_bits(255))      --> 8
	assert(9 == bits.get_required_bits(511))      --> 9
	assert(10 == bits.get_required_bits(512))     --> 10
	assert(0 == bits.get_required_bits(-2147483648)) --> 0
	--assert(nan == bits.get_required_bits2(-2147483648))--> nan
	assert(31 == bits.get_required_bits(2147483647)) --> 31
	--assert(bits.get_required_bits2(2147483647))    --> 30 <-- buggy: should be 31
	assert(32 == bits.get_required_bits(2147483648)) --> 32
	--assert(32 == bits.get_required_bits2(2147483648))--> 32
	assert(32 == bits.get_required_bits(U32MASK)) --> 32
	--assert(bits.get_required_bits2(U32MASK))        --> 31 <-- buggy: should be 32
	assert(bits.get_required_bits(U32MASK + 1))   --> 33
	--assert(bits.get_required_bits2(U32MASK + 1))    --> 33
	assert(bits.get_required_bits(TWO51 - 1))     --> 51
	--assert(bits.get_required_bits2(TWO51 - 1))      --> 51
	assert(52 == bits.get_required_bits(TWO51))   --> 52
	--assert(52 == bits.get_required_bits2(TWO51))    --> 52
end
--]]

-- Export
return bits
