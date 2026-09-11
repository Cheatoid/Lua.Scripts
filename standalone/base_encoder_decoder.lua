-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Arbitrary Base encoding/decoding

-- Localized global functions for better performance
local error, type = error, type
local string, table, math = string, table, math
local string_byte, string_char, string_sub, string_format = string.byte, string.char, string.sub, string.format
local table_concat, table_insert = table.concat, table.insert
local math_floor, math_log, math_fmod = math.floor, math.log, math.fmod

-- Load bit library
local bit = _G.bit32 or _G.bit or require "5_3/bit"
local bit_band, bit_bor, bit_lshift, bit_rshift = bit.band, bit.bor, bit.lshift, bit.rshift

-- Module table
local Base = {}

----------------------------------------------------------------------
-- Private helper functions
----------------------------------------------------------------------

-- Determines if a number is a power of 2 using bitwise AND
local function is_power_of_two(n)
	return n > 0 and bit_band(n, n - 1) == 0
end

-- Validates an alphabet string
local function validate_alphabet(alphabet)
	if type(alphabet) ~= "string" then
		return error("alphabet must be a string", 3)
	end
	local len = #alphabet
	if len < 2 then
		return error("alphabet must contain at least 2 characters", 3)
	end

	local decode_map = {}
	for i = 1, len do
		local char = string_sub(alphabet, i, i)
		local code = string_byte(char)
		if decode_map[code] then
			return error(string_format("alphabet contains duplicate character: '%s'", char), 3)
		end
		decode_map[code] = i - 1 -- Store 0-indexed value
	end

	return len, decode_map
end

----------------------------------------------------------------------
-- Power-of-2 implementation
----------------------------------------------------------------------

local function encode_pow2(data, alphabet, base_len)
	local bits_per_char = math_floor(math_log(base_len, 2))

	-- Pre-generate encode lookup
	local encode_map = {}
	for i = 1, base_len do
		encode_map[i - 1] = string_sub(alphabet, i, i)
	end

	local data_len = #data
	if data_len == 0 then return "" end

	local result = {}
	local buffer = 0
	local bits_in_buffer = 0
	local result_idx = 1

	for i = 1, data_len do
		-- buffer = (buffer << 8) | byte
		buffer = bit_bor(bit_lshift(buffer, 8), string_byte(data, i))
		bits_in_buffer = bits_in_buffer + 8

		while bits_in_buffer >= bits_per_char do
			local shift = bits_in_buffer - bits_per_char
			-- val = buffer >> shift
			local val = bit_rshift(buffer, shift)
			result[result_idx] = encode_map[val]
			result_idx = result_idx + 1

			-- buffer = buffer & ((1 << shift) - 1)
			if shift > 0 then
				buffer = bit_band(buffer, bit_lshift(1, shift) - 1)
			else
				buffer = 0
			end
			bits_in_buffer = bits_in_buffer - bits_per_char
		end
	end

	-- Handle remaining bits
	if bits_in_buffer > 0 then
		-- buffer already contains high bits, just shift to fill remaining low bits
		local val = bit_lshift(buffer, bits_per_char - bits_in_buffer)
		result[result_idx] = encode_map[val]
	end

	return table_concat(result)
end

local function decode_pow2(data, base_len, decode_map)
	local bits_per_char = math_floor(math_log(base_len, 2))
	local data_len = #data
	if data_len == 0 then return "" end

	local result = {}
	local buffer = 0
	local bits_in_buffer = 0
	local result_idx = 1

	for i = 1, data_len do
		local byte = string_byte(data, i)
		local val = decode_map[byte]

		if val == nil then
			return error(string_format("invalid character found: '%s'", string_sub(data, i, i)), 2)
		end

		-- buffer = (buffer << bits_per_char) | val
		buffer = bit_bor(bit_lshift(buffer, bits_per_char), val)
		bits_in_buffer = bits_in_buffer + bits_per_char

		while bits_in_buffer >= 8 do
			local shift = bits_in_buffer - 8
			-- result = char(buffer >> shift)
			result[result_idx] = string_char(bit_rshift(buffer, shift))
			result_idx = result_idx + 1

			-- buffer = buffer & ((1 << shift) - 1)
			if shift > 0 then
				buffer = bit_band(buffer, bit_lshift(1, shift) - 1)
			else
				buffer = 0
			end
			bits_in_buffer = bits_in_buffer - 8
		end
	end

	return table_concat(result)
end

----------------------------------------------------------------------
-- Arbitrary Base implementation
----------------------------------------------------------------------

