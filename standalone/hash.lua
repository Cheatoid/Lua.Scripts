-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Simple hash library for LuaJIT/Luau/5.1+

local M = {}

-- Localized global functions for better performance
local error = error
local tostring = tostring
local string_byte = string.byte
local string_lower = string.lower

----------------------------------------------------------------------
-- Bitwise compatibility layer (safe for all Lua versions)
-- TODO: Use bitwise lib
-- LuaJIT bit uses signed 32-bit integers; bit.bnot(0) produces -1.
-- Lua 5.2 (and Luau) bit32 treats numbers as unsigned 32-bit integers; bit32.bnot(0) produces 4294967295 (0xFFFFFFFF).
-- Lua 5.3+ has native operators and uses signed 64-bit integers.
----------------------------------------------------------------------

local bitwise
local bnot, band, bor, bxor, shl, shr, rol, ror, mul32, u32

local has_native
if _VERSION ~= "Lua 5.1" then
	has_native = pcall(loadstring or load, "return ~0, 3 & 1, 3 | 1, 0x3 ~ 1, 1 << 5, 32 >> 1")
end

if has_native then
	local ok, func = pcall(loadstring or load, [[return {
	u32  = function(n) return n & 0xFFFFFFFF end,
	bnot = function(n) return (~n) & 0xFFFFFFFF end,
	band = function(a, b) return (a & b) & 0xFFFFFFFF end,
	bor  = function(a, b) return (a | b) & 0xFFFFFFFF end,
	bxor = function(a, b) return (a ~ b) & 0xFFFFFFFF end,
	shl  = function(a, b) return (a << b) & 0xFFFFFFFF end,
	shr  = function(a, b) return (a >> b) & 0xFFFFFFFF end,
	rol  = function(x, n)
		x = x & 0xFFFFFFFF
		return ((x << n) | (x >> (32 - n))) & 0xFFFFFFFF
	end,
	ror  = function(x, n)
		x = x & 0xFFFFFFFF
		return ((x >> n) | (x << (32 - n))) & 0xFFFFFFFF
	end,
	mul32 = function(a, b)
		return (a * b) & 0xFFFFFFFF
	end,
}]])
	if ok then
		local ok2, bitlib = pcall(func)
		if ok2 then
			bitwise = bitlib
			bnot, band, bor, bxor, shl, shr, rol, ror, mul32, u32 =
					bitwise.bnot, bitwise.band, bitwise.bor, bitwise.bxor,
					bitwise.shl, bitwise.shr, bitwise.rol, bitwise.ror, bitwise.mul32,
					bitwise.u32
		end
	end
end

if not bitwise then
	local ok_bit, req_bit = pcall(require, "bit")
	bitwise               = bit32 or bit or (ok_bit and req_bit) or
			error("Bitwise library 'bit' (bit32 or LuaJIT) is required on Lua 5.1")

	bnot                  = bitwise.bnot
	band                  = bitwise.band
	bor                   = bitwise.bor
	bxor                  = bitwise.bxor
	shl                   = bitwise.lshift or bitwise.shl
	shr                   = bitwise.rshift or bitwise.shr
	rol                   = bitwise.rol or bitwise.lrotate or function(x, n)
		x = band(x, 0xFFFFFFFF)
		return band(bor(shl(x, n), shr(x, 32 - n)), 0xFFFFFFFF)
	end
	ror                   = bitwise.ror or bitwise.rrotate or function(x, n)
		x = band(x, 0xFFFFFFFF)
		return band(bor(shr(x, n), shl(x, 32 - n)), 0xFFFFFFFF)
	end
	--- 32-bit unsigned multiplication with overflow handling
	---@param a number First operand
	---@param b number Second operand
	---@return number result Result of a * b masked to 32 bits
	mul32                 = function(a, b)
		local a_lo, a_hi = band(a, 0xFFFF), shr(a, 16)
		local b_lo, b_hi = band(b, 0xFFFF), shr(b, 16)
		return band(a_lo * b_lo + band(a_lo * b_hi + a_hi * b_lo, 0xFFFF) * 65536, 0xFFFFFFFF)
	end
	--- Normalize any 32-bit integer (signed/float/64-bit) to unsigned 32-bit [0, 0xFFFFFFFF]
	u32                   = function(n)
		return n % 4294967296
	end
end

M.bit            = bitwise
M.u32            = u32
M.bnot           = bnot
M.band           = band
M.bor            = bor
M.bxor           = bxor
M.shl            = shl
M.shr            = shr
M.rol            = rol
M.ror            = ror
M.mul32          = mul32

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
	return u32(hash)
end

--- Create new FNV-1a32 hash context
---@return table hash Hash context with update and final methods
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
		final = function() return u32(hash) end
	}
end

----------------------------------------------------------------------
-- MurmurHash3 32-bit
----------------------------------------------------------------------

--- Compute MurmurHash3 32-bit hash
---@param str string Input string
---@param seed? number Seed value (default: 0)
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
		hash = band(mul32(hash, 5) + 0xE6546B64, 0xFFFFFFFF)

		i = i + 4
	end

	local k = 0
	local rem = band(len, 3) -- len % 4
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

	return u32(hash)
end

----------------------------------------------------------------------
-- xxHash32
----------------------------------------------------------------------

local P1, P2, P3, P4, P5 = 0x9E3779B1, 0x85EBCA77, 0xC2B2AE3D, 0x27D4EB2F, 0x165667B1

local function xxh32_round(acc, lane)
	acc = band(acc + mul32(lane, P2), 0xFFFFFFFF)
	acc = rol(acc, 13)
	return mul32(acc, P1)
end

--- Compute xxHash32
---@param str string Input string
---@param seed? number Seed value (default: 0)
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

			a1 = xxh32_round(a1, lane1)
			a2 = xxh32_round(a2, lane2)
			a3 = xxh32_round(a3, lane3)
			a4 = xxh32_round(a4, lane4)

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

	return u32(hash)
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
		crc_table[i] = band(crc, 0xFFFFFFFF)
	end
end

--- Compute CRC32 hash
---@param str string Input string
---@param init? number Initial value (default: 0xFFFFFFFF)
---@return number 32-bit CRC32
function M.crc32(str, init)
	init = init or 0xFFFFFFFF
	local crc = band(init, 0xFFFFFFFF)
	for i = 1, #str do
		local byte = string_byte(str, i)
		crc = bxor(shr(crc, 8), crc_table[bxor(band(crc, 0xFF), byte)])
	end
	return u32(bxor(crc, 0xFFFFFFFF))
end

--- Create new CRC32 hash context
---@param init? number Initial value (default: 0xFFFFFFFF)
---@return table hash Hash context with update and final methods
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
		final = function() return u32(bxor(crc, 0xFFFFFFFF)) end
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

-- Export
return M
