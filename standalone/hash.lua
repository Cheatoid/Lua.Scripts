-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Simple hash library for LuaJIT/5.1+

local M = {}

-- Localized global functions for better performance
local error = error
local tonumber = tonumber
local tostring = tostring
local string_byte = string.byte
local string_format = string.format
local string_lower = string.lower
local string_sub = string.sub
local table_concat = table.concat

-- Constants
--local WIDTH = 32
--local MOD = 4294967296      -- 2^32
--local ALL_ONES = 0xFFFFFFFF -- 2^32 - 1

----------------------------------------------------------------------
-- Bitwise compatibility layer (safe for all Lua versions)
-- TODO: Use bitwise lib
----------------------------------------------------------------------

local band, bor, bxor, shl, shr, rol

local has_native = false
if _VERSION ~= "Lua 5.1" then
	local test_code = [[local a = 0xFFFFFFFF & 1
local b = 0xFFFFFFFF | 1
local c = 0xFFFFFFFF ~ 1
local d = 1 << 5
local e = 32 >> 1
return true]]
	local load = loadstring or load
	if load then
		local success = pcall(load, test_code)
		if success then has_native = true end
	end
end

if has_native then
	local bitcode = [[return {
	band = function(a, b) return a & b end,
	bor  = function(a, b) return a | b end,
	bxor = function(a, b) return a ~ b end,
	shl  = function(a, b) return (a << b) & 0xFFFFFFFF end,
	shr  = function(a, b) return a >> b end,
	rol  = function(x, n)
		x = x & 0xFFFFFFFF
		return (x << n) | (x >> (32 - n))
	end
}]]
	local bitops = (loadstring or load)(bitcode)()
	band, bor, bxor, shl, shr, rol = bitops.band, bitops.bor, bitops.bxor, bitops.shl, bitops.shr, bitops.rol
else
	-- Import dependencies
	local bit = bit32 or bit or require "bit"
	if not bit then
		return error("Bitwise library 'bit' (bit32 or LuaJIT) is required on Lua 5.1", 2)
	end
	band = bit.band
	bor  = bit.bor
	bxor = bit.bxor
	shl  = bit.lshift
	shr  = bit.rshift
	rol  = bit.rol or function(x, n) return bor(shl(x, n), shr(x, 32 - n)) end
end

----------------------------------------------------------------------
-- 32-bit unsigned multiply
----------------------------------------------------------------------

--- 32-bit unsigned multiplication with overflow handling
---@param a number First operand
---@param b number Second operand
---@return number Result of a * b masked to 32 bits
local function mul32(a, b)
	a = band(a, 0xFFFFFFFF)
	b = band(b, 0xFFFFFFFF)
	local a_lo = band(a, 0xFFFF)
	local a_hi = shr(a, 16)
	local b_lo = band(b, 0xFFFF)
	local b_hi = shr(b, 16)
	local low = a_lo * b_lo
	local cross = a_lo * b_hi + a_hi * b_lo
	return band(low + band(cross, 0xFFFF) * 65536 + a_hi * b_hi * 4294967296, 0xFFFFFFFF)
end

----------------------------------------------------------------------
-- FNV-1a32
----------------------------------------------------------------------

local FNV_OFFSET = 2166136261
local FNV_PRIME  = 16777619

--- Compute FNV-1a32 hash
---@param str string Input string
---@return number 32-bit FNV-1a hash
function M.fnv1a32(str)
	local hash = FNV_OFFSET
	for i = 1, #str do
		hash = bxor(hash, string_byte(str, i))
		hash = mul32(hash, FNV_PRIME)
	end
	return hash
end

--- Create new FNV-1a32 hash context
---@return table Hash context with update and final methods
function M.fnv1a32_new()
	local hash = FNV_OFFSET
	return {
		update = function(self, data)
			for i = 1, #data do
				hash = bxor(hash, string_byte(data, i))
				hash = mul32(hash, FNV_PRIME)
			end
			return self
		end,
		final = function() return hash end
	}
end

----------------------------------------------------------------------
-- MurmurHash3 32-bit
----------------------------------------------------------------------

