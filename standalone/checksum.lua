-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Streaming CRC-32 (IEEE 802.3 / zlib compatible) and Adler-32 (RFC 1950).
-- Zero dependencies except a bitwise module, accessed as
-- `require "bits"` (bits.band/bor/bnot/bxor/lshift/rshift).
-- Works on LuaJIT/5.1+ and later.
--
-- string.unpack (Lua 5.3+) is preferred for 32-bit word reads when
-- available, with a string.byte fallback; string.pack backs
-- finish_packed() when available.
--
-- Usage:
--   local checksum = require "checksum"
--
--   local h = checksum.crc32.new()    -- same interface for .adler32
--   h:update(chunk1)                  -- chainable, any chunk sizes
--   h:update(chunk2)
--   local n   = h:finish()            -- unsigned 32-bit number
--   local raw = h:finish_packed()     -- 4 bytes, big-endian
--   h:reset()                         -- reuse the object
--
--   local one = checksum.adler32.checksum(data)   -- one-shot
--   assert(checksum.selftest())                   -- sanity checks
--
-- finish() does not consume the state: you may keep updating and call
-- finish() again at any point.

-- Localized global functions for better performance
local assert        = assert
local setmetatable  = setmetatable
local type          = type
local string_byte   = string.byte
local string_char   = string.char
local string_pack   = string.pack -- nil before Lua 5.3
local string_rep    = string.rep
local string_sub    = string.sub
local string_unpack = string.unpack -- nil before Lua 5.3
local table_concat  = table.concat

-- Import dependencies
local bits          = require "bits"
local band          = bits.band
local bor           = bits.bor
local bnot          = bits.bnot
local bxor          = bits.bxor
local lshift        = bits.lshift
local rshift        = bits.rshift

assert(type(band) == "function" and type(bor) == "function"
	and type(bnot) == "function" and type(bxor) == "function"
	and type(lshift) == "function" and type(rshift) == "function")

----------------------------------------------------------------------
-- Shared constants / helpers
----------------------------------------------------------------------

local CRC_POLY   = 0xEDB88320 -- reflected IEEE 802.3 polynomial
local ADLER_MOD  = 65521      -- largest prime < 2^16 (RFC 1950)
local ADLER_NMAX = 5552       -- bytes deferrable before mods are mandatory
local U32        = 4294967296 -- 2^32

-- Some bit libraries return signed 32-bit results; normalize to unsigned.
local function to_u32(x)
	if x < 0 then x = x + U32 end
	return x
end

-- 32-bit little-endian word read. Prefers string.unpack; byte fallback
-- for 5.1/LuaJIT. Hoisted once at load time, not branched per call.
local read_u32le = string_unpack and
		function(s, i)
			return string_unpack("<I4", s, i)
		end
		or
		function(s, i)
			local b1, b2, b3, b4 = string_byte(s, i, i + 3)
			return bor(bor(b1, lshift(b2, 8)), bor(lshift(b3, 16), lshift(b4, 24)))
		end

-- Big-endian 4-byte digest writer. Prefers string.pack.
local pack_u32be = string_pack and
		function(v)
			return string_pack(">I4", v)
		end
		or
		function(v)
			return string_char(
				band(rshift(v, 24), 0xFF),
				band(rshift(v, 16), 0xFF),
				band(rshift(v, 8), 0xFF),
				band(v, 0xFF)
			)
		end

----------------------------------------------------------------------
-- CRC-32: reflected, slice-by-4 table driven. Folding a whole 4-byte
-- word through four 256-entry tables is algebraically identical to four
-- byte-at-a-time steps, so chunk boundaries/alignment never matter.
----------------------------------------------------------------------