local function encode_arbitrary(data, alphabet, base_len)
	local data_len = #data
	if data_len == 0 then return "" end

	local bignum = {}
	for i = 1, data_len do
		bignum[i] = string_byte(data, i)
	end

	local result = {}
	local zero_char = string_sub(alphabet, 1, 1)
	local leading_zeros = 0

	for i = 1, data_len do
		if bignum[i] == 0 then
			leading_zeros = leading_zeros + 1
		else
			break
		end
	end

	while true do
		local carry = 0
		local is_non_zero = false

		for i = 1, #bignum do
			local val = bignum[i] + carry * 256
			bignum[i] = math_floor(val / base_len)
			carry = math_fmod(val, base_len)
			if bignum[i] ~= 0 then is_non_zero = true end
		end

		table_insert(result, string_sub(alphabet, carry + 1, carry + 1))

		if not is_non_zero then break end

		-- Trim leading zeros
		local first_non_zero = 1
		while first_non_zero < #bignum and bignum[first_non_zero] == 0 do
			first_non_zero = first_non_zero + 1
		end
		if first_non_zero > 1 then
			local new_bignum = {}
			for i = first_non_zero, #bignum do
				table_insert(new_bignum, bignum[i])
			end
			bignum = new_bignum
		end
	end

	for _ = 1, leading_zeros do
		table_insert(result, zero_char)
	end

	-- Reverse result
	for i = 1, math_floor(#result / 2) do
		result[i], result[#result - i + 1] = result[#result - i + 1], result[i]
	end

	return table_concat(result)
end

local function decode_arbitrary(data, alphabet, base_len, decode_map)
	local data_len = #data
	if data_len == 0 then return "" end

	local zero_val_byte = string_byte(alphabet, 1)
	local leading_zeros = 0

	for i = 1, data_len do
		if string_byte(data, i) == zero_val_byte then
			leading_zeros = leading_zeros + 1
		else
			break
		end
	end

	local bignum = {}

	for i = leading_zeros + 1, data_len do
		local char_byte = string_byte(data, i)
		local val = decode_map[char_byte]

		if val == nil then
			return error(string_format("invalid character found in input: '%s'", string_sub(data, i, i)), 2)
		end

		local carry = val
		for j = 1, #bignum do
			local num = bignum[j] * base_len + carry
			bignum[j] = math_fmod(num, 256)
			carry = math_floor(num / 256)
		end

		while carry > 0 do
			table_insert(bignum, math_fmod(carry, 256))
			carry = math_floor(carry / 256)
		end
	end

	local result = {}
	for _ = 1, leading_zeros do
		table_insert(result, string_char(0))
	end

	for i = #bignum, 1, -1 do
		table_insert(result, string_char(bignum[i]))
	end

	return table_concat(result)
end

----------------------------------------------------------------------
-- Public API
----------------------------------------------------------------------

function Base.encode(data, alphabet)
	if type(data) ~= "string" then return error("input data must be a string", 2) end
	local base_len, _ = validate_alphabet(alphabet)

	if is_power_of_two(base_len) then
		return encode_pow2(data, alphabet, base_len)
	else
		return encode_arbitrary(data, alphabet, base_len)
	end
end

function Base.decode(data, alphabet)
	if type(data) ~= "string" then return error("input data must be a string", 2) end
	local base_len, decode_map = validate_alphabet(alphabet)

	if is_power_of_two(base_len) then
		return decode_pow2(data, base_len, decode_map)
	else
		return decode_arbitrary(data, alphabet, base_len, decode_map)
	end
end

function Base.new(alphabet)
	local base_len, decode_map = validate_alphabet(alphabet)

	local encode_fn, decode_fn

	if is_power_of_two(base_len) then
		local encode_map = {}
		for i = 1, base_len do
			encode_map[i - 1] = string_sub(alphabet, i, i)
		end

		encode_fn = function(data)
			if type(data) ~= "string" then return error("input data must be a string", 2) end
			return encode_pow2(data, alphabet, base_len)
		end
		decode_fn = function(data)
			if type(data) ~= "string" then return error("input data must be a string", 2) end
			return decode_pow2(data, base_len, decode_map)
		end
	else
		encode_fn = function(data)
			if type(data) ~= "string" then return error("input data must be a string", 2) end
			return encode_arbitrary(data, alphabet, base_len)
		end
		decode_fn = function(data)
			if type(data) ~= "string" then return error("input data must be a string", 2) end
			return decode_arbitrary(data, alphabet, base_len, decode_map)
		end
	end

	return {
		encode = encode_fn,
		decode = decode_fn,
		alphabet = alphabet,
		base = base_len
	}
end

----------------------------------------------------------------------
-- Standard Definitions
----------------------------------------------------------------------

Base.BASE16 = "0123456789ABCDEF"
Base.BASE58 = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
Base.BASE64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

-- Export
return Base