--- Compute MurmurHash3 32-bit hash
---@param str string Input string
---@param seed number|nil Seed value (default: 0)
---@return number 32-bit MurmurHash3
function M.murmur3_32(str, seed)
	seed = seed or 0
	local len = #str
	local hash = band(seed, 0xFFFFFFFF)
	local i = 1

	while i <= len - 3 do
		local b1, b2, b3, b4 = string_byte(str, i, i + 3)
		local k = bor(bor(shl(b4, 24), shl(b3, 16)), bor(shl(b2, 8), b1))

		k = mul32(k, 0xCC9E2D51)
		k = rol(k, 15)
		k = mul32(k, 0x1B873593)

		hash = bxor(hash, k)
		hash = rol(hash, 13)
		hash = mul32(hash, 5) + 0xE6546B64
		hash = band(hash, 0xFFFFFFFF)

		i = i + 4
	end

	local k = 0
	local rem = len % 4
	if rem >= 3 then k = bor(k, shl(string_byte(str, i + 2), 16)) end
	if rem >= 2 then k = bor(k, shl(string_byte(str, i + 1), 8)) end
	if rem >= 1 then
		k = bor(k, string_byte(str, i))
		k = mul32(k, 0xCC9E2D51)
		k = rol(k, 15)
		k = mul32(k, 0x1B873593)
		hash = bxor(hash, k)
	end

	hash = bxor(hash, len)
	hash = bxor(hash, shr(hash, 16))
	hash = mul32(hash, 0x85EBCA6B)
	hash = bxor(hash, shr(hash, 13))
	hash = mul32(hash, 0xC2B2AE35)
	hash = bxor(hash, shr(hash, 16))

	return band(hash, 0xFFFFFFFF)
end

----------------------------------------------------------------------
-- xxHash32
----------------------------------------------------------------------

local P1, P2, P3, P4, P5 = 0x9E3779B1, 0x85EBCA77, 0xC2B2AE3D, 0x27D4EB2F, 0x165667B1

--- Compute xxHash32
---@param str string Input string
---@param seed number|nil Seed value (default: 0)
---@return number 32-bit xxHash
function M.xxh32(str, seed)
	seed = seed or 0
	local len = #str
	local i = 1
	local hash

	if len >= 16 then
		local a1 = band(seed + P1 + P2, 0xFFFFFFFF)
		local a2 = band(seed + P2, 0xFFFFFFFF)
		local a3 = band(seed, 0xFFFFFFFF)
		local a4 = band(seed - P1, 0xFFFFFFFF)

		while i <= len - 15 do
			local b1, b2, b3, b4 = string_byte(str, i, i + 3)
			local b5, b6, b7, b8 = string_byte(str, i + 4, i + 7)
			local b9, b10, b11, b12 = string_byte(str, i + 8, i + 11)
			local b13, b14, b15, b16 = string_byte(str, i + 12, i + 15)

			local lane1 = bor(bor(shl(b4, 24), shl(b3, 16)), bor(shl(b2, 8), b1))
			local lane2 = bor(bor(shl(b8, 24), shl(b7, 16)), bor(shl(b6, 8), b5))
			local lane3 = bor(bor(shl(b12, 24), shl(b11, 16)), bor(shl(b10, 8), b9))
			local lane4 = bor(bor(shl(b16, 24), shl(b15, 16)), bor(shl(b14, 8), b13))

			local function round(acc, lane)
				acc = band(acc + mul32(lane, P2), 0xFFFFFFFF)
				acc = rol(acc, 13)
				return mul32(acc, P1)
			end

			a1 = round(a1, lane1)
			a2 = round(a2, lane2)
			a3 = round(a3, lane3)
			a4 = round(a4, lane4)

			i = i + 16
		end

		hash = band(rol(a1, 1) + rol(a2, 7) + rol(a3, 12) + rol(a4, 18), 0xFFFFFFFF)
		hash = band(hash + len, 0xFFFFFFFF)
	else
		hash = band(seed + len + P5, 0xFFFFFFFF)
	end

	while i <= len - 3 do
		local b1, b2, b3, b4 = string_byte(str, i, i + 3)
		local lane = bor(bor(shl(b4, 24), shl(b3, 16)), bor(shl(b2, 8), b1))
		hash = band(hash + mul32(lane, P3), 0xFFFFFFFF)
		hash = rol(hash, 17)
		hash = mul32(hash, P4)
		i = i + 4
	end

	while i <= len do
		local byte = string_byte(str, i)
		hash = band(hash + mul32(byte, P5), 0xFFFFFFFF)
		hash = rol(hash, 11)
		hash = mul32(hash, P1)
		i = i + 1
	end

	hash = bxor(hash, shr(hash, 15))
	hash = mul32(hash, P2)
	hash = bxor(hash, shr(hash, 13))
	hash = mul32(hash, P3)
	hash = bxor(hash, shr(hash, 16))

	return hash
