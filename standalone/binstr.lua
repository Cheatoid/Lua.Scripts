-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Binary-string bitwise utilities

-- Localized global functions for better performance
local error = error
local type = type
local tostring = tostring
local tonumber = tonumber
local math_floor = math.floor
local string_byte = string.byte
local string_char = string.char
local string_format = string.format
local string_gsub = string.gsub
local string_match = string.match
local string_rep = string.rep
local string_reverse = string.reverse
local string_sub = string.sub
local table_concat = table.concat
local math_huge = math.huge

-- Constants
local VALID_WIDTHS = { [8] = true, [16] = true, [32] = true, [64] = true }

local TWO_POW = {
	[8]  = "256",
	[16] = "65536",
	[32] = "4294967296",
	[64] = "18446744073709551616"
}

----------------------------------------------------------------------
-- Internal helpers
----------------------------------------------------------------------

--- Trim whitespace from both ends of a string.
---@param s string input The input string.
---@return string trimmed The trimmed string.
local function trim(s) return (string_gsub(s, "^%s*(.-)%s*$", "%1")) end

--- Normalize a binary string to a given bit width.
---@param s string input The binary string input (may have "0b" prefix, leading zeros, or spaces).
---@param width? integer bit_width The bit width (8, 16, 32, or 64). Defaults to 64.
---@return string? normalized The normalized binary string, or nil on error.
---@return string? err Error message if validation failed.
local function normalize_bin_input(s, width)
	if width == nil then width = 64 end
	if type(width) ~= "number" or not VALID_WIDTHS[width] then
		return nil, "invalid width; allowed: 8,16,32,64"
	end
	if type(s) ~= "string" then return nil, "input must be a string" end
	s = trim(s)
	if string_sub(s, 1, 2) == "0b" or string_sub(s, 1, 2) == "0B" then s = string_sub(s, 3) end
	if s == "" then return nil, "empty binary string" end
	if string_match(s, "[^01]") then return nil, "binary string contains non-binary characters" end
	if #s > width then return nil, "binary string longer than width" end
	if #s < width then s = string_rep("0", width - #s) .. s end
	return s
end

----------------------------------------------------------------------
-- Decimal-string helpers (operate on non-negative integer decimal strings)
----------------------------------------------------------------------

