-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for bit.lua.
-- Run from this directory:
--   lua bit.lua
--   luajit bit.lua

-- Bootstrap: make requires work from tests/ subdir with plain lua/luajit.
do
	local src = debug.getinfo(1, "S").source
	local dir = src:match("^@(.+/)[^/]+$") or "./"
	local function isfile(p)
		local f = io.open(p, "r")
		if f then
			f:close()
			return true
		end
		return false
	end
	local root
	for _, c in ipairs({ dir, dir .. "../", dir .. "../..//", dir .. "../../..//", "./", "../", "../../" }) do
		if isfile(c .. "standalone/bits.lua") then
			root = c
			break
		end
	end
	root = root or dir .. "../"
	if package then
		package.path = dir ..
				"../?.lua;" ..
				dir ..
				"../?/init.lua;" ..
				dir ..
				"?.lua;" ..
				dir ..
				"?/init.lua;" ..
				root ..
				"?.lua;" ..
				root ..
				"?/init.lua;" ..
				root ..
				"standalone/?.lua;" ..
				root ..
				"math/?.lua;" ..
				root ..
				"collections/?.lua;" ..
				root ..
				"benchmark/?.lua;" ..
				root ..
				"timer/?.lua;" ..
				root ..
				"autocompleter/?.lua;" ..
				root ..
				"permission/?.lua;" ..
				root ..
				"chat_commander/?.lua;" ..
				root .. "vm/?.lua;" .. root .. "require_finder/?.lua;" .. root .. "inventory/?.lua;" .. package.path
	end
	local searchers = package.searchers or package.loaders
	if searchers then
		table.insert(searchers, 2, function(mod)
			if mod:sub(1, 3) == "../" or mod:sub(1, 2) == "./" then
				local clean = mod:gsub("^%./", ""):gsub("^%.%.%/", ""):gsub("^%.%.%/", "")
				local tries = { dir .. "../" .. clean .. ".lua", dir .. "../" .. clean .. "/init.lua", root .. clean .. ".lua",
					root .. clean .. "/init.lua" }
				for _, f in ipairs(tries) do
					if isfile(f) then
						local chunk, err = loadfile(f)
						if chunk then return chunk, f end
					end
				end
			end
			return nil
		end)
	end
end
-- LuaJIT preloads its builtin `bit` lib into package.loaded at startup,
-- which shadows our standalone/bit.lua file. Clear it so require loads the file.
if package and package.loaded then
	package.loaded["bit"] = nil
end
if package and package.preload then
	package.preload["bit"] = nil
end
local lib = require "bit"
-- Bridging: file-locals used by tests mapped to module exports.
local ALL_ONES = lib.MAXVALUE
local HIGH_BIT = lib.HIGH_BIT
local WIDTH = lib.WIDTH
local arshift = lib.arshift
local band = lib.band
local bnot = lib.bnot
local bor = lib.bor
local bswap = lib.bswap
local btest = lib.btest
local bxor = lib.bxor
local countlz = lib.countlz
local countrz = lib.countrz
local extract = lib.extract
local frombytes = lib.frombytes
local fromhex = lib.fromhex
local getbyte = lib.getbyte
local lshift = lib.lshift
local pack_be = lib.pack_be
local pack_i16_be = lib.pack_i16_be
local pack_i16_le = lib.pack_i16_le
local pack_i8 = lib.pack_i8
local pack_le = lib.pack_le
local pack_u16_be = lib.pack_u16_be
local pack_u16_le = lib.pack_u16_le
local pack_u8 = lib.pack_u8
local popcount = lib.popcount
local replace = lib.replace
local rol = lib.rol
local ror = lib.ror
local rshift = lib.rshift
local setbyte = lib.setbyte
local tobytes = lib.tobytes
local tohex = lib.tohex
local tosigned = lib.tosigned
local tounsigned = lib.tounsigned
local unpack_be = lib.unpack_be
local unpack_i16_be = lib.unpack_i16_be
local unpack_i16_le = lib.unpack_i16_le
local unpack_i8 = lib.unpack_i8
local unpack_le = lib.unpack_le
local unpack_u16_be = lib.unpack_u16_be
local unpack_u16_le = lib.unpack_u16_le
local unpack_u8 = lib.unpack_u8
local bit = lib
local string_byte = string.byte
-- TODO(manual): the following were file-locals with no direct export;
-- verify and export or inline as needed: count, hex, left, right