end

----------------------------------------------------------------------
-- CRC32 (IEEE)
----------------------------------------------------------------------

local crc_table = {}
do
	local poly = 0xEDB88320
	for i = 0, 255 do
		local crc = i
		for _ = 1, 8 do
			crc = (band(crc, 1) ~= 0) and bxor(shr(crc, 1), poly) or shr(crc, 1)
		end
		crc_table[i] = crc
	end
end

--- Compute CRC32 hash
---@param str string Input string
---@param init number|nil Initial value (default: 0xFFFFFFFF)
---@return number 32-bit CRC32
function M.crc32(str, init)
	init = init or 0xFFFFFFFF
	local crc = band(init, 0xFFFFFFFF)
	for i = 1, #str do
		local byte = string_byte(str, i)
		crc = bxor(shr(crc, 8), crc_table[bxor(band(crc, 0xFF), byte)])
	end
	return bxor(crc, 0xFFFFFFFF)
end

--- Create new CRC32 hash context
---@param init number|nil Initial value (default: 0xFFFFFFFF)
---@return table Hash context with update and final methods
function M.crc32_new(init)
	local crc = band(init or 0xFFFFFFFF, 0xFFFFFFFF)
	return {
		update = function(self, data)
			for i = 1, #data do
				local byte = string_byte(data, i)
				crc = bxor(shr(crc, 8), crc_table[bxor(band(crc, 0xFF), byte)])
			end
			return self
		end,
		final = function() return bxor(crc, 0xFFFFFFFF) end
	}
end

----------------------------------------------------------------------
-- Generic dispatcher
----------------------------------------------------------------------

local dispatch = {
	fnv1a32 = M.fnv1a32,
	fnv = M.fnv1a32,
	murmur3 = M.murmur3_32,
	murmur = M.murmur3_32,
	xxh32 = M.xxh32,
	xxhash = M.xxh32,
	crc32 = M.crc32,
	crc = M.crc32,
}

--- Generic hash function dispatcher
---@param str string Input string
---@param algorithm string Algorithm name
---@return number 32-bit hash
function M.hash(str, algorithm)
	local func = dispatch[string_lower(algorithm)]
	if not func then
		return error("Unknown hash algorithm: " .. tostring(algorithm), 2)
	end
	return func(str)
end

--[[ Quick tests
if true then
	local tests = {
		{
			name = "FNV-1a32",
			func = M.fnv1a32,
			cases = {
				{ input = "",              expect = 0x811c9dc5 },
				{ input = "a",             expect = 0xe40c292c },
				{ input = "hello",         expect = 0x4f9f2cab },
				{ input = "Hello, World!", expect = 0x5aecf734 },
			}
		},
		{
			name = "Murmur3-32",
			func = M.murmur3_32,
			cases = {
				{ input = "",              expect = 0x00000000 },
				{ input = "hello",         expect = 0x248bfa47 },
				{ input = "Hello, World!", expect = 0x2352d5c7 },
			}
		},
		{
			name = "xxHash32",
			func = M.xxh32,
			cases = {
				{ input = "",              expect = 0x02cc5d05 },
				{ input = "hello",         expect = 0xfb0077f9 },
				{ input = "Hello, World!", expect = 0x4007de50 },
			}
		},
		{
			name = "CRC32",
			func = M.crc32,
			cases = {
				{ input = "",              expect = 0x00000000 },
				{ input = "hello",         expect = 0x3610a686 },
				{ input = "Hello, World!", expect = 0xec4ac3d0 },
			}
		},
	}

	local passed = 0
	local total = 0

	for _, test in next, tests do
		print(string_format("\nTesting %s:", test.name))
		for _, case in next, test.cases do
			total = total + 1
			local result = test.func(case.input)
			if result == case.expect then
				print(string_format("  '%s' -> 0x%08x", case.input, result))
				passed = passed + 1
			else
				print(string_format("  '%s' -> got 0x%08x, expected 0x%08x", case.input, result, case.expect))
			end
		end
	end

	print(string_format("\nUnit tests completed: %d/%d passed", passed, total))
	print(passed == total and "All tests passed!" or "Some tests failed!")
end
--]]

-- Export
return M