--- Multiply a decimal string by 2.
---@param dec string dec_str The decimal string to multiply.
---@return string result The result of dec * 2 as a decimal string.
local function dec_mul2(dec)
	local res = {}
	local carry = 0
	for i = #dec, 1, -1 do
		local d = tonumber(string_sub(dec, i, i))
		local v = d * 2 + carry
		res[#res + 1] = tostring(v % 10)
		carry = math_floor(v / 10)
	end
	while carry > 0 do
		res[#res + 1] = tostring(carry % 10)
		carry = math_floor(carry / 10)
	end
	return string_reverse(table_concat(res))
end

--- Add a small integer to a decimal string.
---@param dec string dec_str The decimal string.
---@param add integer value The small integer to add (must fit in a single digit operation).
---@return string result The result of dec + add as a decimal string.
local function dec_add_small(dec, add)
	if add == 0 then return dec end
	local res = {}
	local carry = add
	for i = #dec, 1, -1 do
		local d = tonumber(string_sub(dec, i, i))
		local v = d + carry
		res[#res + 1] = tostring(v % 10)
		carry = math_floor(v / 10)
	end
	while carry > 0 do
		res[#res + 1] = tostring(carry % 10)
		carry = math_floor(carry / 10)
	end
	return string_reverse(table_concat(res))
end

--- Subtract decimal string b from a, where a >= b. Both are non-negative decimal strings.
---@param a string dec_a The minuend decimal string.
---@param b string dec_b The subtrahend decimal string.
---@return string result The result of a - b as a decimal string.
local function dec_sub(a, b)
	local la, lb = #a, #b
	b = string_rep("0", la - lb) .. b
	local res = {}
	local borrow = 0
	for i = la, 1, -1 do
		local da = tonumber(string_sub(a, i, i))
		local db = tonumber(string_sub(b, i, i))
		local v = da - db - borrow
		if v < 0 then
			v = v + 10
			borrow = 1
		else
			borrow = 0
		end
		res[#res + 1] = tostring(v)
	end
	local s = string_gsub(string_reverse(table_concat(res)), "^0+", "")
	if s == "" then s = "0" end
	return s
end

--- Convert binary string (any length up to width) to decimal string (unsigned).
---@param bin string bin_str The binary string.
---@return string dec The unsigned decimal string.
local function bin_to_dec_unsigned(bin)
	local dec = "0"
	for i = 1, #bin do
		dec = dec_mul2(dec)
		if string_byte(bin, i) == 49 then dec = dec_add_small(dec, 1) end
	end
	dec = string_gsub(dec, "^0+", "")
	if dec == "" then dec = "0" end
	return dec
end

--- Generic per-bit pairwise operation (and, or, xor).
---@param a string bin_a The first binary string.
---@param b string bin_b The second binary string.
---@param width? integer bit_width The bit width (default: 64). Both a and b will be normalized to this width.
---@param op string operation The operation: "and", "or", or "xor".
---@return string? result The result binary string, or nil on error.
---@return string? err Error message if validation failed.
local function bitwise_pair_op(a, b, width, op)
	width = width or 64
	local aa, err = normalize_bin_input(a, width)
	if not aa then return nil, err end
	local bb, err2 = normalize_bin_input(b, width)
	if not bb then return nil, err2 end
	local out = {}
	if op == "and" then
		for i = 1, width do
			out[i] = (string_byte(aa, i) == 49 and string_byte(bb, i) == 49) and "1" or "0"
		end
	elseif op == "or" then
		for i = 1, width do
			out[i] = (string_byte(aa, i) == 49 or string_byte(bb, i) == 49) and "1" or "0"
		end
	elseif op == "xor" then
		for i = 1, width do
			out[i] = (string_byte(aa, i) ~= string_byte(bb, i)) and "1" or "0"
		end
	else
		return nil, "unknown op"
	end
	return table_concat(out)
end

--- Rotate helper: rotate binary string left or right.
---@param bin string bin_str The binary string.
---@param n integer count The number of positions to rotate.
---@param width? integer bit_width The bit width (default: 64).
---@param left boolean direction True for left rotate, false for right rotate.
---@return string? result The rotated binary string, or nil on error.
---@return string? err Error message if validation failed.
local function rot_common(bin, n, width, left)
	width = width or 64
	local b, err = normalize_bin_input(bin, width)
	if not b then return nil, err end
	n = tonumber(n) or 0
	n = ((n % width) + width) % width
	if n == 0 then return b end
	if left then
		return string_sub(b, 1 + n) .. string_sub(b, 1, n)
	end
	return string_sub(b, width - n + 1) .. string_sub(b, 1, width - n)
end

----------------------------------------------------------------------
-- Decimal conversion helpers
----------------------------------------------------------------------

--- Compare decimal strings a and b (non-negative, no leading +/-, no leading zeros required).
---@param a string dec_a The first decimal string.
---@param b string dec_b The second decimal string.
---@return integer result -1 if a < b, 0 if a == b, 1 if a > b.
local function dec_compare(a, b)
	a = string_gsub(a, "^0+", "")
	if a == "" then a = "0" end
	b = string_gsub(b, "^0+", "")
	if b == "" then b = "0" end
	if #a < #b then return -1 end
	if #a > #b then return 1 end
	if a < b then return -1 end
	if a > b then return 1 end
	return 0
end

--- Divide decimal string by 2, return quotient string and remainder (0 or 1).
---@param dec string dec_str The decimal string.
---@return string quotient The quotient decimal string.
---@return integer remainder The remainder (0 or 1).
local function dec_divmod2(dec)
	local q = {}
	local carry = 0
	for i = 1, #dec do
		local d = tonumber(string_sub(dec, i, i))
		local v = carry * 10 + d
		local qd = math_floor(v / 2)
		carry = v % 2
		q[#q + 1] = tostring(qd)
	end
	local qs = string_gsub(table_concat(q), "^0+", "")
	if qs == "" then qs = "0" end
	return qs, carry
end

--- Convert non-negative decimal string to binary string (no width padding).
---@param dec string dec_str The decimal string.
---@return string bin The binary string (without leading zeros).
local function dec_to_bin_unsigned_nopad(dec)
	dec = string_gsub(dec, "^%+", "")
	dec = string_gsub(dec, "^0+", "")
	if dec == "" then dec = "0" end
	if dec == "0" then return "0" end
	local bits = {}
	local cur = dec
	local rem
	while not (cur == "0") do
		cur, rem = dec_divmod2(cur)
		bits[#bits + 1] = tostring(rem)
	end
	-- bits are LSB..MSB, reverse to MSB..LSB
	return string_reverse(table_concat(bits))
end

----------------------------------------------------------------------
-- Public API
----------------------------------------------------------------------

--- Bitwise NOT operation.
---@param a string bin_str The binary string.
---@param width? integer bit_width The bit width (8, 16, 32, or 64). Defaults to 64.
---@return string? result The bitwise NOT result, or nil on error.
---@return string? err Error message if validation failed.
local function bnot(a, width)
	local aa, err = normalize_bin_input(a, width)
	if not aa then return nil, err end
	local out = {}
	for i = 1, #aa do out[i] = (string_byte(aa, i) == 49) and "0" or "1" end
	return table_concat(out)
end

--- Bitwise AND operation.
---@param a string bin_a The first binary string.
---@param b string bin_b The second binary string.
---@param width? integer bit_width The bit width (8, 16, 32, or 64). Defaults to 64.
---@return string? result The bitwise AND result, or nil on error.
---@return string? err Error message if validation failed.
local function band(a, b, width) return bitwise_pair_op(a, b, width, "and") end

--- Bitwise OR operation.
---@param a string bin_a The first binary string.
---@param b string bin_b The second binary string.
---@param width? integer bit_width The bit width (8, 16, 32, or 64). Defaults to 64.
---@return string? result The bitwise OR result, or nil on error.
---@return string? err Error message if validation failed.
local function bor(a, b, width) return bitwise_pair_op(a, b, width, "or") end

--- Bitwise XOR operation.
---@param a string bin_a The first binary string.
---@param b string bin_b The second binary string.
---@param width? integer bit_width The bit width (8, 16, 32, or 64). Defaults to 64.
---@return string? result The bitwise XOR result, or nil on error.
---@return string? err Error message if validation failed.
local function bxor(a, b, width) return bitwise_pair_op(a, b, width, "xor") end

--- Rotate binary string left.
---@param bin string bin_str The binary string.
---@param n integer count The number of positions to rotate left.
---@param width? integer bit_width The bit width (8, 16, 32, or 64). Defaults to 64.
---@return string? result The rotated binary string, or nil on error.
---@return string? err Error message if validation failed.
local function rol(bin, n, width) return rot_common(bin, n, width, true) end

--- Rotate binary string right.
---@param bin string bin_str The binary string.
---@param n integer count The number of positions to rotate right.
---@param width? integer bit_width The bit width (8, 16, 32, or 64). Defaults to 64.
---@return string? result The rotated binary string, or nil on error.
---@return string? err Error message if validation failed.
local function ror(bin, n, width) return rot_common(bin, n, width, false) end

--- Logical left shift.
---@param bin string bin_str The binary string.
---@param n integer count The number of positions to shift left.
---@param width? integer bit_width The bit width (8, 16, 32, or 64). Defaults to 64.
---@return string? result The shifted binary string, or nil on error.
---@return string? err Error message if validation failed.
local function lshift(bin, n, width)
	width = width or 64
	local b, err = normalize_bin_input(bin, width)
	if not b then return nil, err end
	n = tonumber(n) or 0
	if n <= 0 then return b end
	if n >= width then return string_rep("0", width) end
	return string_sub(b, 1 + n) .. string_rep("0", n)
end

--- Logical right shift.
---@param bin string bin_str The binary string.
---@param n integer count The number of positions to shift right.
---@param width? integer bit_width The bit width (8, 16, 32, or 64). Defaults to 64.
---@return string? result The shifted binary string, or nil on error.
---@return string? err Error message if validation failed.
local function rshift(bin, n, width)
	width = width or 64
	local b, err = normalize_bin_input(bin, width)
	if not b then return nil, err end
	n = tonumber(n) or 0
	if n <= 0 then return b end
	if n >= width then return string_rep("0", width) end
	return string_rep("0", n) .. string_sub(b, 1, width - n)
end

--- Arithmetic right shift (preserves sign bit).
---@param bin string bin_str The binary string.
---@param n integer count The number of positions to shift right.
---@param width? integer bit_width The bit width (8, 16, 32, or 64). Defaults to 64.
---@return string? result The shifted binary string, or nil on error.
---@return string? err Error message if validation failed.
local function arshift(bin, n, width)
	width = width or 64
	local b, err = normalize_bin_input(bin, width)
	if not b then return nil, err end
	n = tonumber(n) or 0
	if n <= 0 then return b end
	if n >= width then
		local sign = string_sub(b, 1, 1)
		return string_rep(sign, width)
	end
	local sign = string_sub(b, 1, 1)
	return string_rep(sign, n) .. string_sub(b, 1, width - n)
end

--- Byte-swap: reverse order of bytes. Width must be a multiple of 8.
---@param bin string bin_str The binary string.
---@param width? integer bit_width The bit width (8, 16, 32, or 64). Defaults to 64.
---@return string? result The byte-swapped binary string, or nil on error.
---@return string? err Error message if validation failed.
local function bswap(bin, width)
	width = width or 64
	local b, err = normalize_bin_input(bin, width)
	if not b then return nil, err end
	if (width % 8) ~= 0 then return nil, "width must be multiple of 8 for bswap" end
	local bytes = {}
	local nb = width / 8
	for i = 1, nb do
		local start = (i - 1) * 8 + 1
		bytes[i] = string_sub(b, start, start + 7)
	end
	for i = 1, math_floor(nb / 2) do
		bytes[i], bytes[nb - i + 1] = bytes[nb - i + 1], bytes[i]
	end
	return table_concat(bytes)
end

----------------------------------------------------------------------
-- Decimal conversion
----------------------------------------------------------------------

--- Convert binary string to decimal string (unsigned or signed two's complement).
---@param binstr string bin_str The binary string.
---@param signed? boolean is_signed If true, interpret as signed two's complement.
---@param width? integer bit_width The bit width (8, 16, 32, or 64). Defaults to 64.
---@return string? dec The decimal string, or nil on error.
---@return string? err Error message if conversion failed.
local function to_decimal(binstr, signed, width)
	width = width or 64
	local bin, err = normalize_bin_input(binstr, width)
	if not bin then return nil, err end
	local unsigned_dec = bin_to_dec_unsigned(bin)
	if not signed then return unsigned_dec end
	-- signed two's complement: if MSB == 0 -> same as unsigned
	if string_sub(bin, 1, 1) == "0" then return unsigned_dec end
	-- negative: magnitude = 2^width - unsigned
	local TWO = TWO_POW[width]
	if not TWO then return nil, "unsupported width for signed conversion" end
	unsigned_dec = string_gsub(unsigned_dec, "^0+", "")
	if unsigned_dec == "" then unsigned_dec = "0" end
	local mag = dec_sub(TWO, unsigned_dec)
	return "-" .. mag
end

--- Convert decimal string to normalized width-bit binary string.
---@param decstr string dec_str The decimal string (may start with '-' for negative).
---@param signed? boolean is_signed If true, interpret/produce two's complement for negatives.
---@param width? integer bit_width The bit width (8, 16, 32, or 64). Defaults to 64.
---@return string? result The normalized binary string, or nil on error.
---@return string? err Error message if conversion failed.
local function dec_to_bin(decstr, signed, width)
	width = width or 64
	if type(width) ~= "number" or not VALID_WIDTHS[width] then
		return nil, "invalid width; allowed: 8,16,32,64"
	end
	if type(decstr) ~= "string" then return nil, "decimal input must be a string" end

	decstr = string_gsub(decstr, "^%s*(.-)%s*$", "%1") -- trim
	if decstr == "" then return nil, "empty decimal string" end

	local neg = false
	local first = string_byte(decstr, 1) -- 45 == "-", 43 == "+"
	if first == 45 then
		neg = true
		decstr = string_sub(decstr, 2)
	elseif first == 43 then
		decstr = string_sub(decstr, 2)
	end
	if string_match(decstr, "%D") then return nil, "decimal string contains non-digit characters" end
	decstr = string_gsub(decstr, "^0+", "")
	if decstr == "" then decstr = "0" end

	local TWO = TWO_POW[width]
	if not TWO then return nil, "unsupported width" end

	-- Range checks
	if not signed then
		-- unsigned: 0 <= dec < 2^width
		if neg then return nil, "negative value not allowed for unsigned conversion" end
		if dec_compare(decstr, TWO) >= 0 then
			return nil, "overflow: value >= 2^width"
		end
		local bin = dec_to_bin_unsigned_nopad(decstr)
		if #bin > width then return nil, "overflow after conversion" end
		return string_rep("0", width - #bin) .. bin
	end

	-- signed mode
	-- allowed range: -2^(width-1) .. 2^(width-1)-1
	local HALF
	-- compute 2^(width-1) as decimal string by dividing TWO by 2
	do
		local q, r = dec_divmod2(TWO) -- q = 2^(width-1)
		HALF = q
	end

	if neg then
		-- negative: abs(dec) must be <= HALF
		if dec_compare(decstr, HALF) > 0 then
			return nil, "overflow: negative magnitude too large for signed width"
		end
		-- two's complement: unsigned = 2^width - abs(dec)
		local unsigned = dec_sub(TWO, decstr)
		-- convert unsigned to binary and pad
		local bin = dec_to_bin_unsigned_nopad(unsigned)
		if #bin > width then return nil, "overflow after conversion" end
		return string_rep("0", width - #bin) .. bin
	else
		-- non-negative: must be < 2^(width-1) (to fit signed positive range)
		if dec_compare(decstr, HALF) >= 0 then
			return nil, "overflow: positive value too large for signed width"
		end
		local bin = dec_to_bin_unsigned_nopad(decstr)
		if #bin > width then return nil, "overflow after conversion" end
		return string_rep("0", width - #bin) .. bin
	end
end

----------------------------------------------------------------------
-- Binary stream support: shared primitives
----------------------------------------------------------------------

local WIDTH_BYTES = {
	[8] = 1,
	[16] = 2,
	[32] = 4,
	[64] = 8,
}

local INTEGER_SPECS = {
	{ name = "UInt8",  width = 8,  signed = false },
	{ name = "Int8",   width = 8,  signed = true },
	{ name = "UInt16", width = 16, signed = false },
	{ name = "Int16",  width = 16, signed = true },
	{ name = "UInt32", width = 32, signed = false },
	{ name = "Int32",  width = 32, signed = true },
	{ name = "UInt64", width = 64, signed = false },
	{ name = "Int64",  width = 64, signed = true },
}

--- Parse common endian representations.<br>
--- Little-endian is LSB-first; big-endian is MSB-first.<br>
--- Defaults to little-endian when endian is nil.
---@param endian? boolean|string Endian specifier: "<", "little", "LE", "le" for little-endian; ">", "big", "BE", "be" for big-endian; true for little-endian; false for big-endian; nil defaults to little-endian.
---@return boolean little_endian True for little-endian, false for big-endian.
local function parse_endian(endian)
	if endian == nil
		or endian == true
		or endian == "<"
		or endian == "little"
		or endian == "LE"
		or endian == "le"
	then
		return true
	end

	if endian == false
		or endian == ">"
		or endian == "big"
		or endian == "BE"
		or endian == "be"
	then
		return false
	end

	return error("unsupported endian; use '<'/'LE' or '>'/'BE'", 2)
end

--- Validate integer width and return its byte size.
---@param width integer
---@return integer byte_count
local function width_byte_count(width)
	local n = WIDTH_BYTES[width]
	if not n then
		return error("invalid width; allowed: 8,16,32,64", 2)
	end
	return n
end

--- Normalize a number or decimal string into a clean decimal string.<br>
--- This avoids passing values such as "-0", "+0", or padded strings forward.
---@param value string|number
---@return string dec_string
local function normalize_decimal_value(value)
	local t = type(value)

	if t == "number" then
		if value ~= value or value == math_huge or value == -math_huge then
			return error("numeric value must be finite", 2)
		end

		if value % 1 ~= 0 then
			return error("numeric value must be an integer", 2)
		end

		if value == 0 then
			return "0"
		end

		return string_format("%.0f", value)
	end

	if t ~= "string" then
		return error("value must be a decimal string or number", 2)
	end

	local s = trim(value)
	if s == "" then
		return error("empty decimal value", 2)
	end

	local neg = false
	local first = string_byte(s, 1) -- 45 == "-", 43 == "+"
	if first == 45 then
		neg = true
		s = string_sub(s, 2)
	elseif first == 43 then
		s = string_sub(s, 2)
	end

	s = string_gsub(s, "^0+", "")
	if s == "" then
		return "0"
	end

	if neg then
		return "-" .. s
	end

	return s
end

--- Convert a normalized bit string into raw bytes.<br>
--- The bit string must be MSB-first and have a length divisible by 8.
---@param bits string
---@return string bytes
local function bitstr_to_bytes(bits)
	if (#bits % 8) ~= 0 then
		return error("bit string length must be a multiple of 8", 2)
	end

	local out = {}

	for i = 1, #bits, 8 do
		local byte_bits = string_sub(bits, i, i + 7)
		local dec = bin_to_dec_unsigned(byte_bits)
		out[#out + 1] = string_char(tonumber(dec))
	end

	return table_concat(out)
end

--- Convert raw bytes into a normalized MSB-first bit string.
---@param bytes string
---@return string bits
local function bytes_to_bitstr(bytes)
	local out = {}

	for i = 1, #bytes do
		local b = string_byte(bytes, i)

		local bits, err = dec_to_bin(tostring(b), false, 8)
		if not bits then
			return error(err or "byte to bit conversion failed", 2)
		end

		out[i] = bits
	end

	return table_concat(out)
end

----------------------------------------------------------------------
-- BinaryWriter
----------------------------------------------------------------------

--- Binary data writer.<br>
--- Accumulates raw bytes for sequential encoding.
---@class BinaryWriter
---@field _parts table Chunk list storing written bytes.
---@field _size integer Total number of written bytes.
---@field writeUInt8 fun(self: BinaryWriter, value: string|number, endian: boolean|string): BinaryWriter Write unsigned 8-bit integer.
---@field writeInt8 fun(self: BinaryWriter, value: string|number, endian: boolean|string): BinaryWriter Write signed 8-bit integer.
---@field writeUInt16 fun(self: BinaryWriter, value: string|number, endian: boolean|string): BinaryWriter Write unsigned 16-bit integer.
---@field writeUInt16LE fun(self: BinaryWriter, value: string|number): BinaryWriter Write unsigned 16-bit little-endian integer.
---@field writeUInt16BE fun(self: BinaryWriter, value: string|number): BinaryWriter Write unsigned 16-bit big-endian integer.
---@field writeInt16 fun(self: BinaryWriter, value: string|number, endian: boolean|string): BinaryWriter Write signed 16-bit integer.
---@field writeInt16LE fun(self: BinaryWriter, value: string|number): BinaryWriter Write signed 16-bit little-endian integer.
---@field writeInt16BE fun(self: BinaryWriter, value: string|number): BinaryWriter Write signed 16-bit big-endian integer.
---@field writeUInt32 fun(self: BinaryWriter, value: string|number, endian: boolean|string): BinaryWriter Write unsigned 32-bit integer.
---@field writeUInt32LE fun(self: BinaryWriter, value: string|number): BinaryWriter Write unsigned 32-bit little-endian integer.
---@field writeUInt32BE fun(self: BinaryWriter, value: string|number): BinaryWriter Write unsigned 32-bit big-endian integer.
---@field writeInt32 fun(self: BinaryWriter, value: string|number, endian: boolean|string): BinaryWriter Write signed 32-bit integer.
---@field writeInt32LE fun(self: BinaryWriter, value: string|number): BinaryWriter Write signed 32-bit little-endian integer.
---@field writeInt32BE fun(self: BinaryWriter, value: string|number): BinaryWriter Write signed 32-bit big-endian integer.
---@field writeUInt64 fun(self: BinaryWriter, value: string|number, endian: boolean|string): BinaryWriter Write unsigned 64-bit integer.
---@field writeUInt64LE fun(self: BinaryWriter, value: string|number): BinaryWriter Write unsigned 64-bit little-endian integer.
---@field writeUInt64BE fun(self: BinaryWriter, value: string|number): BinaryWriter Write unsigned 64-bit big-endian integer.
---@field writeInt64 fun(self: BinaryWriter, value: string|number, endian: boolean|string): BinaryWriter Write signed 64-bit integer.
---@field writeInt64LE fun(self: BinaryWriter, value: string|number): BinaryWriter Write signed 64-bit little-endian integer.
---@field writeInt64BE fun(self: BinaryWriter, value: string|number): BinaryWriter Write signed 64-bit big-endian integer.
local BinaryWriter = {}
BinaryWriter.__index = BinaryWriter
BinaryWriter.__type = "BinaryWriter"

--- Create a new BinaryWriter.
---@return BinaryWriter writer New BinaryWriter instance.
function BinaryWriter.new()
	return setmetatable({
		_parts = {},
		_size = 0,
	}, BinaryWriter)
end

--- Append raw bytes to the writer.
---@param self BinaryWriter
---@param bytes string The raw bytes to append.
---@return BinaryWriter self Returns self for method chaining.
function BinaryWriter:_append(bytes)
	if type(bytes) ~= "string" then
		return error("bytes must be a string", 2)
	end

	if #bytes > 0 then
		self._parts[#self._parts + 1] = bytes
		self._size = self._size + #bytes
	end

	return self
end

--- Generic integer writer.
---@param self BinaryWriter
---@param value string|number Decimal string or number.
---@param width integer 8, 16, 32, or 64.
---@param signed boolean True for signed two's complement, false for unsigned.
---@param endian? boolean|string Endian specifier; defaults to little-endian.
---@return BinaryWriter self Returns self for method chaining.
function BinaryWriter:writeInteger(value, width, signed, endian)
	width_byte_count(width)

	local little = parse_endian(endian)
	local dec = normalize_decimal_value(value)

	local bits, err = dec_to_bin(dec, signed, width)
	if not bits then
		return error(err or "integer encoding failed", 2)
	end

	local bytes = bitstr_to_bytes(bits)

	if little and width > 8 then
		bytes = string_reverse(bytes)
	end

	return self:_append(bytes)
end

--- Append a raw byte string unchanged.
---@param self BinaryWriter
---@param bytes string
---@return BinaryWriter self Returns self for method chaining.
function BinaryWriter:writeBytes(bytes)
	return self:_append(bytes)
end

--- Write a batch of signed integers of the same width.
---@param self BinaryWriter
---@param values table|number A table of values, or a single value.
---@param width integer 8, 16, 32, or 64.
---@param endian? boolean|string Endian specifier; defaults to little-endian.
---@return BinaryWriter self
function BinaryWriter:writeInt(values, width, endian)
	if type(values) ~= "table" then
		return self:writeInteger(values, width, true, endian)
	end

	for i = 1, #values do
		self:writeInteger(values[i], width, true, endian)
	end

	return self
end

--- Write a batch of unsigned integers of the same width.
---@param self BinaryWriter
---@param values table|number A table of values, or a single value.
---@param width integer 8, 16, 32, or 64.
---@param endian? boolean|string Endian specifier; defaults to little-endian.
---@return BinaryWriter self
function BinaryWriter:writeUInt(values, width, endian)
	if type(values) ~= "table" then
		return self:writeInteger(values, width, false, endian)
	end

	for i = 1, #values do
		self:writeInteger(values[i], width, false, endian)
	end

	return self
end

--- Return the number of bytes currently written.
---@param self BinaryWriter
---@return integer size
function BinaryWriter:size()
	return self._size
end

--- Clear the writer.
---@param self BinaryWriter
---@return BinaryWriter self
function BinaryWriter:reset()
	self._parts = {}
	self._size = 0
	return self
end

--- Serialize accumulated chunks into one binary string.
---@param self BinaryWriter
---@return string bytes
function BinaryWriter:toString()
	return table_concat(self._parts)
end

BinaryWriter.__tostring = BinaryWriter.toString

-- Generate typed integer writers:
-- writeUInt8, writeInt8, writeUInt16, writeInt16, etc.
-- Also generate explicit LE/BE helpers for multi-byte integers:
-- writeUInt16LE, writeUInt16BE, writeInt32LE, writeInt32BE, etc.
for _, spec in next, INTEGER_SPECS do
	BinaryWriter["write" .. spec.name] = function(self, value, endian)
		return self:writeInteger(value, spec.width, spec.signed, endian)
	end

	if spec.width > 8 then
		BinaryWriter["write" .. spec.name .. "LE"] = function(self, value)
			return self:writeInteger(value, spec.width, spec.signed, true)
		end

		BinaryWriter["write" .. spec.name .. "BE"] = function(self, value)
			return self:writeInteger(value, spec.width, spec.signed, false)
		end
	end
end

----------------------------------------------------------------------
-- BinaryReader
----------------------------------------------------------------------

--- Binary data reader.<br>
--- Reads raw bytes sequentially with cursor.
---@class BinaryReader
---@field _data string Raw binary string buffer.
---@field _pos integer Current 1-based read position.
---@field _len integer Total buffer length in bytes.
---@field readUInt8 fun(self: BinaryReader, endian: boolean|string): integer Read unsigned 8-bit integer.
---@field readInt8 fun(self: BinaryReader, endian: boolean|string): integer Read signed 8-bit integer.
---@field readUInt16 fun(self: BinaryReader, endian: boolean|string): integer Read unsigned 16-bit integer.
---@field readUInt16LE fun(self: BinaryReader): integer Read unsigned 16-bit little-endian integer.
---@field readUInt16BE fun(self: BinaryReader): integer Read unsigned 16-bit big-endian integer.
---@field readInt16 fun(self: BinaryReader, endian: boolean|string): integer Read signed 16-bit integer.
---@field readInt16LE fun(self: BinaryReader): integer Read signed 16-bit little-endian integer.
---@field readInt16BE fun(self: BinaryReader): integer Read signed 16-bit big-endian integer.
---@field readUInt32 fun(self: BinaryReader, endian: boolean|string): integer Read unsigned 32-bit integer.
---@field readUInt32LE fun(self: BinaryReader): integer Read unsigned 32-bit little-endian integer.
---@field readUInt32BE fun(self: BinaryReader): integer Read unsigned 32-bit big-endian integer.
---@field readInt32 fun(self: BinaryReader, endian: boolean|string): integer Read signed 32-bit integer.
---@field readInt32LE fun(self: BinaryReader): integer Read signed 32-bit little-endian integer.
---@field readInt32BE fun(self: BinaryReader): integer Read signed 32-bit big-endian integer.
---@field readUInt64 fun(self: BinaryReader, endian: boolean|string): string Read unsigned 64-bit decimal string.
---@field readUInt64LE fun(self: BinaryReader): string Read unsigned 64-bit little-endian decimal string.
---@field readUInt64BE fun(self: BinaryReader): string Read unsigned 64-bit big-endian decimal string.
---@field readInt64 fun(self: BinaryReader, endian: boolean|string): string Read signed 64-bit decimal string.
---@field readInt64LE fun(self: BinaryReader): string Read signed 64-bit little-endian decimal string.
---@field readInt64BE fun(self: BinaryReader): string Read signed 64-bit big-endian decimal string.
local BinaryReader = {}
BinaryReader.__index = BinaryReader
BinaryReader.__type = "BinaryReader"

--- Create a new BinaryReader.
---@param data string Raw binary string.
---@return BinaryReader reader New BinaryReader instance.
function BinaryReader.new(data)
	if type(data) ~= "string" then
		return error("data must be a string", 2)
	end

	return setmetatable({
		_data = data,
		_pos = 1,
		_len = #data,
	}, BinaryReader)
end

--- Check whether all bytes have been consumed.
---@param self BinaryReader
---@return boolean eof
function BinaryReader:eof()
	return self._pos > self._len
end

--- Number of bytes remaining.
---@param self BinaryReader
---@return integer remaining
function BinaryReader:remaining()
	return self._len - self._pos + 1
end

--- Current 1-based read position.
---@param self BinaryReader
---@return integer position
function BinaryReader:position()
	return self._pos
end

--- Seek to a 1-based position.
---@param self BinaryReader
---@param pos integer
---@return BinaryReader self
function BinaryReader:seek(pos)
	pos = math_floor(tonumber(pos) or 0)

	if pos < 1 or pos > self._len + 1 then
		return error("seek position out of range", 2)
	end

	self._pos = pos
	return self
end

--- Read raw bytes and advance.
---@param self BinaryReader
---@param n integer
---@return string bytes
function BinaryReader:readBytes(n)
	n = math_floor(tonumber(n) or 0)

	if n < 0 then
		return error("byte count cannot be negative", 2)
	end

	if self._pos + n - 1 > self._len then
		return error("attempt to read past end of buffer", 2)
	end

	local s = string_sub(self._data, self._pos, self._pos + n - 1)
	self._pos = self._pos + n
	return s
end

--- Read all remaining bytes.
---@param self BinaryReader
---@return string bytes
function BinaryReader:readAll()
	local s = string_sub(self._data, self._pos)
	self._pos = self._len + 1
	return s
end

--- Generic integer reader.
---@param self BinaryReader
---@param width integer 8, 16, 32, or 64.
---@param signed boolean True for signed two's complement, false for unsigned.
---@param endian? boolean|string Endian specifier; defaults to little-endian.
---@return (number|string)? value Number for 8/16/32-bit, decimal string for 64-bit.
function BinaryReader:readInteger(width, signed, endian)
	local nb = width_byte_count(width)
	local little = parse_endian(endian)

	local bytes = self:readBytes(nb)

	if little and width > 8 then
		bytes = string_reverse(bytes)
	end

	local bits = bytes_to_bitstr(bytes)

	local dec, err = to_decimal(bits, signed, width)
	if not dec then
		return error(err or "integer decoding failed", 2)
	end

	-- Preserve 64-bit precision on Lua implementations without 64-bit integers.
	if width == 64 then
		return dec
	end

	return tonumber(dec)
end

--- Read a batch of signed integers of the same width.
---@param self BinaryReader
---@param n integer Number of integers to read.
---@param width integer 8, 16, 32, or 64.
---@param endian? boolean|string Endian specifier; defaults to little-endian.
---@return table values Array of numbers (or decimal strings for 64-bit).
function BinaryReader:readInt(n, width, endian)
	local out = {}
	for i = 1, n do
		out[i] = self:readInteger(width, true, endian)
	end
	return out
end

--- Read a batch of unsigned integers of the same width.
---@param self BinaryReader
---@param n integer Number of integers to read.
---@param width integer 8, 16, 32, or 64.
---@param endian? boolean|string Endian specifier; defaults to little-endian.
---@return table values Array of numbers (or decimal strings for 64-bit).
function BinaryReader:readUInt(n, width, endian)
	local out = {}
	for i = 1, n do
		out[i] = self:readInteger(width, false, endian)
	end
	return out
end

-- Generate typed integer readers:
-- readUInt8, readInt8, readUInt16, readInt16, etc.
-- Also generate explicit LE/BE helpers for multi-byte integers:
-- readUInt16LE, readUInt16BE, readInt32LE, readInt32BE, etc.
for _, spec in next, INTEGER_SPECS do
	BinaryReader["read" .. spec.name] = function(self, endian)
		return self:readInteger(spec.width, spec.signed, endian)
	end

	if spec.width > 8 then
		BinaryReader["read" .. spec.name .. "LE"] = function(self)
			return self:readInteger(spec.width, spec.signed, true)
		end

		BinaryReader["read" .. spec.name .. "BE"] = function(self)
			return self:readInteger(spec.width, spec.signed, false)
		end
	end
end

----------------------------------------------------------------------
-- Convenience factories and pack/unpack-style helpers
----------------------------------------------------------------------

--- Create a new BinaryWriter.
---@return BinaryWriter writer New BinaryWriter instance.
local function writer()
	return BinaryWriter.new()
end

--- Create a new BinaryReader.
---@param data string Raw binary string.
---@return BinaryReader reader New BinaryReader instance.
local function reader(data)
	return BinaryReader.new(data)
end

--- Pack one integer into a binary string.
---@param value string|number
---@param width integer 8, 16, 32, or 64.
---@param signed boolean
---@param endian? boolean|string Defaults to little-endian.
---@return string bytes
local function packInteger(value, width, signed, endian)
	return BinaryWriter.new()
		:writeInteger(value, width, signed, endian)
		:toString()
end

--- Unpack one integer from a binary string.
---@param data string
---@param pos? integer 1-based start position (default: 1).
---@param width integer 8, 16, 32, or 64.
---@param signed boolean
---@param endian? boolean|string Defaults to little-endian.
---@return (number|string)? value Number for 8/16/32-bit, decimal string for 64-bit.
---@return integer next_pos 1-based position of the next unread byte.
local function unpackInteger(data, pos, width, signed, endian)
	local r = BinaryReader.new(data)

	if pos then
		r:seek(pos)
	end

	local value = r:readInteger(width, signed, endian)
	return value, r:position()
end

--[=[ Quick tests
if true then
	local total, passed, failed = 0, 0, 0
	local function test(name, fn)
		total = total + 1
		local ok, err = pcall(fn)
		if ok then
			passed = passed + 1
		else
			failed = failed + 1
			print(string_format("  FAIL  %s: %s", name, tostring(err)))
		end
	end
	local function expect_error(fn, pattern)
		local ok, err = pcall(fn)
		assert(not ok, "expected error but got success: " .. tostring(err))
		if pattern then
			assert(tostring(err):find(pattern, 1, true),
				"error message does not contain '" .. pattern .. "': " .. tostring(err))
		end
	end
	print("[binstr] testing...")

	-- normalize
	test("normalize with 0b prefix", function()
		local r = normalize_bin_input("0b1011", 8)
		assert(r == "00001011")
	end)

	test("normalize strips spaces", function()
		local r = normalize_bin_input("  1011  ", 8)
		assert(r == "00001011")
	end)

	test("normalize defaults to 64 bits", function()
		local r = normalize_bin_input("1")
		assert(r == string_rep("0", 63) .. "1")
	end)

	test("normalize rejects invalid width", function()
		local r, err = normalize_bin_input("1", 12)
		assert(r == nil)
		assert(err:find("invalid width"))
	end)

	test("normalize rejects non-string", function()
		local r, err = normalize_bin_input(123, 8)
		assert(r == nil)
		assert(err:find("input must be a string"))
	end)

	test("normalize rejects non-binary chars", function()
		local r, err = normalize_bin_input("1021", 8)
		assert(r == nil)
		assert(tostring(err):find("non-binary", 1, true))
	end)

	test("normalize rejects empty string", function()
		local r, err = normalize_bin_input("", 8)
		assert(r == nil)
		assert(err:find("empty"))
	end)

	test("normalize rejects string longer than width", function()
		local r, err = normalize_bin_input("111111111", 8)
		assert(r == nil)
		assert(err:find("longer than width"))
	end)

	-- bitwise NOT
	test("bnot basic", function()
		local r = bnot("1011", 8)
		assert(r == "11110100")
	end)

	test("bnot all zeros", function()
		local r = bnot("0000", 8)
		assert(r == "11111111")
	end)

	test("bnot all ones", function()
		local r = bnot("11111111", 8)
		assert(r == "00000000")
	end)

	test("bnot propagates error", function()
		local r, err = bnot("abc", 8)
		assert(r == nil)
		assert(tostring(err):find("non-binary", 1, true))
	end)

	-- bitwise AND
	test("band basic", function()
		local r = band("1011", "1100", 8)
		assert(r == "00001000")
	end)

	test("band with self", function()
		local r = band("1011", "1011", 8)
		assert(r == "00001011")
	end)

	test("band with zeros", function()
		local r = band("1111", "0000", 8)
		assert(r == "00000000")
	end)

	-- bitwise OR
	test("bor basic", function()
		local r = bor("1011", "1100", 8)
		assert(r == "00001111")
	end)

	test("bor with self", function()
		local r = bor("1011", "1011", 8)
		assert(r == "00001011")
	end)

	test("bor with zeros", function()
		local r = bor("1111", "0000", 8)
		assert(r == "00001111")
	end)

	-- bitwise XOR
	test("bxor basic", function()
		local r = bxor("1011", "1100", 8)
		assert(r == "00000111")
	end)

	test("bxor with self is zero", function()
		local r = bxor("1011", "1011", 8)
		assert(r == "00000000")
	end)

	test("bxor with zero is identity", function()
		local r = bxor("1011", "0000", 8)
		assert(r == "00001011")
	end)

	-- rotate left
	test("rol basic", function()
		local r = rol("0001", 4, 8)
		assert(r == "00010000")
	end)

	test("rol by width is identity", function()
		local r = rol("1011", 8, 8)
		assert(r == "00001011")
	end)

	test("rol by zero is identity", function()
		local r = rol("1011", 0, 8)
		assert(r == "00001011")
	end)

	-- rotate right
	test("ror basic", function()
		local r = ror("0001", 4, 8)
		assert(r == "00010000")
	end)

	test("ror by width is identity", function()
		local r = ror("1011", 8, 8)
		assert(r == "00001011")
	end)

	-- left shift
	test("lshift basic", function()
		local r = lshift("1011", 2, 16)
		assert(r == "0000000000101100")
	end)

	test("lshift by zero", function()
		local r = lshift("1011", 0, 8)
		assert(r == "00001011")
	end)

	test("lshift by width returns zeros", function()
		local r = lshift("1011", 8, 8)
		assert(r == "00000000")
	end)

	test("lshift past width returns zeros", function()
		local r = lshift("1011", 10, 8)
		assert(r == "00000000")
	end)

	-- right shift
	test("rshift basic", function()
		local r = rshift("1011", 2, 16)
		assert(r == "0000000000000010")
	end)

	test("rshift by zero", function()
		local r = rshift("1011", 0, 8)
		assert(r == "00001011")
	end)

	test("rshift by width returns zeros", function()
		local r = rshift("1011", 8, 8)
		assert(r == "00000000")
	end)

	-- arithmetic right shift
	test("arshift preserves sign bit", function()
		local r = arshift("1" .. string_rep("0", 15), 4, 16)
		assert(r == "1111100000000000")
	end)

	test("arshift positive fills zeros", function()
		local r = arshift("00001011", 2, 8)
		assert(r == "00000010")
	end)

	test("arshift by zero", function()
		local r = arshift("10000000", 0, 8)
		assert(r == "10000000")
	end)

	test("arshift by width replicates sign", function()
		local r = arshift("10000000", 8, 8)
		assert(r == "11111111")
	end)

	test("arshift positive by width", function()
		local r = arshift("01111111", 8, 8)
		assert(r == "00000000")
	end)

	-- byte swap
	test("bswap 32-bit", function()
		local r = bswap("00000001001000110100010101100111", 32)
		assert(r == "01100111010001010010001100000001")
	end)

	test("bswap 16-bit", function()
		local r = bswap("0000000100000010", 16)
		assert(r == "0000001000000001")
	end)

	test("bswap 8-bit is identity", function()
		local r = bswap("10101010", 8)
		assert(r == "10101010")
	end)

	test("bswap rejects invalid width", function()
		local r, err = bswap("101", 12)
		assert(r == nil)
		assert(tostring(err):find("invalid width", 1, true))
	end)

	-- to_decimal
	test("to_decimal unsigned", function()
		local r = to_decimal("1111", false, 8)
		assert(r == "15")
	end)

	test("to_decimal signed positive", function()
		local r = to_decimal("00001111", true, 8)
		assert(r == "15")
	end)

	test("to_decimal signed negative (two's complement)", function()
		local r = to_decimal("11111111", true, 8)
		assert(r == "-1")
	end)

	test("to_decimal zero", function()
		local r = to_decimal("0000", false, 8)
		assert(r == "0")
	end)

	test("to_decimal max unsigned 8-bit", function()
		local r = to_decimal("11111111", false, 8)
		assert(r == "255")
	end)

	test("to_decimal min signed 8-bit", function()
		local r = to_decimal("10000000", true, 8)
		assert(r == "-128")
	end)

	-- dec_to_bin
	test("dec_to_bin unsigned 11", function()
		local r = dec_to_bin("11", false, 8)
		assert(r == "00001011")
	end)

	test("dec_to_bin unsigned 255", function()
		local r = dec_to_bin("255", false, 8)
		assert(r == "11111111")
	end)

	test("dec_to_bin signed positive 127", function()
		local r = dec_to_bin("127", true, 8)
		assert(r == "01111111")
	end)

	test("dec_to_bin signed negative -11 (two's complement)", function()
		local r = dec_to_bin("-11", true, 8)
		assert(r == "11110101")
	end)

	test("dec_to_bin signed negative -1", function()
		local r = dec_to_bin("-1", true, 8)
		assert(r == "11111111")
	end)

	test("dec_to_bin signed negative -128", function()
		local r = dec_to_bin("-128", true, 8)
		assert(r == "10000000")
	end)

	test("dec_to_bin zero", function()
		local r = dec_to_bin("0", false, 8)
		assert(r == "00000000")
	end)

	test("dec_to_bin rejects positive overflow for signed", function()
		local r, err = dec_to_bin("128", true, 8)
		assert(r == nil)
		assert(err:find("overflow"))
	end)

	test("dec_to_bin rejects negative overflow for signed", function()
		local r, err = dec_to_bin("-129", true, 8)
		assert(r == nil)
		assert(err:find("overflow"))
	end)

	test("dec_to_bin rejects unsigned overflow", function()
		local r, err = dec_to_bin("256", false, 8)
		assert(r == nil)
		assert(err:find("overflow"))
	end)

	test("dec_to_bin rejects negative for unsigned", function()
		local r, err = dec_to_bin("-1", false, 8)
		assert(r == nil)
		assert(err:find("negative"))
	end)

	test("dec_to_bin with 0b prefix in input", function()
		local r = dec_to_bin("11", false, 8)
		assert(r == "00001011")
	end)

	test("dec_to_bin defaults to 64 bits", function()
		local r = dec_to_bin("1", false)
		assert(#r == 64)
		assert(r == string_rep("0", 63) .. "1")
	end)

	-- aliases
	test("aliases work", function()
		local M = {
			lrot = rol,
			lrotate = rol,
			rrot = ror,
			rrotate = ror,
			["not"] = bnot,
			["and"] = band,
			["or"] = bor,
			xor = bxor,
		}
		assert(M.lrot == rol)
		assert(M.lrotate == rol)
		assert(M.rrot == ror)
		assert(M.rrotate == ror)
		assert(M["not"] == bnot)
		assert(M["and"] == band)
		assert(M["or"] == bor)
		assert(M.xor == bxor)
	end)

	-- BinaryWriter / BinaryReader smoke tests
	test("BinaryWriter/Reader roundtrip", function()
		local w = writer()

		w:writeUInt8(0xAB)
		w:writeUInt16LE(0x1234)
		w:writeUInt32BE(1)
		w:writeInt8(-1)
		w:writeInt16LE(-2)
		w:writeInt32BE(-3)
		w:writeUInt64LE("18446744073709551615")
		w:writeInt64LE("-1")

		local data = w:toString()
		local r = reader(data)

		assert(r:readUInt8() == 0xAB)
		assert(r:readUInt16LE() == 0x1234)
		assert(r:readUInt32BE() == 1)
		assert(r:readInt8() == -1)
		assert(r:readInt16LE() == -2)
		assert(r:readInt32BE() == -3)
		assert(r:readUInt64LE() == "18446744073709551615")
		assert(r:readInt64LE() == "-1")
		assert(r:eof())
	end)

	test("packInteger/unpackInteger roundtrip", function()
		local packed = packInteger(-2, 16, true, "<")
		local value, next_pos = unpackInteger(packed, 1, 16, true, "<")

		assert(value == -2)
		assert(next_pos == 3)
	end)

	test("writeInt/readInt batch roundtrip", function()
		local w = writer()
		w:writeInt({ -1, -2, -3 }, 16, "<")
		w:writeUInt({ 10, 20, 30 }, 16, "<")

		local r = reader(w:toString())
		local signed = r:readInt(3, 16, "<")
		local unsigned = r:readUInt(3, 16, "<")

		assert(signed[1] == -1)
		assert(signed[2] == -2)
		assert(signed[3] == -3)
		assert(unsigned[1] == 10)
		assert(unsigned[2] == 20)
		assert(unsigned[3] == 30)
		assert(r:eof())
	end)

	test("writeInt/readInt single value shorthand", function()
		local w = writer()
		w:writeInt(42, 32, "<")
		w:writeUInt(42, 32, "<")

		local r = reader(w:toString())
		assert(r:readInt(1, 32, "<")[1] == 42)
		assert(r:readUInt(1, 32, "<")[1] == 42)
		assert(r:eof())
	end)

	print(string_format("[binstr] %d/%d tests passed (%d failed)", passed, total, failed))
	assert(failed == 0, string_format("%d test(s) failed", failed))
end
--]=]

-- Export
return {
	-- Binary-string bitwise operations
	normalize = normalize_bin_input,
	bnot = bnot,
	band = band,
	bor = bor,
	bxor = bxor,
	rol = rol,
	ror = ror,
	lshift = lshift,
	rshift = rshift,
	arshift = arshift,
	bswap = bswap,

	-- Decimal conversion
	to_decimal = to_decimal,
	dec_to_bin = dec_to_bin,

	-- Binary stream support
	BinaryWriter = BinaryWriter,
	BinaryReader = BinaryReader,

	-- Convenience factories
	writer = writer,
	reader = reader,
	packInteger = packInteger,
	unpackInteger = unpackInteger,

	-- Convenience aliases
	lrot = rol,
	lrotate = rol,
	rrot = ror,
	rrotate = ror,
	["not"] = bnot,
	["and"] = band,
	["or"] = bor,
	xor = bxor,
}