local function build_crc_tables()
	local base = {} -- T1: CRC of a single byte value
	for i = 0, 255 do
		local c = i
		for _ = 1, 8 do
			if band(c, 1) ~= 0 then
				c = bxor(rshift(c, 1), CRC_POLY)
			else
				c = rshift(c, 1)
			end
		end
		base[i + 1] = c
	end
	local t = { base }
	for k = 2, 4 do -- Tk[i] = byte i followed by k-1 zero bytes
		local prev, cur = t[k - 1], {}
		for i = 1, 256 do
			local v = prev[i]
			cur[i] = bxor(rshift(v, 8), base[band(v, 0xFF) + 1])
		end
		t[k] = cur
	end
	return t
end

local CRC_T                          = build_crc_tables()
local CRC_T1, CRC_T2, CRC_T3, CRC_T4 = CRC_T[1], CRC_T[2], CRC_T[3], CRC_T[4]

local function crc32_update(st, s)
	local crc = st.crc
	local n = #s
	local i = 1
	local last_word = n - 3
	while i <= last_word do -- slice-by-4 word loop
		local x = bxor(crc, read_u32le(s, i))
		crc = bxor(bxor(bxor(CRC_T4[band(x, 0xFF) + 1],
					CRC_T3[band(rshift(x, 8), 0xFF) + 1]),
				CRC_T2[band(rshift(x, 16), 0xFF) + 1]),
			CRC_T1[rshift(x, 24) + 1])
		i = i + 4
	end
	while i <= n do -- 0-3 trailing bytes
		crc = bxor(CRC_T1[band(bxor(crc, string_byte(s, i)), 0xFF) + 1], rshift(crc, 8))
		i = i + 1
	end
	st.crc = crc
end

----------------------------------------------------------------------
-- Adler-32: pure integer arithmetic (no bitwise ops in the hot loop).
-- Reductions are deferred up to ADLER_NMAX bytes; the sums stay exact in
-- a Lua number (double). Inner loop unrolled 8x: the s2 line must use
-- s1 *before* the block updates it.
----------------------------------------------------------------------

local function adler32_update(st, s)
	local s1, s2 = st.s1, st.s2
	local n = #s
	local i = 1
	while i <= n do
		local block_end = i + ADLER_NMAX - 1
		if block_end > n then block_end = n end
		while i + 7 <= block_end do
			local b1, b2, b3, b4, b5, b6, b7, b8 = string_byte(s, i, i + 7)
			s2 = s2 + 8 * s1
					+ 8 * b1 + 7 * b2 + 6 * b3 + 5 * b4
					+ 4 * b5 + 3 * b6 + 2 * b7 + b8
			s1 = s1 + b1 + b2 + b3 + b4 + b5 + b6 + b7 + b8
			i = i + 8
		end
		while i <= block_end do
			s1 = s1 + string_byte(s, i)
			s2 = s2 + s1
			i = i + 1
		end
		s1 = s1 % ADLER_MOD
		s2 = s2 % ADLER_MOD
	end
	st.s1, st.s2 = s1, s2
end

----------------------------------------------------------------------
-- Streaming-hasher factory: the one shared interface for both algorithms.
-- State is a plain table; update()/reset() mutate, finish() is pure.
----------------------------------------------------------------------

local function hasher(init, update, finish)
	local H = {}
	H.__index = H

	function H.new()
		return H.reset(setmetatable({}, H))
	end

	function H.reset(self)
		init(self)
		return self
	end

	function H.update(self, s) -- s must be a string
		update(self, s)
		return self
	end

	function H.finish(self)
		return finish(self)
	end

	function H.finish_packed(self)
		return pack_u32be(finish(self))
	end

	function H.checksum(s) -- one-shot, built on the primitives
		local st = {}
		init(st)
		update(st, s)
		return finish(st)
	end

	return H
end

local crc32 = hasher(
	function(st) st.crc = 0xFFFFFFFF end,
	crc32_update,
	function(st) return to_u32(bnot(st.crc)) end)

local adler32 = hasher(
	function(st) st.s1, st.s2 = 1, 0 end,
	adler32_update,
	function(st) return to_u32(bor(lshift(st.s2, 16), st.s1)) end)