if true then
	-- Test 1: Basic bitwise AND
	assert(band(0xFF, 0x0F) == 0x0F, "Test 1 failed: band(0xFF, 0x0F) should be 0x0F")

	-- Test 2: Basic bitwise OR
	assert(bor(0xF0, 0x0F) == 0xFF, "Test 2 failed: bor(0xF0, 0x0F) should be 0xFF")

	-- Test 3: Basic bitwise XOR
	assert(bxor(0xF0, 0xFF) == 0x0F, "Test 3 failed: bxor(0xF0, 0xFF) should be 0x0F")

	-- Test 4: Bitwise NOT
	assert(bnot(0x00) == 0xFFFFFFFF, "Test 4 failed: bnot(0x00) should be 0xFFFFFFFF")
	assert(bnot(0xFFFFFFFF) == 0x00000000, "Test 4a failed: bnot(0xFFFFFFFF) should be 0x00000000")

	-- Test 5: Left shift
	assert(lshift(1, 8) == 0x100, "Test 5 failed: lshift(1, 8) should be 0x100")

	-- Test 6: Right shift
	assert(rshift(0x100, 8) == 1, "Test 6 failed: rshift(0x100, 8) should be 1")

	-- Test 7: Arithmetic right shift (sign-extending)
	assert(arshift(0x80000000, 31) == 0xFFFFFFFF, "Test 7 failed: arshift(0x80000000, 31) should be 0xFFFFFFFF")

	-- Test 8: Rotate left
	assert(rol(0x80000000, 1) == 1, "Test 8 failed: rol(0x80000000, 1) should be 1")

	-- Test 9: Rotate right
	assert(ror(1, 1) == 0x80000000, "Test 9 failed: ror(1, 1) should be 0x80000000")

	-- Test 10: Bit test
	assert(btest(0xFF, 0x0F) == true, "Test 10 failed: btest(0xFF, 0x0F) should be true")
	assert(btest(0xF0, 0x0F) == false, "Test 10a failed: btest(0xF0, 0x0F) should be false")

	-- Test 11: Extract bit field
	assert(extract(0xFF00FF00, 8, 8) == 0xFF, "Test 11 failed: extract(0xFF00FF00, 8, 8) should be 0xFF")

	-- Test 12: Replace bit field
	assert(replace(0x00000000, 0xFF, 8, 16) == 0x00FF0000,
		"Test 12 failed: replace(0x00000000, 0xFF, 8, 16) should be 0x00FF0000")

	-- Test 13: Count leading zeros
	assert(countlz(0x80000000) == 0, "Test 13 failed: countlz(0x80000000) should be 0")
	assert(countlz(1) == 31, "Test 13a failed: countlz(1) should be 31")
	assert(countlz(0) == 32, "Test 13b failed: countlz(0) should be 32")

	-- Test 14: Count trailing zeros
	assert(countrz(1) == 0, "Test 14 failed: countrz(1) should be 0")
	assert(countrz(0x80000000) == 31, "Test 14a failed: countrz(0x80000000) should be 31")
	assert(countrz(0) == 32, "Test 14b failed: countrz(0) should be 32")

	-- Test 15: Population count
	assert(popcount(0xFF00FF00) == 16, "Test 15 failed: popcount(0xFF00FF00) should be 16")
	assert(popcount(0xFFFFFFFF) == 32, "Test 15a failed: popcount(0xFFFFFFFF) should be 32")

	-- Test 16: Byte swap
	assert(bswap(0x11223344) == 0x44332211, "Test 16 failed: bswap(0x11223344) should be 0x44332211")

	-- Test 17: Get byte
	assert(getbyte(0x11223344, 0) == 0x44, "Test 17 failed: getbyte(0x11223344, 0) should be 0x44")
	assert(getbyte(0x11223344, 3) == 0x11, "Test 17a failed: getbyte(0x11223344, 3) should be 0x11")

	-- Test 18: Set byte
	assert(setbyte(0x00000000, 0xFF, 0) == 0x000000FF,
		"Test 18 failed: setbyte(0x00000000, 0xFF, 0) should be 0x000000FF")

	-- Test 19: To signed
	assert(tosigned(0xFFFFFFFF) == -1, "Test 19 failed: tosigned(0xFFFFFFFF) should be -1")
	assert(tosigned(0x7FFFFFFF) == 2147483647, "Test 19a failed: tosigned(0x7FFFFFFF) should be 2147483647")

	-- Test 20: To unsigned
	assert(tounsigned(-1) == 0xFFFFFFFF, "Test 20 failed: tounsigned(-1) should be 0xFFFFFFFF")

	-- Test 21: From bytes
	assert(frombytes(0x44, 0x33, 0x22, 0x11) == 0x11223344, "Test 21 failed: frombytes should equal 0x11223344")

	-- Test 22: To bytes
	local b0, b1, b2, b3 = tobytes(0x11223344)
	assert(b0 == 0x44 and b1 == 0x33 and b2 == 0x22 and b3 == 0x11, "Test 22 failed: tobytes should return correct bytes")

	-- Test 23: To hex
	assert(tohex(0xDEADBEEF) == "0xDEADBEEF", "Test 23 failed: tohex(0xDEADBEEF) should be '0xDEADBEEF'")
	assert(tohex(0xDEADBEEF, false) == "DEADBEEF", "Test 23a failed: tohex without prefix should be 'DEADBEEF'")

	-- Test 24: From hex
	assert(fromhex("0xDEADBEEF") == 0xDEADBEEF, "Test 24 failed: fromhex('0xDEADBEEF') should be 0xDEADBEEF")
	assert(fromhex("DEADBEEF") == 0xDEADBEEF, "Test 24a failed: fromhex('DEADBEEF') should be 0xDEADBEEF")

	-- Test 25: Pack little-endian
	local packed_le = pack_le(0x11223344)
	assert(#packed_le == 4, "Test 25 failed: pack_le should return 4 bytes")
	assert(unpack_le(packed_le) == 0x11223344, "Test 25a failed: unpack_le should restore original value")

	-- Test 26: Pack big-endian
	local packed_be = pack_be(0x11223344)
	assert(#packed_be == 4, "Test 26 failed: pack_be should return 4 bytes")
	assert(unpack_be(packed_be) == 0x11223344, "Test 26a failed: unpack_be should restore original value")

	-- Test 27: Constants
	assert(WIDTH == 32, "Test 27 failed: WIDTH should be 32")
	assert(ALL_ONES == 0xFFFFFFFF, "Test 27a failed: ALL_ONES should be 0xFFFFFFFF")
	assert(HIGH_BIT == 0x80000000, "Test 27b failed: HIGH_BIT should be 0x80000000")

	-- Test 28: Pack/unpack i8
	local packed_i8_pos = pack_i8(127)
	assert(#packed_i8_pos == 1, "Test 28 failed: pack_i8 should return 1 byte")
	assert(unpack_i8(packed_i8_pos) == 127, "Test 28a failed: unpack_i8 should restore 127")
	local packed_i8_neg = pack_i8(-128)
	assert(unpack_i8(packed_i8_neg) == -128, "Test 28b failed: unpack_i8 should restore -128")
	local packed_i8_zero = pack_i8(0)
	assert(unpack_i8(packed_i8_zero) == 0, "Test 28c failed: unpack_i8 should restore 0")

	-- Test 29: Pack/unpack u8
	local packed_u8 = pack_u8(255)
	assert(#packed_u8 == 1, "Test 29 failed: pack_u8 should return 1 byte")
	assert(unpack_u8(packed_u8) == 255, "Test 29a failed: unpack_u8 should restore 255")
	assert(unpack_u8(pack_u8(0)) == 0, "Test 29b failed: unpack_u8 should restore 0")

	-- Test 30: Pack/unpack i16 little-endian
	local packed_i16_le_pos = pack_i16_le(32767)
	assert(#packed_i16_le_pos == 2, "Test 30 failed: pack_i16_le should return 2 bytes")
	assert(unpack_i16_le(packed_i16_le_pos) == 32767, "Test 30a failed: unpack_i16_le should restore 32767")
	local packed_i16_le_neg = pack_i16_le(-32768)
	assert(unpack_i16_le(packed_i16_le_neg) == -32768, "Test 30b failed: unpack_i16_le should restore -32768")
	assert(unpack_i16_le(pack_i16_le(0)) == 0, "Test 30c failed: unpack_i16_le should restore 0")

	-- Test 31: Pack/unpack i16 big-endian
	local packed_i16_be_pos = pack_i16_be(32767)
	assert(#packed_i16_be_pos == 2, "Test 31 failed: pack_i16_be should return 2 bytes")
	assert(unpack_i16_be(packed_i16_be_pos) == 32767, "Test 31a failed: unpack_i16_be should restore 32767")
	local packed_i16_be_neg = pack_i16_be(-32768)
	assert(unpack_i16_be(packed_i16_be_neg) == -32768, "Test 31b failed: unpack_i16_be should restore -32768")
	assert(unpack_i16_be(pack_i16_be(0)) == 0, "Test 31c failed: unpack_i16_be should restore 0")

	-- Test 32: Pack/unpack u16 little-endian
	local packed_u16_le = pack_u16_le(65535)
	assert(#packed_u16_le == 2, "Test 32 failed: pack_u16_le should return 2 bytes")
	assert(unpack_u16_le(packed_u16_le) == 65535, "Test 32a failed: unpack_u16_le should restore 65535")
	assert(unpack_u16_le(pack_u16_le(0)) == 0, "Test 32b failed: unpack_u16_le should restore 0")

	-- Test 33: Pack/unpack u16 big-endian
	local packed_u16_be = pack_u16_be(65535)
	assert(#packed_u16_be == 2, "Test 33 failed: pack_u16_be should return 2 bytes")
	assert(unpack_u16_be(packed_u16_be) == 65535, "Test 33a failed: unpack_u16_be should restore 65535")
	assert(unpack_u16_be(pack_u16_be(0)) == 0, "Test 33b failed: unpack_u16_be should restore 0")

	-- Test 34: Endianness difference for 16-bit
	local val = 0x1234
	local le = pack_u16_le(val)
	local be = pack_u16_be(val)
	assert(le ~= be, "Test 34 failed: LE and BE should produce different byte order")
	assert(string_byte(le, 1) == 0x34 and string_byte(le, 2) == 0x12, "Test 34a failed: LE byte order incorrect")
	assert(string_byte(be, 1) == 0x12 and string_byte(be, 2) == 0x34, "Test 34b failed: BE byte order incorrect")

	print("All tests passed!")
end