----------------------------------------------------------------------
-- Self-test: canonical vectors, bit-at-a-time reference oracles, and
-- streaming-vs-one-shot equivalence under arbitrary chunking.
----------------------------------------------------------------------

local function crc32_reference(s) -- obvious-but-slow oracle
	local crc = 0xFFFFFFFF
	for i = 1, #s do
		crc = bxor(crc, string_byte(s, i))
		for _ = 1, 8 do
			if band(crc, 1) ~= 0 then
				crc = bxor(rshift(crc, 1), CRC_POLY)
			else
				crc = rshift(crc, 1)
			end
		end
	end
	return to_u32(bnot(crc))
end

local function adler32_reference(s)
	local s1, s2 = 1, 0
	for i = 1, #s do
		s1 = (s1 + string_byte(s, i)) % ADLER_MOD
		s2 = (s2 + s1) % ADLER_MOD
	end
	return s2 * 65536 + s1
end

-- Deterministic pseudo-random blob (Numerical Recipes LCG, exact in doubles).
local function test_data(n)
	local t, x = {}, 0x20230715
	for i = 1, n do
		x = (x * 1664525 + 1013904223) % U32
		t[i] = string_char(x % 256)
	end
	return table_concat(t)
end

local function check_streaming(H, s)
	local h = H.new()
	local i, k = 1, 0
	while i <= #s do -- odd, varying chunk sizes
		local len = k % 13 + 1
		h:update(string_sub(s, i, i + len - 1))
		i = i + len
		k = k + 1
	end
	assert(h:finish() == H.checksum(s), "streaming mismatch")
	h:reset()
	assert(h:update("123456789"):finish() == H.checksum("123456789"), "reset failed")
end

local function selftest()
	-- Canonical known-answer vectors.
	assert(crc32.checksum("") == 0x00000000, "crc32('')")
	assert(crc32.checksum("a") == 0xE8B7BE43, "crc32('a')")
	assert(crc32.checksum("abc") == 0x352441C2, "crc32('abc')")
	assert(crc32.checksum("123456789") == 0xCBF43926, "crc32('123456789')")
	assert(adler32.checksum("") == 0x00000001, "adler32('')")
	assert(adler32.checksum("a") == 0x00620062, "adler32('a')")
	assert(adler32.checksum("abc") == 0x024D0127, "adler32('abc')")
	assert(adler32.checksum("123456789") == 0x091E01DE, "adler32('123456789')")

	-- Packed digests (big-endian).
	assert(crc32.new():update("123456789"):finish_packed()
		== string_char(0xCB, 0xF4, 0x39, 0x26), "crc32 finish_packed")
	assert(adler32.new():update("123456789"):finish_packed()
		== string_char(0x09, 0x1E, 0x01, 0xDE), "adler32 finish_packed")

	-- Long inputs exercise the slice-by-4 word loop, trailing bytes, and
	-- Adler's NMAX blocking. Prime length avoids coincidental alignment.
	local big = test_data(10007)
	assert(crc32.checksum(big) == crc32_reference(big), "crc32 long")
	assert(adler32.checksum(big) == adler32_reference(big), "adler32 long")
	local fox = string_rep("The quick brown fox jumps over the lazy dog", 512)
	assert(crc32.checksum(fox) == crc32_reference(fox), "crc32 fox")
	assert(adler32.checksum(fox) == adler32_reference(fox), "adler32 fox")

	-- Streaming equivalence under arbitrary chunking.
	check_streaming(crc32, big)
	check_streaming(adler32, big)
	check_streaming(crc32, fox)
	check_streaming(adler32, fox)

	-- finish() is non-consuming: updating may resume afterwards.
	local h = crc32.new():update("1234")
	local mid = h:finish()
	h:update("56789")
	assert(mid == crc32.checksum("1234"), "finish must not consume state")
	assert(h:finish() == 0xCBF43926, "resume after finish")

	return true
end

--selftest()

-- Export
return {
	crc32    = crc32,
	adler32  = adler32,
	selftest = selftest,
}
